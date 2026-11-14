--!nocheck
-- Client side of private dungeons. The server keeps the run state + one part-less stand-in per enemy in
-- PlayerGui.AimRngRun (see DungeonRuns); this module builds the floor locally (seeded map) and the real
-- enemy for every stand-in, then keeps them in sync:
--   * stand-in attributes (Health, SlowMult, statuses, shields, Dead) are mirrored onto the local enemy
--   * a removed stand-in removes the enemy (Dead = killed: Volatile blasts / death fx still play)
--   * enemy positions are reported ~6x a second (server area effects and hit checks use them)
--   * FloorCleared builds the victory chest + portal; RaidActive = false tears the floor down
-- It also hides other players while you or they are inside a dungeon (everyone's private dungeon sits
-- at the same coordinates).
--
--   DungeonClient.Init({ Teleport = fn(CFrame) })
--   DungeonClient.EnterFloor(biome, difficulty, floor) -> true when the floor is built and you're in it
--   DungeonClient.OnFloorBuilt = fn(info)  -- after every floor is built here (info: Biome, Difficulty, FloorNumber...)
--   DungeonClient.ProxyForPart(part) -> stand-in, partName  (for hit reports), or nil
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(script.Parent:WaitForChild("ItemData"))
local DungeonGenerator = require(Shared:WaitForChild("DungeonGenerator"))
local DungeonEvents = require(Shared:WaitForChild("DungeonEvents"))
local Encounters = require(script.Parent:WaitForChild("Encounters")) -- (UPDATE 7 run encounters)
local PartyTwin = require(script.Parent:WaitForChild("PartyTwin")) -- (party floors: your own full-detail copy)
local eventConn: RBXScriptConnection? = nil -- the current floor's event-state watcher

local LocalPlayer = Players.LocalPlayer
local DungeonClient = {}

local opts: any = {}
local runFolder: Folder? = nil
local currentConfig: any = nil
local dungeon: Instance? = nil
local built = false
local builtToken = nil -- RunToken of the floor currently built here
local BuildFloor: (info: any) -> () = nil :: any
local byProxy: { [Instance]: Model } = {}
local proxyOf: { [Model]: Instance } = {}
local proxyConns: { [Instance]: { RBXScriptConnection } } = {}

local MIRRORED = {
    Health = true, SlowMult = true, DamageTakenMult = true, Dead = true,
    Burning = true, Chilled = true, Bleeding = true, Decayed = true,
    Orb1 = true, Orb2 = true, Orb3 = true, Orb4 = true, Orb5 = true, Orb6 = true, -- (boss shield orbs: hits counted by the server, BossAI reads them)
    Orb7 = true, Orb8 = true, Orb9 = true, -- (0.62 tracking rounds: BossAI TRACK targets)
    Exposed = true, -- (0.63: the EXPOSED bot -- BossCues marks it)
    Awake = true, -- (LINKED ROOMS pilot: the server woke this bot's pack)
    Homing = true, -- (LINKED ROOMS v3: past the awake cap -- walking home)
    ShellHp = true, ShellMax = true, StaggerUntil = true, -- (ENEMY ATTACKS PILOT: the Shelled elite's shell (server-side) + its stagger)
    RaiseAt = true, RaisePos = true, -- (ENEMY VARIETY 2026-11-07: a raiser's raise, decided by the server -- the beam is the tell)
}

local merchantConn: RBXScriptConnection? = nil -- (wandering merchant stall: its stock listener)
local encounterConn: RBXScriptConnection? = nil -- (UPDATE 7: the run encounter's state listener)
local function SplitMods(s: string?): { string }?
    if not s or s == "" then return nil end
    return string.split(s, ",")
end

local function UpdateBar(model: Model)
    local hud = model:FindFirstChild("HealthHUD")
    local bg = hud and hud:FindFirstChild("Background")
    local fill = bg and bg:FindFirstChild("Fill")
    local h, mh = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
    if fill and fill:IsA("Frame") and type(h) == "number" and type(mh) == "number" and mh > 0 then
        fill.Size = UDim2.new(math.clamp(h / mh, 0, 1), 0, 1, 0)
    end
end

-- (2026-10-14, owner: "why do enemies lose their outlines sometimes"): Roblox draws ONE Highlight per model, so a separate
-- flash Highlight hid the enemy's outline (AimRngOutline, AimRngClient ENEMY VISUALS) on every hit -- nearly all the time
-- with a fast gun -- and every extra one counted against the 31 on screen. With an outline the flash lights ITS fill.
local function HitFlash(model: Model)
    local outline = model:FindFirstChild("AimRngOutline")
    if outline and outline:IsA("Highlight") then
        if outline:GetAttribute("FlashUntil") == nil then
            outline:SetAttribute("BaseFill", outline.FillColor)
            outline:SetAttribute("BaseFillT", outline.FillTransparency)
        end
        local untilT = os.clock() + 0.08
        outline:SetAttribute("FlashUntil", untilT)
        outline.FillColor = Color3.new(1, 1, 1)
        outline.FillTransparency = math.min(0.6, outline:GetAttribute("BaseFillT") or 1)
        task.delay(0.08, function()
            if outline.Parent and outline:GetAttribute("FlashUntil") == untilT then
                outline.FillColor = outline:GetAttribute("BaseFill") or outline.FillColor
                outline.FillTransparency = outline:GetAttribute("BaseFillT") or outline.FillTransparency
                outline:SetAttribute("FlashUntil", nil)
            end
        end)
        return
    end
    if model:FindFirstChild("HitFlash") then return end
    local hl = Instance.new("Highlight")
    hl.Name = "HitFlash"
    hl.FillColor = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 1
    hl.Parent = model
    Debris:AddItem(hl, 0.08)
end

local EnemyAnim = require(script.Parent:WaitForChild("EnemyAnim"))
local function DeathPop(model: Model)
    pcall(EnemyAnim.Death, model) -- (0.53: it breaks apart; the pop stays as the flash)
    local pos = model:GetPivot().Position
    local ball = Instance.new("Part")
    ball.Name = "DeathPop"
    ball.Shape = Enum.PartType.Ball
    ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
    ball.Material = Enum.Material.Neon
    local torso = model:FindFirstChild("Torso")
    ball.Color = (torso and torso:IsA("BasePart")) and torso.Color or Color3.new(1, 0.6, 0.3)
    ball.Size = Vector3.one * 2
    ball.CFrame = CFrame.new(pos)
    ball.Transparency = 0.3
    ball.Parent = Workspace
    TweenService:Create(ball, TweenInfo.new(0.25), { Size = Vector3.one * 6, Transparency = 1 }):Play()
    Debris:AddItem(ball, 0.3)
end

-- PREDICTED HITS (owner 2026-10-03: "when you hit / kill an enemy, its slightly delayed"). The server still decides the
-- damage; this only shows it at once. The flash and the health bar move the instant you hit, and a shot that's clearly
-- lethal plays the death right away (the enemy is hidden and stops attacking). The server's numbers then take over; a
-- predicted kill the server hasn't confirmed within 1.2 s puts the enemy back.
local predictedHidden: { [Model]: { [BasePart]: boolean } } = {}
local predictedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) -- (the last predicted hit on a model: health resync)
local function Unhide(model: Model)
    local st = predictedHidden[model]
    if not st then return end
    predictedHidden[model] = nil
    for p, q in pairs(st) do if p.Parent then p.LocalTransparencyModifier = 0; p.CanQuery = q end end
    model:SetAttribute("PredictedDead", nil)
    model:SetAttribute("AnimDied", nil) -- (a predicted kill the server didn't confirm: animate it again)
    EnemyAnim.Track(model)
end
function DungeonClient.PredictHit(part: Instance?, damage: number?)
    local node = part
    local model: Model? = nil
    while node and node ~= Workspace do
        if node:IsA("Model") and node:GetAttribute("Health") ~= nil then model = node :: Model break end
        node = node.Parent
    end
    if not model or model:GetAttribute("PredictedDead") then return end
    HitFlash(model)
    local proxy = proxyOf[model]
    if not proxy or not damage or damage <= 0 then return end -- (party bots: just the flash -- the server runs them)
    -- (ENEMY ATTACKS PILOT, review C) a SHELLED elite's shell soaks hits first on the server: predicting them off its life faked a
    -- kill mid-fight. While its shell holds (mirrored ShellHp), only the flash -- the server's numbers follow.
    if model:GetAttribute("ShellType") then
        local sh = model:GetAttribute("ShellHp")
        if sh == nil or sh > 0 then return end
    end
    local hp = model:GetAttribute("Health")
    if type(hp) ~= "number" then return end
    local left = math.max(0, hp - damage)
    model:SetAttribute("Health", left)
    UpdateBar(model)
    -- (2026-10-26 sweep: a hit the server refused -- e.g. on a bot still warping in -- left the predicted health on the model for
    -- good: a "dead" bot at 0 that still attacked and kept the exit room shut. Once you've stopped hitting it for 1.2 s, the
    -- server's health takes over again)
    predictedAt[model] = os.clock()
    task.delay(1.25, function()
        if not model.Parent or not proxy.Parent or proxy:GetAttribute("Dead") then return end
        if os.clock() - (predictedAt[model] or 0) < 1.2 then return end
        local v = proxy:GetAttribute("Health")
        if type(v) == "number" and v > 0 and model:GetAttribute("Health") ~= v then
            model:SetAttribute("Health", v)
            UpdateBar(model)
        end
    end)
    if left <= 0 and not model:GetAttribute("IsBoss") and not model:GetAttribute("IsMiniBoss") then
        model:SetAttribute("PredictedDead", true)
        DeathPop(model)
        local st = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then st[d] = d.CanQuery; d.LocalTransparencyModifier = 1; d.CanQuery = false end
        end
        predictedHidden[model] = st
        task.delay(1.2, function()
            if model.Parent and proxy.Parent and not proxy:GetAttribute("Dead") then Unhide(model) end
        end)
    end
end

local function RemoveEnemy(proxy: Instance)
    local model = byProxy[proxy]
    for _, c in ipairs(proxyConns[proxy] or {}) do c:Disconnect() end
    proxyConns[proxy] = nil
    byProxy[proxy] = nil
    if model then
        proxyOf[model] = nil
        if proxy:GetAttribute("Dead") then
            model:SetAttribute("Dead", true) -- lets a Volatile elite go off where it died
            if not model:GetAttribute("PredictedDead") then DeathPop(model) end -- (a predicted kill already popped)
        end
        predictedHidden[model] = nil
        model:Destroy()
    end
end

local function SpawnEnemy(proxy: Instance)
    if byProxy[proxy] or not built or not dungeon or not currentConfig then return end
    if proxy:GetAttribute("Dead") then return end
    if DungeonClient.LinkedHold and DungeonClient.LinkedHold(proxy) then return end -- (LINKED ROOMS v4: not drawn until you near its room)
    local kind = proxy:GetAttribute("Kind")
    local spawnPos = proxy:GetAttribute("SpawnPos") or Vector3.new(0, 10, 600)
    local spec = {
        EnemyId = proxy:GetAttribute("EnemyId"),
        Element = proxy:GetAttribute("Element"),
        MaxHealth = proxy:GetAttribute("MaxHealth"),
        AttackDamage = proxy:GetAttribute("AttackDamage"),
        NoAura = proxy:GetAttribute("Fodder") == true, -- (PACK SIZE BY DIFFICULTY: no element aura on fodder)
        EliteTier = proxy:GetAttribute("EliteTier"), -- (FUTURE-PROOF: the server's rolled tier, never re-counted from the mods)
    }
    local lroom = proxy:GetAttribute("LinkRoom")
    if lroom and currentConfig.Linked and proxy:GetAttribute("LinkPack") then -- (LINKED ROOMS pilot: leashed to its room, idle at its spot)
        local LR = DungeonGenerator.LR
        local L = DungeonGenerator.LinkedLayout(currentConfig)
        local lpath = proxy:GetAttribute("LinkPath")
        if L.Rooms[lroom] then -- (v3: its home boxes (room / path) and its chase area one link out)
            local home, chase, hbb, cbb = LR.LeashBoxes(L, lroom, lpath)
            spec.Link = { X0 = hbb[1], X1 = hbb[2], Z0 = hbb[3], Z1 = hbb[4], Home = spawnPos, Pack = proxy:GetAttribute("LinkPack"),
                HomeBoxes = home, Chase = chase, HomeBB = hbb, ChaseBB = cbb, Near = LR.NearBoxes(L, lroom, lpath) } -- (BOTFIX: Near = distance wakes)
        end
    end
    local pos = DungeonGenerator.FindOpenSpot(spawnPos, 3)
    local ok, model = pcall(DungeonGenerator.CreateOfKind, kind, proxy:GetAttribute("Archetype"), SplitMods(proxy:GetAttribute("EliteMods")), pos, currentConfig, dungeon, spec)
    if not ok or not model then
        warn("[DungeonClient] couldn't build enemy " .. tostring(kind) .. ": " .. tostring(model))
        return
    end
    model:SetAttribute("LocalSim", true)
    if lroom and currentConfig.Linked then model:SetAttribute("NoXRay", true) end -- (BOTFIX: no outline through the rock until the 0.2 s area pass says it's yours)
    byProxy[proxy] = model
    proxyOf[model] = proxy
    -- start from the server's current values
    for k in pairs(MIRRORED) do
        local v = proxy:GetAttribute(k)
        if v ~= nil or k == "DamageTakenMult" then model:SetAttribute(k, v) end
    end
    UpdateBar(model)
    -- (2026-10-26 ARRIVAL FX) a room made as you walk into it warps its bots in (ring, shaft, fade) instead of popping them in --
    -- after the mirrored values above (their SlowMult would undo the hold)
    if lroom and currentConfig.Linked then
        local AFx = require(Shared:WaitForChild("ArrivalFx"))
        if AFx.ShouldPlay(proxy) then AFx.Play(model, AFx.Colour(dungeon:GetAttribute("Biome") or currentConfig.Biome), true, proxy:GetAttribute("WarpIn")) end -- (true: held still while it forms)
    end
    -- BOUNTY objective (FloorObjectives): a gold skull over the marked target, gone when the mark comes off
    local function BountyMark()
        local old = model:FindFirstChild("BountyMark")
        if proxy:GetAttribute("Bounty") ~= true then if old then old:Destroy() end return end
        if old then return end
        local bb = Instance.new("BillboardGui")
        bb.Name = "BountyMark"
        bb.Size = UDim2.fromOffset(46, 46)
        bb.StudsOffset = Vector3.new(0, model:GetExtentsSize().Y * 0.5 + 2.6, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 400
        bb.Parent = model
        -- (0.61f) the custom skull icon, not the Roblox emoji (which ignores the gold tint)
        local t = Instance.new("ImageLabel")
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundTransparency = 1
        t.Image = require(script.Parent:WaitForChild("UIStyle")).Icons.lostgear
        t.ImageColor3 = Color3.fromRGB(255, 205, 80)
        t.ScaleType = Enum.ScaleType.Fit
        t.Parent = bb
        -- (UPDATE 7 BOUNTY CONTRACT: its name under the skull, and its flee countdown once hit)
        local cname = proxy:GetAttribute("ContractName")
        if type(cname) == "string" and cname ~= "" then
            bb.Size = UDim2.fromOffset(220, 74)
            t.Size = UDim2.fromOffset(46, 46); t.Position = UDim2.new(0.5, -23, 0, 0)
            local n = Instance.new("TextLabel")
            n.BackgroundTransparency = 1; n.Position = UDim2.fromOffset(0, 46); n.Size = UDim2.new(1, 0, 0, 26)
            n.Font = Enum.Font.GothamBlack; n.TextSize = 15; n.TextColor3 = Color3.fromRGB(255, 205, 80)
            n.TextStrokeTransparency = 0.4; n.Text = string.upper(cname); n.Parent = bb
            task.spawn(function()
                while bb.Parent do
                    local at = proxy:GetAttribute("FleeAt")
                    if type(at) == "number" then
                        n.Text = string.upper(cname) .. string.format("  %.1fs", math.max(0, at - workspace:GetServerTimeNow()))
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
    BountyMark()
    local conns = {}
    table.insert(conns, proxy.AttributeChanged:Connect(function(k)
        if k == "Bounty" then BountyMark() return end
        if not MIRRORED[k] then return end
        local v = proxy:GetAttribute(k)
        if k == "Health" then
            local old = model:GetAttribute("Health")
            model:SetAttribute("Health", v)
            UpdateBar(model)
            if type(old) == "number" and type(v) == "number" and v < old then HitFlash(model) end
        else
            model:SetAttribute(k, v)
        end
    end))
    table.insert(conns, proxy.AncestryChanged:Connect(function(_, parent)
        if parent == nil then RemoveEnemy(proxy) end
    end))
    proxyConns[proxy] = conns
end

-- ==================== LINKED ROOMS PILOT (client; docs/LINKED_ROOMS.md, AimRngShared/LinkedRooms) ====================
-- On a linked floor (FloorInfo.Linked): the rooms past room 1 that you're not in and not within PARK_DIST of are
-- PARKED (their folders -- dungeon.LinkedRooms.R<i> + StaticGeometry.LinkGeo<i> -- leave the workspace; terrain stays), a small
-- line under the floor banner says where you are ("ROOM 2 / 4", the exit room's count), an arrow at the screen edge points
-- to the next doorway while it's off screen (nothing near the crosshair), and the side room's cache chest opens once the
-- server says its packs are dead (folder attr LinkCache).
local linked: any = { Token = 0 }
-- (v3 perf) enemies of a room that spawns mid-floor: built CLIENT_SPAWN_PER_FRAME a frame (one Heartbeat drain, idle when empty)
local spawnQ: { Instance } = {}
local spawnConn: RBXScriptConnection? = nil
function DungeonClient.QueueSpawn(proxy: Instance)
    table.insert(spawnQ, proxy)
    if spawnConn then return end
    spawnConn = RunService.Heartbeat:Connect(function()
        local n = DungeonGenerator.LR.CLIENT_SPAWN_PER_FRAME
        while n > 0 and #spawnQ > 0 do
            local p = table.remove(spawnQ, 1)
            if p.Parent then SpawnEnemy(p); n -= 1 end
        end
        if #spawnQ == 0 and spawnConn then spawnConn:Disconnect(); spawnConn = nil end
    end)
end
-- (Studio test hook for tools/autoplay.luau) Player attr DevLinked = this floor's layout as text:
--   "H=<half>;R=<i>,<Kind>,<x>,<z>|...;P=<a>,<b>,<x>,<z>,<x>,<z>,<x>,<z>,<x>,<z>|...;F=<solo|party>"
--   each path = its 4 dogleg centre-line waypoints from room a's door to room b's (out of a's door, the leg's two corners, into b)
function DungeonClient.DevLinkedExport(L: any, party: boolean?)
    local LR = DungeonGenerator.LR
    local rs, ps = {}, {}
    for i, r in ipairs(L.Rooms) do table.insert(rs, string.format("%d,%s,%.1f,%.1f", i, r.Kind, r.X, r.Z)) end
    for _, p in ipairs(L.Paths) do
        local pts = {}
        for _, uv in ipairs({ { -4, 0 }, { p.Len / 2, 0 }, { p.Len / 2, p.Off }, { p.Len + 4, p.Off } }) do
            local x, _, z = LR.PathRect(p, uv[1], uv[1], uv[2], uv[2])
            table.insert(pts, string.format("%.1f,%.1f", x, z))
        end
        table.insert(ps, p.A .. "," .. p.B .. "," .. table.concat(pts, ","))
    end
    LocalPlayer:SetAttribute("DevLinked", "H=" .. L.Half .. ";R=" .. table.concat(rs, "|") .. ";P=" .. table.concat(ps, "|") .. ";F=" .. (party and "party" or "solo"))
end

function DungeonClient.LinkedStop()
    linked.Token += 1
    if game:GetService("RunService"):IsStudio() then LocalPlayer:SetAttribute("DevLinked", nil) end
    if linked.Gui then linked.Gui.Enabled = false end
    if linked.CacheConn then linked.CacheConn:Disconnect(); linked.CacheConn = nil end
    if linked.WarpConn then linked.WarpConn:Disconnect(); linked.WarpConn = nil end
    if linked.SealDir then linked.SealDir:ClearAllChildren() end -- (SEALED ROOMS: the barriers go with the floor)
    for _, rm in pairs(linked.Rooms or {}) do -- (parked folders aren't under the floor any more: they go with it by hand)
        if not rm.Shown then
            if linked.Party then -- (a party floor's folders are the server's: back where they were if the floor is still there)
                if linked.Folder then PartyTwin.Park(linked.Folder, rm.Index, true) end -- (PARTY TWIN: the copy's too)
                if rm.Vis and rm.VisParent and rm.VisParent.Parent then rm.Vis.Parent = rm.VisParent end
                if rm.Geo and rm.GeoParent and rm.GeoParent.Parent then rm.Geo.Parent = rm.GeoParent end
            else
                if rm.Vis then rm.Vis:Destroy() end
                if rm.Geo then rm.Geo:Destroy() end
            end
        end
    end
    for m, home in pairs(linked.Held or {}) do -- (party: bots held back from an unrevealed room)
        if m.Parent and home.Parent then m.Parent = home end
    end
    linked.Rooms = nil
    linked.Revealed, linked.Hold, linked.Held, linked.Party, linked.Folder = nil, nil, nil, nil, nil
    linked.ExitMax = nil
end
-- (v4 VISIBILITY) a linked room's enemies are only BUILT here once the room is revealed -- you're inside it or on a path into it
-- (room 1: from the start) -- or once the server has them awake (chasing you); until then their stand-ins wait in linked.Hold
function DungeonClient.LinkedHold(proxy: Instance): boolean
    if not linked.Revealed or not currentConfig or not currentConfig.Linked then return false end
    local lr = proxy:GetAttribute("LinkRoom")
    if not lr or linked.Revealed[lr] or proxy:GetAttribute("Awake") == true then return false end
    linked.Hold[lr] = linked.Hold[lr] or {}
    table.insert(linked.Hold[lr], proxy)
    return true
end

local function LinkedHud(): (ScreenGui, TextLabel, TextLabel)
    if linked.Gui and linked.Gui.Parent then return linked.Gui, linked.Label, linked.Arrow end
    local UIStyle = require(Shared:WaitForChild("UIStyle"))
    local C = UIStyle.Colors
    local gui = Instance.new("ScreenGui")
    gui.Name = "LinkedRoomsHud"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    -- (UI CLEAN R-C: under the windows -- at 4 it drew over every open window (the MENU, OUT OF LIVES); the HUD's own lines
    -- read over it the way the minimap does)
    gui.DisplayOrder = -1
    gui.Enabled = false
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Where"
    lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.Position = UDim2.new(0.5, 0, 0, 160) -- (under the floor banner, the safe-zone line and the floor modifiers)
    lbl.Size = UDim2.fromOffset(380, 26)
    lbl.Text = ""
    lbl.Parent = gui
    do -- (UI CLEAN R-C: the run HUD plate (AimRngShared/RunHud) -- display caps 14 in Text, no stroke)
        local RH = require(Shared:WaitForChild("RunHud"))
        RH.Plate(lbl)
        RH.Role(lbl, "SectionHead")
        lbl.TextSize = 14
    end
    local tick = Instance.new("Frame") -- (SEALED ROOMS: the room's PROGRESS LINE -- a faint 2 px track, the fill in Text; Good once open)
    tick.Name = "Tick"
    tick.BorderSizePixel = 0
    tick.BackgroundColor3 = C.Text
    tick.BackgroundTransparency = 0.86
    tick.Size = UDim2.new(1, 0, 0, 2)
    tick.Position = UDim2.new(0, 0, 1, -2)
    tick.Parent = lbl
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = C.Text
    fill.Size = UDim2.fromScale(1, 1)
    fill.Parent = tick
    linked.Fill, linked.FillAt, linked.FillCol = fill, 1, C.Text
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Size = UDim2.fromOffset(34, 34)
    arrow.BackgroundTransparency = 1
    arrow.Font = Enum.Font.GothamBlack
    arrow.TextSize = 30
    arrow.TextColor3 = C.Neon
    arrow.TextStrokeTransparency = 0.35
    arrow.TextStrokeColor3 = C.Ink
    arrow.Text = "▲"
    arrow.Visible = false
    arrow.Parent = gui
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    linked.Gui, linked.Label, linked.Arrow = gui, lbl, arrow
    return gui, lbl, arrow
end

-- f = the floor folder; cfgL / party: a PARTY floor (server-built: its folder, a config rebuilt from the folder's attrs)
function DungeonClient.LinkedStart(f: Folder, cfgL: any?, party: boolean?)
    DungeonClient.LinkedStop()
    cfgL = cfgL or currentConfig
    if not cfgL or not cfgL.Linked or not (dungeon or party) then return end
    local LR = DungeonGenerator.LR
    local L = DungeonGenerator.LinkedLayout(cfgL)
    local token = linked.Token
    if game:GetService("RunService"):IsStudio() then DungeonClient.DevLinkedExport(L, party) end -- (tools/autoplay.luau reads the route)
    local myDungeon = party and f or dungeon
    local function Live(): boolean
        if party then return f.Parent ~= nil end
        return dungeon == myDungeon
    end
    local geo = myDungeon:FindFirstChild("StaticGeometry")
    local lr = myDungeon:FindFirstChild("LinkedRooms")
    local rooms = {}
    for i = 2, #L.Rooms do
        rooms[i] = { Index = i, Vis = lr and lr:FindFirstChild("R" .. i), Geo = geo and geo:FindFirstChild("LinkGeo" .. i), Shown = true, VisParent = lr, GeoParent = geo }
    end
    linked.Rooms = rooms
    linked.Party = party == true
    linked.Folder = party and f or nil
    linked.Held = {}
    local holder = nil
    if party then
        holder = game:GetService("ReplicatedStorage"):FindFirstChild("LinkedHeldBots") or Instance.new("Folder")
        holder.Name = "LinkedHeldBots"
        holder.Parent = game:GetService("ReplicatedStorage")
    end
    linked.Revealed, linked.Hold = { [1] = true }, {}
    linked.RevealAfter = os.clock() + 1.5 -- (the teleport into the entry room lands first: no reveal from where you stood on the floor before)
    -- the side room's cache (built a moment later: a raycast doesn't see the terrain written this frame)
    task.delay(0.2, function()
        if linked.Token ~= token or not Live() or party then return end -- (party: the server's cache chest)
        local side = L.Side and rooms[L.Side]
        local chest, open, prompt = DungeonGenerator.BuildLinkCache(myDungeon, currentConfig, side and side.Vis)
        if not chest then return end
        local opened = false
        local function Show()
            local st = f:GetAttribute("LinkCache") or ""
            if prompt then
                prompt.Enabled = st == "OPEN"
                prompt.ObjectText = (st == "OPEN") and "HIDDEN CACHE" or "HIDDEN CACHE (guarded)"
            end
            if st == "USED" and open and not opened then opened = true; open() end
        end
        if prompt then
            prompt.Triggered:Connect(function(plr)
                if plr ~= LocalPlayer then return end
                prompt.Enabled = false
                Remotes.GetEvent("OpenChest"):FireServer("LinkCache")
            end)
        end
        linked.CacheConn = f:GetAttributeChangedSignal("LinkCache"):Connect(Show)
        Show()
    end)
    local gui, lbl, arrow = LinkedHud()
    gui.Enabled = true
    local LMap = require(Shared:WaitForChild("MiniMap")) -- (QOL M1: the minimap's rooms-visited note, below)
    -- (2026-10-26 ARRIVAL FX) party floors: the server's bots land in the floor folder -- the ones made on arrival warp in here too
    if party then
        if linked.WarpConn then linked.WarpConn:Disconnect() end
        local AFx = require(Shared:WaitForChild("ArrivalFx"))
        local warpCol = AFx.Colour(f:GetAttribute("Biome") or (cfgL and cfgL.Biome))
        linked.WarpConn = f.ChildAdded:Connect(function(m)
            if not m:IsA("Model") then return end
            task.defer(function() -- (its parts and attributes arrive with it; one defer lets them land)
                if m.Parent and AFx.ShouldPlay(m) then AFx.Play(m, warpCol, nil, m:GetAttribute("WarpIn")) end
            end)
        end)
    end
    -- (SEALED ROOMS, LinkedRooms SEAL) a barrier across each sealed room's way on (attr LinkSeal = "<room>:<left>,..."), solid to you and
    -- your shots, in the floor's accent colour; it fades out the moment the room is clear. Client-side on solo and party floors alike.
    local sealDir = Workspace:FindFirstChild("LinkSeals") or Instance.new("Folder")
    sealDir.Name = "LinkSeals"
    sealDir.Parent = Workspace
    sealDir:ClearAllChildren()
    linked.SealDir = sealDir
    local sealCol: Color3? = nil
    -- (2026-10-26 SEAL GATE, owner: the barriers "look very lazy and bad, clip through the world ... no progress bar"): a gate frame
    -- set into the doorway (AimRngShared/SealGate) whose header shows the room's count + bar and whose beams go dark as it empties
    local SealGate = require(Shared:WaitForChild("SealGate"))
    local gates = {}
    linked.Gates = gates
    local function SyncSeals(sealed: { [number]: number }, sealTot: { [number]: number }?)
        if not sealCol then
            -- (owner: "make sure the beam's colors match the environment") the biome's SIGNATURE colour -- the one its rooms' light
            -- pools, motes and lava glow are drawn in (RoomAtmo.LOOK[biome].Sig) -- else the theme's accent
            local biome = myDungeon:GetAttribute("Biome")
            local ok, th = pcall(DungeonGenerator.MoodTheme, myDungeon, { Biome = biome })
            sealCol = require(Shared:WaitForChild("ArrivalFx")).Colour(biome, (ok and th and th.Accent) or nil)
        end
        for i = 1, L.Main - 1 do
            local g = gates[i]
            if sealed[i] and not g then
                local cf, w = LR.SealFrame(L, i, 2)
                if cf and w then
                    g = SealGate.Build(sealDir, cf, w, sealCol :: Color3)
                    g.Model.Name = "Seal" .. i
                    gates[i] = g
                end
            end
            if g and sealed[i] then
                g:Set(sealed[i], (sealTot and sealTot[i]) or sealed[i])
            elseif g and not sealed[i] and not g.Opening then
                g:Open() -- (green, the beams go out, the gate sinks into the floor)
            end
        end
    end
    task.spawn(function()
        local cam = Workspace.CurrentCamera
        while linked.Token == token and Live() do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Z > 450 then
                local pos = hrp.Position
                local cur, inside = LR.RoomAt(L, pos)
                LMap.Visit(cur, inside) -- (QOL M1: rooms you've been in show solid on the map)
                local sealed, sealTot = LR.SealParse(f:GetAttribute("LinkSeal"))
                SyncSeals(sealed, sealTot)
                -- (v4) reveal a room: you're in it or on a path into it; its held enemies (and any held one the server woke) are built
                for i = 1, #L.Rooms do
                    if os.clock() >= (linked.RevealAfter or 0) and not linked.Revealed[i] and ((cur == i and inside) or LR.OnPathTo(L, i, pos)) then
                        linked.Revealed[i] = true
                        for _, px in ipairs(linked.Hold[i] or {}) do if px.Parent then DungeonClient.QueueSpawn(px) end end
                        linked.Hold[i] = nil
                    end
                end
                if party and holder then -- (party: the server's bots of an unrevealed room are held out of the workspace here)
                    for _, m in ipairs(f:GetChildren()) do
                        local lr2 = m:IsA("Model") and m:GetAttribute("LinkRoom")
                        if lr2 and not linked.Revealed[lr2] and m:GetAttribute("Awake") ~= true then
                            linked.Held[m] = f
                            m.Parent = holder
                        end
                    end
                    for m, home in pairs(linked.Held) do
                        local lr2 = m:GetAttribute("LinkRoom")
                        if not m.Parent then
                            linked.Held[m] = nil
                        elseif linked.Revealed[lr2] or m:GetAttribute("Awake") == true then
                            linked.Held[m] = nil
                            m:SetAttribute("NoXRay", true) -- (BOTFIX: the area pass below clears it in your room / path)
                            if home.Parent then m.Parent = home end
                        end
                    end
                end
                for i, list in pairs(linked.Hold) do
                    for k = #list, 1, -1 do
                        local px = list[k]
                        if not px.Parent then table.remove(list, k)
                        elseif px:GetAttribute("Awake") == true then table.remove(list, k); DungeonClient.QueueSpawn(px) end
                    end
                end
                -- (BOTFIX 2026-10-24, owner: bots "visible before they should be / like stuck in terrain") one pass over the
                -- linked bots (same 0.2 s tick, no rays): X-RAY BY AREA -- the "Outline Through Walls" setting (on by default)
                -- drew the next room's bots through the rock between rooms, where they read as stuck in the terrain; on a
                -- linked floor an outline only goes through walls for a bot in the same room / path as you (or XRAY_NEAR), attr
                -- NoXRay, applied by AimRngClient's outline pass. AWAKE ROOMS: a room with an awake bot in it stays drawn (its
                -- colliders are what keep that bot out of the cover / walls).
                local mine = LR.AreaAt(L, pos)
                local awakeIn, areaOf = {}, {}
                for _, m in ipairs(myDungeon:GetChildren()) do
                    if m:IsA("Model") and m:GetAttribute("LinkPack") ~= nil then
                        local bp = m:GetPivot().Position
                        local a = LR.AreaAt(L, bp)
                        areaOf[m] = a
                        if m:GetAttribute("Awake") == true then awakeIn[a] = true end
                        local xr = a == mine or (bp - pos).Magnitude <= LR.XRAY_NEAR
                        if (m:GetAttribute("NoXRay") == true) == xr then m:SetAttribute("NoXRay", not xr) end
                    end
                end
                -- PARKING: a room you're not in and not within PARK_DIST of leaves the workspace (its packs can't fight you there)
                if LR.PARK then
                    for i, rm in pairs(rooms) do
                        local show = i == cur or LR.BoxDist(L, i, pos) <= LR.PARK_DIST or awakeIn["R" .. i] == true
                        if show ~= rm.Shown then
                            rm.Shown = show
                            if rm.Vis then rm.Vis.Parent = show and lr or nil end
                            if rm.Geo then rm.Geo.Parent = show and geo or nil end
                        end
                        if party then PartyTwin.Park(f, i, rm.Shown) end -- (PARTY TWIN: the copy's room with it; the copy may land late)
                    end
                    -- (BOTFIX) an idle bot standing in a parked room sleeps (no idle mill without its room's colliders)
                    for m, a in pairs(areaOf) do
                        local ri = string.sub(a, 1, 1) == "R" and tonumber(string.sub(a, 2)) or nil
                        local parked = ri ~= nil and rooms[ri] ~= nil and rooms[ri].Shown == false
                        if (m:GetAttribute("LinkParked") == true) ~= parked then m:SetAttribute("LinkParked", parked or nil) end
                    end
                end
                -- (v3 perf) PARTICLE BUDGET: only the FX_NEAREST awake / idle bots nearest the camera keep their particles
                if os.clock() >= (linked.FxAt or 0) and cam then
                    linked.FxAt = os.clock() + 0.5
                    local cp = cam.CFrame.Position
                    local list = {}
                    for _, m in ipairs(myDungeon:GetChildren()) do
                        if m:IsA("Model") and m:GetAttribute("LinkPack") ~= nil and m:GetAttribute("LinkSleep") ~= true then
                            table.insert(list, { m, (m:GetPivot().Position - cp).Magnitude })
                        end
                    end
                    table.sort(list, function(a, b) return a[2] < b[2] end)
                    for k, e in ipairs(list) do
                        local cut = k > LR.FX_NEAREST
                        if (e[1]:GetAttribute("LinkFxCut") == true) ~= cut then
                            e[1]:SetAttribute("LinkFxCut", cut)
                            DungeonGenerator.LinkApplyFx(e[1])
                        end
                    end
                end
                -- where you are + what's left in the exit room
                local r = L.Rooms[cur]
                local cleared = f:GetAttribute("FloorCleared") == true
                local left = f:GetAttribute("RemainingEnemies") or 0
                local where = (r.Kind == "Side") and "SIDE ROOM" or (string.format("ROOM %d / %d", cur, L.Main) .. ((cur == L.Horde) and "  •  HORDE" or ""))
                local tail
                if r.Kind == "Side" then
                    local st = f:GetAttribute("LinkCache") or ""
                    tail = (st == "OPEN") and "CACHE UNGUARDED" or ((st == "USED") and "CACHE TAKEN" or "CACHE GUARDED")
                elseif sealed[cur] then -- (SEALED ROOMS: this room's way on opens when it's clear)
                    tail = string.format("CLEAR THE ROOM: %d LEFT", sealed[cur])
                elseif cleared then
                    tail = "EXIT OPEN"
                else
                    tail = (r.Kind == "Exit") and string.format("EXIT ROOM  •  %d LEFT", left) or string.format("EXIT ROOM: %d LEFT", left)
                end
                lbl.Text = where .. "   •   " .. tail
                -- PROGRESS BAR (owner: "have a dynamic progress bar too"): this room's clear -- a sealed room by its seal count, the exit
                -- room by the floor's remaining (the most seen this floor = the whole); full in green once its way / the exit is open.
                -- It slides to each new value (0.3 s), never flashes.
                do
                    local prog, done = 1, true
                    if r.Kind ~= "Side" and sealed[cur] then
                        local tot = math.max(sealTot[cur] or 0, sealed[cur], 1)
                        prog, done = 1 - sealed[cur] / tot, false
                    elseif r.Kind == "Exit" and not cleared then
                        linked.ExitMax = math.max(linked.ExitMax or 0, left)
                        prog, done = (linked.ExitMax > 0) and (1 - left / linked.ExitMax) or 0, false
                    end
                    local col = done and Color3.fromRGB(96, 206, 140) or linked.FillCol -- (UIStyle.Colors.Good)
                    if linked.Fill and (math.abs(prog - (linked.FillAt or -1)) > 0.001 or linked.Fill.BackgroundColor3 ~= col) then
                        linked.FillAt = prog
                        TweenService:Create(linked.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = UDim2.fromScale(math.clamp(prog, 0, 1), 1), BackgroundColor3 = col }):Play()
                    end
                end
                -- (2026-10-22 autoplay test: on a MAP the map clock line sat on top of this one) under the HUD's banner lines that
                -- are showing (they live in the scaled HUD, so read their real screen spot)
                do
                    -- (2026-10-26: AbsolutePosition is measured below the top bar but this gui ignores the inset, so the line sat
                    -- one top bar too high, on the Loot Storm / City Broadcast lines: subtract this gui's own origin)
                    local hud = LocalPlayer.PlayerGui:FindFirstChild("AimRngMasterHUD")
                    local y = 160
                    if hud then
                        local top = linked.Gui and linked.Gui.AbsolutePosition.Y or 0
                        for _, n in ipairs({ "FloorModsLabel", "DailyClock", "LootStormBanner", "WorldAlertBanner" }) do
                            local o = hud:FindFirstChild(n)
                            if o and o:IsA("GuiObject") and o.Visible and o.Text ~= "" then y = math.max(y, o.AbsolutePosition.Y - top + o.AbsoluteSize.Y + 4) end
                        end
                    end
                    if math.abs(lbl.Position.Y.Offset - y) > 1 then lbl.Position = UDim2.new(0.5, 0, 0, y) end
                end
                -- the arrow: the next doorway down the line (from the side room: the way back), the portals once open
                local target: Vector3? = nil
                if r.Kind == "Side" then
                    target = LR.DoorPoint(L, cur, L.Mid, 6)
                elseif cleared and cur == L.Exit then
                    target = Vector3.new(r.X, 6, r.Z + 30)
                elseif cur < L.Main and not sealed[cur] then -- (SEALED ROOMS: no arrow to a closed door)
                    target = LR.DoorPoint(L, cur, cur + 1, 6)
                end
                local shown = false
                if target and cam then
                    local vp = cam.ViewportSize
                    local sp = cam:WorldToViewportPoint(target)
                    local front = sp.Z > 0
                    if not (front and sp.X > 50 and sp.X < vp.X - 50 and sp.Y > 50 and sp.Y < vp.Y - 50) then
                        local cx, cy = vp.X / 2, vp.Y / 2
                        local dx, dy = sp.X - cx, sp.Y - cy
                        if not front then dx, dy = -dx, -dy end
                        if math.abs(dx) + math.abs(dy) < 1 then dy = 1 end
                        local mx, my = cx - 56, cy - 56
                        local k = math.min(mx / math.max(math.abs(dx), 1e-3), my / math.max(math.abs(dy), 1e-3))
                        arrow.Position = UDim2.fromOffset(cx + dx * k, cy + dy * k)
                        arrow.Rotation = math.deg(math.atan2(dy, dx)) + 90
                        shown = true
                    end
                end
                arrow.Visible = shown
                lbl.Visible = true
            else
                arrow.Visible = false
                lbl.Visible = false
            end
            task.wait(0.2)
        end
        if linked.Token == token then gui.Enabled = false end
    end)
end

-- (QOL M1) the enemies drawn on this client (the minimap's dots, 10 Hz while it shows): the cached proxy -> model table, no scan
function DungeonClient.MapEnemies(): { Instance }
    local out = {}
    for _, m in pairs(byProxy) do if m and m.Parent then table.insert(out, m) end end
    return out
end

local function Teardown()
    DungeonClient.LinkedStop() -- (LINKED ROOMS pilot)
    require(Shared:WaitForChild("MiniMap")).Clear() -- (QOL M1)
    for proxy in pairs(byProxy) do
        local model = byProxy[proxy]
        for _, c in ipairs(proxyConns[proxy] or {}) do c:Disconnect() end
        if model then model:Destroy() end
    end
    table.clear(byProxy)
    table.clear(proxyOf)
    table.clear(proxyConns)
    if dungeon then dungeon:Destroy() end
    local stray = Workspace:FindFirstChild("DungeonFacility")
    if stray then stray:Destroy() end
    for _, item in ipairs(Workspace:GetChildren()) do
        if item.Name == "EnemyPulse" or item.Name == "ShockwaveRing" or item.Name == "SweepingLaser" or item.Name == "SniperLaser" or item.Name == "VolatileCore" then
            item:Destroy()
        end
    end
    dungeon = nil
    built = false
end

local entering = false
local function WatchRunFolder(f: Folder)
    if runFolder == f then return end
    runFolder = f
    local enemies = f:WaitForChild("Enemies")
    enemies.ChildAdded:Connect(function(proxy)
        if currentConfig and currentConfig.Linked and built then -- (LINKED ROOMS v3 perf: a room arriving is built a few a frame)
            DungeonClient.QueueSpawn(proxy)
            return
        end
        task.defer(SpawnEnemy, proxy) -- attributes arrive with the instance; defer so they're all set
    end)
    f:GetAttributeChangedSignal("FloorCleared"):Connect(function()
        if (f:GetAttribute("Revisit") or 0) ~= 0 then return end -- (BACK PORTAL: BuildFloor puts up the revisit's own vault)
        if f:GetAttribute("FloorCleared") == true and built and dungeon and currentConfig then
            local cfg = table.clone(currentConfig)
            if f:GetAttribute("TrialDone") == true then cfg.TrialDone = true end -- (one hub portal)
            if cfg.Linked then -- (LINKED ROOMS pilot: the chest + portals stand in the EXIT room)
                local L = DungeonGenerator.LinkedLayout(currentConfig)
                cfg.LinkedExitZ = L.Rooms[L.Exit].Z - DungeonGenerator.GetChamberLayout(false).CombatZ
                local nx = f:GetAttribute("LinkNext")
                if type(nx) == "number" and nx > 0 then cfg.LinkedNext = nx end -- (v2: the portal's floor label)
            end
            -- PATH CHOICE: the server's options for the next floor (one portal each)
            local raw = f:GetAttribute("Paths")
            if type(raw) == "string" and raw ~= "" then
                local ok, list = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
                if ok and type(list) == "table" and #list > 0 then cfg.Paths = list end
            end
            DungeonGenerator.SpawnVictoryVault(dungeon, cfg)
            -- (0.61) missed loot behind you: a BACK portal by the chest
            if f:GetAttribute("BackOpen") == true and (currentConfig.FloorNumber or 1) > 1 then
                DungeonGenerator.BuildClearedBackPortal(dungeon, currentConfig, currentConfig.FloorNumber - 1)
            end
        end
    end)
    f:GetAttributeChangedSignal("RaidActive"):Connect(function()
        if f:GetAttribute("RaidActive") ~= true then Teardown() end
    end)
    -- A floor the server started on its own (dev tools, future server-driven transitions): build it.
    local function CheckServerFloor()
        task.delay(0.3, function()
            local token = f:GetAttribute("RunToken")
            if f:GetAttribute("RaidActive") == true and token ~= builtToken and not entering then
                BuildFloor({
                    Biome = f:GetAttribute("Biome"), Difficulty = f:GetAttribute("Difficulty"), Endless = f:GetAttribute("Endless") == true, FloorNumber = f:GetAttribute("Floor"),
                    PlayerLevel = f:GetAttribute("PlayerLevel"), Seed = f:GetAttribute("Seed"), RunToken = token,
                    BotSkill = f:GetAttribute("BotSkill"), Mods = f:GetAttribute("Mods"), Event = f:GetAttribute("Event"),
                    BossSkill = f:GetAttribute("BossSkill"), -- (BOT MOVEMENT POE: a map guardian's pace)
                    ModScale = f:GetAttribute("ModScale"), -- (MAPS V2: a map's mods scale with its tier)
                    BossArena = f:GetAttribute("BossArena"), Revisit = f:GetAttribute("Revisit") or 0,
                    Layout = f:GetAttribute("MapLayout"), -- (0.62 MAPS v3: a map's own room layout)
                    WeeklyMod = f:GetAttribute("WeeklyMod"),
                    Linked = f:GetAttribute("Linked") == true, -- (LINKED ROOMS pilot)
                })
            end
        end)
    end
    f:GetAttributeChangedSignal("RunToken"):Connect(CheckServerFloor)
    CheckServerFloor() -- the folder can arrive with a floor already started
end

-- Asks the server for the floor, builds it locally, spawns its enemies and moves you to the entry room.
-- pathIndex: which path portal you took (path choice), nil = the only portal
function DungeonClient.EnterFloor(biome: string, difficulty: string, floor: number, botSkill: number?, pathIndex: number?): boolean
    built = false -- stand-ins for the new floor may replicate before we've rebuilt the map
    entering = true
    local info = Remotes.GetFunction("StartDungeonRaid"):InvokeServer(biome, difficulty, floor, botSkill, pathIndex)
    entering = false
    if type(info) ~= "table" then return false end
    BuildFloor(info)
    return true
end

-- BACK PORTAL: "Back" to the floor behind you / "Return" to the one you came from (DungeonRuns.Revisit decides)
function DungeonClient.Revisit(dir: string): boolean
    built = false
    entering = true
    local info = Remotes.GetFunction("RevisitFloor"):InvokeServer(dir)
    entering = false
    if type(info) ~= "table" then built = dungeon ~= nil; return false end
    BuildFloor(info)
    return true
end

BuildFloor = function(info: any)
    built = false
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local f = pg:WaitForChild("AimRngRun", 10)
    if not f then return end
    WatchRunFolder(f)
    builtToken = info.RunToken

    -- tear down the previous floor's local copy (portal to the next floor keeps the run active)
    DungeonClient.LinkedStop() -- (LINKED ROOMS pilot)
    for proxy in pairs(byProxy) do RemoveEnemy(proxy) end
    if dungeon then dungeon:Destroy() end
    currentConfig = {
        Biome = info.Biome, Difficulty = info.Difficulty, Endless = info.Endless == true, FloorNumber = info.FloorNumber,
        PlayerLevel = info.PlayerLevel, Seed = info.Seed, BotSkill = info.BotSkill, Mods = info.Mods,
        BossSkill = tonumber(info.BossSkill), -- (BOT MOVEMENT POE: a map guardian keeps the pace of the map's old skill roll)
        ModScale = tonumber(info.ModScale), -- (MAPS V2: a map's mods scale with its tier, like the server's config)
        BossArena = info.BossArena, Layout = info.Layout,
        WeeklyMod = (info.WeeklyMod ~= "" and info.WeeklyMod) or nil, -- (UPDATE 7: the weekly boss's modifier)
        Linked = info.Linked == true or nil, -- (LINKED ROOMS pilot: the same line of rooms as the server's)
    }
    dungeon = DungeonGenerator.BuildThemedDungeon(currentConfig)
    dungeon:SetAttribute("RaidActive", true)
    built = true
    if currentConfig.Linked then DungeonClient.LinkedStart(f) end -- (LINKED ROOMS pilot: parking, the room line, the side cache)
    -- (QOL M1 2026-10-28) the live minimap of this floor (AimRngShared/MiniMap: drawn once from the layout, markers from byProxy)
    require(Shared:WaitForChild("MiniMap")).Floor({ Cfg = currentConfig, Folder = f, Party = false, Linked = linked, Enemies = DungeonClient.MapEnemies })
    for _, proxy in ipairs(f.Enemies:GetChildren()) do SpawnEnemy(proxy) end

    local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(currentConfig))
    -- Dungeon event (shrine / altar / cursed chest / fountain), if this floor rolled one.
    if type(info.Event) == "string" and info.Event ~= "" then
        local model = DungeonEvents.Build(dungeon, layout, info.Event, function()
            Remotes.GetEvent("UseEvent"):FireServer()
        end)
        local function ShowState()
            local st = f:GetAttribute("EventState") or ""
            if st == "USED" then
                DungeonEvents.MarkUsed(model, "Used")
            elseif string.sub(st, 1, 5) == "USES:" and model then
                local uses = tonumber(string.sub(st, 6)) or 0
                local sub = model:FindFirstChild("Sub", true)
                if sub then
                    sub.Text = string.format("Next gamble: %d gold (%d left)", DungeonEvents.GamblePrice(info.PlayerLevel or 1, uses), DungeonEvents.GAMBLE_USES - uses)
                end
            end
        end
        if eventConn then eventConn:Disconnect() end
        eventConn = f:GetAttributeChangedSignal("EventState"):Connect(ShowState)
        if info.Event == "GAMBLE_ALTAR" and model then
            local sub = model:FindFirstChild("Sub", true)
            if sub then sub.Text = string.format("Pay %d gold for a random item with boosted odds (3 uses, price doubles).", DungeonEvents.GamblePrice(info.PlayerLevel or 1, 0)) end
        end
        ShowState()
    end
    -- RUN ENCOUNTER (UPDATE 7, Encounters): the Vault Lock -- built here, run locally, paid by the server
    Encounters.Cancel()
    if encounterConn then encounterConn:Disconnect(); encounterConn = nil end
    local encId = f:GetAttribute("Encounter")
    local kind = (type(encId) == "string" and encId ~= "") and Encounters.Kind(encId) or nil
    local encLayout = layout
    if kind and currentConfig.Linked then -- (LINKED ROOMS v2: the encounter stands in the side room -- the reason to go there)
        encLayout = DungeonGenerator.LR.SideLayout(DungeonGenerator.LinkedLayout(currentConfig), layout)
    end
    if kind then
        local def = Encounters.Defs[encId]
        local model, anchor
        local starting = false
        if opts.ShotWeight then Encounters.ShotWeight = opts.ShotWeight end
        model, anchor = kind.Build(dungeon, encLayout, function()
            if starting or Encounters.Active() then return end
            starting = true
            local ok, params = Remotes.GetFunction("EncounterAction"):InvokeServer("Start")
            starting = false
            if not ok then if opts.Toast and params then opts.Toast(tostring(params)) end return end
            kind.Start({ Model = model, Anchor = anchor, PinCF = anchor, Params = params, Layout = encLayout, Dungeon = dungeon,
                UIStyle = require(Shared:WaitForChild("UIStyle")), SoundHelper = require(Shared:WaitForChild("SoundHelper")),
                OnDone = function(res)
                    local _, msg = Remotes.GetFunction("EncounterAction"):InvokeServer("Finish", res.Ok, res.Kills or res.Resets)
                    -- (after the "N ITEMS DROPPED" toast the reward's drops raise, or it overwrites this line)
                    if opts.Toast and msg then task.delay(1.2, function() opts.Toast(tostring(msg)) end) end
                end })
        end)
        local function ShowEnc() kind.Mark(model, f:GetAttribute("EncounterState") or "") end
        encounterConn = f:GetAttributeChangedSignal("EncounterState"):Connect(ShowEnc)
        ShowEnc()
        opts.SeenEnc = opts.SeenEnc or {}
        if not opts.SeenEnc[encId] and opts.Toast then -- (the first of each kind this session: what it is)
            opts.SeenEnc[encId] = true
            opts.Toast("NEW: " .. string.upper(def.Name) .. " by the entrance. " .. def.Text)
        end
    end
    -- Wandering merchant (path reward): a stall by the entrance, wares bought through MerchantBuy
    if merchantConn then merchantConn:Disconnect(); merchantConn = nil end
    local rawStock = f:GetAttribute("Merchant")
    if type(rawStock) == "string" and rawStock ~= "" then
        local function Decode(): any
            local ok, list = pcall(function() return game:GetService("HttpService"):JSONDecode(f:GetAttribute("Merchant") or "") end)
            return ok and list or nil
        end
        local _, refresh = DungeonEvents.BuildMerchant(dungeon, layout, Decode(), function(i)
            local ok, msg = Remotes.GetFunction("MerchantBuy"):InvokeServer(i)
            if opts.Toast and msg then opts.Toast(msg) end
        end)
        merchantConn = f:GetAttributeChangedSignal("Merchant"):Connect(function() refresh(Decode()) end)
    end
    -- BACK PORTAL: a revisited floor is cleared with its chest open and one portal back; any other floor with a floor
    -- behind it gets the way back in its entry room until you step out or something dies
    local revisitOf = tonumber(info.Revisit) or 0
    if revisitOf > 0 then
        local cfg = table.clone(currentConfig)
        cfg.ReturnTo = revisitOf
        DungeonGenerator.SpawnVictoryVault(dungeon, cfg)
        Remotes.GetEvent("ResendGroundLoot"):FireServer() -- (your drops on this floor, where they fell)
    elseif f:GetAttribute("ReturnCleared") == true then
        -- (0.61) back on a floor you had already cleared: its chest (open if you'd opened it), its exit portals, the BACK
        -- portal again, and your drops where they fell
        local cfg = table.clone(currentConfig)
        if f:GetAttribute("TrialDone") == true then cfg.TrialDone = true end
        local raw = f:GetAttribute("Paths")
        if type(raw) == "string" and raw ~= "" then
            local ok, list = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
            if ok and type(list) == "table" and #list > 0 then cfg.Paths = list end
        end
        cfg.ChestOpened = f:GetAttribute("VaultWasOpened") == true
        DungeonGenerator.SpawnVictoryVault(dungeon, cfg)
        if f:GetAttribute("BackOpen") == true and (currentConfig.FloorNumber or 1) > 1 then
            DungeonGenerator.BuildClearedBackPortal(dungeon, currentConfig, currentConfig.FloorNumber - 1)
        end
        Remotes.GetEvent("ResendGroundLoot"):FireServer()
    elseif f:GetAttribute("CanBack") == true then
        local back = DungeonGenerator.BuildBackPortal(dungeon, currentConfig, (info.FloorNumber or 2) - 1)
        local myDungeon = dungeon
        task.spawn(function()
            -- (SafeLocked is still true from the floor before until the server sees you land in this entry room)
            local t0 = os.clock()
            while LocalPlayer:GetAttribute("SafeLocked") == true and os.clock() - t0 < 4 do task.wait(0.1) end
            while back.Parent and dungeon == myDungeon do
                local closed = LocalPlayer:GetAttribute("SafeLocked") == true
                    or (f:GetAttribute("RemainingEnemies") or 0) ~= (f:GetAttribute("TotalEnemies") or 0)
                if closed then back:Destroy() break end
                task.wait(0.3)
            end
        end)
    end
    -- face into the dungeon (+Z), not back at the entry wall
    if opts.Teleport then opts.Teleport(CFrame.lookAt(Vector3.new(0, 7, layout.EntryZ), Vector3.new(0, 7, layout.EntryZ + 10))) end
    if DungeonClient.OnFloorBuilt then DungeonClient.OnFloorBuilt(info) end
end

-- If `part` belongs to a local dungeon enemy: its stand-in and the part's name (what the server needs).
function DungeonClient.ProxyForPart(part: Instance?): (Instance?, string?)
    local node = part
    local link = part and part:FindFirstChild("HitModel") -- (boss shield orbs: outside the boss model, linked to it)
    if link and link:IsA("ObjectValue") and link.Value then node = link.Value end
    while node and node ~= Workspace do
        if node:IsA("Model") then
            local proxy = proxyOf[node :: Model]
            if proxy then return proxy, (part :: Instance):GetAttribute("HitAs") or (part :: Instance).Name end -- (decorations: HitAs)
        end
        node = node.Parent
    end
    return nil, nil
end

function DungeonClient.IsActive(): boolean
    return built
end

-- server-drawn combat effects (explosions / chain arcs), only for us
local function FxBlast(center: Vector3, radius: number, color: Color3)
    local ball = Instance.new("Part")
    ball.Name = "ProcBlast"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.one * radius * 2
    ball.CFrame = CFrame.new(center)
    ball.Material = Enum.Material.Neon
    ball.Color = color
    ball.Transparency = 0.6
    ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
    ball.Parent = Workspace
    TweenService:Create(ball, TweenInfo.new(0.18), { Transparency = 1 }):Play()
    Debris:AddItem(ball, 0.2)
end
local function FxArc(a: Vector3, b: Vector3, color: Color3)
    local beam = Instance.new("Part")
    beam.Name = "ProcArc"
    beam.Size = Vector3.new(0.18, 0.18, (b - a).Magnitude)
    beam.CFrame = CFrame.lookAt((a + b) / 2, b)
    beam.Material = Enum.Material.Neon
    beam.Color = color
    beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
    beam.Parent = Workspace
    Debris:AddItem(beam, 0.12)
end
-- (UPDATE 8 OFFENSE phase 3: shot mod bursts) ONE flat quick ring: a thin horizontal disc that grows + fades in 0.16 s (seen
-- edge-on from eye height, so it never covers the crosshair)
local function FxRing(center: Vector3, radius: number, color: Color3)
    local r = Instance.new("Part")
    r.Name = "ModRing"
    r.Shape = Enum.PartType.Cylinder
    r.Size = Vector3.new(0.08, radius * 0.8, radius * 0.8)
    r.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
    r.Material = Enum.Material.Neon
    r.Color = color
    r.Transparency = 0.55
    r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
    r.Parent = Workspace
    TweenService:Create(r, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = Vector3.new(0.08, radius * 2, radius * 2) }):Play()
    Debris:AddItem(r, 0.18)
end

-- Party dungeons (Workspace.PartyRuns.Run_<id>) are server-built and replicate to everyone; every one that
-- isn't yours is made invisible, non-colliding and non-raycastable on this client (they all overlap the
-- same coordinates), and its sounds, lights, prompts and particles are switched off.
local hiddenRuns: { [Instance]: { [Instance]: any } } = {}
local function HideInst(store: { [Instance]: any }, d: Instance)
    if store[d] then return end
    if d:IsA("BasePart") then
        store[d] = { CanCollide = d.CanCollide, CanQuery = d.CanQuery, CanTouch = d.CanTouch }
        d.LocalTransparencyModifier = 1
        d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
    elseif d:IsA("Decal") then
        store[d] = true
        d.LocalTransparencyModifier = 1
    elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Highlight")
        or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then -- (beams: the lighthouse sweep, orb tethers)
        store[d] = { Enabled = d.Enabled }
        d.Enabled = false
    elseif d:IsA("Sound") then
        store[d] = { Volume = d.Volume }
        d.Volume = 0
    end
end
local function RestoreInst(d: Instance, o: any)
    if not d.Parent then return end
    if d:IsA("BasePart") then
        d.LocalTransparencyModifier = 0
        d.CanCollide, d.CanQuery, d.CanTouch = o.CanCollide, o.CanQuery, o.CanTouch
    elseif d:IsA("Decal") then
        d.LocalTransparencyModifier = 0
    elseif type(o) == "table" and o.Enabled ~= nil then
        (d :: any).Enabled = o.Enabled
    elseif type(o) == "table" and o.Volume ~= nil then
        (d :: any).Volume = o.Volume
    end
end
local runConns: { [Instance]: RBXScriptConnection } = {}
local function UpdateRunVisibility(folder: Instance)
    local rid = LocalPlayer:GetAttribute("RunId")
    local w = LocalPlayer:GetAttribute("WatchUid") -- (0.62 SPECTATE: watching a party player shows their floor)
    local wp = w and game:GetService("Players"):GetPlayerByUserId(w)
    if wp then rid = wp:GetAttribute("RunId") end
    local mine = folder:GetAttribute("RunId") ~= nil and folder:GetAttribute("RunId") == rid
    if mine then
        local store = hiddenRuns[folder]
        if store then
            for d, o in pairs(store) do RestoreInst(d, o) end
            hiddenRuns[folder] = nil
        end
        if runConns[folder] then runConns[folder]:Disconnect(); runConns[folder] = nil end
        PartyTwin.Sync(folder, true) -- (PARTY TWIN: your own full-detail copy of the floor, the server's scenery hidden under it)
    else
        PartyTwin.Sync(folder, false) -- (before the hide below: it records the server's own collision flags)
        local store = hiddenRuns[folder] or {}
        hiddenRuns[folder] = store
        for _, d in ipairs(folder:GetDescendants()) do HideInst(store, d) end
        if not runConns[folder] then
            runConns[folder] = folder.DescendantAdded:Connect(function(d) HideInst(store, d) end)
        end
    end
end

-- set one option after Init (e.g. Toast, once the HUD exists)
function DungeonClient.SetOpt(k: string, v: any)
    opts[k] = v
end

function DungeonClient.Init(o: any)
    opts = o or {}
    task.spawn(function()
        local container = Workspace:WaitForChild("PartyRuns", math.huge)
        for _, f in ipairs(container:GetChildren()) do UpdateRunVisibility(f) end
        container.ChildAdded:Connect(function(f) task.defer(UpdateRunVisibility, f) end)
        container.ChildRemoved:Connect(function(f)
            PartyTwin.Drop(f)
            hiddenRuns[f] = nil
            if runConns[f] then runConns[f]:Disconnect(); runConns[f] = nil end
        end)
        DungeonClient.RefreshRunVisibility = function()
            for _, f in ipairs(container:GetChildren()) do UpdateRunVisibility(f) end
        end
        LocalPlayer:GetAttributeChangedSignal("WatchUid"):Connect(DungeonClient.RefreshRunVisibility)
        LocalPlayer:GetAttributeChangedSignal("RunId"):Connect(function()
            for _, f in ipairs(container:GetChildren()) do UpdateRunVisibility(f) end
        end)
    end)
    -- (BOUNDS GUARD 2026-11-07, owner: "we need to add bounds to the map so people cant jump out of the map"): the 10 Hz
    -- out-of-map safety net on every dungeon floor (AimRngShared/BoundsGuard); solo floors = this module's own build
    task.spawn(function()
        local okB, BG = pcall(function() return require(script.Parent:WaitForChild("BoundsGuard", 10)) end)
        if okB and BG then BG.Start({ Solo = function() return (built and dungeon) or nil, currentConfig end }) end
    end)
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    task.spawn(function()
        local f = pg:WaitForChild("AimRngRun", math.huge)
        WatchRunFolder(f)
    end)

    Remotes.GetEvent("CombatFx").OnClientEvent:Connect(function(kind, a, b, c)
        if kind == "Blast" and typeof(a) == "Vector3" then FxBlast(a, b, c)
        elseif kind == "Arc" and typeof(a) == "Vector3" then FxArc(a, b, c)
        elseif kind == "Ring" and typeof(a) == "Vector3" then FxRing(a, b, c) end
    end)

    -- enemy positions -> server
    local posEv = Remotes.GetEvent("EnemyPositions")
    task.spawn(function()
        while true do
            task.wait(1 / 6)
            if built and next(byProxy) then
                local list = {}
                for proxy, model in pairs(byProxy) do
                    local id = proxy:GetAttribute("EnemyId")
                    if id and model.Parent then list[tostring(id)] = model:GetPivot().Position end
                end
                posEv:FireServer(list)
            end
        end
    end)

    -- SINGLE INSTANCES (owner 2026-10-05: "you can see and hear other players shooting ... it should all be single
    -- instances, even within parties"): a player in another instance (InstanceKey: hub / your range / your solo
    -- floor / your party's floor) is fully hidden -- body, gear, skins' beams / particles / lights / guis, name tags --
    -- and every sound on them is muted. (Their shots aren't even sent to you: CombatServer's ShotFx relay.)
    task.spawn(function()
        local InstanceKey = require(script.Parent:WaitForChild("InstanceKey"))
        local hidden: { [Model]: { [Instance]: any } } = {}
        local EFFECT = { "Beam", "ParticleEmitter", "Trail", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight",
            "BillboardGui", "SurfaceGui", "Highlight" }
        local function HideOne(store: { [Instance]: any }, d: Instance)
            if d:IsA("BasePart") or d:IsA("Decal") then
                if store[d] == nil then store[d] = d.LocalTransparencyModifier end
                if d.LocalTransparencyModifier ~= 1 then d.LocalTransparencyModifier = 1 end
            elseif d:IsA("Sound") then
                if store[d] == nil then store[d] = d.Volume end
                if d.Volume ~= 0 then d.Volume = 0 end
            elseif d:IsA("Humanoid") then
                -- (owner 2026-10-07: "Hideout shows you other players name as if you were in the same instance": the
                -- Roblox name / health over their head comes from the Humanoid, not a gui)
                if store[d] == nil then store[d] = d.DisplayDistanceType end
                if d.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
            else
                for _, cls in ipairs(EFFECT) do
                    if d:IsA(cls) then
                        if store[d] == nil then store[d] = (d :: any).Enabled end
                        if (d :: any).Enabled then (d :: any).Enabled = false end
                        break
                    end
                end
            end
        end
        local function Restore(store: { [Instance]: any })
            for d, v in pairs(store) do
                if d.Parent then
                    if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0
                    elseif d:IsA("Sound") then d.Volume = v
                    elseif d:IsA("Humanoid") then d.DisplayDistanceType = v
                    else pcall(function() (d :: any).Enabled = v end) end
                end
            end
        end
        while true do
            task.wait(0.2)
            local mine = InstanceKey.Of(LocalPlayer)
            local seen: { [Model]: boolean } = {}
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                if p ~= LocalPlayer and char then
                    seen[char] = true
                    local hv = LocalPlayer:GetAttribute("HideoutView")
                    local hide = not InstanceKey.Sees(mine, InstanceKey.Of(p), hv == nil) -- (2026-10-23: the loft parks the city too)
                    if hide then
                        local store = hidden[char] or {}
                        hidden[char] = store
                        for _, d in ipairs(char:GetDescendants()) do HideOne(store, d) end -- (parts stream in / effects re-enable)
                    elseif hidden[char] then
                        Restore(hidden[char])
                        hidden[char] = nil
                    end
                end
            end
            for char in pairs(hidden) do if not seen[char] or not char.Parent then hidden[char] = nil end end
        end
    end)
end

-- (LINKED ROOMS on PARTY floors) the party floor you're on (Player attr RunId -> workspace.PartyRuns.Run_<id>): a linked one gets
-- the same client side as solo (HUD, arrow, parking, particle budget, unrevealed rooms' bots held back)
do
    local partyToken = 0
    local function OnRun()
        partyToken += 1
        local my = partyToken
        if linked.Party then DungeonClient.LinkedStop() end
        require(Shared:WaitForChild("MiniMap")).Clear(true) -- (QOL M1: a party floor's minimap goes with it)
        local id = LocalPlayer:GetAttribute("RunId")
        if type(id) ~= "string" or id == "" then return end
        task.spawn(function()
            local pr = Workspace:WaitForChild("PartyRuns", 10)
            local f = pr and pr:WaitForChild("Run_" .. id, 10)
            if not f or my ~= partyToken then return end
            local t0 = os.clock()
            while f:GetAttribute("Linked") == nil and os.clock() - t0 < 5 do task.wait(0.1) end
            if my ~= partyToken then return end
            local isLinked = f:GetAttribute("Linked") == true
            local cfg = { Linked = isLinked or nil, Seed = f:GetAttribute("LinkSeed"), Difficulty = f:GetAttribute("Difficulty") }
            require(Shared:WaitForChild("MiniMap")).Floor({ Cfg = cfg, Folder = f, Party = true, Linked = linked }) -- (QOL M1: every party floor)
            if not isLinked then return end
            DungeonClient.LinkedStart(f, cfg, true)
        end)
    end
    if RunService:IsClient() and LocalPlayer then
        LocalPlayer:GetAttributeChangedSignal("RunId"):Connect(OnRun)
        task.defer(OnRun)
    end
end

return DungeonClient
