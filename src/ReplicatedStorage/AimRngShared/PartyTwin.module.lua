--!nocheck
-- PARTY TWIN (2026-10-25, owner: "I want everyone to be able to see the same generated arenas in multiplayer"). A party floor is
-- server-built (Workspace.PartyRuns.Run_<id>), and the full map look -- terrain ground and cliffs, prop sets, rims, every room's
-- atmosphere -- only exists on a client build, so party floors were the plain part-built version. Now:
--   SERVER (PartyRuns.BuildFloor, config.Mirror): DungeonGenerator builds the floor down the solo client's path draw for draw
--     (MapShell.Mirror: terrain writes go nowhere) -> its colliders are exactly a client build's; DungeonGenerator.MirrorStamp
--     strips the pure dressing, marks every folder Scenery and stamps attr Twin = the build config (JSON).
--   CLIENT (here): the party floor you're on (or the one you're watching) gets its own full-detail copy, Workspace.PartyTwin,
--     built from that config -- the same seed, so every member sees the same map -- and the server's Scenery folders are
--     hidden + non-colliding under it (anything put in them later with attr Live -- a boss's pillars, the side room's cache
--     chest -- stays). Bots, chests, portals, loot and FX are the server's as before. A floor without attr Twin (Studio
--     DevTwinOff) is left as it is.
-- DungeonClient calls Sync from its run-visibility pass (before it hides another run's folder) and Park from the linked rooms'
-- parking loop.
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local PartyTwin = {}
PartyTwin.NAME = "PartyTwin"

local cur: any = nil -- { Folder, Twin, Store, Conns, Token, Parked }
local token = 0

local EFFECT = { "ParticleEmitter", "Light", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "BillboardGui", "SurfaceGui", "Highlight" }
local function Live(d: Instance, top: Instance): boolean
    local n = d
    while n and n ~= top.Parent do
        if n:GetAttribute("Live") then return true end
        n = n.Parent
    end
    return false
end
local function Hide(store: { [Instance]: any }, d: Instance, top: Instance)
    if store[d] or Live(d, top) then return end
    if d:IsA("BasePart") then
        store[d] = { CanCollide = d.CanCollide, CanQuery = d.CanQuery, CanTouch = d.CanTouch }
        d.LocalTransparencyModifier = 1
        d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
    elseif d:IsA("Decal") then
        store[d] = true
        d.LocalTransparencyModifier = 1
    elseif d:IsA("Sound") then
        store[d] = { Volume = d.Volume }
        d.Volume = 0
    else
        for _, cls in ipairs(EFFECT) do
            if d:IsA(cls) then store[d] = { Enabled = (d :: any).Enabled }; (d :: any).Enabled = false; break end
        end
    end
end
local function Restore(store: { [Instance]: any })
    for d, o in pairs(store) do
        if d.Parent then
            if d:IsA("BasePart") then
                d.LocalTransparencyModifier = 0
                d.CanCollide, d.CanQuery, d.CanTouch = o.CanCollide, o.CanQuery, o.CanTouch
            elseif d:IsA("Decal") then
                d.LocalTransparencyModifier = 0
            elseif type(o) == "table" and o.Volume ~= nil then
                (d :: any).Volume = o.Volume
            elseif type(o) == "table" and o.Enabled ~= nil then
                (d :: any).Enabled = o.Enabled
            end
        end
    end
end

-- the copy of `folder` (nil while it builds / when there is none)
function PartyTwin.Of(folder: Instance?): Instance?
    if cur and folder and cur.Folder == folder and cur.Twin and cur.Twin.Parent then return cur.Twin end
    return nil
end

-- the server's floor shown again, the copy gone (folder = only if it is that one's; nil = whatever is up)
function PartyTwin.Drop(folder: Instance?)
    if not cur or (folder and cur.Folder ~= folder) then return end
    local c = cur
    cur = nil
    token += 1
    for _, cn in ipairs(c.Conns) do cn:Disconnect() end
    Restore(c.Store)
    for _, f in pairs(c.Parked) do f:Destroy() end -- (parked rooms aren't under the copy any more)
    if c.Twin then c.Twin:Destroy() end -- (its terrain goes with it: MapShell's AncestryChanged clear)
end

-- DungeonClient's visibility pass: mine = this folder is the floor you're on / watching
function PartyTwin.Sync(folder: Instance, mine: boolean)
    if not mine then PartyTwin.Drop(folder); return end
    if cur and cur.Folder == folder then return end
    PartyTwin.Drop()
    token += 1
    local my = token
    local c = { Folder = folder, Store = {}, Conns = {}, Parked = {} }
    cur = c
    task.spawn(function()
        local t0 = os.clock()
        while folder.Parent and folder:GetAttribute("Twin") == nil and os.clock() - t0 < 10 do task.wait(0.1) end
        local raw = folder:GetAttribute("Twin")
        if my ~= token or not folder.Parent or type(raw) ~= "string" then return end
        local ok, cfg = pcall(HttpService.JSONDecode, HttpService, raw)
        if not ok or type(cfg) ~= "table" then return end
        cfg.FolderName, cfg.FolderParent, cfg.TwinRun = PartyTwin.NAME, Workspace, folder:GetAttribute("RunId")
        local DungeonGenerator = require(script.Parent:WaitForChild("DungeonGenerator"))
        local t1 = os.clock()
        local okB, twin = pcall(DungeonGenerator.BuildThemedDungeon, cfg)
        if my ~= token or not folder.Parent then
            if okB and twin then twin:Destroy() end
            return
        end
        if not okB or not twin then
            warn("[PartyTwin] build failed: " .. tostring(twin)) -- (the server's floor stays shown)
            return
        end
        c.Twin = twin
        twin:SetAttribute("TwinMs", math.floor((os.clock() - t1) * 1000))
        -- (a big floor replicates over several frames: a Scenery folder can land after the copy is up -- the entry gates did)
        local function Cover(top: Instance)
            if not top:GetAttribute("Scenery") then return end
            for _, d in ipairs(top:GetDescendants()) do Hide(c.Store, d, top) end
            table.insert(c.Conns, top.DescendantAdded:Connect(function(d) Hide(c.Store, d, top) end))
        end
        for _, top in ipairs(folder:GetChildren()) do Cover(top) end
        table.insert(c.Conns, folder.ChildAdded:Connect(Cover))
        if PartyTwin.OnBuilt then pcall(PartyTwin.OnBuilt, folder, twin) end
    end)
end

-- LINKED ROOMS parking on a party floor: room i's folders in the copy (LinkedRooms.R<i>, StaticGeometry.LinkGeo<i>) leave the
-- workspace with the server's (show = false) and come back (true)
function PartyTwin.Park(folder: Instance, i: number, show: boolean)
    local twin = PartyTwin.Of(folder)
    if not twin then return end
    local c = cur
    for _, key in ipairs({ "LinkedRooms/R" .. i, "StaticGeometry/LinkGeo" .. i }) do
        local home = twin:FindFirstChild(string.match(key, "^(.-)/"))
        local name = string.match(key, "/(.+)$")
        if home then
            if show then
                local f = c.Parked[key]
                if f then c.Parked[key] = nil; f.Parent = home end
            elseif not c.Parked[key] then
                local f = home:FindFirstChild(name)
                if f then c.Parked[key] = f; f.Parent = nil end
            end
        end
    end
end

return PartyTwin
