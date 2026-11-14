--!nocheck
-- ============================================================================================
-- BOUNDS GUARD (2026-11-07, owner play-testing a Molten linked floor: "we need to add bounds to the map so people cant jump
-- out of the map"). A cheap safety net on EVERY dungeon floor (solo + party, regular / boss / linked / map floors): every
-- floor is built at the same spot from the same plan (DungeonGenerator.GetChamberLayout + LinkedRooms.Layout), so its
-- walkable space is known as a handful of boxes -- the entry room, the corridor, room 1 (the combat room / boss arena) and,
-- on a linked floor, every other room + the walk segments of every path. TICK times a second (no per-frame work, no parts,
-- no rays) the client checks its own root against them: outside every box by MARGIN studs, above TOP (the invisible lids sit
-- at y 56.5) or below BOTTOM, for OUT_FOR seconds -> back to the newest safe spot (a grounded spot well inside a box, kept
-- every SAFE_GAP s, SAFE_KEEP of them). The client owns its character's physics on solo AND party floors (the server only
-- moves you on respawns / new floors, and those land inside the boxes), so nothing here fights server-side position logic.
--   * never runs: downed / spectating, outside the dungeon band (hub, hideout, range, PvP), up at the aim trials (y > 250),
--     without a floor of yours (solo: DungeonClient's build; party: Workspace.PartyRuns.Run_<RunId>)
--   * GRACE after a floor change or any 60+ stud jump in one tick (portals, respawns, the floor's own teleport)
--   * the entry room is never a return spot once the doorway has locked behind you (Player attr SafeLocked): the server
--     would read a 40+ stud jump into it as "just placed" and reopen the safe zone
-- Player attr BoundsFix = how many times you were put back (Studio check); workspace attr DevBoundsOff (Studio) = off;
-- Player attr DevBounds (Studio) = this floor's boxes, "x0,x1,z0,z1,top,entry|...".
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = script.Parent
local DungeonGenerator = require(Shared:WaitForChild("DungeonGenerator"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local BoundsGuard = {}
BoundsGuard.TICK = 0.1 -- (10 Hz)
BoundsGuard.OUT_FOR = 0.3
BoundsGuard.MARGIN = 3 -- (walls are 4 thick on the box line: the root can never legitimately be past the wall's outer face)
BoundsGuard.TOP = 60 -- (rooms + paths: lids at y 56.5)
BoundsGuard.TOP_ENTRY = 26 -- (entry room roof ~y 20, corridor ceiling ~y 14)
BoundsGuard.BOTTOM = -12 -- (floor top y 2)
BoundsGuard.SAFE_KEEP = 8
BoundsGuard.SAFE_GAP = 0.35
BoundsGuard.SAFE_INSET = 2.5
BoundsGuard.GRACE = 1.2 -- (after a 60+ stud jump: a portal / respawn / the floor's own teleport)
BoundsGuard.FLOOR_GRACE = 3 -- (a new floor: you may still stand where the last one put you until its entry teleport lands)
BoundsGuard.JUMP = 60

local FLOOR_Y = 2

-- the floor's walkable boxes: { x0, x1, z0, z1, top, entry }
function BoundsGuard.Boxes(isBoss: boolean, cfg: any): { any }
    local lay = DungeonGenerator.GetChamberLayout(isBoss)
    local out = {}
    local eh = lay.EntrySize / 2
    table.insert(out, { -eh, eh, lay.EntryZ - eh, lay.EntryZ + eh, BoundsGuard.TOP_ENTRY, true })
    local cw = lay.CorridorWidth / 2
    table.insert(out, { -cw, cw, lay.CorridorAStart - 1, lay.CorridorAEnd + 1, BoundsGuard.TOP_ENTRY, true })
    local h = lay.CombatSize / 2
    table.insert(out, { -h, h, lay.CombatZ - h, lay.CombatZ + h, BoundsGuard.TOP, false })
    if cfg and cfg.Linked and not isBoss then
        local LR = DungeonGenerator.LR
        local ok, L = pcall(DungeonGenerator.LinkedLayout, cfg)
        if ok and L then
            for i = 2, #L.Rooms do
                local x0, x1, z0, z1 = LR.Box(L, i, 0)
                table.insert(out, { x0, x1, z0, z1, BoundsGuard.TOP, false })
            end
            for _, p in ipairs(L.Paths) do
                for _, b in ipairs(LR.PathBoxes(p, 0, 2)) do table.insert(out, { b[1], b[2], b[3], b[4], BoundsGuard.TOP, false }) end
            end
        end
    end
    return out
end

-- inside any box, grown by m (negative = shrunk); noEntry skips the entry room + corridor
function BoundsGuard.Inside(boxes: { any }, p: Vector3, m: number, noEntry: boolean?): boolean
    if p.Y < BoundsGuard.BOTTOM then return false end
    for _, b in ipairs(boxes) do
        if not (noEntry and b[6]) and p.X >= b[1] - m and p.X <= b[2] + m and p.Z >= b[3] - m and p.Z <= b[4] + m and p.Y <= b[5] + math.min(m, 0) then
            return true
        end
    end
    return false
end

local started = false
-- o.Solo() -> (floorKey: Instance?, cfg) for a solo floor built on this client
function BoundsGuard.Start(o: any)
    if started then return end
    started = true
    local LocalPlayer = Players.LocalPlayer
    local key, boxes, entryCF, fallbackCF = nil, nil, nil, nil
    local safe: { Vector3 } = {}
    local lastSafeAt, outSince, graceUntil = 0, nil, 0
    local lastPos: Vector3? = nil
    local partyCfg: { [Instance]: any } = setmetatable({}, { __mode = "k" })

    local function Floor(): (Instance?, boolean, any)
        local rid = LocalPlayer:GetAttribute("RunId")
        if type(rid) == "string" and rid ~= "" then
            local pr = Workspace:FindFirstChild("PartyRuns")
            local f = pr and pr:FindFirstChild("Run_" .. rid)
            if f then
                local cfg = partyCfg[f]
                if not cfg then
                    if f:GetAttribute("Linked") == nil then return nil, false, nil end -- (still replicating)
                    cfg = { Linked = f:GetAttribute("Linked") == true or nil, Seed = f:GetAttribute("LinkSeed"), Difficulty = f:GetAttribute("Difficulty") }
                    partyCfg[f] = cfg
                end
                return f, f:GetAttribute("IsBossFloor") == true, cfg
            end
        end
        local d, cfg = o.Solo()
        if not d or not cfg then return nil, false, nil end
        return d, ItemData.IsBossConfig(cfg) == true, cfg
    end

    task.spawn(function()
        while true do
            task.wait(BoundsGuard.TICK)
            local ok, err = pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not (root and hum) or hum.Health <= 0 or root.Anchored then outSince = nil; return end
                if LocalPlayer:GetAttribute("Downed") or LocalPlayer:GetAttribute("Spectating") then outSince = nil; return end
                if RunService:IsStudio() and Workspace:GetAttribute("DevBoundsOff") then outSince = nil; return end
                local pos = root.Position
                if pos.Z < 450 or pos.Y > 250 or pos.X > 4000 or pos.X < -4000 then outSince = nil; lastPos = nil; return end -- (not on a dungeon floor)
                local f, isBoss, cfg = Floor()
                if not f then outSince = nil; key = nil; return end
                local now = os.clock()
                if f ~= key or not boxes then
                    key = f
                    boxes = BoundsGuard.Boxes(isBoss, cfg)
                    local lay = DungeonGenerator.GetChamberLayout(isBoss)
                    entryCF = Vector3.new(0, 7, lay.EntryZ)
                    fallbackCF = Vector3.new(0, 7, lay.CombatZ - lay.CombatSize / 2 + 12)
                    table.clear(safe)
                    graceUntil = now + BoundsGuard.FLOOR_GRACE
                    if RunService:IsStudio() then -- (Studio: the boxes for a wall / lid audit from execute_luau)
                        local rows = {}
                        for _, b in ipairs(boxes) do table.insert(rows, string.format("%.2f,%.2f,%.2f,%.2f,%g,%d", b[1], b[2], b[3], b[4], b[5], b[6] and 1 or 0)) end
                        LocalPlayer:SetAttribute("DevBounds", table.concat(rows, "|"))
                    end
                    outSince = nil
                end
                if lastPos and (pos - lastPos).Magnitude > BoundsGuard.JUMP then graceUntil = now + BoundsGuard.GRACE; outSince = nil end -- (a teleport)
                lastPos = pos
                if now < graceUntil then return end
                local locked = LocalPlayer:GetAttribute("SafeLocked") == true
                if BoundsGuard.Inside(boxes, pos, BoundsGuard.MARGIN) then
                    outSince = nil
                    -- a safe spot: grounded, well inside a box (not the entry room once it has locked behind you)
                    if now - lastSafeAt >= BoundsGuard.SAFE_GAP and hum.FloorMaterial ~= Enum.Material.Air
                        and BoundsGuard.Inside(boxes, pos, -BoundsGuard.SAFE_INSET, locked) and pos.Y < BoundsGuard.TOP - 8 then
                        lastSafeAt = now
                        table.insert(safe, pos)
                        if #safe > BoundsGuard.SAFE_KEEP then table.remove(safe, 1) end
                    end
                    return
                end
                outSince = outSince or now
                if now - outSince < BoundsGuard.OUT_FOR then return end
                -- out of the map: the newest safe spot that is still a good one (each is used once), else the floor's entry
                local spot
                while #safe > 0 do
                    local s = table.remove(safe)
                    if BoundsGuard.Inside(boxes, s, -BoundsGuard.SAFE_INSET, locked) then spot = s; break end
                end
                spot = spot or (locked and fallbackCF or entryCF)
                local rot = root.CFrame.Rotation
                char:PivotTo(CFrame.new(spot + Vector3.new(0, 0.5, 0)) * rot)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                outSince = nil
                lastPos = spot
                graceUntil = now + 0.5
                LocalPlayer:SetAttribute("BoundsFix", (LocalPlayer:GetAttribute("BoundsFix") or 0) + 1)
            end)
            if not ok then warn("[BoundsGuard] " .. tostring(err)) task.wait(2) end
        end
    end)
end

return BoundsGuard
