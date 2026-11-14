--!nocheck
-- ============================================================================================
-- THE BAZAAR (0.55, owner 2026-10-06: "Add trading while I'm gone too, and a trading hub for players").
-- A night market courtyard of the walled city, far west of the hub (Zones.MARKET_CENTER), shared by everyone in the
-- server (InstanceKey "market"): the place to meet traders. Same look as the city (HubCity): grimy towers with the window
-- grid texture, neon boards in Chinese with English under them, lantern strings, cables, steam, wet street.
--   * 6 TRADE TABLES: a booth each (counter, stools, awning, lantern). Their prompt opens the TRADE window.
--   * the FURNITURE STALL: the hideout furniture shop (gold pieces).
--   * THE TRADE BOARD: a tall neon board in the middle, the Bazaar's landmark.
--   * the CITY GATE: a neon arch; its prompt takes you back to the hub.
-- Everything is anchored, decor is CanQuery / CanTouch off, only walkable pieces collide. Budget ~700 parts, 3 lights.
-- HubMarket.Build() -> the folder; HubMarket.SPAWN = where the teleport menu drops you.
-- ============================================================================================
local HubMarket = {}

local Zones = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Zones"))
local HubCity = require(script.Parent:WaitForChild("HubCity")) -- (UPDATE 4: the city's facade tiles, paper lanterns, wet street)
local EnvKit = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("EnvKit")) -- (UPDATE 4: AC / cage relief)
local M = Enum.Material
local function C(r, g, b) return Color3.fromRGB(r, g, b) end
local O = Zones.MARKET_CENTER -- ground centre (top of the street = O.Y)
local G = O.Y
local HALF = 70 -- courtyard half size (the towers stand outside it)
HubMarket.SPAWN = CFrame.lookAt(O + Vector3.new(0, 3, 52), O + Vector3.new(0, 3, 0))
local WINDOW_GRID = "rbxassetid://125253926384764" -- (HubCity.WINDOW_GRID)

local NEON = { Red = C(255, 40, 60), Pink = C(255, 70, 190), Cyan = C(40, 230, 255), Green = C(70, 255, 130), Amber = C(255, 170, 40), Violet = C(170, 90, 255) }
local GRIME = { C(92, 84, 74), C(78, 72, 66), C(104, 96, 80), C(70, 76, 74), C(98, 80, 72), C(84, 92, 86), C(110, 100, 84), C(66, 62, 60) }

local folder
local function P(props: any): BasePart
    local p = Instance.new(props.Wedge and "WedgePart" or "Part")
    p.Anchored = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.CastShadow = props.Shadow == true
    p.CanCollide = props.Collide == true
    p.CanQuery = props.Collide == true
    p.CanTouch = false
    for k, v in pairs(props) do
        if k ~= "Wedge" and k ~= "Shadow" and k ~= "Collide" and k ~= "Parent" then p[k] = v end
    end
    p.Parent = props.Parent or folder
    return p
end
local function Neon(props: any): BasePart
    props.Material = M.Neon
    return P(props)
end
local function Sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3, sub: string?)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 24
    sg.LightInfluence = 0; sg.Brightness = 1.7; sg.Parent = part
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBlack; t.TextScaled = true; t.TextColor3 = color; t.Text = text
    t.TextStrokeColor3 = C(10, 6, 8); t.TextStrokeTransparency = 0.3
    t.Size = UDim2.fromScale(0.9, sub and 0.56 or 0.84); t.Position = UDim2.fromScale(0.05, 0.06)
    t:SetAttribute("KeepFont", true)
    t.Parent = sg
    if sub then
        local s = t:Clone(); s.Text = sub; s.Font = Enum.Font.GothamBold; s.Size = UDim2.fromScale(0.86, 0.28); s.Position = UDim2.fromScale(0.07, 0.66)
        s.TextColor3 = C(240, 236, 228); s.Parent = sg
    end
end
local function Prompt(part: BasePart, action: string, object: string, name: string): ProximityPrompt
    local pp = Instance.new("ProximityPrompt")
    pp.Name = name
    pp.ActionText = action
    pp.ObjectText = object
    pp.MaxActivationDistance = 11
    pp.RequiresLineOfSight = false
    pp.HoldDuration = 0
    pp.Style = Enum.ProximityPromptStyle.Default
    pp.Parent = part
    return pp
end

-- a tower block standing on the courtyard's edge: body + window grid on the face toward the courtyard, a few lit
-- windows, an AC unit or two, a neon blade sign. face = the outward normal (toward the courtyard centre).
local facadeRng = Random.new(3307) -- (which facade tile a tower wears: its own stream)
local reliefRng = Random.new(4411) -- (UPDATE 4: the kit relief on the towers -- its own stream)
local propRng = Random.new(5151) -- (G.25: street props at the tower feet -- its own stream)
local streetN = 0 -- (UPDATE 4: which shop-level tile a tower wears, in turn)
-- (HUB LOOK 2026-10-24, owner: "copy and paste items") per-instance look of the repeated kit props, its own stream
local varRng = Random.new(5152)
local function KV(name: string, scale: number, pct: number, lo: number): any
    local sc, tint = HubCity.KitVary(varRng, name, scale, pct, lo)
    return { Parent = folder, Scale = sc, Tint = tint, Shadow = false }
end
local function Tower(rng: Random, pos: Vector3, w: number, d: number, h: number, faceYaw: number)
    local cf = CFrame.new(pos.X, G + h / 2, pos.Z) * CFrame.Angles(0, math.rad(faceYaw), 0)
    local col = GRIME[rng:NextInteger(1, #GRIME)]
    -- (UPDATE 4: the city's facade tiles -- framed windows, cages, AC boxes, laundry -- on the floors above the shop level;
    -- the plain street-level mass below. The window grid texture + AC parts are gone; every old draw is kept in order.)
    local F0 = HubCity.FACADE_FLOOR0
    local body = P({ Name = "Tower", Size = Vector3.new(w, F0, d), CFrame = cf * CFrame.new(0, F0 / 2 - h / 2, 0), Color = col, Material = M.Concrete, Collide = true })
    local upper = P({ Name = "Tower", Size = Vector3.new(w, h - F0, d), CFrame = cf * CFrame.new(0, F0 / 2, 0), Color = col, Material = M.Concrete, Collide = true })
    HubCity.FacadeTex(upper, facadeRng:NextInteger(1, #HubCity.FACADES), G + h, w, G, HubCity.FACES_SIDES) -- (windows on the sides too)
    -- (UPDATE 4: the street level was a plain dark band) a shop level on the face: signboards, a shutter, a lit display
    -- window, a door -- two Textures, no parts; the lit twin skips the plaza dimming
    streetN += 1
    local sk = streetN % #HubCity.IMG.Street + 1
    for layer, img in ipairs({ HubCity.IMG.Street[sk], HubCity.IMG.StreetGlow[sk] }) do
        local tx = Instance.new("Texture")
        tx.Name = (layer == 1) and "Street" or "StreetGlow"
        tx.Texture = img; tx.Face = Enum.NormalId.Front
        tx.StudsPerTileU = 20; tx.StudsPerTileV = F0
        tx.OffsetStudsU = (streetN * 7.3) % 20
        tx.ZIndex = layer -- (the lit twin draws over the wall tile: equal ZIndex left the order to chance)
        if layer == 2 then tx:SetAttribute("NoDim", true) end
        tx.Parent = body
    end
    -- (UPDATE 4) real relief on the floors the eye sees: kit AC units under a window, a barred balcony cage over one,
    -- snapped into the tile's bays (the tops sit on a floor line now, so the relief MaterialVariant lines up as well)
    for _, fy in ipairs({ 16, 26, 36, 46 }) do
        if fy + 10 <= h then
            if EnvKit.Has("City", "ACUnit") and reliefRng:NextNumber() < 0.85 then
                local bx = HubCity.FacadeBayX(reliefRng:NextNumber(-w / 2 + 3, w / 2 - 3), w)
                if bx then EnvKit.Place("City", "ACUnit", cf * CFrame.new(bx, fy + 1.0 - h / 2, -d / 2 - 0.6), KV("ACUnit", 1.1, 0.12, 0.7)) end
            end
            if EnvKit.Has("City", "BalconyCage") and reliefRng:NextNumber() < 0.5 then
                local bx = HubCity.FacadeBayX(reliefRng:NextNumber(-w / 2 + 4, w / 2 - 4), w)
                if bx then EnvKit.Place("City", "BalconyCage", cf * CFrame.new(bx, fy + 2.6 - h / 2, -d / 2 - 1.7), KV("BalconyCage", 1.7, 0.08, 0.72)) end
            end
        end
    end
    -- (G.25) the street level: a doorstep shrine, gas cylinders, a parked bicycle (not by the
    -- city gate in the middle of the south side)
    if not (faceYaw == 0 and math.abs(pos.X - O.X) < 16) then
        local used = {}
        local function Slot(half: number): number?
            for _ = 1, 5 do
                if w - 4 < half * 2 then return nil end
                local x = propRng:NextNumber(-w / 2 + 2 + half, w / 2 - 2 - half)
                local ok = true
                for _, u in ipairs(used) do if x + half > u[1] and x - half < u[2] then ok = false end end
                if ok then table.insert(used, { x - half, x + half }); return x end
            end
            return nil
        end
        local base = -h / 2
        if propRng:NextNumber() < 0.45 then
            local _ = Slot(1.4) -- (was a meter box on the wall: the drawn shop level fills the wall now; the draw is kept)
        end
        if propRng:NextNumber() < 0.25 then
            local x = Slot(1.1)
            if x then EnvKit.Place("City", "DoorShrine", cf * CFrame.new(x, base, -d / 2 - 0.75) * CFrame.Angles(0, math.rad(varRng:NextNumber(-6, 6)), 0), KV("DoorShrine", 1, 0.1, 0.8)) end
        end
        if propRng:NextNumber() < 0.22 then
            local x = Slot(1.6)
            if x then EnvKit.Place("City", "GasCage", cf * CFrame.new(x, base, -d / 2 - 1.4) * CFrame.Angles(0, math.rad(varRng:NextNumber(-8, 8)), 0), KV("GasCage", 1.4, 0.08, 0.72)) end
        end
        if propRng:NextNumber() < 0.18 then
            local x = Slot(2.6)
            if x then EnvKit.Place("City", "Bicycle", cf * CFrame.new(x, base, -d / 2 - 0.95) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(4)) * CFrame.Angles(0, math.rad(varRng:NextNumber(-10, 10)), 0), KV("Bicycle", 1.45, 0.06, 0.7)) end
        end
    end
    -- lit rooms (dim and sparse), snapped into the texture's window bays
    for fy = 21.5, h - 6, 10 do
        if rng:NextNumber() < 0.2 then
            local x = HubCity.FacadeBayX(rng:NextNumber(-w / 2 + 3, w / 2 - 3), w)
            local lc = (rng:NextNumber() < 0.7) and C(214, 150, 84) or C(110, 150, 196)
            if x and fy + 4 < h then
                Neon({ Name = "LitWindow", Size = Vector3.new(HubCity.FACADE_WIN.W, HubCity.FACADE_WIN.H, 0.12), CFrame = cf * CFrame.new(x, (fy - 5.5 + HubCity.FACADE_WIN.Mid) - h / 2, -d / 2 - 0.06), Color = lc, Transparency = 0.55 })
            end
        end
    end
    for _ = 1, rng:NextInteger(1, 2) do local _ = rng:NextNumber(-w / 2 + 3, w / 2 - 3) end -- (was: AC parts; the texture has them)
    -- a vertical neon blade sign
    if rng:NextNumber() < 0.7 then
        local words = { "當舖", "茶樓", "金舖", "藥房", "電器", "眼鏡", "書局", "冰室" }
        local nc = ({ NEON.Red, NEON.Pink, NEON.Cyan, NEON.Green, NEON.Amber, NEON.Violet })[rng:NextInteger(1, 6)]
        local bx = rng:NextNumber(-w / 2 + 2, w / 2 - 2)
        local blade = P({ Name = "BladeSign", Size = Vector3.new(0.5, 9, 3), CFrame = cf * CFrame.new(bx, 13 - h / 2 + rng:NextNumber(0, 6), -d / 2 - 1.8), Color = C(24, 20, 26), Material = M.SmoothPlastic })
        Neon({ Name = "BladeEdge", Size = Vector3.new(0.6, 9.2, 0.2), CFrame = blade.CFrame * CFrame.new(0, 0, -1.6), Color = nc })
        HubCity.BladeFrame(P, blade, 1.8) -- (UPDATE 4: steel brackets into the wall)
        local s = words[rng:NextInteger(1, #words)]
        local out = {}
        for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
        Sign(blade, Enum.NormalId.Left, table.concat(out, "\n"), nc)
        Sign(blade, Enum.NormalId.Right, table.concat(out, "\n"), nc)
    end
    return upper
end

-- a TRADE TABLE booth facing `dir` (yaw degrees; 0 = its counter faces -Z)
local function Booth(cf: CFrame, accent: Color3, n: number)
    -- (HUB LOOK 2026-10-24, owner: "copy and paste items": six identical booths -> each its own lean of the awning, wood
    -- tone, stool spots and lantern side / height; a couple of degrees of yaw. Same parts, same prompt spot)
    local bv = Random.new(n * 977 + 13)
    cf = cf * CFrame.Angles(0, math.rad(bv:NextNumber(-3, 3)), 0)
    local wood = C(92, 58, 40):Lerp(C(70, 52, 40), bv:NextNumber())
    P({ Name = "BoothFloor", Size = Vector3.new(12, 0.3, 9), CFrame = cf * CFrame.new(0, 0.15, 0), Color = C(56, 42, 36), Material = M.WoodPlanks, Collide = true })
    local counter = P({ Name = "TradeCounter", Size = Vector3.new(9, 3.2, 2.4), CFrame = cf * CFrame.new(0, 1.9, -1), Color = wood, Material = M.Wood, Collide = true })
    P({ Name = "CounterTop", Size = Vector3.new(9.6, 0.3, 3), CFrame = cf * CFrame.new(0, 3.65, -1), Color = C(46, 38, 36), Material = M.Marble })
    Neon({ Name = "CounterEdge", Size = Vector3.new(9.6, 0.15, 0.15), CFrame = cf * CFrame.new(0, 3.5, -2.55), Color = accent })
    -- two stools on the street side, a lantern and a ledger on the counter
    for sx = -1, 1, 2 do
        local sp = CFrame.new(sx * bv:NextNumber(1.8, 3.2), 0, -4 - bv:NextNumber(-0.3, 0.8))
        P({ Name = "Stool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.6, 1.6), CFrame = cf * sp * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ({ C(170, 40, 46), C(60, 92, 130), C(150, 120, 60) })[bv:NextInteger(1, 3)], Material = M.SmoothPlastic })
        P({ Name = "StoolLeg", Size = Vector3.new(0.3, 2, 0.3), CFrame = cf * sp * CFrame.new(0, 1.1, 0), Color = C(40, 40, 44), Material = M.Metal })
    end
    P({ Name = "Ledger", Size = Vector3.new(1.4, 0.2, 1), CFrame = cf * CFrame.new(-2.6, 3.9, -1) * CFrame.Angles(0, math.rad(12), 0), Color = C(120, 30, 34), Material = M.SmoothPlastic })
    P({ Name = "CoinStack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = cf * CFrame.new(2.8, 4.1, -1) * CFrame.Angles(0, 0, math.rad(90)), Color = C(250, 196, 60), Material = M.Metal })
    -- back wall, posts, striped awning
    -- three booth builds (n): "Stripe" brick back + striped canvas, "Tin" corrugated tin back + plain dark canvas, "Tile"
    -- glazed-tile back + a steeper striped canvas
    local style = ({ "Stripe", "Tin", "Tile" })[(n - 1) % 3 + 1]
    local backWall = P({ Name = "BoothBack", Size = Vector3.new(12, 9, 0.6), CFrame = cf * CFrame.new(0, 4.6, 4.2), Color = C(40, 36, 40), Material = M.Brick, Collide = true })
    if style == "Tin" then backWall.Material = M.CorrodedMetal; backWall.Color = C(84, 78, 70)
    elseif style == "Tile" then backWall.Material = M.SmoothPlastic; backWall.Color = C(70, 72, 70); HubCity.Img(backWall, Enum.NormalId.Front, HubCity.IMG.Tiles, 3, C(150, 150, 140):Lerp(accent, 0.12)) end
    for sx = -1, 1, 2 do
        P({ Name = "Post", Size = Vector3.new(0.5, 9, 0.5), CFrame = cf * CFrame.new(sx * 5.7, 4.5, -3.8), Color = C(30, 30, 34), Material = M.Metal })
    end
    -- (UPDATE 4: one canvas with printed stripes instead of six strips)
    local awning = P({ Name = "Awning", Size = Vector3.new(12, 0.2, 8.6), CFrame = cf * CFrame.new(0, 9.4, 0) * CFrame.Angles(math.rad((style == "Tile") and bv:NextNumber(-18, -14) or bv:NextNumber(-12, -7)), 0, 0), Color = accent:Lerp(C(0, 0, 0), bv:NextNumber(0.3, 0.45)), Material = M.Fabric })
    if style == "Tin" then awning.Color = accent:Lerp(C(24, 22, 26), 0.72) end
    for _, face in ipairs((style == "Tin") and {} or { Enum.NormalId.Top, Enum.NormalId.Bottom }) do
        local st = HubCity.Img(awning, face, HubCity.IMG.Stripes, 4)
        if st then st.StudsPerTileV = 8.6 end
    end
    -- goods on a shelf + a poster on the back wall
    P({ Name = "BackShelf", Size = Vector3.new(9, 0.25, 1.2), CFrame = cf * CFrame.new(0, 5.6, 3.3), Color = C(70, 50, 34), Material = M.WoodPlanks })
    local gp = P({ Name = "Goods", Size = Vector3.new(8.6, 2.2, 0.05), CFrame = cf * CFrame.new(0, 5.73 + 1.1, 3.5), Transparency = 1 })
    HubCity.Img(gp, Enum.NormalId.Front, HubCity.IMG.Goods[n % 3 + 1])
    local poster = P({ Name = "Poster", Size = Vector3.new(2.2, 3.2, 0.05), CFrame = cf * CFrame.new(n % 2 == 0 and -3.6 or 3.6, 7.2, 3.85) * CFrame.Angles(0, 0, math.rad((n % 3 - 1) * 3)), Transparency = 1 })
    HubCity.Img(poster, Enum.NormalId.Front, HubCity.IMG.Posters[n % 3 + 1])
    -- the board: 交易 + TRADE TABLE n
    local board = P({ Name = "BoothBoard", Size = Vector3.new(8, 2.2, 0.4), CFrame = cf * CFrame.new(0, 10.8, -4), Color = C(20, 16, 22), Material = M.SmoothPlastic })
    Neon({ Name = "BoardEdge", Size = Vector3.new(8.2, 0.15, 0.2), CFrame = board.CFrame * CFrame.new(0, -1.15, 0), Color = accent })
    Sign(board, Enum.NormalId.Front, "交易 " .. n, accent, "TRADE TABLE")
    -- a paper lantern + the counter's neon caught in the wet street (the plaza's cobbles stand 0.2 proud)
    HubCity.PaperLantern(P, cf * CFrame.new((bv:NextNumber() < 0.5) and 4.6 or -4.6, bv:NextNumber(7.1, 7.9), -3.6), bv:NextNumber(1.3, 1.6), C(230, 50, 40):Lerp(C(214, 70, 40), bv:NextNumber()))
    local gpos = (cf * CFrame.new(0, 0, -8.5)).Position
    local onPlaza = math.abs(gpos.X - O.X) < 30 and math.abs(gpos.Z - O.Z) < 30
    HubCity.WetGlow(P, cf * CFrame.new(0, onPlaza and 0.24 or 0.04, -8.5), 8, 10, accent, 0.35)
    -- the prompt lives on the counter top
    local anchor = P({ Name = "TradeTable" .. n, Size = Vector3.new(2, 1, 2), CFrame = cf * CFrame.new(0, 4.2, -1), Transparency = 1 })
    Prompt(anchor, "Trade", "Trade table", "PromptTrade")
    return anchor
end

function HubMarket.Build(): Folder
    local old = workspace:FindFirstChild("MarketWorld")
    if old then old:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "MarketWorld"
    local rng = Random.new(5150)
    varRng = Random.new(5152) -- (HUB LOOK: a rebuild comes out the same)

    -- ground: the wet street + kerbs + puddles
    local street = P({ Name = "Street", Size = Vector3.new(HALF * 2 + 60, 4, HALF * 2 + 60), CFrame = CFrame.new(O.X, G - 2, O.Z), Color = C(44, 42, 46), Material = M.Asphalt, Collide = true })
    local plaza = P({ Name = "Plaza", Size = Vector3.new(60, 0.2, 60), CFrame = CFrame.new(O.X, G + 0.1, O.Z), Color = C(70, 60, 56), Material = M.Cobblestone, Collide = true })
    -- (HUB LOOK 2026-10-24: the Bazaar's street was plain dark Asphalt -- after the night dimming (22, 21, 23) the first 40
    -- studs of the view were a black void -- and the plaza Roblox's stock cobbles. Same ground as the hub now: the
    -- HubAsphalt street + HubPaving pavers, the hub's colours)
    local MS = game:GetService("MaterialService")
    if MS:FindFirstChild("HubAsphalt") then
        street.MaterialVariant = "HubAsphalt"; street.Color = C(168, 164, 176)
    else
        HubCity.Img(street, Enum.NormalId.Top, HubCity.IMG.StreetWet, 48) -- (UPDATE 4: wet patches, not coloured slabs)
    end
    if MS:FindFirstChild("HubPaving") then plaza.Material = M.Pavement; plaza.MaterialVariant = "HubPaving"; plaza.Color = C(176, 168, 172) end
    for _ = 1, 9 do -- (was: puddle slabs; the draws are kept so the rest comes out the same)
        local _ = { rng:NextNumber(-HALF + 6, HALF - 6), rng:NextNumber(-HALF + 6, HALF - 6), rng:NextNumber(4, 9), rng:NextNumber(3, 7), rng:NextNumber(0, 3), rng:NextInteger(1, 3) }
    end

    -- the towers round the courtyard (their faces toward the middle) + invisible walls + a lid
    local function Row(side: string)
        local x = -HALF - 4
        while x < HALF + 4 do
            local w = rng:NextNumber(14, 24)
            local h = 26 + 10 * rng:NextInteger(5, 10) -- (UPDATE 4: was 21.5 + ..; the tops on a floor line for the relief)
            local d = 18
            local along = x + w / 2
            if side == "N" then Tower(rng, Vector3.new(O.X + along, 0, O.Z - HALF - d / 2), w, d, h, 180)
            elseif side == "S" then Tower(rng, Vector3.new(O.X + along, 0, O.Z + HALF + d / 2), w, d, h, 0)
            elseif side == "W" then Tower(rng, Vector3.new(O.X - HALF - d / 2, 0, O.Z + along), w, d, h, -90)
            else Tower(rng, Vector3.new(O.X + HALF + d / 2, 0, O.Z + along), w, d, h, 90) end
            x += w
        end
    end
    for _, s in ipairs({ "N", "S", "W", "E" }) do Row(s) end
    for _, sp in ipairs({ { Vector3.new(0, 0, -HALF - 1), Vector3.new(HALF * 2 + 40, 1, 2) }, { Vector3.new(0, 0, HALF + 1), Vector3.new(HALF * 2 + 40, 1, 2) },
        { Vector3.new(-HALF - 1, 0, 0), Vector3.new(2, 1, HALF * 2 + 40) }, { Vector3.new(HALF + 1, 0, 0), Vector3.new(2, 1, HALF * 2 + 40) } }) do
        local p = P({ Name = "MarketWall", Size = Vector3.new(sp[2].X, 160, sp[2].Z), CFrame = CFrame.new(O + sp[1] + Vector3.new(0, 80, 0)), Transparency = 1, Collide = true })
        p.CanQuery = false
    end
    local lid = P({ Name = "MarketLid", Size = Vector3.new(HALF * 2 + 40, 2, HALF * 2 + 40), CFrame = CFrame.new(O + Vector3.new(0, 150, 0)), Transparency = 1, Collide = true })
    lid.CanQuery = false

    -- THE TRADE BOARD: a tall neon landmark in the middle (a plinth, a pole, the double-sided board, a ring of lanterns)
    P({ Name = "Plinth", Size = Vector3.new(10, 1.6, 10), CFrame = CFrame.new(O + Vector3.new(0, 0.8, 0)), Color = C(54, 48, 50), Material = M.Granite, Collide = true })
    for k = 0, 3 do -- (a thin rim round the plinth top; a full slab glowed like a lamp)
        Neon({ Name = "PlinthEdge", Size = Vector3.new(10.2, 0.15, 0.25), CFrame = CFrame.new(O + Vector3.new(0, 1.62, 0)) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 4.98), Color = NEON.Cyan })
    end
    P({ Name = "Pole", Size = Vector3.new(1.4, 26, 1.4), CFrame = CFrame.new(O + Vector3.new(0, 14, 0)), Color = C(34, 32, 36), Material = M.Metal, Collide = true })
    do -- a four-sided sign box (two crossed boards cut through each other's text)
        local b = P({ Name = "TradeBoard", Size = Vector3.new(15, 7, 15), CFrame = CFrame.new(O + Vector3.new(0, 22, 0)), Color = C(20, 14, 24), Material = M.SmoothPlastic })
        for _, y in ipairs({ 3.6, -3.6 }) do
            for k = 0, 3 do
                Neon({ Name = "BoardFrame", Size = Vector3.new(15.4, 0.3, 0.3), CFrame = b.CFrame * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, y, 7.6), Color = (k % 2 == 0) and NEON.Pink or NEON.Cyan })
            end
        end
        Sign(b, Enum.NormalId.Front, "交易市場", NEON.Pink, "THE BAZAAR  •  TRADE HERE")
        Sign(b, Enum.NormalId.Back, "交易市場", NEON.Pink, "THE BAZAAR  •  TRADE HERE")
        Sign(b, Enum.NormalId.Left, "交易市場", NEON.Cyan, "THE BAZAAR  •  TRADE HERE")
        Sign(b, Enum.NormalId.Right, "交易市場", NEON.Cyan, "THE BAZAAR  •  TRADE HERE")
    end
    for k = 0, 7 do
        local a = k / 8 * math.pi * 2
        HubCity.PaperLantern(P, CFrame.new(O + Vector3.new(math.cos(a) * 6, 17, math.sin(a) * 6)), 1.4, (k % 2 == 0) and C(220, 50, 44) or C(220, 140, 40))
    end
    local glow = P({ Name = "BoardLight", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(O + Vector3.new(0, 30, 0)), Transparency = 1 })
    local l = Instance.new("PointLight"); l.Color = C(255, 120, 200); l.Range = 30; l.Brightness = 0.6; l.Shadows = false; l.Parent = glow

    -- six trade tables in two rows facing the middle
    local accents = { NEON.Cyan, NEON.Pink, NEON.Green, NEON.Amber, NEON.Violet, NEON.Red }
    local n = 0
    for _, row in ipairs({ { z = -34, yaw = 180 }, { z = 34, yaw = 0 } }) do
        for _, x in ipairs({ -36, 0, 36 }) do
            n += 1
            local cf = CFrame.new(O + Vector3.new(x, 0, row.z)) * CFrame.Angles(0, math.rad(row.yaw), 0)
            if not (row.z > 0 and x == 0) then -- (the middle of the south row stays open: the city gate is behind it)
                Booth(cf, accents[n], n)
            end
        end
    end
    -- the FURNITURE STALL (hideout furniture for gold), west side
    do
        local cf = CFrame.new(O + Vector3.new(-54, 0, 0)) * CFrame.Angles(0, math.rad(-90), 0)
        local a = Booth(cf, NEON.Amber, 7)
        a.Name = "FurnitureStall"
        local pp = a:FindFirstChild("PromptTrade")
        pp.Name = "PromptFurniture"; pp.ActionText = "Browse"; pp.ObjectText = "Furniture stall"
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text == "交易 7" then d.Text = "家具" end
            if d:IsA("TextLabel") and d.Text == "TRADE TABLE" and d:IsDescendantOf(folder) and d.Parent.Parent.Name == "BoothBoard" and (d.Parent.Parent.Position - a.Position).Magnitude < 14 then d.Text = "HIDEOUT FURNITURE" end
        end
        -- crates of furniture behind it
        for k = 1, 4 do
            P({ Name = "Crate", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cf * CFrame.new(-6.5, 1.3 + ((k > 2) and 2.6 or 0), 1 + (k % 2) * 2.8) * CFrame.Angles(0, math.rad(k * 9), 0), Color = C(120, 86, 52), Material = M.WoodPlanks, Collide = true })
        end
    end
    -- the CITY GATE (south): a neon arch + its prompt
    do
        local gz = O.Z + HALF - 6
        for sx = -1, 1, 2 do
            P({ Name = "GatePillar", Size = Vector3.new(2.4, 16, 2.4), CFrame = CFrame.new(O.X + sx * 8, G + 8, gz), Color = C(150, 30, 36), Material = M.SmoothPlastic, Collide = true })
            Neon({ Name = "GatePillarGlow", Size = Vector3.new(0.3, 15, 0.3), CFrame = CFrame.new(O.X + sx * 6.7, G + 8, gz - 1.25), Color = NEON.Amber })
        end
        local beam = P({ Name = "GateBeam", Size = Vector3.new(22, 2.4, 3), CFrame = CFrame.new(O.X, G + 16.6, gz), Color = C(150, 30, 36), Material = M.SmoothPlastic })
        P({ Name = "GateRoof", Size = Vector3.new(26, 0.8, 5), CFrame = CFrame.new(O.X, G + 18.2, gz), Color = C(30, 26, 30), Material = M.Slate })
        Sign(beam, Enum.NormalId.Front, "回城", NEON.Amber, "BACK TO THE CITY")
        local membrane = P({ Name = "CityGate", Size = Vector3.new(13, 14, 0.4), CFrame = CFrame.new(O.X, G + 7.5, gz + 0.6), Color = C(255, 150, 60), Material = M.Neon, Transparency = 0.55 })
        Prompt(membrane, "Go", "Back to the city", "PromptCity")
    end
    -- overhead: lantern strings + cables criss-crossing the courtyard
    for k = -2, 2 do
        local z = O.Z + k * 22
        local y = G + 24 + (k % 2) * 3
        P({ Name = "Cable", Size = Vector3.new(HALF * 2, 0.15, 0.15), CFrame = CFrame.new(O.X, y + 0.8, z), Color = C(14, 14, 16), Material = M.SmoothPlastic })
        for x = -HALF + 6, HALF - 6, 9 do
            P({ Name = "StringLantern", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(O.X + x, y - 0.1 + math.sin(x * 0.3) * 0.4, z),
                Color = ((x // 9) % 2 == 0) and C(220, 50, 44) or C(220, 150, 50), Material = M.Neon, Transparency = 0.4 })
        end
    end
    -- street stuff: vending machines, crates, a food cart with steam, a few stools
    local function Vending(cf, col)
        P({ Name = "Vending", Size = Vector3.new(3, 6.5, 2.4), CFrame = cf * CFrame.new(0, 3.25, 0), Color = col, Material = M.SmoothPlastic, Collide = true })
        Neon({ Name = "VendingFront", Size = Vector3.new(2.4, 4, 0.1), CFrame = cf * CFrame.new(0, 4, -1.25), Color = C(220, 240, 255), Transparency = 0.2 })
    end
    Vending(CFrame.new(O + Vector3.new(60, 0, -60)) * CFrame.Angles(0, math.rad(-135), 0), C(200, 40, 50))
    Vending(CFrame.new(O + Vector3.new(64, 0, -56)) * CFrame.Angles(0, math.rad(-135), 0), C(40, 110, 200))
    Vending(CFrame.new(O + Vector3.new(-62, 0, 58)) * CFrame.Angles(0, math.rad(45), 0), C(240, 200, 60))
    do
        local cf = CFrame.new(O + Vector3.new(54, 0, 24)) * CFrame.Angles(0, math.rad(90), 0)
        P({ Name = "Cart", Size = Vector3.new(6, 3, 3), CFrame = cf * CFrame.new(0, 2.2, 0), Color = C(190, 60, 40), Material = M.SmoothPlastic, Collide = true })
        for sx = -1, 1, 2 do P({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.6, 1.6), CFrame = cf * CFrame.new(sx * 2.2, 0.8, 1.6) * CFrame.Angles(0, math.rad(90), 0), Color = C(30, 30, 30), Material = M.Metal }) end
        P({ Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 2, 2), CFrame = cf * CFrame.new(1.4, 4.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C(170, 170, 176), Material = M.Metal })
        local steam = P({ Name = "SteamSrc", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(1.4, 5.3, 0), Transparency = 1 })
        local e = Instance.new("ParticleEmitter")
        e.Texture = "rbxassetid://241594419"; e.Rate = 4; e.Lifetime = NumberRange.new(2, 3); e.Speed = NumberRange.new(1.5, 2.5)
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.5) })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
        e.Color = ColorSequence.new(C(220, 220, 225)); e.LightEmission = 0.1; e.Parent = steam
        local board = P({ Name = "CartBoard", Size = Vector3.new(5, 1.6, 0.3), CFrame = cf * CFrame.new(0, 6.8, -1), Color = C(24, 18, 22), Material = M.SmoothPlastic })
        Sign(board, Enum.NormalId.Front, "魚蛋 • 燒賣", NEON.Amber)
        for k = -1, 1 do P({ Name = "Stool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.4, 1.4), CFrame = cf * CFrame.new(k * 2.2, 1.6, -3.4) * CFrame.Angles(0, 0, math.rad(90)), Color = C(40, 90, 170), Material = M.SmoothPlastic }) end
    end
    for k = 1, 6 do
        P({ Name = "StreetCrate", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(O + Vector3.new(rng:NextNumber(-60, 60), 1.2, (k % 2 == 0) and -60 or 60)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
            Color = C(110, 80, 50), Material = M.WoodPlanks, Collide = true })
    end
    -- two sodium lamps (SpotLights) over the trade rows
    for _, z in ipairs({ -26, 26 }) do
        local lamp = P({ Name = "Lamp", Size = Vector3.new(3, 0.6, 1.4), CFrame = CFrame.new(O + Vector3.new(0, 20, z)), Color = C(40, 40, 44), Material = M.Metal })
        Neon({ Name = "LampGlow", Size = Vector3.new(2.6, 0.1, 1), CFrame = lamp.CFrame * CFrame.new(0, -0.35, 0), Color = C(255, 190, 110) })
        local sl = Instance.new("SpotLight"); sl.Face = Enum.NormalId.Bottom; sl.Angle = 110; sl.Range = 30; sl.Brightness = 1.1; sl.Color = C(255, 180, 110); sl.Shadows = false; sl.Parent = lamp
    end

    folder:SetAttribute("SignPropsCleared", HubCity.ClearSignProps(folder)) -- (HUBFIX: no facade prop through a sign / board)
    HubCity.DimPlaza(folder, O) -- (HUB LOOK v2: shaped round the courtyard's own middle) (UPDATE 4 NIGHT: the same darker surfaces as the city; neon, signs and lanterns stay bright)
    folder:SetAttribute("Built", os.time())
    folder.Parent = workspace
    return folder
end

return HubMarket
