--!nocheck
-- QOL M1 (2026-10-28; owner: "A map / overview would be good", then "the map should be a dynamic working mini map, not what you
-- currently have"; contract docs/QOL_2026-10-28.md): a LIVE MINIMAP on every dungeon floor -- solo (client-built) and party (the
-- server's floor + your PARTY TWIN copy) alike.
--   * CORNER (default): a square widget top-right under the currency chips, far from the crosshair. It turns with your camera
--     (the way you look is UP), you are the fixed arrow in its middle, the floor scrolls under you.
--   * LARGE: the same live map centred on the screen, see-through, a wider view. OFF: nothing.
--     Key_Map (default N) / a pad's D-pad RIGHT cycles corner -> large -> off and the choice is saved (Settings > Interface
--     "Minimap"; "Minimap Zoom" Near / Normal / Far). On a phone, tapping the map cycles it.
--   * WHAT IT SHOWS: the floor drawn from data, not from parts -- a linked floor from its LinkedRooms layout (start room, rooms,
--     the dogleg paths), any other floor (regular, boss / mini-boss arenas, trials) from DungeonGenerator.GetChamberLayout (start
--     room + corridor + the arena). Fog: a linked room you haven't stepped into is a dim outline; one you've been in is solid,
--     green once it's clear. Live markers: enemies (red; idle / asleep dimmer; elites + mini-bosses bigger, bosses biggest),
--     party members (green), Rare+ loot on the ground (its rarity colour; Drop Rules' hidden drops not shown), the closed gates
--     of sealed rooms, the side room's cache (guarded / open / taken), the exit portal once the floor is clear.
--   * PERFORMANCE (owner: "must run on almost anything", phones too): the floor is drawn ONCE per floor into one canvas frame;
--     each frame only that canvas's rotation + offset move (and only when you turned / moved), markers are pooled frames
--     refreshed at 10 Hz from cached lists (DungeonClient's enemy table / the party folder's children / GroundLoot's drop table --
--     no GetDescendants), and nothing runs at all while it's off, in the hub or while a window is open.
-- DungeonClient: MiniMap.Floor(ctx) on every floor build (solo BuildFloor, party RunId), MiniMap.Clear() on teardown,
-- MiniMap.Visit(room, inside) from its 0.2 s linked loop.
-- Studio hook: Player attr DevMap = "Corner" | "Large" | "Off" sets the mode, "Cycle" = the key press (no keyboard in agent tests);
-- attr DevMapMode = the live mode.
local MiniMap = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = script.Parent

MiniMap.PAD_KEY = Enum.KeyCode.DPadRight -- (free on a pad: PlatformControls PAD_DOWN / MovementController PAD don't use it)
MiniMap.TICK = 0.1 -- (markers: 10 Hz while shown)
MiniMap.CORNER_PX = 184 -- (the corner widget's size)
MiniMap.LARGE_PX = 470 -- (the large map's size; both fit the screen's height)
MiniMap.ZOOM = { Near = 1.6, Normal = 1.15, Far = 0.8 } -- (pixels a stud: Normal shows ~160 studs across the corner widget)
MiniMap.LARGE_ZOOM = 0.85 -- (x the zoom in the large view: a wider area)
MiniMap.MODES = { "Corner", "Large", "Off" }
MiniMap.START_SIZE, MiniMap.START_Z = 40, 550 -- (the entry room, GetChamberLayout EntrySize / EntryZ)
MiniMap.DOT = { Fodder = 4, Bot = 5, Elite = 7, Mini = 9, Boss = 11 }
MiniMap.MAX_DOTS = 120

local LocalPlayer = Players.LocalPlayer
local mode = "Corner"
local cur: any = nil -- this floor: { Ctx, L?, Rooms, Paths, Visited, VisitAt, Seen, Canvas, ... }
local ui: any = nil -- the persistent widget
local shown = false
local stepConn: RBXScriptConnection? = nil
local tickToken = 0

local function U() return require(Shared:WaitForChild("UIStyle")) end
local function LR() return require(Shared:WaitForChild("LinkedRooms")) end
local function GS() return require(Shared:WaitForChild("GameSettings")) end

local function New(class: string, props: { [string]: any }): Instance
    local i = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then i[k] = v end end
    if props.Parent then i.Parent = props.Parent end
    return i
end

-- ==================== the widget (built once a session) ====================
local function BuildUi()
    if ui then return ui end
    local S = U()
    local C = S.Colors
    local gui = New("ScreenGui", { Name = "MiniMapGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1, Enabled = false }) -- (under the HUD: its lines stay readable over the large map) :: ScreenGui
    -- (UI CLEAN R-C: the run HUD plate -- flat Bg0, square, no facet / ink edge / neon edge; the map draws straight on it)
    local win = New("Frame", { Name = "Map", BackgroundColor3 = C.Bg0, BorderSizePixel = 0, Parent = gui }) :: Frame
    win:SetAttribute("NoSkin", true)
    local edge = nil
    -- the clip: a plain ClipsDescendants frame (it clips its TURNED children -- checked in Studio; only a turned clipper or ancestor
    -- stops clipping). Not a CanvasGroup: that one re-renders a texture every frame the map turns.
    local grp = New("Frame", { Name = "Clip", BackgroundColor3 = C.Well, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), Parent = win }) :: Frame
    local pivot = New("Frame", { Name = "Pivot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0), Parent = grp }) :: Frame
    local zoom = New("UIScale", { Name = "Zoom", Parent = pivot }) :: UIScale
    -- you: the fixed arrow in the middle (never turned: the map turns under it)
    local me = New("TextLabel", { Name = "You", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20), Text = "▲", Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = C.Neon,
        TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0, ZIndex = 5, Parent = win }) :: TextLabel
    local legend = New("TextLabel", { Name = "Legend", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6),
        Size = UDim2.new(1, 0, 0, 16), Font = S.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextStrokeColor3 = C.Ink, TextStrokeTransparency = 0.3,
        Text = "", Visible = false, Parent = win }) :: TextLabel
    local fit = New("UIScale", { Name = "Fit", Parent = win }) :: UIScale
    -- phones: a tap on the map cycles it (no key)
    local tap = New("TextButton", { Name = "Tap", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 6, Visible = false, Parent = win }) :: TextButton
    tap.Activated:Connect(function() MiniMap.Cycle() end)
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    ui = { Gui = gui, Win = win, Grp = grp, Pivot = pivot, Zoom = zoom, Me = me, Legend = legend, Fit = fit, Tap = tap, Edge = edge }
    return ui
end

-- ==================== the floor (drawn once) ====================
-- canvas pixels at 1 px a stud: the way on (+Z) is up, your right walking in (-X) is right
local function Geometry(ctx: any): any
    local DG = require(Shared:WaitForChild("DungeonGenerator"))
    local rects, rooms, paths = {}, {}, {}
    local hs = MiniMap.START_SIZE / 2
    local L = nil
    local cfg = ctx.Cfg or {}
    if cfg.Linked then
        local ok, got = pcall(DG.LinkedLayout, cfg)
        if ok then L = got end
    end
    local minX, maxX, minZ, maxZ
    if L then
        minX, maxX, minZ, maxZ = L.MinX, L.MaxX, L.MinZ, L.MaxZ
        for i, r in ipairs(L.Rooms) do
            rooms[i] = { r.X - L.Half, r.X + L.Half, r.Z - L.Half, r.Z + L.Half, Kind = r.Kind, X = r.X, Z = r.Z, Half = L.Half }
        end
        local LRm = LR()
        for k, p in ipairs(L.Paths) do
            paths[k] = { A = p.A, B = p.B, Boxes = LRm.PathBoxes(p, 0, 2) }
        end
    else
        local lay = DG.GetChamberLayout(false)
        local h = lay.CombatSize / 2
        rooms[1] = { -h, h, lay.CombatZ - h, lay.CombatZ + h, Kind = "Exit", X = 0, Z = lay.CombatZ, Half = h }
        minX, maxX, minZ, maxZ = -h, h, lay.CombatZ - h, lay.CombatZ + h
    end
    minZ = math.min(minZ, MiniMap.START_Z - hs)
    table.insert(rects, { -hs, hs, MiniMap.START_Z - hs, MiniMap.START_Z + hs, "Start" })
    table.insert(rects, { -8, 8, MiniMap.START_Z + hs - 1, rooms[1][3] + 1, "Corridor" })
    local pad = 40
    return { L = L, Rooms = rooms, Paths = paths, Rects = rects, X0 = minX - pad, X1 = maxX + pad, Z0 = minZ - pad, Z1 = maxZ + pad }
end

local function Draw()
    local S = U()
    local C = S.Colors
    local g = cur.Geo
    local w, h = g.X1 - g.X0, g.Z1 - g.Z0
    local canvas = New("Frame", { Name = "Floor", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Parent = ui.Pivot }) :: Frame
    local function P(x: number, z: number): (number, number) return g.X1 - x, g.Z1 - z end
    cur.P = P
    local function Slab(name: string, x0: number, x1: number, z0: number, z1: number, z: number): Frame
        local px, py = P(math.max(x0, x1), math.max(z0, z1))
        return New("Frame", { Name = name, BorderSizePixel = 0, Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(math.abs(x1 - x0), math.abs(z1 - z0)),
            BackgroundColor3 = C.Bg2, ZIndex = z, Parent = canvas }) :: Frame
    end
    cur.RectF = {}
    for _, r in ipairs(g.Rects) do
        local f = Slab(r[5], r[1], r[2], r[3], r[4], 2)
        table.insert(cur.RectF, f)
        f.BackgroundColor3 = (r[5] == "Start") and C.Bg2 or C.Line
        if r[5] == "Start" then S.InkEdge(2).Parent = f end
    end
    cur.PathF = {}
    for k, p in ipairs(g.Paths) do
        cur.PathF[k] = {}
        for _, b in ipairs(p.Boxes) do table.insert(cur.PathF[k], Slab("Path" .. k, b[1], b[2], b[3], b[4], 2)) end
    end
    cur.RoomF = {}
    for i, r in ipairs(g.Rooms) do
        local f = Slab("Room" .. i, r[1], r[2], r[3], r[4], 3)
        local st = New("UIStroke", { Thickness = 2, LineJoinMode = Enum.LineJoinMode.Miter, Color = C.Ink, Parent = f }) :: UIStroke
        cur.RoomF[i] = { F = f, Edge = st, Kind = r.Kind }
    end
    -- closed gates (sealed rooms' way on)
    cur.Gates = {}
    if g.L then
        local LRm = LR()
        for i = 1, g.L.Main - 1 do
            local d = LRm.DoorPoint(g.L, i, i + 1, 2)
            local p = LRm.PathBetween(g.L, i, i + 1)
            if d and p then
                local gf = Slab("Gate" .. i, d.X - p.W / 2, d.X + p.W / 2, d.Z - 2, d.Z + 4, 6)
                gf.BackgroundColor3 = C.Warn
                gf.Visible = false
                cur.Gates[i] = gf
            end
        end
    end
    -- the side cache + the exit portal (a diamond: a turned square -- no text in a turning map)
    local function Mark(name: string, x: number, z: number, size: number, col: Color3, rot: number): Frame
        local px, py = P(x, z)
        local f = New("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = col, BorderSizePixel = 0, Rotation = rot, ZIndex = 7, Parent = canvas }) :: Frame
        S.InkEdge(2).Parent = f
        return f
    end
    if g.L and g.L.Side then
        local sr = g.L.Rooms[g.L.Side]
        cur.Cache = Mark("Cache", sr.X, sr.Z - g.L.Half * 0.35, 9, C.Warn, 0)
    end
    local er = g.Rooms[g.L and g.L.Exit or 1]
    cur.Portal = Mark("Portal", er.X, er.Z + 30, 11, C.Good, 45)
    cur.Portal.Visible = false
    cur.Canvas = canvas
    cur.Dots = {}
end

-- ==================== live data ====================
local function Alive(m: Instance): boolean
    if m:GetAttribute("Dead") == true or m:GetAttribute("PredictedDead") == true then return false end
    local h = m:GetAttribute("Health")
    return h == nil or h > 0
end
-- what's left per linked room (the stand-ins / server bots made so far -- a room you haven't reached has none yet)
local function Counts(ctx: any): { [number]: number }
    local out = {}
    local function Add(m: Instance)
        local r = m:GetAttribute("LinkRoom")
        if type(r) == "number" and Alive(m) then out[r] = (out[r] or 0) + 1 end
    end
    local root = ctx.Party and ctx.Folder or ctx.Folder:FindFirstChild("Enemies")
    if root then for _, m in ipairs(root:GetChildren()) do Add(m) end end
    local lk = ctx.Linked
    if ctx.Party and lk and lk.Held then for m in pairs(lk.Held) do if m.Parent then Add(m) end end end
    return out
end
-- the enemies drawn on YOUR screen (solo: the client's models; party: the server's bots in the run folder -- held ones are out of it)
local function Enemies(ctx: any): { Instance }
    if ctx.Enemies then return ctx.Enemies() end
    local out = {}
    for _, m in ipairs(ctx.Folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("MaxHealth") ~= nil then table.insert(out, m) end
    end
    return out
end

local function Dot(k: number): Frame
    local d = cur.Dots[k]
    if d then return d end
    local S = U()
    d = New("Frame", { Name = "D", AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = S.Colors.Bad, ZIndex = 8, Parent = cur.Canvas }) :: Frame
    New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = d })
    local st = New("UIStroke", { Color = S.Colors.Ink, Thickness = 1, Parent = d }) :: UIStroke
    d:SetAttribute("k", k)
    cur.Dots[k] = d
    cur.DotStroke = cur.DotStroke or {}
    cur.DotStroke[k] = st
    return d
end

local function Refresh()
    if not cur or not cur.Canvas then return end
    local S = U()
    local C = S.Colors
    local ctx, g = cur.Ctx, cur.Geo
    local f = ctx.Folder
    local cleared = f:GetAttribute("FloorCleared") == true
    -- rooms: fog / seen / clear
    if g.L then
        local LRm = LR()
        local counts = Counts(ctx)
        local sealed = LRm.SealParse(f:GetAttribute("LinkSeal"))
        local now = os.clock()
        for i, rf in pairs(cur.RoomF) do
            local visited = cur.Visited[i] == true
            local n = counts[i] or 0
            if n > 0 then cur.Seen[i] = true end
            local clear = (rf.Kind == "Exit" and cleared) or (visited and n == 0 and (cur.Seen[i] or now - (cur.VisitAt[i] or now) > 3))
            local col = clear and Color3.fromRGB(30, 62, 46) or C.Bg2
            local tr = visited and 0.05 or 0.85
            tr = 1 - (1 - tr) * (1 - (ui.Fade or 0))
            if rf.F.BackgroundColor3 ~= col then rf.F.BackgroundColor3 = col end
            if rf.F.BackgroundTransparency ~= tr then rf.F.BackgroundTransparency = tr end
            local ec = visited and C.Ink or C.Muted
            if rf.Kind == "Exit" then ec = cleared and C.Good or (visited and C.Ink or C.Gold) end
            if rf.Edge.Color ~= ec then rf.Edge.Color = ec end
        end
        for k, list in pairs(cur.PathF) do
            local p = g.Paths[k]
            local c = (cur.Visited[p.A] or cur.Visited[p.B]) and C.Bg2 or C.Line
            local ptr = ui.Fade or 0
            for _, fr in ipairs(list) do
                if fr.BackgroundColor3 ~= c then fr.BackgroundColor3 = c end
                if fr.BackgroundTransparency ~= ptr then fr.BackgroundTransparency = ptr end
            end
        end
        for i, gf in pairs(cur.Gates) do
            local v = sealed[i] ~= nil
            if gf.Visible ~= v then gf.Visible = v end
        end
        if cur.Cache then
            local cs = f:GetAttribute("LinkCache") or ""
            local col = (cs == "OPEN") and C.Gold or ((cs == "USED") and C.Muted or C.Warn)
            if cur.Cache.BackgroundColor3 ~= col then cur.Cache.BackgroundColor3 = col end
        end
    else
        local rf = cur.RoomF[1]
        local col = cleared and Color3.fromRGB(30, 62, 46) or C.Bg2
        if rf and rf.F.BackgroundColor3 ~= col then rf.F.BackgroundColor3 = col end
        local tr = 1 - 0.95 * (1 - (ui.Fade or 0))
        if rf and rf.F.BackgroundTransparency ~= tr then rf.F.BackgroundTransparency = tr end
    end
    if cur.Portal.Visible ~= cleared then cur.Portal.Visible = cleared end
    for _, rf in ipairs(cur.RectF) do
        local tr = ui.Fade or 0
        if rf.BackgroundTransparency ~= tr then rf.BackgroundTransparency = tr end
    end
    -- markers (pooled dots): enemies, party members, Rare+ loot
    local P = cur.P
    local k = 0
    local function Put(pos: Vector3, size: number, col: Color3, tr: number, square: boolean)
        if k >= MiniMap.MAX_DOTS then return end
        k += 1
        local d = Dot(k)
        local px, py = P(pos.X, pos.Z)
        d.Position = UDim2.fromOffset(px, py)
        if d.Size.X.Offset ~= size then d.Size = UDim2.fromOffset(size, size) end
        if d.BackgroundColor3 ~= col then d.BackgroundColor3 = col end
        if d.BackgroundTransparency ~= tr then d.BackgroundTransparency = tr end
        local rot = square and 45 or 0
        if d.Rotation ~= rot then d.Rotation = rot end
        local corner = d:FindFirstChildOfClass("UICorner")
        if corner then
            local want = square and UDim.new(0, 0) or UDim.new(0.5, 0)
            if corner.CornerRadius ~= want then corner.CornerRadius = want end
        end
        if not d.Visible then d.Visible = true end
    end
    for _, m in ipairs(Enemies(ctx)) do
        if m.Parent and Alive(m) then
            local ok, pv = pcall(m.GetPivot, m)
            if ok then
                local size = MiniMap.DOT.Bot
                if m:GetAttribute("IsBoss") then size = MiniMap.DOT.Boss
                elseif m:GetAttribute("IsMiniBoss") then size = MiniMap.DOT.Mini
                else
                    local et, em = m:GetAttribute("EliteTier"), m:GetAttribute("EliteMods") -- (a tier name or number; party bots carry "Magic" / "Rare")
                    if (et ~= nil and et ~= 0 and et ~= "") or (type(em) == "string" and em ~= "") then size = MiniMap.DOT.Elite
                    elseif m:GetAttribute("Fodder") then size = MiniMap.DOT.Fodder end
                end
                local idle = g.L ~= nil and m:GetAttribute("LinkPack") ~= nil and m:GetAttribute("Awake") ~= true
                Put(pv.Position, size, C.Bad, idle and 0.55 or 0, false)
            end
        end
    end
    local id = LocalPlayer:GetAttribute("RunId")
    if ctx.Party and type(id) == "string" and id ~= "" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p:GetAttribute("RunId") == id then
                local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if r then Put(r.Position, 8, C.Good, 0, false) end
            end
        end
    end
    local okG, GL = pcall(require, Shared:FindFirstChild("GroundLoot"))
    if okG and GL and GL.MapDrops then
        for _, dr in ipairs(GL.MapDrops()) do Put(dr.Pos, 7, dr.Col, 0, true) end
    end
    for j = k + 1, #cur.Dots do
        local d = cur.Dots[j]
        if d.Visible then d.Visible = false end
    end
end

-- ==================== mode / layout / per-frame turn ====================
local function MenuOpen(): boolean
    local hud = LocalPlayer.PlayerGui:FindFirstChild("AimRngMasterHUD")
    local menus = hud and hud:FindFirstChild("Menus")
    if not menus then return false end
    for _, c in ipairs(menus:GetChildren()) do
        if c:IsA("GuiObject") and c.Visible then return true end
    end
    return false
end

local function Layout()
    if not ui then return end
    local S = U()
    local C = S.Colors
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local zoomK = MiniMap.ZOOM[GS().Get("MinimapZoom") or "Normal"] or MiniMap.ZOOM.Normal
    if mode == "Large" then
        local px = MiniMap.LARGE_PX
        ui.Win.AnchorPoint = Vector2.new(0.5, 0.5)
        ui.Win.Position = UDim2.fromScale(0.5, 0.5)
        ui.Win.Size = UDim2.fromOffset(px, px)
        ui.Win.BackgroundTransparency = 0.6
        ui.Grp.BackgroundTransparency = 1
        ui.Fade = 0.4 -- (see-through: the rooms' fills x this, below)
        ui.Fit.Scale = math.clamp(math.min(vp.Y * 0.78 / px, vp.X * 0.7 / px), 0.45, 1)
        ui.Zoom.Scale = zoomK * MiniMap.LARGE_ZOOM
        ui.Me.Visible = false -- (the crosshair is the middle of the large map: no arrow drawn over it -- owner rule)
        local key = GS().TouchOnly() and "TAP" or string.upper(GS().KeyLabel(GS().BindName("Map")))
        ui.Legend.Text = "● ENEMY   ● PARTY   ◆ PORTAL   ■ CACHE   ▬ GATE     [" .. key .. "] SMALL / OFF"
        ui.Legend.Visible = true
    else
        local px = MiniMap.CORNER_PX
        ui.Win.AnchorPoint = Vector2.new(1, 0)
        do -- (UI CLEAN P5: the screen grid -- right edge on the currency chips' margin, top = under the chips (20 + 36) + GAP, in HUD units x the HUD scale)
            local k = S.InterfaceScale and S.InterfaceScale() or 1 -- (= the HUD gui's own scale)
            -- (UI CLEAN R-C: the currency row is 32 tall now -- RunHud.CUR_H)
            ui.Win.Position = UDim2.new(1, -math.floor((S.MARGIN or 16) * k + 0.5), 0, math.floor((20 + 32 + (S.GAP or 8)) * k + 0.5))
        end
        ui.Win.Size = UDim2.fromOffset(px, px)
        ui.Win.BackgroundTransparency = 0.2 -- (UI CLEAN R-C: the HUD plate, a little more solid -- rooms must read over bright floors)
        ui.Grp.BackgroundTransparency = 1
        ui.Fade = 0
        ui.Fit.Scale = math.clamp(vp.Y / 820, 0.62, 1)
        ui.Zoom.Scale = zoomK
        ui.Me.Visible = true
        ui.Legend.Visible = false
    end
    ui.Tap.Visible = GS().TouchOnly()
end

local lastYaw, lastPos = nil, nil
local function Step()
    if not cur or not cur.Canvas or not ui then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local pos = hrp and hrp.Position or cam.CFrame.Position
    local lv = cam.CFrame.LookVector
    if math.abs(lv.X) + math.abs(lv.Z) < 1e-3 then lv = cam.CFrame.UpVector end
    -- the way you look points UP: map heading (-lv.X, -lv.Z) turned to (0, -1)
    local yaw = -90 - math.deg(math.atan2(-lv.Z, -lv.X))
    if lastYaw and math.abs(yaw - lastYaw) < 0.4 and lastPos and (pos - lastPos).Magnitude < 0.25 then return end
    lastYaw, lastPos = yaw, pos
    local px, py = cur.P(pos.X, pos.Z)
    cur.Canvas.Position = UDim2.fromOffset(-px, -py)
    ui.Pivot.Rotation = yaw
end

local function Apply()
    local want = cur ~= nil and mode ~= "Off" and not cur.MenuHidden
    if want and not cur.Canvas then
        BuildUi()
        Layout()
        Draw()
    end
    if want ~= shown then
        shown = want
        if ui then ui.Gui.Enabled = want end
        if stepConn then stepConn:Disconnect(); stepConn = nil end
        lastYaw, lastPos = nil, nil
        if want then
            stepConn = RunService.RenderStepped:Connect(Step)
            Step()
        end
    end
end

local function TickLoop()
    tickToken += 1
    local my = tickToken
    task.spawn(function()
        while my == tickToken and cur do
            -- a window open hides it (markers stop too); checked here at 10 Hz, not every frame
            local mh = MenuOpen()
            if mh ~= (cur.MenuHidden == true) then cur.MenuHidden = mh; Apply() end
            if shown then
                local ok, err = pcall(Refresh)
                if not ok and not cur.Warned then cur.Warned = true; warn("[MiniMap] " .. tostring(err)) end -- (once a floor; keeps going)
            end
            task.wait(MiniMap.TICK)
        end
    end)
end

function MiniMap.SetMode(m: string)
    if m ~= "Corner" and m ~= "Large" and m ~= "Off" then m = "Corner" end
    mode = m
    if RunService:IsStudio() then LocalPlayer:SetAttribute("DevMapMode", m) end -- (tests read the live mode here)
    if ui then Layout() end
    lastYaw = nil
    Apply()
end
function MiniMap.Cycle()
    local i = table.find(MiniMap.MODES, mode) or 1
    local nxt = MiniMap.MODES[i % #MiniMap.MODES + 1]
    GS().Set("Minimap", nxt) -- (saved; OnChanged below applies it)
    if GS().Get("Minimap") ~= nxt then MiniMap.SetMode(nxt) end
end
function MiniMap.Mode(): string return mode end

-- ctx = { Cfg = the floor config (Linked / Seed / Difficulty), Folder = the run folder (solo PlayerGui.AimRngRun, party
-- workspace.PartyRuns.Run_<id>), Party, Linked = DungeonClient's linked record (party: Held), Enemies = fn -> models (solo) }
function MiniMap.Floor(ctx: any)
    MiniMap.Clear()
    cur = { Ctx = ctx, Visited = {}, VisitAt = {}, Seen = {} }
    local ok, geo = pcall(Geometry, ctx)
    if not ok then warn("[MiniMap] " .. tostring(geo)); cur = nil; return end
    cur.Geo = geo
    if not geo.L then cur.Visited[1] = true end
    Apply()
    TickLoop()
end
function MiniMap.Clear(partyOnly: boolean?)
    if not cur then return end
    if partyOnly and not cur.Ctx.Party then return end
    tickToken += 1
    if cur.Canvas then cur.Canvas:Destroy() end
    cur = nil
    Apply()
end
function MiniMap.Visit(i: number, inside: boolean)
    if not cur or not inside or cur.Visited[i] then return end
    cur.Visited[i] = true
    cur.VisitAt[i] = os.clock()
end

-- input + settings
if RunService:IsClient() and LocalPlayer then
    local G = GS()
    G.OnChanged("Minimap", function(v) MiniMap.SetMode(v) end)
    G.OnChanged("MinimapZoom", function() if ui then Layout(); lastYaw = nil end end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if not cur then return end
        if input.KeyCode == MiniMap.PAD_KEY then
            if not G.IsTyping() then MiniMap.Cycle() end
            return
        end
        if gp or G.IsTyping() then return end
        if G.InputIs(input, "Map") then MiniMap.Cycle() end
    end)
    LocalPlayer:GetAttributeChangedSignal("DevMap"):Connect(function()
        local v = LocalPlayer:GetAttribute("DevMap")
        if not RunService:IsStudio() or type(v) ~= "string" then return end
        if v == "Cycle" then MiniMap.Cycle() else MiniMap.SetMode(v) end
    end)
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if ui then Layout() end end)
    end
end

return MiniMap
