--!nocheck
-- ============================================================================================
-- HUB v5 "WALLED CITY" (2026-10-05). Owner: "We are revamping again into a kowloon walled city aesthetic ... (this
-- aesthetic exactly)" + 4 references: a dense, grimy walled-city alley at night -- towering patched-together apartment
-- blocks, barred balconies, AC units and pipes, hanging shop boards in Chinese characters, neon signs (red / pink /
-- cyan / green), cables and red paper lanterns strung overhead, roll-up shutters and awnings, vending machines and
-- arcade cabinets, cafe tables, a wet reflective street with puddles and steam, lit almost entirely by neon.
-- Built from primitives (owner: the generated meshes "look very generated"), inside the old footprint so every contract
-- stays: the station anchors (counters) sit where the booths' counters were, the gates' rifts / vortices are
-- HubGenerator's, the leaderboards hang on the side facades, the Centerpiece rings still turn (client), spawn and the
-- Training Grounds doorway are unchanged.
-- HubCity.Build(hub, H) -- H = HubGenerator's helpers { P, L, Neon, Light, Prompt, Emit, FLOOR_TOP, FLOOR_HALF }.
-- HubCity.Shop(hub, cf, t, H) -- one station storefront (t = BuildBooth's table); returns the anchor (counter).
-- ============================================================================================
local HubCity = {}
HubCity.GROUND = 4 -- the street's top (= the Training Grounds' terrain); HubGenerator's FLOOR_TOP 1.5 is under it

local Terrain = workspace.Terrain
local CS = game:GetService("CollectionService") -- (UPDATE 4: HubFlicker / HubSway tags for the client HubLife script)
local MaterialService = game:GetService("MaterialService")
-- (UPDATE 4) textured kit meshes for hero props live IN THE PLACE: ReplicatedStorage.EnvKit.City.<Name> (Studio generate_mesh,
-- owner Ctrl+S). A missing item falls back to the old part-built prop, so nothing breaks on an unsaved place.
local EnvKit = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("EnvKit"))
local M = Enum.Material
local function C(r, g, b) return Color3.fromRGB(r, g, b) end

-- palette
local NEON = { Red = C(255, 40, 60), Pink = C(255, 70, 190), Cyan = C(40, 230, 255), Green = C(70, 255, 130), Amber = C(255, 170, 40),
    Violet = C(170, 90, 255), White = C(240, 240, 255) }
local NEON_LIST = { NEON.Red, NEON.Pink, NEON.Cyan, NEON.Green, NEON.Amber, NEON.Violet, NEON.Red, NEON.Cyan }
local GRIME = { C(92, 84, 74), C(78, 72, 66), C(104, 96, 80), C(70, 76, 74), C(98, 80, 72), C(84, 92, 86), C(110, 100, 84), C(66, 62, 60) }
local PAINT = { C(120, 140, 128), C(150, 136, 104), C(140, 110, 108), C(96, 112, 124) } -- faded teal / ochre / rose / slate
local SIGNS = { "麵館", "當舖", "藥房", "牙醫", "茶餐廳", "電器", "理髮", "酒家", "旅館", "五金", "鐘錶", "眼鏡", "照相", "冰室", "書局", "診所", "金舖", "車房" }

-- HUB DECLUTTER (2026-10-12, owner: "fix the hub. Its insanely cluttered now and is overwhelming"): how much of each kind
-- of dressing gets built. Fractions = the share kept (thinned on its own stream AFTER the old draws, so every kept piece
-- stands exactly where it did); false = none; lists = which sites stay. Stations, gates, boards, the plinth, spawn and
-- the range doorway are never thinned. Set a value back to 1 / true to bring a kind back.
HubCity.CALM = {
    BladeSign = 0.35, BladeSignNorth = 0,     -- facade blade signs over the street (none on the gate wall)
    RoofSign = 0.35, RoofSignNorth = 0,       -- rooftop neon signs (none over the gates)
    NeonWindows = false,                       -- lit rooms in neon colours (false: warm / TV-blue only)
    FacadeAC = 0.5, FacadeCage = 0.4,          -- kit relief on the facades
    CableEvery = 4, BridgeNeon = false, Bridges = { [-30] = true },
    LanternStrings = {},                       -- the big strings across the plaza (1-4; all crossed a gate / board / doorway view)
    StreetBoards = {},                         -- the 6 hanging boards (each hung in front of a shop, a leaderboard or the range sign)
    TrafficLight = false, VendingSites = { [3] = true, [4] = true }, Junk = { [1] = true, [4] = true }, GasCages = 1,
    FoodCarts = 1, EdgeStacks = 0.5, CurbScooters = false, LooseScooters = 2, CafeTables = 2, Arcade = false,
    MarketStalls = { [-25] = true, [27] = true }, MarketLanterns = false, Steam = { [40] = true },
    Wires = 4, RustPatches = 3, Rubble = 2, BrokenBoard = false, Cracks = 2, OilStains = 3, -- (HUB LOOK: the asphalt v2 carries its own fine cracks)
    KioskNeon = false,
    ShopBlade = false, ShopLightbox = false, ShopExtra = { Plants = true, AC = true, Lanterns = true }, -- (no crates / A-frames on the sidewalk)
    GateLightBoxes = false, GateLanterns = true, GateConduit = false,
}

-- the stations' own names on their boards
HubCity.ZH = {
    ShopStand = "黑市", RollAltar = "武器鍛造", UpgradeAnvil = "強化工坊", InvLocker = "倉庫",
    TreeAltar = "技能神殿", IndexAltar = "圖鑑", ArmoryStand = "軍械", SeasonStand = "賽季",
}

local function Text(part: BasePart, face: Enum.NormalId, text: string, color: Color3, opts: any?)
    opts = opts or {}
    local sg = Instance.new("SurfaceGui")
    sg.Name = "Sign"; sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = opts.PPS or 24
    sg.LightInfluence = opts.Lit and 0.6 or 0; sg.Brightness = opts.Brightness or 2.4; sg.Parent = part
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(opts.W or 0.9, opts.H or 0.86); t.Position = UDim2.fromScale((1 - (opts.W or 0.9)) / 2, opts.Y or 0.07)
    t.Font = opts.Font or Enum.Font.GothamBlack; t.TextScaled = true; t.TextColor3 = color; t.Text = text
    t.TextStrokeColor3 = opts.Stroke or C(10, 6, 8); t.TextStrokeTransparency = opts.StrokeT or 0.4
    t:SetAttribute("KeepFont", true)
    t.Parent = sg
    if opts.Sub then
        t.Size = UDim2.fromScale(0.9, 0.58)
        local s = t:Clone(); s.Text = opts.Sub; s.Size = UDim2.fromScale(0.86, 0.26); s.Position = UDim2.fromScale(0.07, 0.68); s.Font = Enum.Font.GothamBold
        s.TextColor3 = opts.SubColor or color; s.Parent = sg
    end
    return sg
end

local function Vertical(s: string): string
    local out = {}
    for _, cp in utf8.codes(s) do table.insert(out, utf8.char(cp)) end
    return table.concat(out, "\n")
end

-- ===================================================================================== UPDATE 4 SHARED PIECES
HubCity.IMG = { WetGlow = "rbxassetid://97854338013348", StreetWet = "rbxassetid://136772723759678", HoloBeam = "rbxassetid://139998108633015",
    -- (tools/make_city_facades.py shop: the shopfronts' wall tiles, packed shelves, posters, awning stripes)
    Tiles = "rbxassetid://140567825686995", Goods = { "rbxassetid://105661784504712", "rbxassetid://100891110939449", "rbxassetid://93830888212142" },
    Posters = { "rbxassetid://84361720684182", "rbxassetid://86990064604299", "rbxassetid://96175803981910" }, Stripes = "rbxassetid://113164742600306",
    -- (tools/make_city_facades.py ground: street decals)
    Cracks = "rbxassetid://119126414697433", Stain = "rbxassetid://115702285188071", Zebra = "rbxassetid://121085025698537", Slow = "rbxassetid://116390706279014", Drain = "rbxassetid://135334196603435",
    -- (tools/make_city_facades.py street: a whole shop level 20 x 16 studs -- signboards, shutter, lit window, door -- and
    -- its lit-only twin, laid on top with NoDim so the windows / signs glow while the wall takes the plaza dimming)
    Street = { "rbxassetid://136359453827652", "rbxassetid://99977765941660" }, StreetGlow = { "rbxassetid://102294419897430", "rbxassetid://99776300329592" } }
-- an image on one face of a part (a Decal, or a tiling Texture when tile = studs per tile); returns it
function HubCity.Img(part: BasePart, face: Enum.NormalId, id: string?, tile: number?, color: Color3?)
    if not id or id == "rbxassetid://0" then return nil end
    local d = Instance.new(tile and "Texture" or "Decal")
    d.Texture = id; d.Face = face
    if tile then d.StudsPerTileU = tile; d.StudsPerTileV = tile end
    if color then d.Color3 = color end
    d.Parent = part
    return d
end -- (tools/make_city_facades.py make_wet; image ids)
-- (HUB LOOK 2026-10-24, owner: "copy and paste items") a repeated kit prop's own look: scale +- pct and a grime tint
-- (lo..1 of the kit's own Tint, a touch warmer or cooler) drawn from the caller's rng -> scale, tint
function HubCity.KitVary(rng: Random, name: string, scale: number, pct: number, lo: number?): (number, Color3)
    local tpl = EnvKit.Get and EnvKit.Get("City", name)
    local base = tpl and tpl:GetAttribute("Tint")
    if typeof(base) ~= "Color3" then base = Color3.new(1, 1, 1) end
    local v, w = rng:NextNumber(lo or 0.75, 1), rng:NextNumber(-0.05, 0.05)
    return scale * (1 + rng:NextNumber(-pct, pct)), Color3.new(math.clamp(base.R * v * (1 + w), 0, 1), math.clamp(base.G * v, 0, 1), math.clamp(base.B * v * (1 - w), 0, 1))
end
-- (HUB LOOK) every paper lantern a little different in size, tilt and dye (the strings were rows of identical balls)
local lanternVar = Random.new(808)
-- a paper lantern: a squat glowing body between two dark lacquer caps, a yellow tassel (Q = the caller's part maker; cf =
-- the body's centre). lite: no tassel (the strings high over the street: 3 parts, not 4). (With one small gold cap the
-- red ball read as a tomato -- both caps, wide and dark, make it a lantern.)
function HubCity.PaperLantern(Q, cf: CFrame, s: number, col: Color3, lite: boolean?)
    s = s * lanternVar:NextNumber(0.88, 1.12)
    col = col:Lerp(Color3.fromRGB(150, 24, 30), lanternVar:NextNumber(0, 0.3))
    cf = cf * CFrame.Angles(math.rad(lanternVar:NextNumber(-7, 7)), lanternVar:NextNumber(0, 6.28), math.rad(lanternVar:NextNumber(-7, 7)))
    local body = Q({ Name = "Lantern", Size = Vector3.new(s * 1.12, s, s * 1.12), CFrame = cf, Color = col, Material = M.Neon, Transparency = 0.12, CanCollide = false })
    local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = body
    -- (UPDATE 4 depth pass budget: one dark cylinder THROUGH the body shows as both caps -- the body hides its middle)
    Q({ Name = "LanternCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 1.08, s * 0.7, s * 0.7), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = C(34, 24, 20), Material = M.SmoothPlastic, CanCollide = false })
    if lite then return body end
    Q({ Name = "LanternTassel", Size = Vector3.new(s * 0.12, s * 0.6, s * 0.12), CFrame = cf * CFrame.new(0, -s * 0.85, 0), Color = C(232, 178, 54), Material = M.Fabric, CanCollide = false })
    return body
end
-- the reflection of a neon light in the wet street: a soft streak lying on the ground (cf = its centre, flat), len along
-- cf's -Z (toward the viewer), tinted col; a = how strong (0..1). (UPDATE 4: SELF-LIT -- a SurfaceGui with LightInfluence
-- 0, so it reads as the sign's coloured light pool on the wet street at no light cost; the hub has a 23-light budget)
function HubCity.WetGlow(Q, cf: CFrame, len: number, wid: number, col: Color3, a: number)
    if HubCity.IMG.WetGlow == "rbxassetid://0" then return end
    local p = Q({ Name = "WetGlow", Size = Vector3.new(wid, 0.05, len), CFrame = cf, Transparency = 1, CanCollide = false })
    p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
    local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Top; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 8; sg.LightInfluence = 0; sg.Brightness = 2.2; sg.Parent = p
    local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Size = UDim2.fromScale(1, 1); im.Image = HubCity.IMG.WetGlow
    im.ImageColor3 = col; im.ImageTransparency = 1 - math.min(1, a * 1.1); im.Parent = sg
    p:SetAttribute("NoDim", true)
    return p
end
-- the walk surface height under (x, z) in the city: the sidewalks stand 0.4 over the street
-- (UPDATE 4) a blade sign's steel brackets: a rod along its top and bottom edge running back into the wall it hangs
-- from (the blades floated 0.6 off the wall). make = the caller's part maker (Q / P); gap = blade centre -> wall.
function HubCity.BladeFrame(make, blade: BasePart, gap: number)
    local h, d = blade.Size.Y, blade.Size.Z
    local len = d / 2 + gap + 0.2
    for _, sy in ipairs({ 1, -1 }) do
        make({ Name = "BladeArm", Size = Vector3.new(0.3, 0.3, len), CFrame = blade.CFrame * CFrame.new(0, sy * (h / 2 + 0.15), gap - len / 2 + 0.2),
            Color = Color3.fromRGB(34, 34, 38), Material = Enum.Material.Metal, CanCollide = false })
    end
end

function HubCity.WalkY(x: number, z: number): number
    local ax = math.abs(x)
    return (ax >= 41.5 and ax <= 53.5 and z >= -59 and z <= 57) and HubCity.GROUND + 0.4 or HubCity.GROUND
end

-- ===================================================================================== WEATHERING
-- (owner 2026-10-05: "overall vibe needs some more rust and broken things (not too much though), some wires and such")
-- Shared by the city and the Training Grounds. All dressing: no lights, no collisions, never queryable (shots pass).
--   Wires(list)    loose cable ends dangling from overhead runs: { top = Vector3, len, sway (degrees) }
--   Patches(list)  rusted corrugated sheets bolted over a wall at street level: { pos = Vector3, yaw (deg, faces -Z), w, h }
--   Rubble(list)   a few broken concrete chunks + a bent rebar at a wall's foot: { pos = Vector3 }
--   Conduit(a, b, y, out) a bundle of three exposed pipes along a wall from a to b (x/z), brackets every ~30 studs
--   BrokenBoard(pos, w, text) a shop board hanging askew from its one remaining wire
local RUST = { Color3.fromRGB(122, 70, 40), Color3.fromRGB(96, 58, 38), Color3.fromRGB(140, 84, 46), Color3.fromRGB(84, 64, 52) }
local function Weathering(Q, rng: Random, G: number)
    local W = {}
    function W.Wires(list)
        for _, w in ipairs(list) do
            local tilt = CFrame.Angles(math.rad(rng:NextNumber(-w.sway, w.sway)), 0, math.rad(rng:NextNumber(-w.sway, w.sway)))
            local cf = CFrame.new(w.top) * tilt * CFrame.new(0, -w.len / 2, 0)
            Q({ Name = "LooseWire", Size = Vector3.new(0.12, w.len, 0.12), CFrame = cf, Color = Color3.fromRGB(18, 18, 20), Material = Enum.Material.SmoothPlastic, CanCollide = false })
            if rng:NextNumber() < 0.4 then -- a frayed end (copper showing)
                Q({ Name = "WireEnd", Size = Vector3.new(0.16, 0.5, 0.16), CFrame = cf * CFrame.new(0, -w.len / 2 - 0.2, 0), Color = Color3.fromRGB(190, 120, 60), Material = Enum.Material.Metal, CanCollide = false })
            end
        end
    end
    function W.Patches(list)
        for _, pt in ipairs(list) do
            local cf = CFrame.new(pt.pos) * CFrame.Angles(0, math.rad(pt.yaw), math.rad(rng:NextNumber(-3, 3)))
            local col = RUST[rng:NextInteger(1, #RUST)]
            Q({ Name = "RustPatch", Size = Vector3.new(pt.w, pt.h, 0.18), CFrame = cf, Color = col, Material = Enum.Material.CorrodedMetal, CanCollide = false })
            for k = -1, 1, 2 do -- corrugation ribs
                Q({ Name = "RustRib", Size = Vector3.new(0.25, pt.h, 0.12), CFrame = cf * CFrame.new(k * pt.w * 0.22, 0, -0.14), Color = col:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.CorrodedMetal, CanCollide = false })
            end
            if rng:NextNumber() < 0.5 then -- a corner peeled off
                Q({ Name = "RustCurl", Size = Vector3.new(pt.w * 0.3, pt.h * 0.25, 0.14), CFrame = cf * CFrame.new(pt.w * 0.36, pt.h * 0.38, -0.4) * CFrame.Angles(math.rad(-28), 0, math.rad(12)), Color = col, Material = Enum.Material.CorrodedMetal, CanCollide = false })
            end
        end
    end
    function W.Rubble(list)
        for _, r in ipairs(list) do
            for _ = 1, rng:NextInteger(3, 5) do
                local sz = rng:NextNumber(0.8, 2.2)
                Q({ Name = "Rubble", Shape = (rng:NextNumber() < 0.3) and Enum.PartType.Wedge or Enum.PartType.Block, Size = Vector3.new(sz, sz * rng:NextNumber(0.5, 0.9), sz * rng:NextNumber(0.7, 1.2)),
                    CFrame = CFrame.new(r.pos + Vector3.new(rng:NextNumber(-2.5, 2.5), G + sz * 0.3, rng:NextNumber(-2.5, 2.5))) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
                    Color = Color3.fromRGB(96, 92, 86):Lerp(Color3.fromRGB(70, 66, 60), rng:NextNumber()), Material = Enum.Material.Concrete, CanCollide = false })
            end
            Q({ Name = "Rebar", Size = Vector3.new(0.18, 3.2, 0.18), CFrame = CFrame.new(r.pos + Vector3.new(0.6, G + 1.2, -0.4)) * CFrame.Angles(math.rad(rng:NextNumber(20, 45)), rng:NextNumber(0, 6), 0),
                Color = RUST[1], Material = Enum.Material.CorrodedMetal, CanCollide = false })
        end
    end
    function W.Conduit(a: Vector3, b: Vector3, y: number, out: Vector3)
        local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
        local mid = Vector3.new((a.X + b.X) / 2, y, (a.Z + b.Z) / 2)
        local dir = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Unit
        local base = CFrame.lookAt(mid, mid + dir)
        for k, c in ipairs({ Color3.fromRGB(70, 66, 60), Color3.fromRGB(40, 40, 44), RUST[2] }) do
            Q({ Name = "Conduit", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.45, 0.45), CFrame = (base + out * (0.35 + 0.5 * k)) * CFrame.new(0, (k - 2) * 0.55, 0) * CFrame.Angles(0, math.rad(90), 0),
                Color = c, Material = Enum.Material.Metal, CanCollide = false })
        end
        for t = -len / 2 + 4, len / 2 - 4, 30 do
            Q({ Name = "ConduitBracket", Size = Vector3.new(0.3, 2.2, 1.6), CFrame = base * CFrame.new(0, 0, -t) + out * 0.9, Color = Color3.fromRGB(34, 34, 36), Material = Enum.Material.Metal, CanCollide = false })
        end
    end
    function W.BrokenBoard(pos: Vector3, w: number, text: string, face: Color3, ink: Color3)
        -- hangs from its left wire only: rotated round that corner, the right wire snapped (a short stub left)
        local pivot = CFrame.new(pos + Vector3.new(-w / 2 + 1, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(-24))
        local board = Q({ Name = "BrokenBoard", Size = Vector3.new(w, 5.4, 0.5), CFrame = pivot * CFrame.new(w / 2 - 1, -2.8, 0), Color = face, Material = Enum.Material.SmoothPlastic })
        for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
            Text(board, f, text, ink, { PPS = 16, Lit = true, Brightness = 1.1, StrokeT = 1, Font = Enum.Font.GothamBold, W = 0.94 })
        end
        Q({ Name = "BoardRust", Size = Vector3.new(w, 1.4, 0.55), CFrame = board.CFrame * CFrame.new(0, -2.1, 0), Color = RUST[1], Material = Enum.Material.CorrodedMetal, Transparency = 0.2, CanCollide = false })
        Q({ Name = "BoardWire", Size = Vector3.new(0.1, 14, 0.1), CFrame = CFrame.new(pos + Vector3.new(-w / 2 + 1, 2.8 + 7, 0)), Color = Color3.fromRGB(16, 16, 18), Material = Enum.Material.SmoothPlastic, CanCollide = false })
        Q({ Name = "SnappedWire", Size = Vector3.new(0.1, 4, 0.1), CFrame = CFrame.new(pos + Vector3.new(w / 2 - 1, 2.8 + 12, 0)) * CFrame.Angles(0, 0, math.rad(14)), Color = Color3.fromRGB(16, 16, 18), Material = Enum.Material.SmoothPlastic, CanCollide = false })
    end
    return W
end

-- ===================================================================================== FACADES (UPDATE 4)
-- (owner, UPDATE 4: "too robloxy and low quality / effort ... breathtaking and intentional"): the towers were flat boxes
-- with a black glass strip per floor and orange squares. Each block's floors are now ONE Texture (tools/
-- make_city_facades.py: 20 x 20-stud tiles = 2 floors x 4 window bays: framed windows, curtains, security cages, AC
-- boxes, sills, grime; the wall is transparent so the block's colour + material show). Contract with the tiles: floor
-- lines every 10 studs from FACADE_FLOOR0 (the shop level), the window opening 3.0 .. 7.4 studs above a floor line, bay
-- centres 2.5 + 5 k studs from the face's U origin (FACADE_U0: +1 = the part's local +X edge).
-- (UPDATE 4: the NIGHT tiles facade_<k>_nt -- their painted panes are dark glass; the lit rooms are the Neon LitWindow parts.
-- Day tiles: 86675622980380 / 106738504239700 / 115161719780476 / 106633007789252)
HubCity.FACADES = { "rbxassetid://118912348108489", "rbxassetid://128353189650653", "rbxassetid://120306559202636", "rbxassetid://140001422292538" }
local FACADE_FLOOR0 = 16
HubCity.FACADE_U0 = 1
HubCity.FACADE_VSIGN = 1
local FACADE_WIN_W, FACADE_WIN_H, FACADE_WIN_MID = 3.0, 3.6, 5.2
-- the facade Texture on a block's front (-Z) face; topY = the face's top (world y), so its floor lines meet the others'
-- (UPDATE 4, owner: "a lot of the buildings only have windows on one side"): faces = which faces get the tile (default
-- Front; the city passes the sides too, the south row its back as well) -- every visible face reads as a building, and a
-- corner shows a return instead of a flat plate. The relief variant below lines up on every face (tested).
local FACES_FRONT = { Enum.NormalId.Front }
local function FacadeTex(part: BasePart, k: number, topY: number, w: number, ground: number?, faces: { Enum.NormalId }?)
    local id = HubCity.FACADES[k]
    if not id or id == "rbxassetid://0" then return part end
    local h = (topY - ((ground or HubCity.GROUND) + FACADE_FLOOR0)) % 10 -- (the face top's height over the floor line below it)
    for _, face in ipairs(faces or FACES_FRONT) do
        local tx = Instance.new("Texture")
        tx.Name = "Facade"; tx.Texture = id; tx.Face = face
        tx.StudsPerTileU = 20; tx.StudsPerTileV = 20
        tx.OffsetStudsV = (h > 0.01) and ((HubCity.FACADE_VSIGN > 0) and (10 - h) or h) or 0
        tx.Parent = part
    end
    -- (UPDATE 4 DEPTH, owner: the buildings "lack any sort of depth") the RELIEF under the tile: MaterialVariant HubFacade<k>
    -- (in the PLACE, MaterialService: neutral wall ColorMap + NORMAL + ROUGHNESS from tools/make_city_facades.py relief --
    -- recessed glass, raised frames / sills / cages / AC boxes, joints at the floor lines). A variant tiles from the same
    -- face corner as the Texture (tested) but has no offset, so it goes only on blocks whose top sits on a floor line.
    if (h <= 0.01 or h >= 9.99) and MaterialService:FindFirstChild("HubFacade" .. k) then
        part.Material = M.Concrete
        part.MaterialVariant = "HubFacade" .. k
    end
    return part
end
-- the local x of the texture's window bay nearest to x on a face w wide (nil: too close to the edge to be whole)
local function FacadeBayX(x: number, w: number, u0: number?): number?
    u0 = u0 or HubCity.FACADE_U0 -- (u0 -1: the BACK face, whose texture starts at the other edge)
    local u = (u0 > 0) and (w / 2 - x) or (x + w / 2)
    local k = math.floor((u - 2.5) / 5 + 0.5)
    local uc = 2.5 + 5 * k
    if uc - 2 < 0 or uc + 2 > w then return nil end
    return (u0 > 0) and (w / 2 - uc) or (uc - w / 2)
end
local FACES_SIDES = { Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right }
local FACES_ALL = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
HubCity.FACES_SIDES = FACES_SIDES
-- (UPDATE 4: the south row's street face; it was a 3-stud slab at z 76-79 -- now 10+ deep from here back to z 79, the
-- Training Grounds' pads start at 79.5)
HubCity.SOUTH_FRONT = 69

-- (shared with the Bazaar, HubMarket: the same facade tiles on its towers; ground = that street's top)
HubCity.FacadeTex, HubCity.FacadeBayX = FacadeTex, FacadeBayX
HubCity.FACADE_FLOOR0, HubCity.FACADE_WIN = FACADE_FLOOR0, { W = FACADE_WIN_W, H = FACADE_WIN_H, Mid = FACADE_WIN_MID }

-- ===================================================================================== the city
function HubCity.Build(hub: Folder, H: any)
    local P, Light, Emit = H.P, H.Light, H.Emit
    local F, HALF = H.GROUND or H.FLOOR_TOP, H.FLOOR_HALF
    local rng = Random.new(19840)
    local city = Instance.new("Folder"); city.Name = "WalledCity"; city.Parent = hub
    -- (HUB DECLUTTER) a dropped piece is still built while `dropping` is on -- its random draws stay in order -- and
    -- destroyed at the end of Build, so everything kept comes out where it was
    local CALM = HubCity.CALM
    local rngCalm = Random.new(31337)
    local function Keep(f: number): boolean return rngCalm:NextNumber() < f end
    local dropping, trash = false, {}
    local function Q(props) -- a dressing part: no shadow, no clicks
        props.CanQuery = props.CanQuery == true
        local p = P(city, props)
        p.CastShadow = false
        if dropping then table.insert(trash, p) end
        return p
    end
    local function Drop(keep: boolean, fn)
        local was = dropping
        dropping = was or not keep
        fn()
        dropping = was
    end

    -- ===== GROUND: wet concrete, puddles, gutters, manholes; the old terrain plateau stays under it =====
    -- (terrain voxels are 4 studs: the old plateau's surface rendered at y 3.5-4, not FLOOR_TOP 1.5 -- the street is a
    -- PART at y 4 = the Training Grounds' ground, so the doorway is flush and every prop stands on a known height)
    Terrain:FillBlock(CFrame.new(0, -30, 70), Vector3.new(352, 60, 420), M.Rock)
    local street = P(city, { Name = "Street", Size = Vector3.new(152, 2, 151), Position = Vector3.new(0, F - 1, -0.5), Color = C(92, 88, 96), Material = M.Asphalt, Reflectance = 0.1 }) -- (a faint wet sheen)
    street.CastShadow = false
    -- (UPDATE 4: the flat coloured puddle slabs read as paint squares -- the wet patches are a texture layer on the street now
    -- (irregular dark water, a faint sheen) and each neon sign throws a soft coloured streak on the ground (WetGlow). The
    -- old draws are kept so the rest of the approved layout comes out the same.)
    for _ = 1, 26 do
        local p = Vector3.new(rng:NextNumber(-58, 58), F + 0.03, rng:NextNumber(-62, 62))
        if p.Magnitude > 12 then local _ = { rng:NextNumber(5, 16), rng:NextNumber(4, 10), rng:NextNumber(0, 3), rng:NextInteger(1, 4) } end
    end
    -- (UPDATE 4 GROUND, owner: the hub "still does not look great" -- the slab texture read as a baseplate / bathroom floor):
    -- the street is MaterialVariant HubAsphalt (in the PLACE: worn wet asphalt -- aggregate, repair patches, tar-sealed
    -- cracks, oil, glossy puddles in the roughness map; tools/make_city_facades.py groundmats), the sidewalks HubPaving
    -- (small staggered stone pavers, thin joints). Without the variants the old textures stay.
    local NEW_GROUND = MaterialService:FindFirstChild("HubAsphalt") ~= nil
    if NEW_GROUND then
        street.MaterialVariant = "HubAsphalt"; street.Color = C(168, 164, 176); street.Reflectance = 0
    elseif HubCity.IMG.StreetWet ~= "rbxassetid://0" then
        local tx = Instance.new("Texture"); tx.Name = "Wet"; tx.Texture = HubCity.IMG.StreetWet; tx.Face = Enum.NormalId.Top
        tx.StudsPerTileU = 48; tx.StudsPerTileV = 48; tx.Parent = street
    end
    local manholes = {}
    for _, z in ipairs({ -40, 0, 40 }) do
        local mh = Q({ Name = "Manhole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 3.4, 3.4), CFrame = CFrame.new(rng:NextNumber(-30, 30), F + 0.04, z) * CFrame.Angles(0, 0, math.rad(90)),
            Color = C(40, 38, 36), Material = M.DiamondPlate, CanCollide = false })
        manholes[z] = mh.Position
    end
    for _, sx in ipairs({ -1, 1 }) do -- gutters along the side facades
        Q({ Name = "Gutter", Size = Vector3.new(1.4, 0.1, 148), Position = Vector3.new(sx * (HALF - 1.2), F + 0.02, 0), Color = C(26, 26, 28), Material = M.Metal, CanCollide = false })
    end
    -- faded road paint
    -- (HUB LOOK 2026-10-24: this was SEVEN identical dashes stacked on one spot (52 + i * 0) -- coplanar copies that
    -- z-fought: two worn dashes now, different lengths)
    for _, d in ipairs({ { 47.5, 3.6, 0.55 }, { 55.5, 4.2, 0.62 } }) do Q({ Name = "Paint", Size = Vector3.new(0.5, 0.05, d[2]), Position = Vector3.new(0, F + 0.03, d[1]), Color = C(200, 170, 60), Material = M.SmoothPlastic, Transparency = d[3], CanCollide = false }) end
    for i = 0, 4 do Q({ Name = "Crossing", Size = Vector3.new(2.2, 0.05, 9), Position = Vector3.new(-9 + i * 4.5, F + 0.03, 62), Color = C(200, 200, 190), Material = M.SmoothPlastic, Transparency = 0.55, CanCollide = false }) end
    -- STREET PASS (0.58, owner: "Hub needs to feel better in the same way the biomes do, it still looks a bit low quality"):
    -- the street was one flat dark slab. Poured-concrete slabs with seams / cracks / oil stains (tools/make_street_art.py),
    -- raised paved SIDEWALKS with a curb along both shop rows, and a thin violet ground mist. ~10 parts + 1 emitter.
    local function Tex(part: BasePart, id: string, studs: number, tr: number, face: Enum.NormalId?)
        local tx = Instance.new("Texture")
        tx.Texture = "rbxassetid://" .. id; tx.Face = face or Enum.NormalId.Top
        tx.StudsPerTileU = studs; tx.StudsPerTileV = studs; tx.Transparency = tr
        tx.Parent = part
        return tx
    end
    if not NEW_GROUND then Tex(street, "118407545629893", 36, 0.3) end
    for _, sx in ipairs({ -1, 1 }) do
        local walk = P(city, { Name = "Sidewalk", Size = Vector3.new(12, 0.4, 116), Position = Vector3.new(sx * 47.5, F + 0.2, -1), Color = C(118, 112, 120), Material = M.Concrete })
        walk.CastShadow = false
        if MaterialService:FindFirstChild("HubPaving") then
            walk.Material = M.Pavement; walk.MaterialVariant = "HubPaving"; walk.Color = C(176, 168, 172)
        else
            Tex(walk, "138627255941968", 18, 0.15)
        end
        local curb = Q({ Name = "Curb", Size = Vector3.new(0.7, 0.5, 116), Position = Vector3.new(sx * 41.2, F + 0.25, -1), Color = C(70, 66, 72), Material = M.Concrete, CanCollide = false })
        Tex(curb, "138627255941968", 18, 0.4, Enum.NormalId.Top)
        for z = -54, 50, 26 do -- (faded yellow curb paint in front of each shop: no parking)
            Q({ Name = "CurbPaint", Size = Vector3.new(0.72, 0.52, 8), Position = Vector3.new(sx * 41.2, F + 0.25, z + 13), Color = C(200, 160, 40), Material = M.SmoothPlastic, Transparency = 0.35, CanCollide = false })
        end
    end
    do -- a thin violet mist hugging the street (one emitter, ~50 particles)
        local mist = Q({ Name = "StreetMist", Size = Vector3.new(120, 1, 120), Position = Vector3.new(0, F + 0.8, 0), Transparency = 1, CanCollide = false })
        local e = Instance.new("ParticleEmitter")
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.Color = ColorSequence.new(C(150, 90, 150), C(90, 70, 140))
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 20) })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.86), NumberSequenceKeypoint.new(1, 1) })
        e.Lifetime = NumberRange.new(9, 12); e.Rate = 4.5; e.Speed = NumberRange.new(0.3, 0.8); e.SpreadAngle = Vector2.new(180, 10)
        e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-4, 4); e.LightEmission = 0.12; e.LightInfluence = 0.4
        e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        e.Parent = mist
    end

    -- ===== THE BLOCKS: four facades of patched-together towers closing in on the street =====
    -- along = the facade's direction, inward = toward the plaza; openings = gaps (gates, the range doorway) as {centre, width, height}
    local litLights = 0
    -- (0.58) the rooftop / upper-floor additions draw from their OWN random stream, so the approved street-level city
    -- (every block, sign and balcony from `rng`) comes out exactly as before
    local rngTop = Random.new(9917)
    local rngFac = Random.new(4471) -- (UPDATE 4: which facade texture a block wears)
    local flickN = 0 -- (UPDATE 4: every third neon blade sign flickers now and then -- HubLife)
    local rngMass = Random.new(7373) -- (UPDATE 4 DEPTH: recesses)
    local rngBack = Random.new(1717) -- (UPDATE 4: the south row's range-side face)
    local rngProp = Random.new(2929) -- (G.25: the south row's street props -- its own stream)
    local rngRel = Random.new(8484) -- (UPDATE 4 DEPTH: 3D AC units / cages / rooftop shacks)
    local HAS_AC, HAS_CAGE, HAS_SHACK = EnvKit.Has("City", "ACUnit"), EnvKit.Has("City", "BalconyCage"), EnvKit.Has("City", "RoofShack")
    -- HUB LOOK (2026-10-24, owner: "a part of the problem is using copy and paste items"): every repeated kit prop gets its
    -- own scale, grime tint and (where it stands free) a few degrees of yaw -- on its OWN stream, so every approved draw
    -- above / below stays in order and every piece stands where it did. No new parts.
    local rngVar = Random.new(2410)
    lanternVar = Random.new(808)
    local function VScale(s: number, pct: number): number return s * (1 + rngVar:NextNumber(-pct, pct)) end
    local function VTint(name: string, lo: number?): Color3
        local tpl = EnvKit.Get and EnvKit.Get("City", name)
        local base = tpl and tpl:GetAttribute("Tint")
        if typeof(base) ~= "Color3" then base = Color3.new(1, 1, 1) end
        local v, w = rngVar:NextNumber(lo or 0.8, 1), rngVar:NextNumber(-0.05, 0.05)
        return Color3.new(math.clamp(base.R * v * (1 + w), 0, 1), math.clamp(base.G * v, 0, 1), math.clamp(base.B * v * (1 - w), 0, 1))
    end
    local function VYaw(deg: number): CFrame return CFrame.Angles(0, math.rad(rngVar:NextNumber(-deg, deg)), 0) end
    -- HUBFIX DEPTH (2026-10-25, owner: "the hub buildings still seem flat and lazy"): real 3D on the street faces -- upper
    -- floors that STEP BACK (a new roof line + parapet), a recessed LOGGIA floor (the windows sit 4.5 studs in, end piers +
    -- a solid balustrade), projecting ORIELS (enclosed bay windows wearing the facade tile) and stacked BALCONIES, a soil
    -- pipe beside some. One plan per block from its OWN stream (a fixed count of draws per block, so the approved city
    -- comes out the same) and never the same feature twice in a row. Protruding pieces are Models (DEPTH_MODELS):
    -- DepthClear drops any that would cross a bridge / cable / lamp / sign. HubCity.DEPTH3D = false (or Studio workspace attr
    -- DevDepthOff) = the old flat blocks.
    local rngD = Random.new(6262)
    local depthModels = {}
    local southFronts = {} -- (UPDATE 4: { x0, x1, z } of each south-row block's street face -- some step forward)
    local function SouthFrontZ(x: number): number
        local z = HubCity.SOUTH_FRONT
        for _, sf in ipairs(southFronts) do
            if x > sf[1] - 0.5 and x < sf[2] + 0.5 then z = math.min(z, sf[3]) end
        end
        return z
    end
    local function Facade(origin: Vector3, along: Vector3, inward: Vector3, length: number, openings: { any }, boards: boolean?, thin: boolean?, side: string?)
        local t = -length / 2
        local yaw = math.atan2(-inward.X, -inward.Z)
        -- (HUB LOOK v2: the leaderboards are lightbox cabinets at y ~35-56 now -- no relief / lit rooms poke out in front of them;
        -- checked AFTER the draws, so the approved layout stays put)
        local function BoardZone(c, w, y)
            return boards and math.abs(c) < 56 + w / 2 and y > 28 and y < 55
        end
        local function Blocked(c, w, y)
            -- (side facades: nothing in front of the leaderboards -- they hang at y 22-46 between z -50 and 52)
            if boards and math.abs(c) < 56 + w / 2 and y > 17 and y < 50 then return true end
            for _, o in ipairs(openings) do
                if math.abs(c - o[1]) < (w + o[2]) / 2 and y < o[3] then return true end
            end
            return false
        end
        -- (HUBFIX DEPTH) the block's plan: heights are over the street (F), floor lines at FACADE_FLOOR0 + 10 k.
        -- steps = { { S, sb } }: from S up the wall stands sb further back (a second step adds to the first) -- the stepped
        -- skyline; feats = up to two of loggia / oriel / balcony, one in the street zone (below 56) and one above the
        -- leaderboards (56 up), never the same kind as the block before in that zone.
        -- oriel / balcony: u0 / u1 = the span in the texture's bay units from the face's +X edge; loggia: L (band L .. L+10)
        local prevFeat = {}
        local KINDS = { "loggia", "oriel", "balcony" }
        local function Plan(c: number, w: number, hgt: number, open: any, depth: number): any
            local d = {}
            for k = 1, 16 do d[k] = rngD:NextNumber() end -- (always sixteen: one block's plan never shifts another's)
            local p = { steps = {}, feats = {} }
            if open or HubCity.DEPTH3D == false or workspace:GetAttribute("DevDepthOff") then return p end -- (Studio A/B: workspace attr DevDepthOff)
            local zc = (origin + along * c).Z
            if not thin and hgt >= 76 and d[1] < 0.8 then
                local S = hgt - 10 * (1 + math.floor(d[2] * 3))
                if S >= 66 then
                    table.insert(p.steps, { S = S, sb = 8 + math.floor(d[3] * 9) * 0.5 })
                    if hgt - S >= 30 and d[10] < 0.6 then table.insert(p.steps, { S = hgt - 10, sb = 4 + math.floor(d[11] * 5) * 0.5 }) end
                    -- (the roof keeps its tank / antenna: every step together stops 1 stud short of the block's middle)
                    local room, tot = depth / 2 - 1, 0
                    for _, st in ipairs(p.steps) do tot += st.sb end
                    if tot > room then for _, st in ipairs(p.steps) do st.sb = math.max(2, math.floor(st.sb * room / tot * 2) / 2) end end
                end
            end
            local topFree = p.steps[1] and p.steps[1].S or hgt
            local nb = math.floor((w + 0.2) / 5)
            local used = {} -- (bay spans taken: the two features never share bays)
            local function Span(k: number, r: number): (number?, number?)
                if nb - k - 2 < 0 then return nil, nil end -- (a whole bay clear of both corners: the drain pipe lives there)
                local opts = nb - k - 1
                for tryN = 0, opts - 1 do
                    local j = 1 + (math.floor(r * opts) + tryN) % opts
                    local free = true
                    for _, u in ipairs(used) do if 5 * j < u[2] + 2.5 and 5 * (j + k) > u[1] - 2.5 then free = false end end
                    if free then return 5 * j, 5 * (j + k) end
                end
                return nil, nil
            end
            local function Clear(y0: number, y1: number): boolean
                for y = y0, y1 - 1, 10 do if Blocked(c, w, y + 1) or Blocked(c, w, y + 9) or BoardZone(c, w, y + 5) then return false end end
                return true
            end
            local loggiaTaken = false
            for zone = 1, 2 do -- 1 = the street floors (16 .. 56), 2 = above the leaderboards (56 up)
                local lo, hi = (zone == 1) and FACADE_FLOOR0 or 56, (zone == 1) and 56 or topFree
                local base = 3 * zone
                local idx = 1 + math.floor(d[base + 1] * 3)
                local got = nil
                for step = 0, 2 do
                    local kind = KINDS[(idx - 1 + step) % 3 + 1]
                    if kind ~= prevFeat[zone] then
                        if kind == "loggia" and not thin and not loggiaTaken and w >= 12 then
                            local L = math.max(lo, 46) + 10 * math.floor(d[base + 2] * 2)
                            -- (the walkway bridge meets the side rows at z -30, 60 over the street: no loggia round it)
                            local bridge = (side == "W" or side == "E") and math.abs(zc + 30) < w / 2 + 4 and L <= 62 and L + 10 >= 58
                            if L >= lo and L + 10 <= hi and L + 20 <= topFree and Clear(L, L + 10) and not bridge then
                                got = { kind = "loggia", L = L, r = 4.5 }; loggiaTaken = true
                            end
                        elseif kind == "oriel" then
                            local k = math.min((w >= 22) and 3 or 2, nb - 2)
                            local y0 = lo + 10 * math.floor(d[base + 2] * 2)
                            local y1 = math.min(hi, topFree - 10, y0 + 10 * (2 + math.floor(d[base + 3] * 3)))
                            if k >= 1 and y1 - y0 >= 20 and Clear(y0, y1) then
                                local u0, u1 = Span(k, d[12 + zone])
                                if u0 then got = { kind = "oriel", u0 = u0, u1 = u1, y0 = y0, y1 = y1 } end
                            end
                        elseif kind == "balcony" then
                            local k = math.max(1, math.min((w >= 18) and 2 or 1, nb - 2))
                            local floors = {}
                            for fy = lo + ((zone == 1) and 10 or 0), hi - 10, 10 do
                                if #floors < 2 + math.floor(d[base + 3] * 2) and fy + 10 <= topFree and Clear(fy, fy + 10) then table.insert(floors, fy) end
                            end
                            if #floors >= 2 then
                                local u0, u1 = Span(k, d[12 + zone])
                                if u0 then got = { kind = "balcony", u0 = u0, u1 = u1, floors = floors, steel = d[15] < 0.45 } end
                            end
                        end
                        if got then break end
                    end
                end
                prevFeat[zone] = got and got.kind
                if not got then -- (nothing fits this zone: slab edges -- projecting floor lines every other floor)
                    local ys = {}
                    for fy = lo + 10, hi - 10, 20 do
                        if #ys < 2 and fy + 10 <= topFree and Clear(fy - 10, fy + 10) then table.insert(ys, fy) end
                    end
                    if ys[1] then got = { kind = "bands", ys = ys } end
                end
                if got then
                    table.insert(p.feats, got)
                    if got.u0 then table.insert(used, { got.u0, got.u1 }) end
                end
            end
            return p
        end
        while t < length / 2 - 2 do
            local w = math.min(rng:NextNumber(14, 26), length / 2 - t)
            local c = t + w / 2
            local hgt = thin and rng:NextNumber(48, 72) or rng:NextNumber(70, 135)
            hgt = FACADE_FLOOR0 + 10 * math.floor((hgt - FACADE_FLOOR0) / 10 + 0.5) -- (UPDATE 4: tops on a floor line, so the facade texture's floors line up)
            local depth = thin and 10 or rng:NextNumber(18, 34) -- (thin = the south row: 10 deep, its back on the Training Grounds)
            local col = GRIME[rng:NextInteger(1, #GRIME)]
            if rng:NextNumber() < 0.3 then col = PAINT[rng:NextInteger(1, #PAINT)]:Lerp(col, 0.4) end
            local mat = ({ M.Concrete, M.Concrete, M.Slate, M.Brick, M.Plaster })[rng:NextInteger(1, 5)]
            -- the mass (above any opening there's still building: the opening is cut as a lintel)
            local open = nil
            for _, o in ipairs(openings) do if math.abs(c - o[1]) < (w + o[2]) / 2 then open = o end end
            -- (UPDATE 4 DEPTH, owner: "the hub buildings just feel exceptionally flat and lack any sort of depth"): blocks step
            -- BACK off the street wall -- most a little, some 2-3 studs, about one in eight 6 (an alley mouth) -- never where
            -- a leaderboard hangs, over a gate opening or on the thin south row (own rng stream)
            local recess = 0
            local rr = rngMass:NextNumber()
            if not open and not thin and not (boards and math.abs(c) < 56 + w / 2) then
                recess = (rr < 0.12) and 6 or ((rr < 0.6) and (0.8 + (rr * 37 % 1) * 2.2) or 0)
            elseif thin and not open and rr < 0.6 then -- (the south row steps FORWARD instead: its back stays on z 79)
                local pr = 1 + (rr * 53 % 1) * 2.5
                depth += pr; recess = -pr
            end
            local base = origin + along * c - inward * (depth / 2 + recess) -- (the block sits BEHIND the facade line)
            local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
            local fk = rngFac:NextInteger(1, #HubCity.FACADES) -- (its own stream: the approved draws stay in order)
            local plan = Plan(c, w, hgt, open, depth) -- (HUBFIX DEPTH)
            -- how far back the wall sits at a height over the street (a loggia band / the stepped-back floors)
            local loggia = nil
            for _, f in ipairs(plan.feats) do if f.kind == "loggia" then loggia = f end end
            local stepBack = 0 -- (the roof's front edge: every step added up)
            for _, st in ipairs(plan.steps) do stepBack += st.sb end
            local function Back(y: number): number
                if loggia and y >= loggia.L and y < loggia.L + 10 then return loggia.r end
                local b = 0
                for _, st in ipairs(plan.steps) do if y >= st.S then b += st.sb end end
                return b
            end
            -- a feature's span in the block's local x (from the texture's bay units: u runs from the +X edge)
            local function SpanX(u0: number, u1: number): (number, number) return (w + 0.2) / 2 - u1, (w + 0.2) / 2 - u0 end
            local function Behind(x: number, y: number, orielOnly: boolean?): boolean -- (relief an oriel / balcony would bury or cut)
                for _, f in ipairs(plan.feats) do
                    if f.u0 and (f.kind == "oriel" or not orielOnly) then
                        local x0, x1 = SpanX(f.u0, f.u1)
                        if x >= x0 - 1.2 and x <= x1 + 1.2 then
                            if f.kind == "oriel" then
                                if y >= f.y0 - 1 and y < f.y1 then return true end
                            else
                                for _, fy in ipairs(f.floors) do if y >= fy - 1 and y < fy + 9 then return true end end
                            end
                        end
                    end
                end
                return false
            end
            if thin then
                local wx = (origin + along * c).X
                table.insert(southFronts, { wx - w / 2, wx + w / 2, (base + inward * (depth / 2)).Z })
            end
            if open then
                local bottom = open[3]
                FacadeTex(Q({ Name = "Block", Size = Vector3.new(w + 0.2, hgt - bottom, depth), CFrame = cf * CFrame.new(0, F + bottom + (hgt - bottom) / 2, 0), Color = col, Material = mat, CanQuery = true }), fk, F + hgt, w + 0.2, nil, thin and FACES_ALL or FACES_SIDES)
                -- (owner 2026-10-05: "dungeon portals in hub have no back wall, you can just walk out into space"): only the
                -- part of the block over the doorway is cut -- the rest stays solid to the ground (a block that only
                -- clipped a gate's edge used to be hollow along its whole width, leaving street-level holes beside the gates)
                local lo, hi = open[1] - open[2] / 2, open[1] + open[2] / 2
                local sx = cf.RightVector:Dot(along) -- (cf's local +X runs against the facade direction: -1)
                for _, seg in ipairs({ { c - w / 2, math.min(c + w / 2, lo) }, { math.max(c - w / 2, hi), c + w / 2 } }) do
                    local sw = seg[2] - seg[1]
                    if sw > 0.2 then
                        local mid = (seg[1] + seg[2]) / 2 - c
                        -- (UPDATE 4: street level plain, the floors above it textured)
                        Q({ Name = "Block", Size = Vector3.new(sw + 0.1, FACADE_FLOOR0, depth), CFrame = cf * CFrame.new(mid * sx, F + FACADE_FLOOR0 / 2, 0), Color = col, Material = mat, CanQuery = true })
                        FacadeTex(Q({ Name = "Block", Size = Vector3.new(sw + 0.1, bottom - FACADE_FLOOR0, depth), CFrame = cf * CFrame.new(mid * sx, F + (FACADE_FLOOR0 + bottom) / 2, 0), Color = col, Material = mat, CanQuery = true }), fk, F + bottom, sw + 0.1,
                            nil, thin and { Enum.NormalId.Front, Enum.NormalId.Back } or FACES_FRONT) -- (no windows on the faces inside the doorway)
                    end
                end
            else
                -- (UPDATE 4: split at the shop level -- the plain street-level mass + the textured floors above)
                Q({ Name = "Block", Size = Vector3.new(w + 0.2, FACADE_FLOOR0, depth), CFrame = cf * CFrame.new(0, F + FACADE_FLOOR0 / 2, 0), Color = col, Material = mat, CanQuery = true })
                -- (HUBFIX DEPTH: the floors above are cut at the loggia band / the setback; each slice keeps its back face
                -- where it was and steps its FRONT back; every cut is on a floor line, so the tile + relief line up)
                local cuts = { FACADE_FLOOR0, hgt }
                if loggia then table.insert(cuts, loggia.L); table.insert(cuts, loggia.L + 10) end
                for _, st in ipairs(plan.steps) do table.insert(cuts, st.S) end
                table.sort(cuts)
                for k = 1, #cuts - 1 do
                    local a, b = cuts[k], cuts[k + 1]
                    if b - a > 0.5 then
                        local rec = Back(a + 0.5)
                        local inLoggia = loggia and a == loggia.L -- (the loggia's back wall in shade: darker)
                        local nStep = 0 -- (each step back is a touch darker: night haze reads it as further away)
                        for _, st in ipairs(plan.steps) do if a >= st.S then nStep += 1 end end
                        local sc = inLoggia and col:Lerp(C(10, 8, 10), 0.5) or col:Lerp(C(10, 8, 10), 0.12 * nStep)
                        FacadeTex(Q({ Name = "Block", Size = Vector3.new(w + 0.2, b - a, depth - rec), CFrame = cf * CFrame.new(0, F + (a + b) / 2, rec / 2), Color = sc, Material = mat, CanQuery = true }), fk, F + b, w + 0.2, nil, thin and FACES_ALL or FACES_SIDES)
                    end
                end
            end
            -- front face frame: local -Z of cf points toward the plaza (yaw)
            local front = depth / 2
            -- (HUB LOOK v2 2026-10-24, owner: the fronts "read as wallpaper" from the spawn): a projecting STRING COURSE at the
            -- shop level (the line between the plain street-level mass and the tiled floors) -- one part a block, darker than
            -- the wall, so every tower reads as a building with a base. Not on blocks over an opening (gates, the range
            -- doorway) or in front of a leaderboard.
            if not open and not Blocked(c, w, FACADE_FLOOR0 - 0.5) then
                Q({ Name = "Ledge", Size = Vector3.new(w + 0.2, 0.75, 1.0), CFrame = cf * CFrame.new(0, F + FACADE_FLOOR0 - 0.55, -front - 0.45), -- (just under the floor line: the first floor's AC units hang from it)
                    Color = col:Lerp(C(20, 18, 18), 0.35), Material = M.Concrete, CanCollide = false })
            end
            if thin then -- (UPDATE 4) the south row's BACK = the Training Grounds' backdrop: kit relief + lit rooms in its own bays
                local back = front
                -- street level, both faces: a roll-down shutter, a door under a small lit box sign, a drain pipe (not in the doorway)
                local segs = {}
                if open then
                    local lo, hi = open[1] - open[2] / 2, open[1] + open[2] / 2
                    for _, sg in ipairs({ { c - w / 2, math.min(c + w / 2, lo) }, { math.max(c - w / 2, hi), c + w / 2 } }) do
                        if sg[2] - sg[1] > 7 then table.insert(segs, sg) end
                    end
                else
                    table.insert(segs, { c - w / 2, c + w / 2 })
                end
                local sxr = cf.RightVector:Dot(along)
                for _, sd in ipairs({ 1, -1 }) do -- (+1 the range side, -1 the hub street)
                    local zf = sd * back -- (the face's local z)
                    for _, sg in ipairs(segs) do
                        local sw = sg[2] - sg[1]
                        local mid = ((sg[1] + sg[2]) / 2 - c) * sxr
                        local shw = math.min(sw - 6, 10)
                        if shw > 3 then
                            Q({ Name = "BackShutter", Size = Vector3.new(shw, 8.5, 0.25), CFrame = cf * CFrame.new(mid - (sw / 2 - shw / 2 - 1) * 0.6 * sd, F + 4.25, zf + sd * 0.12), Color = C(96, 92, 88):Lerp(col, 0.25), Material = M.CorrodedMetal, CanCollide = false })
                        end
                        local dx = mid + (sw / 2 - 2.6) * ((rngBack:NextNumber() < 0.5) and 1 or -1) * 0.8
                        Q({ Name = "BackDoor", Size = Vector3.new(3, 7, 0.3), CFrame = cf * CFrame.new(dx, F + 3.5, zf + sd * 0.15), Color = C(40, 44, 48), Material = M.Metal, CanCollide = false })
                        local lb = Q({ Name = "BackDoorSign", Size = Vector3.new(3.2, 1, 0.5), CFrame = cf * CFrame.new(dx, F + 8.2, zf + sd * 0.4), Color = C(242, 236, 214), Material = M.SmoothPlastic, CanCollide = false })
                        Text(lb, (sd > 0) and Enum.NormalId.Back or Enum.NormalId.Front, SIGNS[rngBack:NextInteger(1, #SIGNS)], C(170, 24, 24), { PPS = 30, Brightness = 1.4, StrokeT = 1 })
                        Q({ Name = "BackPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(hgt - 2, 0.6, 0.6), CFrame = cf * CFrame.new(mid + (sw / 2 - 0.9) * sd, F + (hgt - 2) / 2, zf + sd * 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color = C(70, 64, 58), Material = M.Metal, CanCollide = false })
                        -- (G.25) kit props in the free stretches of wall: meter boxes on both faces; on the street side a
                        -- doorstep shrine and a parked bicycle (the range side keeps its floor clear: the pads start at z 79.5)
                        -- (the meter boxes hang high, over the shutter; the floor props may stand in front of a shutter, never the door)
                        local wallOcc, floorOcc = { { dx - 2.2, dx + 2.2 } }, { { dx - 2.2, dx + 2.2 } }
                        local lo, hi = mid - sw / 2 + 2.6, mid + sw / 2 - 2.6
                        local function Slot(half: number, occ): number?
                            for _ = 1, 6 do
                                if hi - lo < half * 2 then return nil end
                                local x = rngProp:NextNumber(lo + half, hi - half)
                                local wx = (cf * CFrame.new(x, 0, 0)).Position.X
                                local ok = not (sd < 0 and (math.abs(wx - 26) < 4.5 + half or math.abs(wx + 45.5) < 1.6 + half or math.abs(wx - 49.5) < 1.6 + half or math.abs(wx) > 69 - half)) -- (vending at x 26 / the corners, gas cages)
                                for _, o in ipairs(occ) do if x + half > o[1] and x - half < o[2] then ok = false end end
                                if ok then table.insert(occ, { x - half, x + half }); return x end
                            end
                            return nil
                        end
                        local turn = (sd > 0) and CFrame.Angles(0, math.pi, 0) or CFrame.new() -- (kit fronts face local -Z)
                        if rngProp:NextNumber() < 0.6 then
                            local x = Slot(1.4, wallOcc)
                            if x then EnvKit.Place("City", "MeterBoxes", cf * CFrame.new(x, F + 9.2, zf + sd * 0.37) * turn, { Parent = city, Scale = VScale(1.05, 0.1), Tint = VTint("MeterBoxes", 0.75), Shadow = false }) end
                        end
                        if sd < 0 and rngProp:NextNumber() < 0.5 then
                            local x = Slot(1.1, floorOcc)
                            if x then EnvKit.Place("City", "DoorShrine", cf * CFrame.new(x, F, zf - 0.75) * VYaw(6), { Parent = city, Scale = VScale(1, 0.1), Shadow = false }) end
                        end
                        if sd < 0 and rngProp:NextNumber() < 0.35 then
                            local x = Slot(2.6, floorOcc)
                            if x then EnvKit.Place("City", "Bicycle", cf * CFrame.new(x, F, zf - 0.95) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(4)) * VYaw(10), { Parent = city, Scale = VScale(1.45, 0.06), Tint = VTint("Bicycle", 0.7), Shadow = false }) end
                        end
                    end
                end
                for _, fy in ipairs({ 16, 26, 36 }) do
                    if fy + 10 <= hgt and not (open and math.abs(c - open[1]) < (w + open[2]) / 2 and fy < open[3]) then
                        if HAS_AC and rngBack:NextNumber() < 0.8 then
                            local bx = FacadeBayX(rngBack:NextNumber(-w / 2 + 3, w / 2 - 3), w + 0.2, -1)
                            if bx then EnvKit.Place("City", "ACUnit", cf * CFrame.new(bx, F + fy + 1.0, back + 0.6) * CFrame.Angles(0, math.pi, 0), { Parent = city, Scale = VScale(1.1, 0.12), Tint = VTint("ACUnit", 0.72), Shadow = false }) end
                        end
                        if HAS_CAGE and rngBack:NextNumber() < 0.45 then
                            local bx = FacadeBayX(rngBack:NextNumber(-w / 2 + 4, w / 2 - 4), w + 0.2, -1)
                            if bx then EnvKit.Place("City", "BalconyCage", cf * CFrame.new(bx, F + fy + 2.6, back + 1.7) * CFrame.Angles(0, math.pi, 0), { Parent = city, Scale = VScale(1.7, 0.08), Tint = VTint("BalconyCage", 0.75), Shadow = false }) end
                        end
                    end
                end
                for y = 16, hgt - 6, 10 do
                    if rngBack:NextNumber() < 0.4 then
                        local roll = rngBack:NextNumber()
                        local lc = (roll < 0.75) and C(214, 150, 84) or ((roll < 0.9) and C(110, 150, 196) or NEON_LIST[rngBack:NextInteger(1, #NEON_LIST)])
                        if roll >= 0.9 and not CALM.NeonWindows then lc = C(214, 150, 84) end
                        local lx = FacadeBayX(rngBack:NextNumber(-w / 2 + 3, w / 2 - 3), w + 0.2, -1)
                        if lx and y + 10 <= hgt and not (open and y < open[3]) then
                            Q({ Name = "LitWindow", Size = Vector3.new(FACADE_WIN_W, FACADE_WIN_H, 0.12), CFrame = cf * CFrame.new(lx, F + y + FACADE_WIN_MID, back + 0.06), Color = lc, Material = M.Neon, Transparency = 0.4, CanCollide = false })
                        end
                    end
                end
            end
            -- (UPDATE 4 DEPTH) the four floors the eye sees (16 / 26 / 36 / 46 over the street) get REAL relief: kit AC units on
            -- brackets under a window and barred balcony cages over one, in the facade texture's window bays (kit meshes,
            -- one part each; skipped where a leaderboard / gate sightline needs the wall clear)
            if true then -- (UPDATE 4: the south row too, now that it is a real block)
                for _, fy in ipairs({ 16, 26, 36, 46 }) do
                    if fy + 10 <= hgt and not Blocked(c, w, fy + 4) then
                        -- (HUBFIX DEPTH: on the wall where it now stands -- a loggia / setback floor sits further back; none
                        -- behind an oriel or a balcony, no cage inside a loggia. The keep / scale / tint draws happen as before)
                        if HAS_AC and rngRel:NextNumber() < 0.9 then
                            local bx = FacadeBayX(rngRel:NextNumber(-w / 2 + 3, w / 2 - 3), w + 0.2)
                            if bx and Keep(CALM.FacadeAC) and not BoardZone(c, w, fy + 1) then
                                local m = EnvKit.Place("City", "ACUnit", cf * CFrame.new(bx, F + fy + 1.0, -front - 0.6 + Back(fy + 1)), { Parent = city, Scale = VScale(1.1, 0.12), Tint = VTint("ACUnit", 0.72), Shadow = false })
                                if m and Behind(bx, fy + 1) then m:Destroy() end
                            end
                        end
                        if HAS_CAGE and rngRel:NextNumber() < 0.55 then
                            local bx = FacadeBayX(rngRel:NextNumber(-w / 2 + 4, w / 2 - 4), w + 0.2)
                            if bx and Keep(CALM.FacadeCage) and not BoardZone(c, w, fy + 2.6) then
                                local m = EnvKit.Place("City", "BalconyCage", cf * CFrame.new(bx, F + fy + 2.6, -front - 1.7 + Back(fy + 2.6)), { Parent = city, Scale = VScale(1.7, 0.08), Tint = VTint("BalconyCage", 0.75), Shadow = false })
                                if m and (Behind(bx, fy + 2.6) or (loggia and fy == loggia.L)) then m:Destroy() end
                            end
                        end
                    end
                end
            end
            -- floors: a dark window band per floor + a lit window or two, AC units, the odd barred balcony
            -- (UPDATE 4: the windows, AC units, cages, laundry and grime are the facade TEXTURE now -- one per block instead of
            -- a part per floor. Every random draw below is kept in the same order, so the approved city comes out the same;
            -- only lit rooms are still parts (neon glow), snapped into the texture's window bays.)
            for y = 16, hgt - 6, 10 do
                if not Blocked(c, w, y + 4) then
                    -- (dim, warm, uneven -- a few rooms lit behind grimy glass, the odd TV-blue or neon one)
                    local nLit = (rng:NextNumber() < 0.45) and 1 or 0
                    -- (0.58: up where the hideout looks across -- above y 60 -- more rooms are lit)
                    if F + y > 60 and nLit == 0 and rngTop:NextNumber() < 0.55 then nLit = 1 end
                    if F + y > 60 and rngTop:NextNumber() < 0.3 then nLit += 1 end
                    for _ = 1, nLit do
                        local roll = rng:NextNumber()
                        local lc = (roll < 0.75) and C(214, 150, 84) or ((roll < 0.9) and C(110, 150, 196) or NEON_LIST[rng:NextInteger(1, #NEON_LIST)])
                        if roll >= 0.9 and not CALM.NeonWindows then lc = C(214, 150, 84) end -- (HUB DECLUTTER: no rainbow rooms)
                        local _ = rng:NextNumber(1.8, 3)
                        local lx = FacadeBayX(rng:NextNumber(-w / 2 + 3, w / 2 - 3), w + 0.2)
                        if lx and (y + 10 <= hgt) and not BoardZone(c, w, y + FACADE_WIN_MID) and not Behind(lx, y + FACADE_WIN_MID, true) then
                            Q({ Name = "LitWindow", Size = Vector3.new(FACADE_WIN_W, FACADE_WIN_H, 0.12), CFrame = cf * CFrame.new(lx, F + y + FACADE_WIN_MID, -front - 0.06 + Back(y + 1)),
                                Color = lc, Material = M.Neon, Transparency = 0.4, CanCollide = false })
                        end
                    end
                    if rng:NextNumber() < 0.55 then local _ = rng:NextNumber(-w / 2 + 2, w / 2 - 2) end -- (was: an AC part)
                    if rng:NextNumber() < 0.22 then -- (was: a balcony cage)
                        local bw = math.min(w - 3, rng:NextNumber(5, 9))
                        local _ = rng:NextNumber(-w / 2 + bw / 2 + 1, w / 2 - bw / 2 - 1)
                        if rng:NextNumber() < 0.5 then local _ = rng:NextInteger(1, #PAINT) end
                    end
                end
            end
            -- (was: stain parts -- the texture carries the grime; draws kept)
            for _ = 1, rng:NextInteger(2, 3) do
                local sh = rng:NextNumber(14, 40)
                local sy = rng:NextNumber(14, math.max(16, hgt - sh / 2 - 4))
                if not Blocked(c, w, sy) then
                    local _ = { rng:NextNumber(1, 3.5), rng:NextNumber(-w / 2 + 1.5, w / 2 - 1.5), rng:NextInteger(1, 3) }
                end
            end
            -- a drain pipe down the corner
            local pipeTop = plan.steps[1] and (plan.steps[1].S + 2) or hgt -- (HUBFIX DEPTH: on a stepped block it ends at the setback roof)
            Q({ Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(pipeTop - 4, 0.7, 0.7), CFrame = cf * CFrame.new(w / 2 - 0.8, F + pipeTop / 2, -front - 0.5) * CFrame.Angles(0, 0, math.rad(90)),
                Color = C(70, 64, 58), Material = M.Metal, CanCollide = false })
            -- ROOFTOPS (0.58, owner: "The hub needs to be built so from the hideout doesn't just look all black"): the hideout
            -- floats over the plaza at y 80 and looks across at the towers' tops -- a parapet, then a water tank on stilts or an
            -- antenna with a red beacon, and now and then a rooftop neon sign facing the plaza (no lights: neon only)
            if true then -- (UPDATE 4: the south row has a real roof now)
                local top = F + hgt
                local sbT = stepBack -- (HUBFIX DEPTH: the roof's front edge on a stepped block)
                -- (HUB LOOK v2: a CORNICE that overhangs the face 0.9 instead of a flush parapet -- a shadow line on every roof)
                Q({ Name = "Parapet", Size = Vector3.new(w + 0.2, 1.3, 1.6), CFrame = cf * CFrame.new(0, top + 0.65, -front + sbT + 0.15), Color = col:Lerp(C(0, 0, 0), 0.3), Material = mat, CanCollide = false })
                if HAS_SHACK and rngRel:NextNumber() < 0.35 and w > 14 then -- (UPDATE 4 DEPTH: a stair shack breaks the roofline)
                    EnvKit.Place("City", "RoofShack", cf * CFrame.new(rngRel:NextNumber(-w / 2 + 4, w / 2 - 4), top, front * 0.45) * CFrame.Angles(0, (rngVar:NextNumber() < 0.5) and 0 or math.pi, 0), { Parent = city, Scale = VScale(1, 0.12), Tint = VTint("RoofShack", 0.75), Shadow = false })
                end
                local r = rngTop:NextNumber()
                if r < 0.32 then
                    local tx = rngTop:NextNumber(-w / 2 + 3, w / 2 - 3)
                    local tcol = ({ C(112, 96, 78), C(80, 84, 90), C(120, 60, 44) })[rngTop:NextInteger(1, 3)]
                    if EnvKit.Has("City", "WaterTank") then -- (UPDATE 4: the textured kit tank on its scaffold -- skyline silhouettes)
                        EnvKit.Place("City", "WaterTank", cf * CFrame.new(tx, top, 3) * CFrame.Angles(0, math.rad((tx * 37) % 360), 0), { Parent = city, Scale = VScale(0.9, 0.15), Tint = VTint("WaterTank", 0.75), Shadow = false })
                    else
                        Q({ Name = "TankStand", Size = Vector3.new(3.2, 2.4, 3.2), CFrame = cf * CFrame.new(tx, top + 1.2, 3), Color = C(38, 36, 34), Material = M.DiamondPlate, Transparency = 0.45, CanCollide = false })
                        Q({ Name = "WaterTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.6, 4.2, 4.2), CFrame = cf * CFrame.new(tx, top + 4.7, 3) * CFrame.Angles(0, 0, math.rad(90)),
                            Color = tcol, Material = M.Wood, CanCollide = false })
                    end
                elseif r < 0.6 then
                    local tx = rngTop:NextNumber(-w / 2 + 2, w / 2 - 2)
                    local mh = rngTop:NextNumber(8, 16)
                    Q({ Name = "Antenna", Size = Vector3.new(0.3, mh, 0.3), CFrame = cf * CFrame.new(tx, top + mh / 2, 1), Color = C(60, 60, 64), Material = M.Metal, CanCollide = false })
                    Q({ Name = "AntennaBar", Size = Vector3.new(3, 0.18, 0.18), CFrame = cf * CFrame.new(tx, top + mh * 0.7, 1), Color = C(60, 60, 64), Material = M.Metal, CanCollide = false })
                    Q({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = cf * CFrame.new(tx, top + mh, 1), Color = C(255, 50, 40), Material = M.Neon, CanCollide = false })
                end
                if w > 16 and rngTop:NextNumber() < 0.3 then Drop(Keep((side == "N") and CALM.RoofSignNorth or CALM.RoofSign), function()
                    local sw, shh = math.min(w - 2, rngTop:NextNumber(12, 18)), rngTop:NextNumber(4, 6)
                    local ncol = NEON_LIST[rngTop:NextInteger(1, #NEON_LIST)]
                    local sign = Q({ Name = "RoofSign", Size = Vector3.new(sw, shh, 0.4), CFrame = cf * CFrame.new(0, top + shh / 2 + 1.6, -front + sbT + 1.2), Color = C(14, 12, 16), Material = M.Metal, CanCollide = false })
                    Text(sign, Enum.NormalId.Front, SIGNS[rngTop:NextInteger(1, #SIGNS)], ncol, { PPS = 12, Brightness = 2.4, Stroke = ncol, StrokeT = 0.6 })
                    for _, dy in ipairs({ 1.4, shh + 1.8 }) do
                        Q({ Name = "RoofSignNeon", Size = Vector3.new(sw + 0.4, 0.3, 0.3), CFrame = cf * CFrame.new(0, top + dy, -front + sbT + 0.95), Color = ncol, Material = M.Neon, CanCollide = false })
                    end
                    for _, lx in ipairs({ -sw / 2 + 1, sw / 2 - 1 }) do
                        Q({ Name = "RoofSignLeg", Size = Vector3.new(0.4, 1.6, 0.4), CFrame = cf * CFrame.new(lx, top + 0.8, -front + sbT + 1.2), Color = C(30, 30, 32), Material = M.Metal, CanCollide = false })
                        -- (UPDATE 4) a back strut from the sign's upper edge down to the roof
                        local a, b = Vector3.new(lx, top + 1.6 + shh * 0.8, -front + sbT + 1.45), Vector3.new(lx, top, -front + sbT + 1.45 + shh * 0.75)
                        local wa, wb = (cf * CFrame.new(a)).Position, (cf * CFrame.new(b)).Position
                        Q({ Name = "RoofSignStrut", Size = Vector3.new(0.35, 0.35, (wb - wa).Magnitude), CFrame = CFrame.lookAt((wa + wb) / 2, wb), Color = C(30, 30, 32), Material = M.Metal, CanCollide = false })
                    end
                    for _, ex in ipairs({ -sw / 2 - 0.2, sw / 2 + 0.2 }) do -- (UPDATE 4) the frame's end posts
                        Q({ Name = "RoofSignPost", Size = Vector3.new(0.4, shh + 1, 0.6), CFrame = cf * CFrame.new(ex, top + shh / 2 + 1.6, -front + sbT + 1.2), Color = C(30, 30, 32), Material = M.Metal, CanCollide = false })
                    end
                end) end
            end
            -- a vertical blade sign sticking out over the street (lower floors), half of them neon
            if rng:NextNumber() < 0.55 and not Blocked(c, w, 30) then Drop(Keep((side == "N") and CALM.BladeSignNorth or CALM.BladeSign), function()
                local sh = rng:NextNumber(9, 15)
                local sy = rng:NextNumber(22, 36)
                local neon = rng:NextNumber() < 0.55
                local ncol = NEON_LIST[rng:NextInteger(1, #NEON_LIST)]
                local blade = Q({ Name = "BladeSign", Size = Vector3.new(0.6, sh, 3.2), CFrame = cf * CFrame.new(rng:NextNumber(-w / 2 + 2, w / 2 - 2), F + sy, -front - 2.2),
                    Color = neon and C(16, 14, 18) or ({ C(190, 40, 36), C(220, 200, 150), C(230, 190, 60), C(40, 60, 90) })[rng:NextInteger(1, 4)], Material = neon and M.Metal or M.SmoothPlastic, CanCollide = false })
                HubCity.BladeFrame(Q, blade, 2.2)
                local word = Vertical(SIGNS[rng:NextInteger(1, #SIGNS)])
                for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
                    Text(blade, face, word, neon and ncol or C(20, 16, 14), { PPS = 20, Lit = not neon, Brightness = neon and 1.7 or 1.2, Stroke = neon and C(10, 6, 8) or C(255, 240, 220), StrokeT = neon and 0.35 or 1 })
                end
                if neon then
                    local n1 = Q({ Name = "BladeNeon", Size = Vector3.new(0.7, sh + 0.4, 0.25), CFrame = blade.CFrame * CFrame.new(0, 0, 1.7), Color = ncol, Material = M.Neon, CanCollide = false })
                    local n2 = Q({ Name = "BladeNeon", Size = Vector3.new(0.7, sh + 0.4, 0.25), CFrame = blade.CFrame * CFrame.new(0, 0, -1.7), Color = ncol, Material = M.Neon, CanCollide = false })
                    -- (UPDATE 4) its light pool on the pavement under it + now and then a broken-tube flicker (HubLife)
                    local gp = blade.Position
                    local out = (cf * CFrame.new(0, 0, -front - 9)).Position -- (straight out from the wall)
                    local gy = HubCity.WalkY(gp.X, gp.Z) + 0.03
                    local c0 = Vector3.new(gp.X, gy, gp.Z)
                    local dir = Vector3.new(out.X - c0.X, 0, out.Z - c0.Z)
                    if dir.Magnitude > 0.1 then
                        HubCity.WetGlow(Q, CFrame.lookAt(c0 + dir.Unit * 3, c0 + dir.Unit * 9), 12, 7, ncol, 0.5)
                    end
                    flickN += 1
                    if flickN % 3 == 0 then -- (every third neon blade)
                        CS:AddTag(n1, "HubFlicker"); CS:AddTag(n2, "HubFlicker")
                    end
                    if litLights < 3 and rng:NextNumber() < 0.5 then
                        litLights += 1
                        Light(blade, "PointLight", { Range = 26, Brightness = 1.4, Color = ncol, Shadows = false })
                    end
                end
                Q({ Name = "SignBracket", Size = Vector3.new(0.3, 0.3, 2.2), CFrame = blade.CFrame * CFrame.new(0, sh / 2 - 0.6, 2.2), Color = C(30, 30, 32), Material = M.Metal, CanCollide = false })
            end) end
            -- (HUBFIX DEPTH) the pieces in front of / on the stepped wall -- built last, so DepthClear sees the blade sign.
            -- No random draws in here (the look follows from the plan), so nothing after it moves.
            if plan.steps[1] or plan.feats[1] then
                local function Group(name: string): Model
                    local m = Instance.new("Model"); m.Name = name; m.Parent = city
                    table.insert(depthModels, m)
                    return m
                end
                local function Put(m: Model, props: any): BasePart local p = Q(props); p.Parent = m; return p end
                -- trim = the light concrete of slab edges / caps (an edge that catches the light reads as depth at night)
                local trim = col:Lerp(C(176, 170, 160), 0.38)
                local back = 0
                for _, st in ipairs(plan.steps) do -- each step's roof edge: a low parapet where the floors below end
                    Put(Group("DepthSetback"), { Name = "SetbackParapet", Size = Vector3.new(w + 0.2, 1.2, 0.7), CFrame = cf * CFrame.new(0, F + st.S + 0.6, -front + back + 0.35), Color = trim, Material = mat, CanCollide = false })
                    back += st.sb
                end
                for fi, f in ipairs(plan.feats) do
                    local seed = math.floor((f.u0 or 0) / 5 + hgt / 10 + w + fi) -- (a per-feature pick without a draw)
                    if f.kind == "loggia" then -- end piers + a solid balustrade with a light capping: the band behind is 4.5 deep
                        local m = Group("DepthLoggia")
                        local L, r = f.L, f.r
                        for _, sx in ipairs({ -1, 1 }) do
                            Put(m, { Name = "LoggiaPier", Size = Vector3.new(1.4, 10, r), CFrame = cf * CFrame.new(sx * ((w + 0.2) / 2 - 0.7), F + L + 5, -front + r / 2), Color = col, Material = mat, CanCollide = false })
                        end
                        Put(m, { Name = "LoggiaRail", Size = Vector3.new(w - 2.6, 3.2, 0.5), CFrame = cf * CFrame.new(0, F + L + 1.6, -front + 0.25), Color = trim, Material = mat, CanCollide = false })
                        -- a lit room or two at the back of the loggia (warm: somebody is home)
                        local nbL = math.floor((w + 0.2) / 5)
                        for k = 0, (nbL >= 4) and (seed % 2) or 0 do -- (inner bays only: the end ones sit behind the piers)
                            local j = 1 + (seed + 2 * k) % math.max(1, nbL - 2)
                            local lx = (nbL >= 3) and ((w + 0.2) / 2 - (2.5 + 5 * j)) or nil
                            if lx then Put(m, { Name = "LitWindow", Size = Vector3.new(FACADE_WIN_W, FACADE_WIN_H, 0.12), CFrame = cf * CFrame.new(lx, F + L + FACADE_WIN_MID, -front + r - 0.06), Color = C(214, 150, 84), Material = M.Neon, Transparency = 0.4, CanCollide = false }) end
                        end
                    elseif f.kind == "oriel" then -- an enclosed bay window hung off the wall, wearing the same window tile
                        local m = Group("DepthOriel")
                        local x0, x1 = SpanX(f.u0, f.u1)
                        local ow, od, xc = x1 - x0, 3.4, (x0 + x1) / 2
                        local paint = col:Lerp(PAINT[seed % #PAINT + 1], 0.55)
                        paint = Color3.new(math.min(1, paint.R * 1.12), math.min(1, paint.G * 1.12), math.min(1, paint.B * 1.12))
                        local o = Put(m, { Name = "Oriel", Size = Vector3.new(ow, f.y1 - f.y0 + 0.6, od), CFrame = cf * CFrame.new(xc, F + (f.y0 + f.y1) / 2 - 0.3, -front - od / 2), Color = paint, Material = mat, CanCollide = false })
                        FacadeTex(o, fk, F + f.y1, ow, nil, FACES_FRONT)
                        Put(m, { Name = "OrielCap", Size = Vector3.new(ow + 0.7, 0.55, od + 0.6), CFrame = cf * CFrame.new(xc, F + f.y1 + 0.27, -front - od / 2 - 0.2), Color = trim, Material = M.Concrete, CanCollide = false })
                        local floorsIn = math.floor((f.y1 - f.y0) / 10)
                        local ly = f.y0 + 10 * (seed % floorsIn)
                        local lc = (seed % 3 == 0) and C(110, 150, 196) or C(214, 150, 84)
                        Put(m, { Name = "LitWindow", Size = Vector3.new(FACADE_WIN_W, FACADE_WIN_H, 0.12), CFrame = cf * CFrame.new(x1 - 2.5 - 5 * (seed % 2), F + ly + FACADE_WIN_MID, -front - od - 0.06), Color = lc, Material = M.Neon, Transparency = 0.4, CanCollide = false })
                        if seed % 2 == 0 then -- a soil pipe down the wall beside it
                            Put(m, { Name = "SoilPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(f.y1 - FACADE_FLOOR0 + 2, 0.5, 0.5), CFrame = cf * CFrame.new(x0 - 0.6, F + (FACADE_FLOOR0 + f.y1 + 2) / 2, -front - 0.3) * CFrame.Angles(0, 0, math.rad(90)), Color = C(84, 80, 74), Material = M.Metal, CanCollide = false })
                        end
                    elseif f.kind == "bands" then -- slab edges: each its own piece (DepthClear can drop one alone)
                        for _, y in ipairs(f.ys) do
                            Put(Group("DepthBand"), { Name = "SlabEdge", Size = Vector3.new(w + 0.2, 0.7, 1.8), CFrame = cf * CFrame.new(0, F + y - 0.3, -front - 0.85), Color = trim, Material = M.Concrete, CanCollide = false })
                        end
                    elseif f.kind == "balcony" then -- stacked balconies: solid painted fronts with a light edge, or a slab + a steel grille
                        local m = Group("DepthBalcony")
                        local x0, x1 = SpanX(f.u0, f.u1)
                        local bw, xc = x1 - x0 + 0.4, (x0 + x1) / 2
                        local paint = col:Lerp(PAINT[seed % #PAINT + 1], 0.6)
                        for _, fy in ipairs(f.floors) do
                            if f.steel then
                                Put(m, { Name = "BalconySlab", Size = Vector3.new(bw, 0.45, 2.7), CFrame = cf * CFrame.new(xc, F + fy - 0.22, -front - 1.35), Color = trim, Material = M.Concrete, CanCollide = false })
                                Put(m, { Name = "BalconyGrille", Size = Vector3.new(bw, 2.7, 0.14), CFrame = cf * CFrame.new(xc, F + fy + 1.35, -front - 2.63), Color = C(38, 40, 44), Material = M.DiamondPlate, CanCollide = false })
                            else
                                Put(m, { Name = "Balcony", Size = Vector3.new(bw, 3.3, 2.6), CFrame = cf * CFrame.new(xc, F + fy + 1.25, -front - 1.3), Color = paint, Material = mat, CanCollide = false })
                                Put(m, { Name = "BalconyEdge", Size = Vector3.new(bw + 0.2, 0.3, 2.8), CFrame = cf * CFrame.new(xc, F + fy + 3.05, -front - 1.35), Color = trim, Material = M.Concrete, CanCollide = false })
                            end
                        end
                        if seed % 2 == 1 then
                            local top = f.floors[#f.floors] + 3
                            Put(m, { Name = "SoilPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(top - FACADE_FLOOR0 + 2, 0.5, 0.5), CFrame = cf * CFrame.new(x1 + 0.6, F + (FACADE_FLOOR0 + top + 2) / 2, -front - 0.3) * CFrame.Angles(0, 0, math.rad(90)), Color = C(84, 80, 74), Material = M.Metal, CanCollide = false })
                        end
                    end
                end
            end
            t += w
        end
    end
    local L = HALF + 3
    -- (the side rows stop at z 74: the Training Grounds start at z 75)
    Facade(Vector3.new(0, 0, -HALF), Vector3.xAxis, Vector3.zAxis, L * 2, { { -38, 30, 40 }, { 38, 30, 40 } }, nil, nil, "N")   -- north (the two gates)
    Facade(Vector3.new(-HALF, 0, -2), -Vector3.zAxis, Vector3.xAxis, L * 2 - 4, {}, true, nil, "W")                          -- west (leaderboards)
    Facade(Vector3.new(HALF, 0, -2), Vector3.zAxis, -Vector3.xAxis, L * 2 - 4, {}, true, nil, "E")                           -- east (leaderboards)
    Facade(Vector3.new(0, 0, HubCity.SOUTH_FRONT), -Vector3.xAxis, -Vector3.zAxis, L * 2, { { 0, 42, 29 } }, false, true, "S")    -- south (the range doorway)
    -- (UPDATE 4, owner: the doorway "leads into the training range ... completely thin and flat") THE TUNNEL through the
    -- 10-deep block: tiled walls, a paved floor, a ceiling with fluorescent tubes + pipes, a steel portal frame at the range
    -- mouth (the hub mouth keeps the green neon frame). RANGE geometry untouched (the pads start at z 79.5).
    do
        local z0, z1 = HubCity.SOUTH_FRONT, HALF + 4
        local zc, zl = (z0 + z1) / 2, z1 - z0
        Q({ Name = "TunnelFloor", Size = Vector3.new(42, 0.3, zl), Position = Vector3.new(0, F - 0.15 + 0.02, zc), Color = C(150, 144, 150), Material = M.Pavement, CanCollide = true, CanQuery = true })
            .MaterialVariant = MaterialService:FindFirstChild("HubPaving") and "HubPaving" or ""
        for _, sx in ipairs({ -1, 1 }) do
            local wall = Q({ Name = "TunnelWall", Size = Vector3.new(0.4, 29, zl), Position = Vector3.new(sx * 20.8, F + 14.5, zc), Color = C(86, 82, 78), Material = M.Concrete, CanCollide = false })
            HubCity.Img(wall, (sx < 0) and Enum.NormalId.Right or Enum.NormalId.Left, HubCity.IMG.Tiles, 4, C(96, 92, 86))
            Q({ Name = "TunnelPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(zl, 0.8, 0.8), Position = Vector3.new(sx * 19.6, F + 26.6, zc) + Vector3.new(0, 0, 0), Color = C(70, 64, 58), Material = M.Metal, CanCollide = false })
                .CFrame = CFrame.new(sx * 19.6, F + 26.6, zc) * CFrame.Angles(0, math.rad(90), 0)
        end
        Q({ Name = "TunnelCeiling", Size = Vector3.new(42, 0.4, zl), Position = Vector3.new(0, F + 28.8, zc), Color = C(58, 56, 54), Material = M.Concrete, CanCollide = false })
        for _, tx in ipairs({ -11, 0, 11 }) do
            Q({ Name = "TunnelTube", Size = Vector3.new(0.3, 0.25, zl - 2), Position = Vector3.new(tx, F + 28.45, zc), Color = C(225, 240, 255), Material = M.Neon, CanCollide = false })
        end
        HubCity.WetGlow(Q, CFrame.new(0, F + 0.06, zc), zl, 30, C(200, 225, 255), 0.35)
        for _, sx in ipairs({ -1, 1 }) do -- the range mouth's steel portal frame
            Q({ Name = "PortalJamb", Size = Vector3.new(1.4, 29, 1.2), Position = Vector3.new(sx * 21.4, F + 14.5, z1 + 0.3), Color = C(46, 46, 50), Material = M.Metal, CanCollide = false })
        end
        Q({ Name = "PortalHead", Size = Vector3.new(44.2, 1.6, 1.2), Position = Vector3.new(0, F + 29.6, z1 + 0.3), Color = C(46, 46, 50), Material = M.Metal, CanCollide = false })
    end
    -- invisible colliders up the facades: nobody climbs out
    for _, b in ipairs({ { Vector3.new(0, 70, -HALF - 3), Vector3.new(160, 140, 6) }, { Vector3.new(0, 70, HALF + 4), Vector3.new(160, 140, 6) },
        { Vector3.new(-HALF - 3, 70, 0), Vector3.new(6, 140, 160) }, { Vector3.new(HALF + 3, 70, 0), Vector3.new(6, 140, 160) } }) do
        local c = P(city, { Name = "CityCollider", Size = b[2], Position = b[1] + Vector3.new(0, 30, 0), Transparency = 1, CanQuery = false })
        c.CastShadow = false
    end
    -- ...and down to the street behind the north / west / east blocks (a safety net under the facades: nobody walks out
    -- of the city at street level even if a block leaves a gap). The south side has the Training Grounds doorway.
    for _, b in ipairs({ { Vector3.new(0, 0, -HALF - 30), Vector3.new(222, 6) }, { Vector3.new(-HALF - 30, 0, -16), Vector3.new(6, 170) },
        { Vector3.new(HALF + 30, 0, -16), Vector3.new(6, 170) } }) do -- (the sides stop at z 69: the Training Grounds start at z 75)
        local c = P(city, { Name = "CityCollider", Size = Vector3.new(b[2].X, 40, b[2].Y), Position = b[1] + Vector3.new(0, F + 18, 0), Transparency = 1, CanQuery = false })
        c.CastShadow = false
    end
    -- a roof lid high up so the camera / players can't leave over the towers
    local lid = P(city, { Name = "SkyLid", Size = Vector3.new(170, 2, 170), Position = Vector3.new(0, 150, 0), Transparency = 1, CanQuery = false })
    lid.CastShadow = false

    -- ===== OVERHEAD: cables, walkway bridges, red lantern strings, the big neon city sign =====
    for ci = 1, 26 do -- cables strung wall to wall (two segments: a sag)
        local alongX = rng:NextNumber() < 0.5
        local y = rng:NextNumber(30, 66)
        -- (UPDATE 4, owner: the hub "looks a bit worse than all of the new biomes" -- the web boxed the new night sky in:
        -- every other cable is gone and the rest hang higher; the draws are kept so the city comes out the same)
        local keep = ci % (CALM.CableEvery or 2) == 0 -- (HUB DECLUTTER: every 4th of the old 26)
        y += 10
        local o = rng:NextNumber(-60, 60)
        local a = alongX and Vector3.new(-HALF, y, o) or Vector3.new(o, y, -HALF)
        local b = alongX and Vector3.new(HALF, y + rng:NextNumber(-6, 6), o + rng:NextNumber(-20, 20)) or Vector3.new(o + rng:NextNumber(-20, 20), y + rng:NextNumber(-6, 6), HALF)
        local mid = (a + b) / 2 - Vector3.new(0, rng:NextNumber(2, 6), 0)
        for _, seg in ipairs(keep and { { a, mid }, { mid, b } } or {}) do
            local d = (seg[2] - seg[1]).Magnitude
            Q({ Name = "Cable", Size = Vector3.new(0.14, 0.14, d), CFrame = CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), Color = C(16, 16, 18), Material = M.SmoothPlastic, CanCollide = false })
        end
    end
    for _, z in ipairs({ -30, 22 }) do Drop(CALM.Bridges[z] == true, function() -- walkway bridges across the street
        local y = (z < 0) and 64 or 54 -- (UPDATE 4: the one in front of the spawn 46 -> 64, out of the view up to the sky)
        Q({ Name = "Bridge", Size = Vector3.new(HALF * 2, 1.4, 6), Position = Vector3.new(0, y, z), Color = C(58, 56, 54), Material = M.Concrete })
        for _, s in ipairs({ -1, 1 }) do
            Q({ Name = "BridgeRail", Size = Vector3.new(HALF * 2, 3, 0.2), Position = Vector3.new(0, y + 2.2, z + s * 2.9), Color = C(30, 30, 32), Material = M.DiamondPlate, Transparency = 0.3, CanCollide = false })
        end
        if CALM.BridgeNeon then
            Q({ Name = "BridgeNeon", Size = Vector3.new(HALF * 2, 0.25, 0.25), Position = Vector3.new(0, y - 0.8, z - 3), Color = (z < 0) and NEON.Cyan or NEON.Pink, Material = M.Neon, CanCollide = false })
        end
    end) end
    -- red paper lanterns on strings across the plaza (the bloom makes them glow; no lights)
    for i, s in ipairs({ { Vector3.new(-HALF, 22, -50), Vector3.new(HALF, 23, -44) }, { Vector3.new(-HALF, 21, -4), Vector3.new(HALF, 22, 6) },
        { Vector3.new(-HALF, 23, 40), Vector3.new(HALF, 22, 34) }, { Vector3.new(-30, 25, -HALF), Vector3.new(-26, 24, HALF) } }) do
        if not CALM.LanternStrings[i] then continue end -- (HUB DECLUTTER: no rng draws in here)
        local a, b = s[1], s[2]
        local d = (b - a).Magnitude
        Q({ Name = "LanternString", Size = Vector3.new(0.1, 0.1, d), CFrame = CFrame.lookAt((a + b) / 2, b), Color = C(20, 16, 14), Material = M.SmoothPlastic, CanCollide = false })
        local n = 14
        for k = 1, n - 1 do
            local p = a:Lerp(b, k / n) - Vector3.new(0, math.sin(k / n * math.pi) * 3 + 1.2, 0)
            HubCity.PaperLantern(Q, CFrame.new(p), 1.15, (i == 4 and k % 3 == 0) and NEON.Amber or C(200, 32, 36), true)
        end
    end
    -- big hanging signboards across the street (the walled city's signature: weathered boards on cables over the alley;
    -- kept off the sightlines from the plaza to the two gate boards)
    local BOARDS = {
        -- (owner 2026-10-05: "the signs in the hub are too neon and hard to read" -- these two hung right in front of the
        -- DUNGEONS / CHALLENGES gate boards from the plaza: moved to the south end of the street, behind the spawn)
        { Vector3.new(-16, 26, 50), 22, "茶餐廳  冰室", C(226, 214, 190), C(30, 22, 18) }, { Vector3.new(18, 25, 44), 18, "電器行", C(180, 36, 30), C(250, 220, 120) },
        { Vector3.new(-34, 25, -12), 22, "九龍城寨", C(230, 190, 60), C(30, 20, 14) }, { Vector3.new(30, 23, 10), 22, "牙科診所", C(220, 210, 190), C(160, 30, 26) },
        { Vector3.new(-32, 22, 30), 22, "當舖  按揭", C(40, 60, 90), C(240, 230, 210) }, { Vector3.new(36, 22, 46), 20, "酒家  麵館", C(200, 40, 34), C(250, 236, 200) },
    }
    for bi, b in ipairs(BOARDS) do Drop(CALM.StreetBoards[bi] == true, function()
        local yaw = (rng:NextNumber() < 0.5) and 0 or math.rad(rng:NextNumber(-12, 12))
        local cf = CFrame.new(b[1]) * CFrame.Angles(0, yaw, 0)
        b = { b[1], b[2] * 0.8, b[3], b[4], b[5] } -- (UPDATE 4: 80% the size -- they blocked the skyline)
        local set = Instance.new("Model"); set.Name = "StreetBoardSet"; set.Parent = city
        if dropping then table.insert(trash, set) end
        local board = Q({ Name = "StreetBoard", Size = Vector3.new(b[2], 5.6, 1.0), CFrame = cf, Color = b[4], Material = M.SmoothPlastic })
        -- (UPDATE 4: built signs, not flat boards -- 1 stud thick, steel side frames, a lit strip under the bottom edge)
        for _, sx in ipairs({ -1, 1 }) do
            Q({ Name = "BoardFrame", Size = Vector3.new(0.35, 6.2, 1.2), CFrame = cf * CFrame.new(sx * (b[2] / 2 + 0.17), 0, 0), Color = C(40, 36, 32), Material = M.Metal, CanCollide = false })
        end
        Q({ Name = "BoardNeon", Size = Vector3.new(b[2] - 1, 0.16, 0.5), CFrame = cf * CFrame.new(0, -3.0, 0), Color = b[5]:Lerp(b[4], 0.3), Material = M.Neon, CanCollide = false })
        HubCity.WetGlow(Q, CFrame.new(b[1].X, HubCity.WalkY(b[1].X, b[1].Z) + 0.03, b[1].Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, math.rad(90), 0), b[2] * 0.9, 9, b[5]:Lerp(b[4], 0.4), 0.35)
        for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
            Text(board, face, b[3], b[5], { PPS = 16, Lit = true, Brightness = 1.4, StrokeT = 1, Font = Enum.Font.GothamBold, W = 0.94 })
        end
        -- rust along the bottom edge, the frame, the two hanging wires
        Q({ Name = "BoardRust", Size = Vector3.new(b[2], 1.2, 1.05), CFrame = cf * CFrame.new(0, -2.3, 0), Color = C(110, 66, 36), Material = M.CorrodedMetal, Transparency = 0.25, CanCollide = false })
        Q({ Name = "BoardFrame", Size = Vector3.new(b[2] + 0.4, 0.3, 0.6), CFrame = cf * CFrame.new(0, 2.9, 0), Color = C(40, 36, 32), Material = M.Metal, CanCollide = false })
        for _, sx in ipairs({ -1, 1 }) do
            Q({ Name = "BoardWire", Size = Vector3.new(0.1, 18, 0.1), CFrame = cf * CFrame.new(sx * (b[2] / 2 - 1), 11.9, 0), Color = C(16, 16, 18), Material = M.SmoothPlastic, CanCollide = false })
        end
        -- (UPDATE 4) the board, its rust, frame and wires sway together about the wires' tops (client HubLife, off on Low)
        for _, d in ipairs(city:GetChildren()) do
            if d:IsA("BasePart") and (d.Name == "StreetBoard" or d.Name == "BoardRust" or d.Name == "BoardFrame" or d.Name == "BoardWire" or d.Name == "BoardNeon") and (d.Position - cf.Position).Magnitude < b[2] / 2 + 13 and not d:GetAttribute("Set") then
                d:SetAttribute("Set", true); d.Parent = set
            end
        end
        set.WorldPivot = cf * CFrame.new(0, 20.9, 0)
        CS:AddTag(set, "HubSway")
    end) end
    -- warm sodium lamps on brackets: amber pools on the wet street under the neon
    for li, l in ipairs({ { -HALF + 2, -2 }, { HALF - 2, 2 }, { -HALF + 2, 56 }, { HALF - 2, -56 } }) do
        local sx = (l[1] < 0) and 1 or -1
        -- (HUB LOOK 2026-10-24: four identical bracket lamps -> each its own arm reach / height, a dark hood over a thin lens)
        local reach, ly = 3.4 + (li % 3) * 0.7, 19.4 + ((li * 37) % 5) * 0.35
        local arm = Q({ Name = "LampArm", Size = Vector3.new(reach, 0.3, 0.3), Position = Vector3.new(l[1] + sx * reach / 2, ly + 0.4, l[2]), Color = C(30, 30, 32), Material = M.Metal, CanCollide = false })
        Q({ Name = "LampHead", Size = Vector3.new(1.6, 0.45, 1.0), Position = Vector3.new(l[1] + sx * (reach - 0.2), ly + 0.15, l[2]), Color = C(28, 28, 31), Material = M.Metal, CanCollide = false })
        local head = Q({ Name = "Sodium", Size = Vector3.new(1.2, 0.08, 0.75), Position = Vector3.new(l[1] + sx * (reach - 0.2), ly - 0.1, l[2]), Color = C(255, 170, 80), Material = M.Neon, CanCollide = false })
        Light(head, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 40, Angle = 100, Brightness = 2.2, Color = C(255, 160, 80), Shadows = false })
        local _ = arm
    end
    -- the big city sign over the gates (replaces the keep's crest)
    local big = Q({ Name = "CitySign", Size = Vector3.new(34, 10, 1), Position = Vector3.new(0, 34, -HALF + 0.8), Color = C(12, 10, 14), Material = M.Metal })
    Text(big, Enum.NormalId.Back, "瞄準城", NEON.Red, { PPS = 20, Sub = "AIMBOUND  •  AIM  •  LOOT  •  ASCEND", SubColor = NEON.Cyan, Brightness = 1.8, Stroke = C(10, 6, 8), StrokeT = 0.3 })
    for _, dy in ipairs({ 5.2, -5.2 }) do Q({ Name = "CitySignNeon", Size = Vector3.new(34.4, 0.3, 0.3), Position = Vector3.new(0, 34 + dy, -HALF + 1.4), Color = NEON.Red, Material = M.Neon, CanCollide = false }) end
    Light(big, "PointLight", { Range = 34, Brightness = 1.6, Color = NEON.Red, Shadows = false })
    HubCity.WetGlow(Q, CFrame.new(0, F + 0.03, -HALF + 14), 22, 30, NEON.Red, 0.4) -- (UPDATE 4: its red on the wet street)
    -- the range doorway (its sign is the Training Grounds' own): green neon round the 42-wide opening
    Q({ Name = "RangeSignNeon", Size = Vector3.new(30.4, 0.3, 0.3), Position = Vector3.new(0, F + 29.3, HubCity.SOUTH_FRONT - 0.1), Color = NEON.Green, Material = M.Neon, CanCollide = false })
    for _, sx in ipairs({ -1, 1 }) do
        Q({ Name = "RangeDoorNeon", Size = Vector3.new(0.35, 28, 0.35), Position = Vector3.new(sx * 20.6, F + 14, HubCity.SOUTH_FRONT - 0.1), Color = NEON.Green, Material = M.Neon, CanCollide = false })
    end
    -- a hanging traffic light over the road to the range
    if CALM.TrafficLight then
    local tl = Q({ Name = "TrafficLight", Size = Vector3.new(1.6, 4.4, 1.4), Position = Vector3.new(6, 24, 50), Color = C(30, 30, 30), Material = M.Metal })
    for k, col in ipairs({ C(80, 10, 10), NEON.Amber, C(10, 60, 30) }) do
        Q({ Name = "TrafficLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Position = tl.Position + Vector3.new(0, 1.4 - (k - 1) * 1.4, -0.6), Color = col, Material = (k == 2) and M.Neon or M.SmoothPlastic, CanCollide = false })
    end
    Q({ Name = "TrafficWire", Size = Vector3.new(0.12, 0.12, 30), Position = Vector3.new(6, 26.4, 50), Color = C(16, 16, 18), Material = M.SmoothPlastic, CanCollide = false })
    end

    -- ===== STREET LIFE: vending machines, arcade cabinets, cafe tables, rubbish, steam =====
    local function Vending(cf: CFrame, col: Color3, idx: number?)
        if EnvKit.Has("City", "Vending") then -- (UPDATE 4: a textured double drink machine -- kit mesh + one invisible collider)
            if idx == 2 then return end -- (its neighbour site: the double unit covers both)
            local at = (idx == 1) and cf * CFrame.new(2.5, 0, 0) or cf
            EnvKit.Place("City", "Vending", at * CFrame.new(0, F, 0), { Parent = city, Scale = 1.75, Shadow = false })
            local vc = P(city, { Name = "Vending", Size = Vector3.new(6.8, 6.4, 2.6), CFrame = at * CFrame.new(0, F + 3.2, 0), Transparency = 1 })
            vc.CastShadow = false
            HubCity.WetGlow(Q, at * CFrame.new(0, 0.03, -4.5), 8, 7, C(210, 230, 255), 0.4)
            return
        end
        local v = P(city, { Name = "Vending", Size = Vector3.new(4, 7, 3), CFrame = cf * CFrame.new(0, F + 3.5, 0), Color = C(200, 200, 205):Lerp(col, 0.25), Material = M.SmoothPlastic })
        Q({ Name = "VendingGlass", Size = Vector3.new(2.6, 4.2, 0.1), CFrame = cf * CFrame.new(-0.5, F + 4.4, -1.52), Color = C(220, 240, 255), Material = M.Neon, Transparency = 0.45, CanCollide = false })
        Q({ Name = "VendingPanel", Size = Vector3.new(0.7, 4.2, 0.1), CFrame = cf * CFrame.new(1.4, F + 4.4, -1.52), Color = col, Material = M.Neon, Transparency = 0.2, CanCollide = false })
        for r = 0, 2 do Q({ Name = "VendingShelf", Size = Vector3.new(2.5, 0.12, 0.1), CFrame = cf * CFrame.new(-0.5, F + 3.2 + r * 1.3, -1.6), Color = col:Lerp(C(255, 255, 255), 0.4), Material = M.Neon, CanCollide = false }) end
        return v
    end
    local function Arcade(cf: CFrame, col: Color3)
        P(city, { Name = "Arcade", Size = Vector3.new(2.8, 6.2, 2.8), CFrame = cf * CFrame.new(0, F + 3.1, 0), Color = C(24, 22, 30), Material = M.SmoothPlastic })
        Q({ Name = "ArcadeScreen", Size = Vector3.new(2.2, 1.8, 0.1), CFrame = cf * CFrame.new(0, F + 4.6, -1.42) * CFrame.Angles(math.rad(-12), 0, 0), Color = col, Material = M.Neon, Transparency = 0.15, CanCollide = false })
        Q({ Name = "ArcadeMarquee", Size = Vector3.new(2.6, 0.7, 0.1), CFrame = cf * CFrame.new(0, F + 5.9, -1.42), Color = NEON_LIST[rng:NextInteger(1, #NEON_LIST)], Material = M.Neon, CanCollide = false })
        Q({ Name = "ArcadeDeck", Size = Vector3.new(2.6, 0.3, 1.2), CFrame = cf * CFrame.new(0, F + 3.4, -1.7) * CFrame.Angles(math.rad(15), 0, 0), Color = C(40, 36, 46), Material = M.SmoothPlastic, CanCollide = false })
    end
    local function Table(pos: Vector3)
        if EnvKit.Has("City", "CafeSet") then -- (UPDATE 4: the textured kit set; was 11 plain blocks; the draws are kept)
            local turn = 0
            for _ = 0, 2 do turn += rng:NextNumber(-0.3, 0.3) end
            EnvKit.Place("City", "CafeSet", CFrame.new(pos + Vector3.new(0, F, 0)) * CFrame.Angles(0, turn * 2, 0),
                { Parent = city, Scale = VScale(1.3, 0.08), Tint = VTint("CafeSet", 0.75), Shadow = false, Hitbox = Vector3.new(2.8, 2.9, 2.8) })
            return
        end
        Q({ Name = "CafeTable", Size = Vector3.new(3.4, 0.25, 3.4), Position = pos + Vector3.new(0, F + 2.6, 0), Color = C(70, 60, 50), Material = M.Wood, CanCollide = true })
        Q({ Name = "CafeTableLeg", Size = Vector3.new(0.3, 2.5, 0.3), Position = pos + Vector3.new(0, F + 1.25, 0), Color = C(40, 40, 42), Material = M.Metal, CanCollide = false })
        for k = 0, 2 do
            local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
            local cp = pos + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
            Q({ Name = "Chair", Size = Vector3.new(1.6, 0.2, 1.6), Position = cp + Vector3.new(0, F + 1.7, 0), Color = C(60, 50, 40), Material = M.Wood, CanCollide = false })
            Q({ Name = "ChairBack", Size = Vector3.new(1.6, 1.6, 0.2), CFrame = CFrame.lookAt(cp + Vector3.new(0, F + 2.6, 0), pos + Vector3.new(0, F + 2.6, 0)) * CFrame.new(0, 0, 0.8), Color = C(50, 44, 38), Material = M.Metal, CanCollide = false })
            Q({ Name = "ChairLeg", Size = Vector3.new(0.2, 1.6, 0.2), Position = cp + Vector3.new(0, F + 0.8, 0), Color = C(40, 40, 42), Material = M.Metal, CanCollide = false })
        end
    end
    local function Junk(pos: Vector3)
        for _ = 1, rng:NextInteger(2, 4) do
            local s = rng:NextNumber(1.2, 2.2)
            Q({ Name = "TrashBag", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.8, s), Position = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), F + s * 0.35, rng:NextNumber(-1.5, 1.5)), Color = C(18, 18, 20), Material = M.SmoothPlastic, Reflectance = 0.1 })
        end
        Q({ Name = "Crate", Size = Vector3.new(2.4, 2, 2.4), CFrame = CFrame.new(pos + Vector3.new(1.8, F + 1, -1)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = C(90, 70, 46), Material = M.WoodPlanks, CanCollide = true })
    end
    -- vending machines + junk in the open corners (the storefronts fill both side walls from z -50 to 52)
    local vi = 0
    for _, v in ipairs({ { Vector3.new(-56, 0, -HALF + 2.5), Vector3.new(-56, 0, 0) }, { Vector3.new(-61, 0, -HALF + 2.5), Vector3.new(-61, 0, 0) },
        { Vector3.new(-HALF + 2.5, 0, math.min(62, SouthFrontZ(-HALF + 2.5) - 3.8)), Vector3.new(0, 0, math.min(62, SouthFrontZ(-HALF + 2.5) - 3.8)) },
        { Vector3.new(HALF - 2.5, 0, math.min(64, SouthFrontZ(HALF - 2.5) - 3.8)), Vector3.new(0, 0, math.min(64, SouthFrontZ(HALF - 2.5) - 3.8)) },
        { Vector3.new(26, 0, math.min(SouthFrontZ(22.6), SouthFrontZ(29.4)) - 1.6), Vector3.new(26, 0, 0) } }) do -- (UPDATE 4: against the south row's real face)
        vi += 1
        local vcol = NEON_LIST[rng:NextInteger(1, #NEON_LIST)]
        if CALM.VendingSites[vi] then Vending(CFrame.lookAt(v[1], v[2]), vcol, (vi == 1 and not CALM.VendingSites[2]) and 0 or vi) end
    end
    for ji, jp in ipairs({ Vector3.new(-66, 0, -64), Vector3.new(66, 0, -62), Vector3.new(-40, 0, 63), Vector3.new(44, 0, 63) }) do -- (z 63: the south row's front is at 69 now)
        Drop(CALM.Junk[ji] == true, function() Junk(jp) end)
    end
    -- (G.25) caged gas cylinders beside two of the junk piles, back to the wall
    for gi, g in ipairs({ { -45.5, -1 }, { 49.5, -1 } }) do
        if gi > CALM.GasCages then continue end
        local gz = SouthFrontZ(g[1]) - 1.4
        EnvKit.Place("City", "GasCage", CFrame.new(g[1], F, gz) * VYaw(8), { Parent = city, Scale = VScale(1.4, 0.08), Tint = VTint("GasCage", 0.75), Shadow = false })
    end
    -- street-food carts, scooters and stools down the middle lanes (the walking lines to the gates / shops stay clear)
    local function Cart(cf: CFrame, col: Color3, word: string)
        if EnvKit.Has("City", "FoodCart") then -- (UPDATE 4: the textured kit cart; one invisible collider; the sign, steam + stools stay)
            EnvKit.Place("City", "FoodCart", cf * CFrame.new(0, F, 0), { Parent = city, Scale = 1, Shadow = false })
            local cc = P(city, { Name = "Cart", Size = Vector3.new(6.4, 3.4, 3.4), CFrame = cf * CFrame.new(0, F + 1.7, 0), Transparency = 1 })
            cc.CastShadow = false
            local sign = Q({ Name = "CartSign", Size = Vector3.new(4.6, 1.1, 0.15), CFrame = cf * CFrame.new(0, F + 5.6, -2.05), Color = C(240, 230, 210), Material = M.SmoothPlastic })
            Text(sign, Enum.NormalId.Front, word, C(180, 30, 26), { PPS = 24, Lit = true, Brightness = 1.6, StrokeT = 1 })
            local steam = Q({ Name = "CartSteam", Size = Vector3.new(1, 0.2, 1), CFrame = cf * CFrame.new(-1.6, F + 3.6, 0), Transparency = 1, CanCollide = false })
            local se = Emit(steam, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C(230, 225, 230)), Size = NumberSequence.new(0.6, 3), Transparency = NumberSequence.new(0.7, 1),
                Lifetime = NumberRange.new(2, 3), Rate = 3, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top })
            if se then CS:AddTag(se, "QThin") end
            HubCity.WetGlow(Q, cf * CFrame.new(0, 0.03, -3.5), 7, 8, C(255, 200, 140), 0.45)
            for k = 0, 2 do -- (HUB LOOK: three identical stools in a ruler line -> pulled out at odd spots, mixed heights + colours)
                local sh = rngVar:NextNumber(1.3, 1.7)
                Q({ Name = "Stool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(sh, 1.2, 1.2), CFrame = cf * CFrame.new(-2.1 + k * 2.1 + rngVar:NextNumber(-0.4, 0.4), F + sh / 2, -3.4 - rngVar:NextNumber(-0.3, 0.7)) * CFrame.Angles(0, 0, math.rad(90)),
                    Color = ({ C(196, 40, 38), C(176, 52, 40), C(60, 96, 140) })[(k + rngVar:NextInteger(0, 2)) % 3 + 1], Material = M.SmoothPlastic })
            end
            return
        end
        P(city, { Name = "Cart", Size = Vector3.new(6, 3.2, 3), CFrame = cf * CFrame.new(0, F + 2.2, 0), Color = C(150, 140, 120):Lerp(col, 0.2), Material = M.Metal })
        for _, sx in ipairs({ -1, 1 }) do
            Q({ Name = "CartWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.4, 1.4), CFrame = cf * CFrame.new(sx * 2.4, F + 0.7, 1.6), Color = C(20, 20, 20), Material = M.SmoothPlastic })
            Q({ Name = "CartPole", Size = Vector3.new(0.2, 4, 0.2), CFrame = cf * CFrame.new(sx * 2.8, F + 5.8, 0), Color = C(40, 40, 44), Material = M.Metal })
        end
        Q({ Name = "CartCanopy", Size = Vector3.new(6.8, 0.2, 3.8), CFrame = cf * CFrame.new(0, F + 7.9, 0), Color = col, Material = M.Fabric })
        local sign = Q({ Name = "CartSign", Size = Vector3.new(5, 1.2, 0.15), CFrame = cf * CFrame.new(0, F + 7.1, -1.9), Color = C(240, 230, 210), Material = M.SmoothPlastic })
        Text(sign, Enum.NormalId.Front, word, C(180, 30, 26), { PPS = 24, Lit = true, Brightness = 1.6, StrokeT = 1 })
        Q({ Name = "CartBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = cf * CFrame.new(0, F + 7.4, 0), Color = C(255, 210, 150), Material = M.Neon })
        local steam = Q({ Name = "CartSteam", Size = Vector3.new(1, 0.2, 1), CFrame = cf * CFrame.new(-1.4, F + 4, 0), Transparency = 1, CanCollide = false })
        Emit(steam, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C(230, 225, 230)), Size = NumberSequence.new(0.6, 3), Transparency = NumberSequence.new(0.75, 1),
            Lifetime = NumberRange.new(2, 3), Rate = 2, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top })
        for k = 0, 2 do Q({ Name = "Stool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 1.2, 1.2), CFrame = cf * CFrame.new(-2 + k * 2, F + 0.8, -3.2) * CFrame.Angles(0, 0, math.rad(90)), Color = C(200, 40, 40), Material = M.SmoothPlastic }) end
    end
    if CALM.FoodCarts >= 2 then Cart(CFrame.new(-24, 0, -22) * CFrame.Angles(0, math.rad(200), 0), C(200, 40, 40), "魚蛋  燒賣") end -- (HUB DECLUTTER: the one in the gate approach goes first)
    if CALM.FoodCarts >= 1 then Cart(CFrame.new(26, 0, 20) * CFrame.Angles(0, math.rad(15), 0), C(230, 170, 40), "糖水") end
    local function Scooter(cf: CFrame, col: Color3)
        if EnvKit.Has("City", "Scooter") then -- (UPDATE 4: the textured kit scooter + one collider)
            EnvKit.Place("City", "Scooter", cf * CFrame.new(0, F, 0), { Parent = city, Scale = 1.2, Shadow = false, Hitbox = true, HitParent = city })
            return
        end
        Q({ Name = "ScooterBody", Size = Vector3.new(1.2, 1.6, 4.2), CFrame = cf * CFrame.new(0, F + 1.6, 0), Color = col, Material = M.SmoothPlastic, Reflectance = 0.1, CanCollide = true })
        for _, z in ipairs({ -1.6, 1.6 }) do Q({ Name = "ScooterWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.4, 1.4), CFrame = cf * CFrame.new(0, F + 0.7, z), Color = C(20, 20, 20), Material = M.SmoothPlastic }) end
        Q({ Name = "ScooterBar", Size = Vector3.new(1.8, 0.2, 0.2), CFrame = cf * CFrame.new(0, F + 3.2, -1.7), Color = C(40, 40, 44), Material = M.Metal })
    end
    -- (UPDATE 4 GROUND) street-edge clutter between the shopfronts: trash piles and goods stacks on the sidewalk by the
    -- curb, scooters parked along it in the street (kit meshes, one collider each; the shop fronts stay open)
    if EnvKit.Has("City", "TrashPile") then
        local rc = Random.new(5151)
        for _, sx in ipairs({ -1, 1 }) do
            for _, z in ipairs({ -25, 1, 27, 53 }) do -- (the gaps between the shops: their fronts stay open)
                local kind = (rc:NextNumber() < 0.5) and "TrashPile" or "GoodsStack"
                local scf = CFrame.new(sx * 44.2, F + 0.4, z + rc:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, math.rad(sx > 0 and -90 or 90) + rc:NextNumber(-0.4, 0.4), 0)
                if Keep(CALM.EdgeStacks) then EnvKit.Place("City", kind, scf, { Parent = city, Scale = VScale(1.1, 0.15), Tint = VTint(kind, 0.72), Shadow = false, Hitbox = true, HitParent = city }) end
                if rc:NextNumber() < 0.5 and z < 50 then
                    local sz, sr = rc:NextNumber(-1, 1), rc:NextNumber(-0.25, 0.25)
                    if CALM.CurbScooters then Scooter(CFrame.new(sx * 39.2, 0, z + sz) * CFrame.Angles(0, sr, 0), C(170, 40, 40)) end
                end
            end
        end
    end
    -- (UPDATE 4 DENSITY, owner: the plaza is "too wide and empty for a walled city") a NIGHT MARKET: kit stalls (tarp canopy,
    -- a counter of goods, hanging bulbs) in the street between the shopfronts and two pairs in the middle, each under a
    -- self-lit warm pool, and two low lantern strings over them. Kept clear: the walking lines spawn -> plinth -> gates and
    -- straight across into every shop (shops at z -38 / -12 / 14 / 40), the kiosk + bench islands
    if EnvKit.Has("City", "MarketStall") then
        for _, sp in ipairs({ { 35, -25 }, { 35, 1 }, { 35, 27 }, { 16, 1 }, { 16, 27 } }) do
            if not (sp[1] > 20 and CALM.MarketStalls[sp[2]]) then continue end -- (HUB DECLUTTER: only the street stalls by the shop gaps)
            for _, sx in ipairs({ -1, 1 }) do
                local pos = Vector3.new(sx * sp[1], F, sp[2])
                local face = (sp[1] > 20) and Vector3.new(0, F, sp[2]) or Vector3.new(sx * 40, F, sp[2]) -- (street stalls face the plaza, middle ones the shops)
                local scf = CFrame.lookAt(pos, Vector3.new(face.X, F, face.Z))
                scf = scf * VYaw(9) -- (HUB LOOK: the two stalls were mirror twins)
                EnvKit.Place("City", "MarketStall", scf, { Parent = city, Scale = VScale(1.05, 0.1), Tint = VTint("MarketStall", 0.72), Shadow = false, Hitbox = Vector3.new(7, 4, 4.6), HitParent = city })
                HubCity.WetGlow(Q, scf * CFrame.new(0, 0.03, -3.5), 7, 8, C(255, 196, 130), 0.55)
            end
        end
        for _, lz in ipairs(CALM.MarketLanterns and { -25, 27 } or {}) do
            local a, b = Vector3.new(-40, 16.5, lz), Vector3.new(40, 16, lz + 2)
            Q({ Name = "LanternString", Size = Vector3.new(0.1, 0.1, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = C(20, 16, 14), Material = M.SmoothPlastic, CanCollide = false })
            for k = 1, 9 do
                local pl = a:Lerp(b, k / 10) - Vector3.new(0, math.sin(k / 10 * math.pi) * 2 + 0.9, 0)
                HubCity.PaperLantern(Q, CFrame.new(pl), 1.0, (k % 3 == 0) and NEON.Amber or C(205, 34, 34), true)
            end
        end
    end
    if CALM.LooseScooters >= 1 then Scooter(CFrame.new(-14, 0, 58) * CFrame.Angles(0, math.rad(80), 0), C(170, 40, 40)) end
    if CALM.LooseScooters >= 2 then Scooter(CFrame.new(-11, 0, 60) * CFrame.Angles(0, math.rad(95), 0), C(60, 90, 120)) end
    if CALM.LooseScooters >= 3 then Scooter(CFrame.new(40, 0, -56) * CFrame.Angles(0, math.rad(20), 0), C(200, 190, 170)) end
    -- the street-food corner: tables under the lanterns
    for ti, p in ipairs({ Vector3.new(-30, 0, 56), Vector3.new(-22, 0, 63), Vector3.new(30, 0, 58) }) do
        if ti <= CALM.CafeTables then Table(p) else for _ = 0, 2 do local _ = rng:NextNumber(-0.3, 0.3) end end -- (draws kept)
    end
    -- an arcade corner by the north-east gate
    for k = 0, 2 do
        local acol = NEON_LIST[rng:NextInteger(1, #NEON_LIST)]
        if CALM.Arcade then Arcade(CFrame.lookAt(Vector3.new(58 - k * 3.4, 0, -HALF + 4), Vector3.new(58 - k * 3.4, 0, 0)), acol)
        else local _ = rng:NextInteger(1, #NEON_LIST) end -- (its marquee colour draw)
    end
    -- steam out of the manholes and a vent
    for _, z in ipairs({ -40, 40 }) do
        local sx = rng:NextNumber(-30, 30) -- (G.25: out of the manhole itself; the draw is kept)
        if not CALM.Steam[z] then continue end
        local s = Q({ Name = "Steam", Size = Vector3.new(2.6, 0.3, 2.6), Position = Vector3.new(manholes[z] and manholes[z].X or sx, F + 0.2, z), Transparency = 1, CanCollide = false })
        Emit(s, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C(200, 190, 210)), LightEmission = 0.1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(4, 6), Rate = 3, Speed = NumberRange.new(2, 4),
            SpreadAngle = Vector2.new(20, 20), Acceleration = Vector3.new(0.6, 0.4, 0), EmissionDirection = Enum.NormalId.Top })
    end

    -- ===== WEATHERING: rust, a broken board, loose wires (kept to the edges and overhead: the walking lines stay clean) =====
    do
        local Wt = Weathering(Q, rng, F)
        local wires = {}
        for _ = 1, 10 do
            table.insert(wires, { top = Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(34, 50), rng:NextNumber(-60, 60)), len = rng:NextNumber(5, 12), sway = 12 })
        end
        for wi, w in ipairs(wires) do Drop(wi <= CALM.Wires, function() Wt.Wires({ w }) end) end
        local patchList = { -- street level on the north wall (between the gates and the corners) and the side walls' open ends
            { pos = Vector3.new(-64, F + 4, -HALF + 0.2), yaw = 180, w = 7, h = 6 }, { pos = Vector3.new(-6, F + 5, -HALF + 0.2), yaw = 180, w = 6, h = 8 },
            { pos = Vector3.new(14, F + 3.5, -HALF + 0.2), yaw = 180, w = 5, h = 5 }, { pos = Vector3.new(66, F + 4.5, -HALF + 0.2), yaw = 180, w = 6, h = 7 },
            { pos = Vector3.new(-HALF + 0.2, F + 4, -64), yaw = -90, w = 6, h = 7 }, { pos = Vector3.new(HALF - 0.2, F + 4, -58), yaw = 90, w = 7, h = 6 },
        }
        for pi, pt in ipairs(patchList) do Drop(pi % 2 == 1 and (pi + 1) / 2 <= CALM.RustPatches, function() Wt.Patches({ pt }) end) end
        local rubbleList = { { pos = Vector3.new(-16, 0, -HALF + 3) }, { pos = Vector3.new(70, 0, SouthFrontZ(70) - 3) }, { pos = Vector3.new(-70, 0, -70) } }
        for ri, r in ipairs(rubbleList) do Drop(ri ~= 1 and ri - 1 <= CALM.Rubble, function() Wt.Rubble({ r }) end) end -- (the one by the gate goes)
        if CALM.BrokenBoard then Wt.BrokenBoard(Vector3.new(-50, 26, 54), 16, "旅館  冰室", C(214, 200, 170), C(150, 30, 26)) end
    end

    -- ===== UPDATE 4 STREET LIFE (owner: the hub "looks a bit worse than all of the new biomes"): the bare paving got
    -- cracks, oil stains, worn crossings in front of the gates, painted road text and gutter grates (Decals: they take the
    -- scene light like the street), and the empty ~70 studs from the spawn to the gates got three dressed islands -- a
    -- newspaper kiosk between the two gate paths, benches + planters + bollards either side -- each under a sodium lamp
    -- whose amber pool is SELF-LIT (no Light object: the hub's light budget). The walking lines spawn -> plinth -> gates and
    -- the ways into the shops stay clear. Own rng stream (the approved draws above are untouched).
    do
        local rg = Random.new(6060)
        local function Flat(name: string, img: string, cf: CFrame, w: number, l: number, col: Color3?, t: number?)
            if img == "rbxassetid://0" then return end
            local fp = Q({ Name = name, Size = Vector3.new(w, 0.05, l), CFrame = cf, Transparency = 1, CanCollide = false })
            fp.CanQuery, fp.CanTouch = false, false
            local dcl = Instance.new("Decal"); dcl.Face = Enum.NormalId.Top; dcl.Texture = img; dcl.Transparency = t or 0
            if col then dcl.Color3 = col end
            dcl.Parent = fp
        end
        for ci = 1, 9 do
            local x, z = rg:NextNumber(-38, 38), rg:NextNumber(-62, 62)
            local sz = rg:NextNumber(9, 16)
            local rot = rg:NextNumber(0, 6.28)
            if ci <= CALM.Cracks then Flat("Cracks", HubCity.IMG.Cracks, CFrame.new(x, F + 0.02, z) * CFrame.Angles(0, rot, 0), sz, sz, nil, 0.15) end
        end
        for oi = 1, 7 do
            local x, z = rg:NextNumber(-36, 36), rg:NextNumber(-60, 60)
            local sz = rg:NextNumber(3, 6)
            local rot, ln = rg:NextNumber(0, 6.28), rg:NextNumber(0.7, 1.2)
            if oi <= CALM.OilStains then Flat("OilStain", HubCity.IMG.Stain, CFrame.new(x, F + 0.025, z) * CFrame.Angles(0, rot, 0), sz, sz * ln, nil, 0.25) end
        end
        for _, gx in ipairs({ -38, 38 }) do -- worn crossings in front of the gates
            Flat("Zebra", HubCity.IMG.Zebra, CFrame.new(gx, F + 0.03, -52) * CFrame.Angles(0, math.rad(90), 0), 7, 22, nil, 0.1)
        end
        Flat("RoadText", HubCity.IMG.Slow, CFrame.new(-14, F + 0.03, 48) * CFrame.Angles(0, math.rad(180), 0), 9, 4.5, nil, 0.15)
        Flat("RoadText", HubCity.IMG.Slow, CFrame.new(14, F + 0.03, -44), 9, 4.5, nil, 0.15)
        for _, sx in ipairs({ -1, 1 }) do
            for z = -52, 52, 26 do
                Flat("Drain", HubCity.IMG.Drain, CFrame.new(sx * 40.3, F + 0.03, z + 6), 1.6, 3.2, nil, 0)
            end
        end
        local AMBER = C(255, 170, 80)
        -- (HUB LOOK 2026-10-24, owner: "scuffed and unprofessional"): the street furniture was raw primitives -- a square
        -- stick with a glowing yellow BOX for a lamp, toy-yellow bollards, ball shrubs, benches on solid slabs -- and every
        -- copy identical. Now: a round pole on a base collar, a dark luminaire with only its lens lit; dark steel bollards;
        -- clipped hedges in the planters; slatted benches on two frames. Each copy takes its own height / yaw / tint
        -- (rngVar). Parts: lamp 3 -> 5, bench 4 -> 5, the rest unchanged.
        local function Lamp(pos: Vector3)
            local h = rngVar:NextNumber(12.4, 13.4)
            local turn = CFrame.new(pos) * CFrame.Angles(0, math.rad(rngVar:NextNumber(-25, 25)), 0)
            local steel = C(38, 39, 42):Lerp(C(52, 50, 46), rngVar:NextNumber())
            Q({ Name = "LampBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.95, 0.95), CFrame = turn * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = steel, Material = M.Metal })
            Q({ Name = "LampPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.42, 0.42), CFrame = turn * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = steel, Material = M.Metal })
            Q({ Name = "LampArm", Size = Vector3.new(0.26, 0.26, 2.8), CFrame = turn * CFrame.new(0, h - 0.15, -1.25) * CFrame.Angles(math.rad(-6), 0, 0), Color = steel, Material = M.Metal, CanCollide = false })
            Q({ Name = "LampHead", Size = Vector3.new(1.1, 0.42, 1.9), CFrame = turn * CFrame.new(0, h - 0.32, -2.75), Color = C(30, 30, 33), Material = M.Metal, CanCollide = false })
            local lensCf = turn * CFrame.new(0, h - 0.56, -2.75)
            Q({ Name = "Sodium", Size = Vector3.new(0.8, 0.08, 1.5), CFrame = lensCf, Color = C(226, 150, 72):Lerp(C(236, 186, 130), rngVar:NextNumber(0, 0.35)), Material = M.Neon, CanCollide = false }) -- (a touch under full amber: the lens blooms instead of reading as a lit box)
            HubCity.WetGlow(Q, CFrame.new(lensCf.Position.X, pos.Y + 0.03, lensCf.Position.Z), 13, 13, AMBER, 0.62)
        end
        local function Island(cx: number, cz: number, w: number, d: number)
            Q({ Name = "IslandKerb", Size = Vector3.new(w + 0.6, 0.3, d + 0.6), Position = Vector3.new(cx, F + 0.15, cz), Color = C(70, 66, 72), Material = M.Concrete, CanQuery = true, CanCollide = true })
            local isl = Q({ Name = "Island", Size = Vector3.new(w, 0.32, d), Position = Vector3.new(cx, F + 0.16, cz), Color = C(96, 92, 98), Material = M.Pavement, CanQuery = true, CanCollide = true })
            if MaterialService:FindFirstChild("HubPaving") then isl.MaterialVariant = "HubPaving"; isl.Color = C(150, 144, 148) end -- (the sidewalks' pavers, not plain plastic)
        end
        -- two bench MODELS (HUB LOOK, owner: "add new models too on top of simply duplicating"): "Slat" = two wooden seat
        -- slats + a back slat on open cast frames (the islands); "Block" = a cast-concrete block with a wooden top, no back
        -- (by the spawn) -- 5 / 2 parts
        local function Bench(cf: CFrame, style: string?)
            cf = cf * CFrame.Angles(0, math.rad(rngVar:NextNumber(-5, 5)), 0)
            local wood = C(110, 74, 46):Lerp(C(84, 62, 44), rngVar:NextNumber())
            if style == "Block" then
                local bw = rngVar:NextNumber(4.6, 6)
                Q({ Name = "BenchBlock", Size = Vector3.new(bw, 1.45, 1.7), CFrame = cf * CFrame.new(0, 0.725, 0), Color = C(92, 88, 84):Lerp(C(78, 76, 76), rngVar:NextNumber()), Material = M.Concrete, CanCollide = true, CanQuery = true })
                Q({ Name = "BenchSeat", Size = Vector3.new(bw + 0.3, 0.26, 1.9), CFrame = cf * CFrame.new(0, 1.58, 0), Color = wood, Material = M.WoodPlanks, CanCollide = true, CanQuery = true })
                return
            end
            local iron = C(30, 30, 32):Lerp(C(46, 40, 34), rngVar:NextNumber())
            for _, sz in ipairs({ -0.38, 0.38 }) do
                Q({ Name = "BenchSeat", Size = Vector3.new(5, 0.22, 0.62), CFrame = cf * CFrame.new(0, 1.72, sz), Color = wood, Material = M.WoodPlanks, CanCollide = true, CanQuery = true })
            end
            Q({ Name = "BenchBack", Size = Vector3.new(5, 0.7, 0.18), CFrame = cf * CFrame.new(0, 2.75, 0.68) * CFrame.Angles(math.rad(-12), 0, 0), Color = wood, Material = M.WoodPlanks })
            for _, bx in ipairs({ -2.05, 2.05 }) do -- (an open cast frame: the seat rests on it, the back post rises from it)
                Q({ Name = "BenchLeg", Size = Vector3.new(0.22, 2.9, 0.22), CFrame = cf * CFrame.new(bx, 1.45, 0.45) * CFrame.Angles(math.rad(-8), 0, 0), Color = iron, Material = M.Metal })
            end
        end
        -- two planter MODELS: a square concrete box with a clipped hedge, a round concrete tub with a low rounded shrub
        local function Planter(pos: Vector3, s: number, style: string?)
            local stone = C(84, 80, 76):Lerp(C(96, 90, 82), rngVar:NextNumber())
            local leaf = C(46, 74, 44):Lerp(C(62, 84, 48), rngVar:NextNumber())
            if style == "Round" then
                local d = 2.9 * s
                Q({ Name = "PlanterTub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, d, d), CFrame = CFrame.new(pos + Vector3.new(0, 0.65, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = stone, Material = M.Concrete, CanCollide = true, CanQuery = true })
                local hh = rngVar:NextNumber(1.6, 2.2) * s
                Q({ Name = "Shrub", Shape = Enum.PartType.Ball, Size = Vector3.new(d * 0.86, hh, d * 0.86), CFrame = CFrame.new(pos + Vector3.new(0, 1.3 + hh * 0.3, 0)), Color = leaf, Material = M.LeafyGrass, CanCollide = false })
                return
            end
            Q({ Name = "PlanterBox", Size = Vector3.new(2.6 * s, 1.6, 2.6 * s), Position = pos + Vector3.new(0, 0.8, 0), Color = stone, Material = M.Concrete, CanCollide = true, CanQuery = true })
            local hh = rngVar:NextNumber(1.1, 1.8) * s
            Q({ Name = "Shrub", Size = Vector3.new(2.3 * s, hh, 2.3 * s), CFrame = CFrame.new(pos + Vector3.new(0, 1.6 + hh / 2 - 0.1, 0)) * CFrame.Angles(0, math.rad(rngVar:NextNumber(-4, 4)), 0),
                Color = leaf, Material = M.LeafyGrass, CanCollide = false })
        end
        local function Bollard(pos: Vector3)
            local bh = rngVar:NextNumber(2.0, 2.4)
            Q({ Name = "Bollard", Shape = Enum.PartType.Cylinder, Size = Vector3.new(bh, 0.62, 0.62), CFrame = CFrame.new(pos + Vector3.new(0, bh / 2, 0)) * CFrame.Angles(math.rad(rngVar:NextNumber(-2, 2)), 0, math.rad(90)),
                Color = C(46, 47, 50):Lerp(C(58, 54, 46), rngVar:NextNumber()), Material = M.Metal, CanCollide = true })
        end
        local IY = F + 0.32
        -- the kiosk island between the two gate paths (they pass x +-27 at z -40)
        Island(0, -40, 14, 7)
        do
            local kcf = CFrame.lookAt(Vector3.new(3, IY, -40), Vector3.new(3, IY, 0))
            Q({ Name = "Kiosk", Size = Vector3.new(5, 6.4, 3.4), CFrame = kcf * CFrame.new(0, 3.2, 0), Color = C(46, 92, 70), Material = M.Metal, CanCollide = true, CanQuery = true })
            Q({ Name = "KioskRoof", Size = Vector3.new(6, 0.4, 4.6), CFrame = kcf * CFrame.new(0, 6.6, -0.4), Color = C(30, 60, 46), Material = M.Metal })
            local shelf = Q({ Name = "KioskGoods", Size = Vector3.new(4.4, 2.2, 0.05), CFrame = kcf * CFrame.new(0, 3.4, -1.74), Transparency = 1, CanCollide = false })
            HubCity.Img(shelf, Enum.NormalId.Front, HubCity.IMG.Goods[2])
            local ks = Q({ Name = "KioskSign", Size = Vector3.new(5.2, 1.2, 0.3), CFrame = kcf * CFrame.new(0, 5.6, -1.86), Color = C(14, 12, 16), Material = M.Metal, CanCollide = false })
            Text(ks, Enum.NormalId.Front, "報紙  雜誌", NEON.Amber, { PPS = 20, Brightness = 2, Stroke = C(10, 6, 8), StrokeT = 0.4 })
            if CALM.KioskNeon then Q({ Name = "KioskNeon", Size = Vector3.new(5.4, 0.18, 0.18), CFrame = kcf * CFrame.new(0, 4.95, -1.86), Color = NEON.Amber, Material = M.Neon, CanCollide = false }) end
            Planter(Vector3.new(-4.5, IY, -41), 0.9, "Round")
            Bollard(Vector3.new(-6.4, IY, -37.2)); Bollard(Vector3.new(6.4, IY, -37.2))
            Lamp(Vector3.new(-1.5, IY, -37.6))
        end
        -- bench islands either side of the plinth (off the spawn -> gate lines, which pass x +-13 at z -8)
        for _, sx in ipairs({ -1, 1 }) do
            Island(sx * 27, -2, 8, 6)
            Bench(CFrame.lookAt(Vector3.new(sx * 27, IY, -3), Vector3.new(sx * 27, IY, 20)))
            Planter(Vector3.new(sx * 30, IY, 0.4), 0.8, (sx < 0) and "Round" or "Box")
            Bollard(Vector3.new(sx * 23.4, IY, -4.4)); Bollard(Vector3.new(sx * 23.4, IY, 0.4))
            Lamp(Vector3.new(sx * 24.5, IY, 0.3))
            -- benches by the spawn, facing the plaza
            Bench(CFrame.lookAt(Vector3.new(sx * 15, F, 38), Vector3.new(sx * 15, F, 0)), "Block")
            Planter(Vector3.new(sx * 19.5, F, 38), 0.7)
        end
    end

    -- ===== THE PLAZA CENTRE (UPDATE 4: was a plain cyan kiosk on a flat planter): a stepped concrete plinth with a steel
    -- lip and a neon ring, a hologram PROJECTOR on it (finned steel housing, lens barrel, glowing lens) whose beam rises to
    -- the Centerpiece rings above (HubGenerator's, turned by the client round y 36) -- the rings read as its projection.
    -- Beams + one emitter, no new lights (the ring core's light covers it); the motes thin on the Low setting.
    local CS = game:GetService("CollectionService")
    -- (the projector skips the PLAZA_DIM pass -- NoDim -- or the steel went black against the dimmed street)
    local STEEL, STEEL2, FIN = C(84, 88, 98), C(50, 52, 60), C(104, 108, 118)
    local function Cyl(name, d, h, y, col, mat, extra)
        local props = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = CFrame.new(0, F + y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = col, Material = mat, CanCollide = false }
        for k, v in pairs(extra or {}) do props[k] = v end
        return Q(props)
    end
    Cyl("PlinthStep", 16, 0.5, 0.25, C(70, 68, 66), M.Concrete, { CanCollide = true, CanQuery = true })
    Cyl("Plinth", 12.6, 1.5, 1.25, C(84, 80, 76), M.Concrete, { CanCollide = true, CanQuery = true })
    Cyl("PlinthLip", 13.3, 0.3, 2.15, STEEL, M.Metal)
    Cyl("PlinthNeon", 12.9, 0.14, 1.85, NEON.Cyan, M.Neon)
    -- the projector: a finned base, the housing ("Waypoint": the old kiosk's name), the lens barrel, a glowing rim + lens
    local proj = {}
    table.insert(proj, Cyl("ProjectorBase", 6, 0.6, 2.6, STEEL2, M.Metal))
    local housing = Cyl("Waypoint", 4.6, 1.8, 3.8, STEEL, M.Metal, { CanCollide = true, CanQuery = true })
    table.insert(proj, housing)
    for k = 0, 11 do
        local a = k / 12 * math.pi * 2
        table.insert(proj, Q({ Name = "ProjectorFin", Size = Vector3.new(0.18, 1.5, 1.0), CFrame = CFrame.new(0, F + 3.7, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.6), Color = FIN, Material = M.Metal, CanCollide = false }))
    end
    Cyl("ProjectorBand", 4.75, 0.22, 4.25, NEON.Cyan, M.Neon)
    table.insert(proj, Cyl("LensBarrel", 3.2, 1.0, 5.2, STEEL2, M.Metal))
    Cyl("LensRim", 3.5, 0.25, 5.8, NEON.Cyan, M.Neon, { Transparency = 0.2 })
    local lens = Cyl("Lens", 2.7, 0.12, 5.9, C(170, 250, 255), M.Neon)
    for _, pp in ipairs(proj) do pp:SetAttribute("NoDim", true) end
    -- (HUB LOOK v2 2026-10-24, owner: "plaza floor structure ... subtle, no clutter"): the three diamond-plate cable covers
    -- (they read as planks lying on the street) -> a square BAND of the sidewalks' pavers framing the plinth, flush with
    -- the asphalt, so the centre reads as a designed square; two gutter grates at its corners take the run-off
    do
        local IN, BW = 11, 2.4
        local OUT = IN + BW
        for _, b in ipairs({ { 0, -(IN + BW / 2), OUT * 2, BW }, { 0, IN + BW / 2, OUT * 2, BW }, { -(IN + BW / 2), 0, BW, IN * 2 }, { IN + BW / 2, 0, BW, IN * 2 } }) do
            local band = Q({ Name = "PlazaBand", Size = Vector3.new(b[3], 0.12, b[4]), Position = Vector3.new(b[1], F - 0.02, b[2]), Color = C(150, 144, 150), Material = M.Pavement, CanCollide = false })
            if MaterialService:FindFirstChild("HubPaving") then band.MaterialVariant = "HubPaving" end
        end
        if HubCity.IMG.Drain ~= "rbxassetid://0" then
            for _, sx in ipairs({ -1, 1 }) do
                local dp = Q({ Name = "Drain", Size = Vector3.new(1.6, 0.05, 3.2), CFrame = CFrame.new(sx * (OUT + 0.9), F + 0.03, -OUT + 1.6), Transparency = 1, CanCollide = false })
                dp.CanTouch = false
                local dcl = Instance.new("Decal"); dcl.Face = Enum.NormalId.Top; dcl.Texture = HubCity.IMG.Drain; dcl.Parent = dp
            end
        end
    end
    -- the beam: lens -> the rings' centre (a wide soft cone + a thin bright core), scrolling scanlines
    local top = P(city, { Name = "HoloTop", Size = Vector3.new(0.2, 0.2, 0.2), Position = Vector3.new(0, 36, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
    local a0 = Instance.new("Attachment"); a0.Name = "Beam0"; a0.Position = Vector3.new(0.1, 0, 0); a0.Parent = lens -- (the lens is a cylinder on its side: local +X = up)
    local a1 = Instance.new("Attachment"); a1.Name = "Beam1"; a1.Parent = top
    local function HoloBeam(name, w0, w1, t0, t1, col, speed)
        local b = Instance.new("Beam"); b.Name = name; b.Attachment0 = a0; b.Attachment1 = a1
        b.Width0 = w0; b.Width1 = w1; b.FaceCamera = true; b.Segments = 1
        b.LightEmission = 1; b.LightInfluence = 0; b.Brightness = 1.4
        b.Color = ColorSequence.new(col, col:Lerp(NEON.Pink, 0.35))
        b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(0.75, (t0 + t1) / 2), NumberSequenceKeypoint.new(1, t1) })
        if HubCity.IMG.HoloBeam ~= "rbxassetid://0" then
            b.Texture = HubCity.IMG.HoloBeam; b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 9; b.TextureSpeed = speed
        end
        b.Parent = lens
        return b
    end
    HoloBeam("HoloCone", 2.4, 12.5, 0.55, 0.88, NEON.Cyan, 0.35)
    HoloBeam("HoloCore", 0.5, 1.4, 0.25, 0.7, C(190, 250, 255), 0.9)
    -- data motes drifting up the beam (thinned on Low)
    local motes = Emit(lens, { Color = ColorSequence.new(C(150, 245, 255)), LightEmission = 1, LightInfluence = 0,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 1) }),
        Lifetime = NumberRange.new(4.5, 6), Rate = 7, Speed = NumberRange.new(4.5, 6), SpreadAngle = Vector2.new(9, 9),
        EmissionDirection = Enum.NormalId.Right })
    if motes then CS:AddTag(motes, "QThin") end
    housing.CastShadow = false
    -- (HubGenerator builds the Centerpiece rings; HubCity.TintCenterpiece turns them into a neon hologram)
    -- (HUB DECLUTTER) everything built while dropping goes now
    for _, d in ipairs(trash) do d:Destroy() end
    HubCity.Dropped = #trash
    HubCity.DepthClear(city, depthModels)
end

-- (HUBFIX DEPTH) DepthClear: the depth pieces were planned without knowing the bridges, cables, lamps, lantern strings,
-- street boards and blade signs built round them. Any oriel / balcony stack that would cross one is dropped whole; a
-- facade kit prop (AC unit, cage, meter box) or a lit window it would bury goes instead. Loggias + setbacks stay (they
-- are the block itself) -- the plan keeps them clear of the bridge. Counts on the city folder: DepthKept / DepthDropped.
local DEPTH_SKIP = { Block = true, Ledge = true, Parapet = true, Pipe = true, Street = true, Sidewalk = true, Curb = true, CurbPaint = true, Gutter = true }
local function BoxesTouch(a: BasePart, b: BasePart, pad: number): boolean
    local function Into(p: BasePart, q: BasePart): boolean -- p's 8 corners seen in q's frame, vs q's box
        local h = p.Size / 2
        local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
        for ix = -1, 1, 2 do for iy = -1, 1, 2 do for iz = -1, 1, 2 do
            local v = q.CFrame:PointToObjectSpace((p.CFrame * CFrame.new(h.X * ix, h.Y * iy, h.Z * iz)).Position)
            lo = lo:Min(v); hi = hi:Max(v)
        end end end
        local e = q.Size / 2 - Vector3.new(pad, pad, pad)
        return lo.X < e.X and hi.X > -e.X and lo.Y < e.Y and hi.Y > -e.Y and lo.Z < e.Z and hi.Z > -e.Z
    end
    return Into(a, b) and Into(b, a)
end
function HubCity.DepthClear(city: Instance, models: { Model })
    local mine = {}
    for _, m in ipairs(models) do for _, p in ipairs(m:GetDescendants()) do mine[p] = true end end
    local others = {}
    for _, d in ipairs(city:GetDescendants()) do
        if d:IsA("BasePart") and not mine[d] and not DEPTH_SKIP[d.Name] and d.Transparency < 0.98 then table.insert(others, d) end
    end
    local kept, dropped, cleared = 0, 0, 0
    for _, m in ipairs(models) do
        if m.Name == "DepthOriel" or m.Name == "DepthBalcony" or m.Name == "DepthBand" then
            local bad = false
            for _, p in ipairs(m:GetChildren()) do
                if p:IsA("BasePart") then
                    for _, o in ipairs(others) do
                        if o.Parent and (o.Position - p.Position).Magnitude < (o.Size.Magnitude + p.Size.Magnitude) / 2 and BoxesTouch(p, o, 0.05) then
                            local kit = o:FindFirstAncestorOfClass("Model")
                            if kit and kit ~= city and HubCity.FACADE_PROPS[kit.Name] then kit:Destroy(); cleared += 1
                            elseif o.Name == "LitWindow" then o:Destroy(); cleared += 1
                            else bad = true; break end
                        end
                    end
                end
                if bad then break end
            end
            if bad then m:Destroy(); dropped += 1 else kept += 1 end
        else
            kept += 1
        end
    end
    city:SetAttribute("DepthKept", kept); city:SetAttribute("DepthDropped", dropped); city:SetAttribute("DepthPropsCleared", cleared)
end

-- ===================================================================================== the Training Grounds
-- (owner 2026-10-05: "Fix the training ground" -- it was still the frontier keep's firing yard: stone walls, wood fences,
-- braziers, seen through the hub's south doorway.) A walled-city back lot: tower blocks close in on three sides, the
-- backs of the hub's south row on the fourth, a big neon range sign on the back row (lined up with the doorway), sodium
-- lamps on the firing line, red lanterns over it, cables high up. HubGenerator still builds the bays / pads / DPS dummy /
-- colliders (same contract for RangeClient); this is only the dressing. Everything is CanQuery false except the blocks
-- (shots pass through the dressing), and it all sits above the bots' box (y 5-26) or behind the walls.
-- HubCity.Range(tg, H, R) -- tg = the TrainingGrounds folder, H = HubGenerator's helpers, R = HubGenerator.RANGE.
HubCity.WINDOW_GRID = "rbxassetid://125253926384764" -- (tools/make_city_art.py -> art/ui/city/window_grid.png, uploaded)
function HubCity.Range(tg: Folder, H: any, R: any)
    local rv = Random.new(2411) -- (HUB LOOK 2026-10-24: per-instance variation on its own stream; the yard's draws stay in order)
    local P, Light = H.P, H.Light
    local G = HubCity.GROUND
    local W = R.HalfX
    local rng = Random.new(7741)
    local rangeFac = Random.new(8812) -- (UPDATE 4: which facade tile a range block wears)
    local rangeRel = Random.new(9393) -- (UPDATE 4 DEPTH: range setbacks + kit relief)
    local RHAS_AC, RHAS_CAGE = EnvKit.Has("City", "ACUnit"), EnvKit.Has("City", "BalconyCage")
    local bladeN = 0 -- (RANGE REDO: blade signs counted, every 3rd built)
    local function Q(props)
        props.CanQuery = props.CanQuery == true
        local p = P(tg, props)
        p.CastShadow = false
        return p
    end

    -- ===== THE BLOCKS: a lighter Facade (fewer floors of detail: the yard is seen from far off) =====
    -- PART BUDGET: the window bands are ONE Texture per block (tools/make_city_art.py window_grid: a 10-stud floor tile,
    -- band 2.9-7.1 studs from the tile top) instead of a part per floor; heights snap to 21.5 + 10n so the bands line up
    -- with the lit windows (G + y + 2.4). First version was 1,029 range parts -> this one ~640.
    local function Row(origin: Vector3, along: Vector3, inward: Vector3, length: number, hMin: number, hMax: number, dMin: number, dMax: number)
        local yaw = math.atan2(-inward.X, -inward.Z)
        local t = -length / 2
        while t < length / 2 - 2 do
            local w = math.min(rng:NextNumber(16, 28), length / 2 - t)
            local c = t + w / 2
            local hgt = 21.5 + 10 * math.floor((rng:NextNumber(hMin, hMax) - 21.5) / 10 + 0.5)
            local depth = rng:NextNumber(dMin, dMax)
            local col = GRIME[rng:NextInteger(1, #GRIME)]
            if rng:NextNumber() < 0.3 then col = PAINT[rng:NextInteger(1, #PAINT)]:Lerp(col, 0.4) end
            local mat = ({ M.Concrete, M.Concrete, M.Slate, M.Brick, M.Plaster })[rng:NextInteger(1, 5)]
            local recess = (rangeRel:NextNumber() < 0.55) and rangeRel:NextNumber(0.8, 3.2) or 0 -- (UPDATE 4 DEPTH: setbacks)
            local cf = CFrame.new(origin + along * c - inward * (depth / 2 + recess)) * CFrame.Angles(0, yaw, 0) -- (local -Z faces the yard)
            local front = depth / 2
            -- (UPDATE 4: the city's facade tiles above the shop level, like the hub's blocks; the window grid is gone)
            Q({ Name = "Block", Size = Vector3.new(w + 0.2, FACADE_FLOOR0 + 1, depth), CFrame = cf * CFrame.new(0, G + (FACADE_FLOOR0 - 1) / 2, 0), Color = col, Material = mat, CanQuery = true })
            -- (UPDATE 4 DEPTH: the top snapped UP to the tile's floor line so the relief variant lines up)
            local top = FACADE_FLOOR0 + 10 * math.ceil((hgt + 1 - FACADE_FLOOR0) / 10)
            FacadeTex(Q({ Name = "Block", Size = Vector3.new(w + 0.2, top - FACADE_FLOOR0, depth), CFrame = cf * CFrame.new(0, G + (FACADE_FLOOR0 + top) / 2, 0), Color = col, Material = mat, CanQuery = true }),
                rangeFac:NextInteger(1, #HubCity.FACADES), G + top, w + 0.2, G, FACES_SIDES)
            local front0 = depth / 2
            for _, fy in ipairs({ 16, 26 }) do -- (UPDATE 4 DEPTH: kit AC units + cages on the two lower floors, in the bays)
                if fy + 10 <= top then
                    if RHAS_AC and rangeRel:NextNumber() < 0.55 then
                        local bx = FacadeBayX(rangeRel:NextNumber(-w / 2 + 3, w / 2 - 3), w + 0.2)
                        if bx then EnvKit.Place("City", "ACUnit", cf * CFrame.new(bx, G + fy + 1.0, -front0 - 0.6), { Parent = tg, Scale = 1.1 * rv:NextNumber(0.88, 1.12), Tint = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(150, 140, 128), rv:NextNumber()), Shadow = false }) end
                    end
                    if RHAS_CAGE and rangeRel:NextNumber() < 0.3 then
                        local bx = FacadeBayX(rangeRel:NextNumber(-w / 2 + 4, w / 2 - 4), w + 0.2)
                        if bx then EnvKit.Place("City", "BalconyCage", cf * CFrame.new(bx, G + fy + 2.6, -front0 - 1.7), { Parent = tg, Scale = 1.7 * rv:NextNumber(0.92, 1.08), Tint = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(140, 130, 120), rv:NextNumber()), Shadow = false }) end
                    end
                end
            end
            local _ = rng:NextNumber(0, 10) -- (was the window grid's offset draw)
            -- street level: a rolled-down shutter now and then
            if rng:NextNumber() < 0.5 then
                local sw = math.min(w - 4, rng:NextNumber(8, 14))
                Q({ Name = "Shutter", Size = Vector3.new(sw, 8, 0.2), CFrame = cf * CFrame.new(rng:NextNumber(-w / 2 + sw / 2 + 1, w / 2 - sw / 2 - 1), G + 4, -front - 0.1),
                    Color = C(96, 92, 86):Lerp(col, 0.3), Material = M.CorrodedMetal, CanCollide = false })
            end
            -- floors (the bands are the texture): the odd lit room, AC units, a rare barred balcony
            for y = 14, hgt - 6, 10 do
                if rng:NextNumber() < 0.3 then -- (UPDATE 4: lit rooms snapped into the facade tiles' window bays)
                    local roll = rng:NextNumber()
                    local lc = (roll < 0.75) and C(214, 150, 84) or ((roll < 0.9) and C(110, 150, 196) or NEON_LIST[rng:NextInteger(1, #NEON_LIST)])
                    local _ = rng:NextNumber(1.8, 3)
                    local lx = FacadeBayX(rng:NextNumber(-w / 2 + 3, w / 2 - 3), w + 0.2)
                    if lx and y + 12 <= hgt then
                        Q({ Name = "LitWindow", Size = Vector3.new(FACADE_WIN_W, FACADE_WIN_H, 0.12), CFrame = cf * CFrame.new(lx, G + y + 2 + FACADE_WIN_MID, -front - 0.06),
                            Color = lc, Material = M.Neon, Transparency = 0.55, CanCollide = false })
                    end
                end
                if rng:NextNumber() < 0.2 then local _ = rng:NextNumber(-w / 2 + 2, w / 2 - 2) end -- (was an AC part: the tiles have them)
                if rng:NextNumber() < 0.06 then -- (was a balcony: draws kept)
                    local bw = math.min(w - 3, rng:NextNumber(5, 9))
                    local _ = rng:NextNumber(-w / 2 + bw / 2 + 1, w / 2 - bw / 2 - 1)
                end
            end
            -- a rust streak or a drain pipe down the corner
            local sh = rng:NextNumber(14, 34)
            if rng:NextNumber() < 0.5 then local _ = { rng:NextNumber(1, 3.5), rng:NextNumber(-w / 2 + 1.5, w / 2 - 1.5), rng:NextInteger(1, 3) } -- (was a stain part: the tiles carry the grime)
            else Q({ Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(hgt - 4, 0.7, 0.7), CFrame = cf * CFrame.new(w / 2 - 0.8, G + hgt / 2, -front - 0.5) * CFrame.Angles(0, 0, math.rad(90)),
                Color = C(70, 64, 58), Material = M.Metal, CanCollide = false }) end
            -- a neon blade sign up high (above the bots' box)
            -- (RANGE REDO 2026-10-24, owner: the range is "full neon": only every 3rd blade sign is built; the draws stay in order)
            if rng:NextNumber() < 0.35 and hgt > 44 then
                local bh = rng:NextNumber(9, 14)
                local ncol = NEON_LIST[rng:NextInteger(1, #NEON_LIST)]
                local bx, by = rng:NextNumber(-w / 2 + 2, w / 2 - 2), rng:NextNumber(32, 40)
                local wordIdx = rng:NextInteger(1, #SIGNS)
                bladeN += 1
                if bladeN % 3 == 1 then
                local blade = Q({ Name = "BladeSign", Size = Vector3.new(0.6, bh, 3.2), CFrame = cf * CFrame.new(bx, G + by, -front - 2.2), Color = C(16, 14, 18), Material = M.Metal, CanCollide = false })
                HubCity.BladeFrame(Q, blade, 2.2)
                local word = Vertical(SIGNS[wordIdx])
                for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
                    Text(blade, face, word, ncol, { PPS = 20, Brightness = 3, Stroke = ncol, StrokeT = 0.6 })
                end
                for _, z in ipairs({ 1.7, -1.7 }) do
                    Q({ Name = "BladeNeon", Size = Vector3.new(0.7, bh + 0.4, 0.25), CFrame = blade.CFrame * CFrame.new(0, 0, z), Color = ncol, Material = M.Neon, CanCollide = false })
                end
                end
            end
            t += w
        end
    end
    local midZ = (R.Z0 + R.Z1) / 2
    local depthZ = R.Z1 - R.Z0
    local before = {}
    for _, d in ipairs(tg:GetDescendants()) do before[d] = true end
    Row(Vector3.new(0, 0, R.Z1), -Vector3.xAxis, -Vector3.zAxis, W * 2 + 8, 58, 100, 16, 28)            -- back (seen from the hub doorway)
    Row(Vector3.new(W, 0, midZ), Vector3.zAxis, -Vector3.xAxis, depthZ + 6, 40, 70, 12, 20)              -- east
    Row(Vector3.new(-W, 0, midZ), -Vector3.zAxis, Vector3.xAxis, depthZ + 6, 40, 70, 12, 20)             -- west
    local nIn = H.FLOOR_HALF + 2 -- (the hub's own south row covers |x| < 78)
    local nLen = W - nIn
    for _, s in ipairs({ -1, 1 }) do
        Row(Vector3.new(s * (nIn + nLen / 2), 0, R.Z0 + 3), Vector3.xAxis * s, Vector3.zAxis, nLen, 34, 56, 10, 16) -- north, either side of the hub
    end

    -- (UPDATE 4 NIGHT: the yard's tower blocks get the city's darker surfaces -- only what the Rows just built (blocks,
    -- shutters, pipes, the kit relief); bay furniture, pads, the dummy and every sign keep their colours)
    do
        local k = HubCity.PLAZA_DIM
        local function Dim(c: Color3): Color3 return Color3.new(c.R * k, c.G * k, c.B * k) end
        for _, d in ipairs(tg:GetDescendants()) do
            if not before[d] then
                if d:IsA("BasePart") and d.Material ~= M.Neon and d.Transparency < 1 then d.Color = Dim(d.Color)
                elseif d:IsA("Texture") or d:IsA("Decal") then d.Color3 = Dim(d.Color3)
                elseif d:IsA("SurfaceAppearance") then pcall(function() d.Color = Dim(d.Color) end) end
            end
        end
    end

    -- ===== the backs of the hub's south row (|x| < 76, facing the yard): the doorway's range side =====
    local backZ = H.FLOOR_HALF + 4.2 -- (the hub's thin south blocks end at z 79)
    for _ = 1, 6 do local _ = { rng:NextNumber(12, 30), rng:NextNumber(-3, 3), rng:NextNumber(-4, 4) } end -- (UPDATE 4: was a few AC
    -- parts + lit windows on a blank wall; the south row is a real 10-deep block now with windows, relief and lit rooms on
    -- this side -- HubCity.Build. Draws kept so the rest of the yard comes out the same)
    -- (RANGE REDO 2026-10-24: painted signs, not neon -- warm white letters on dark steel, lit by the scene)
    local over = Q({ Name = "RangeDoorSign", Size = Vector3.new(26, 6, 0.6), Position = Vector3.new(0, G + 33, backZ + 0.3), Color = C(30, 30, 33), Material = M.Metal })
    Text(over, Enum.NormalId.Back, "返回城寨", C(236, 226, 206), { PPS = 18, Sub = "BACK TO THE CITY", SubColor = C(190, 186, 178), Brightness = 1.1, Lit = true, Stroke = C(10, 8, 8), StrokeT = 0.5 })
    -- (no neon round this side of the doorway: the hub's green frame already shows through and two frames read as a mess)

    -- ===== the big range sign on the back row, straight through the hub's doorway =====
    -- (RANGE REDO: a painted steel sign under two gooseneck lamps; the green neon bars are gone)
    local big = Q({ Name = "RangeSign", Size = Vector3.new(46, 13, 1), Position = Vector3.new(0, G + 54, R.Z1 - 0.8), Color = C(34, 36, 38), Material = M.Metal })
    Text(big, Enum.NormalId.Front, "訓練場", C(240, 228, 204), { PPS = 16, Sub = "TRAINING GROUNDS  •  13 BAYS  •  DPS TEST", SubColor = C(214, 168, 72), Brightness = 1.25, Lit = true, Stroke = C(10, 8, 8), StrokeT = 0.45 })
    for _, sx in ipairs({ -1, 1 }) do
        local base = Vector3.new(sx * 15, G + 61.2, R.Z1 - 1.4)
        Q({ Name = "SignLampArm", Size = Vector3.new(0.25, 0.25, 2.6), CFrame = CFrame.new(base + Vector3.new(0, 0.2, -1.2)), Color = C(30, 30, 32), Material = M.Metal })
        Q({ Name = "SignLamp", Size = Vector3.new(1.6, 0.5, 0.9), CFrame = CFrame.new(base + Vector3.new(0, 0, -2.5)) * CFrame.Angles(math.rad(-25), 0, 0), Color = C(28, 28, 30), Material = M.Metal })
        Q({ Name = "SignLampLens", Size = Vector3.new(1.3, 0.06, 0.6), CFrame = CFrame.new(base + Vector3.new(0, -0.28, -2.45)) * CFrame.Angles(math.rad(-25), 0, 0), Color = C(255, 214, 160), Material = M.Neon })
    end

    -- ===== the firing line: the old sodium pole lamps + red paper lantern strings are gone (the firing shed lights it:
    -- HubCity.RangeShed). Their draws were on rv / lanternVar only: nothing after them moves.
    -- cables strung high over the bays (well above the bots' box) -- every other one built (draws kept)
    for ci = 1, 12 do
        local x = rng:NextNumber(-W + 10, W - 10)
        local a = Vector3.new(x, G + rng:NextNumber(46, 62), R.Z0 + 4)
        local b = Vector3.new(x + rng:NextNumber(-40, 40), G + rng:NextNumber(46, 62), R.Z1)
        local mid = (a + b) / 2 - Vector3.new(0, rng:NextNumber(3, 7), 0)
        for _, seg in ipairs(ci % 2 == 0 and { { a, mid }, { mid, b } } or {}) do
            Q({ Name = "Cable", Size = Vector3.new(0.14, 0.14, (seg[2] - seg[1]).Magnitude), CFrame = CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), Color = C(16, 16, 18), Material = M.SmoothPlastic, CanCollide = false })
        end
    end
    -- (the coloured wet patches on the firing strip are gone; their draws are kept so the weathering stays where it was)
    for _ = 1, 8 do
        local _ = { rng:NextNumber(5, 14), rng:NextNumber(3, 7), rng:NextNumber(-W + 10, W - 10), rng:NextNumber(R.Z0 + 4, R.LineZ - 3), rng:NextNumber(0, 3), rng:NextInteger(1, 3) }
    end
    -- weathering: a pipe bundle along the back row, rust patches, rubble in the corners, a broken board, loose wires
    local Wt = Weathering(Q, rng, G)
    Wt.Conduit(Vector3.new(-W + 2, 0, R.Z1 - 0.2), Vector3.new(W - 2, 0, R.Z1 - 0.2), G + 12, -Vector3.zAxis)
    local patches = {}
    for _, x in ipairs({ -128, -70, -18, 40, 96, 140 }) do
        table.insert(patches, { pos = Vector3.new(x + rng:NextNumber(-6, 6), G + rng:NextNumber(3.5, 6), R.Z1 - 0.15), yaw = 0, w = rng:NextNumber(5, 8), h = rng:NextNumber(5, 8) })
    end
    for _, z in ipairs({ 140, 205 }) do
        table.insert(patches, { pos = Vector3.new(-W + 0.15, G + 4.5, z), yaw = -90, w = 6, h = 7 })
        table.insert(patches, { pos = Vector3.new(W - 0.15, G + 4.5, z + 12), yaw = 90, w = 7, h = 6 })
    end
    Wt.Patches(patches)
    Wt.Rubble({ { pos = Vector3.new(-W + 4, 0, R.Z1 - 4) }, { pos = Vector3.new(W - 4, 0, R.Z1 - 4) }, { pos = Vector3.new(-W + 4, 0, R.LineZ + 40) } })
    local wires = {}
    for _ = 1, 8 do
        table.insert(wires, { top = Vector3.new(rng:NextNumber(-W + 10, W - 10), G + rng:NextNumber(40, 52), rng:NextNumber(R.LineZ + 30, R.Z1 - 10)), len = rng:NextNumber(4, 9), sway = 10 })
    end
    Wt.Wires(wires) -- (their lowest ends stay above y 30: over the bots' box)
    Wt.BrokenBoard(Vector3.new(-96, G + 34, R.Z1 - 2.5), 14, "五金  車房", C(40, 60, 90), C(240, 230, 210))
end

-- ===================================================================================== THE BACK-LOT RANGE (RANGE REDO)
-- (2026-10-24, owner: "the training range is like full neon which makes no sense at all ... I think we need to redo that
-- entire area"; plan docs/RANGE_REDO_2026-10-24.md). A covered FIRING SHED over the firing strip -- corrugated roof on
-- steel columns, a booth per bay (partitions, a shooting counter, a rubber mat, a stencilled lane plate on the fascia, a
-- tube lamp), a painted firing line, a concrete apron with the lane numbers; downrange packed dirt (terrain), chalk lane
-- lines, two overhead gantries (distance strip + parked steel targets) above the bots' box, a sand backstop berm
-- (terrain, HubGenerator) and a RANGE RULES board by the doorway. NO Light objects: self-lit lenses only (tested
-- in Play: a SpotLight over the DPS booth made the GUN darker + bluer -- GearLight counts a near lamp as light on the gear,
-- a downward spot barely reaches it: grey plate 53,57,66 with the lamp, 63,66,71 without, 71,72,74 at the doorway). HubGenerator builds the pads / dummy / colliders (RangeClient's contract, unchanged);
-- this is dressing: CanQuery false, CastShadow false (sky light + GearLight's sky sense see through it, like before).
-- HubCity.RangeShed(tg, H, R, bayCol, bayText) -- after the bays; bayCol / bayText = HubGenerator's BAY_COLORS / BAY_TEXT.
HubCity.SHED = { Back = 79.2, Front = 101.2, Height = 17, Apron = 108, Gantries = { 148, 198 } }
function HubCity.RangeShed(tg: Folder, H: any, R: any, bayCol: any, bayText: any)
    local P = H.P
    local G = HubCity.GROUND
    local W = R.HalfX
    local S = HubCity.SHED
    local rv = Random.new(2413) -- (its own stream: per-booth props, tints, turns)
    local function Q(props)
        props.CanQuery = props.CanQuery == true
        if props.CanCollide == nil then props.CanCollide = false end
        local p = P(tg, props)
        p.CastShadow = false
        return p
    end
    local V, CF = Vector3.new, CFrame.new
    local STEEL, STEEL_D, PLY = C(74, 76, 82), C(46, 48, 53), C(104, 92, 78) -- (plywood greyed: 124,100,74 read orange next to the steel)
    local ROOF = G + S.Height -- the roof's underside
    local zc = (S.Back + S.Front) / 2
    local nBays = #R.Bays

    -- ===== the shed: roof, gutter, rafters at every bay border, two purlins, H-columns along the front
    Q({ Name = "ShedRoof", Size = V(W * 2 + 4, 0.5, S.Front - S.Back + 1.4), CFrame = CF(0, ROOF + 0.25, zc + 0.7), Color = C(84, 82, 78), Material = M.CorrodedMetal })
    Q({ Name = "ShedGutter", Size = V(W * 2 + 4, 0.5, 0.6), CFrame = CF(0, ROOF + 0.15, S.Front + 1.15), Color = STEEL_D, Material = M.Metal })
    for _, z in ipairs({ 86.5, 94 }) do
        Q({ Name = "ShedPurlin", Size = V(W * 2, 0.45, 0.45), CFrame = CF(0, ROOF - 0.22, z), Color = STEEL_D, Material = M.Metal })
    end
    for k = 0, nBays do
        local x = -W + R.BayW * k
        Q({ Name = "ShedRafter", Size = V(0.45, 0.7, S.Front - S.Back), CFrame = CF(x, ROOF - 0.35, zc), Color = STEEL, Material = M.Metal })
        Q({ Name = "ShedColumn", Size = V(0.8, S.Height, 0.8), CFrame = CF(x, G + S.Height / 2, S.Front - 0.1), Color = STEEL, Material = M.Metal, CanCollide = true })
        Q({ Name = "ShedColumnBase", Size = V(1.7, 0.3, 1.7), CFrame = CF(x, G + 0.15, S.Front - 0.1), Color = STEEL_D, Material = M.Metal })
    end

    -- the booth plate on the fascia: dark steel, white stencil, the bay's colour only as a thin stripe
    local function Plate(part: BasePart, idx: number, kind: string, col: Color3)
        local sg = Instance.new("SurfaceGui")
        sg.Name = "Sign"; sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 24
        sg.LightInfluence = 0.75; sg.Brightness = 1.15; sg.Parent = part
        local stripe = Instance.new("Frame")
        stripe.BorderSizePixel = 0; stripe.BackgroundColor3 = col; stripe.Size = UDim2.fromScale(0.012, 0.7); stripe.Position = UDim2.fromScale(0.03, 0.15); stripe.Parent = sg
        local num = Instance.new("TextLabel")
        num.BackgroundTransparency = 1; num.Size = UDim2.fromScale(0.16, 0.8); num.Position = UDim2.fromScale(0.055, 0.1); num.TextScaled = true
        num.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); num:SetAttribute("KeepFont", true)
        num.TextColor3 = C(236, 232, 220); num.Text = string.format("%02d", idx); num.TextXAlignment = Enum.TextXAlignment.Left; num.Parent = sg
        local t = num:Clone(); t.Size = UDim2.fromScale(0.74, 0.5); t.Position = UDim2.fromScale(0.23, 0.08); t.Text = (kind == "DPS") and "DPS TEST" or string.upper(kind); t.Parent = sg
        local s = num:Clone(); s.Size = UDim2.fromScale(0.74, 0.3); s.Position = UDim2.fromScale(0.23, 0.6)
        s.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium); s.TextColor3 = C(176, 172, 164)
        s.Text = string.upper((bayText[kind] or "") .. "  •  step on the pad"); s.Parent = sg
    end

    for i, kind in ipairs(R.Bays) do
        local cx = -W + R.BayW * (i - 0.5)
        local col = bayCol[kind] or C(220, 200, 160)
        -- fascia segment = the lane plate (the gaps between segments are the columns)
        local fas = Q({ Name = "BayHeader", Size = V(R.BayW - 0.9, 2.4, 0.5), CFrame = CF(cx, ROOF - 1.2, S.Front + 0.1), Color = C(34, 35, 38), Material = M.Metal })
        Plate(fas, i, kind, col)
        -- shooting counter (collides): a bench top + a front panel down to the floor
        Q({ Name = "BoothCounter", Size = V(R.BayW - 0.6, 0.3, 2.2), CFrame = CF(cx, G + 3.5, R.LineZ + 0.4), Color = PLY:Lerp(C(96, 76, 58), rv:NextNumber(0, 0.6)), Material = M.WoodPlanks, CanCollide = true })
        Q({ Name = "BoothCounterFront", Size = V(R.BayW - 0.6, 3.35, 0.25), CFrame = CF(cx, G + 1.68, R.LineZ + 1.35), Color = STEEL_D, Material = M.Metal, CanCollide = true })
        -- rubber mat where you stand
        Q({ Name = "BoothMat", Size = V(R.BayW - 5, 0.08, 9.5), CFrame = CF(cx, G + 0.04, 91.6) * CFrame.Angles(0, math.rad(rv:NextNumber(-1.2, 1.2)), 0), Color = C(28, 28, 30), Material = M.Rubber })
        -- tube lamp under the roof (self-lit lens only: no Light object -- see the header)
        Q({ Name = "TubeLampHousing", Size = V(0.55, 0.35, 7), CFrame = CF(cx, ROOF - 0.42, 92), Color = C(40, 40, 44), Material = M.Metal })
        Q({ Name = "TubeLamp", Size = V(0.32, 0.06, 6.6), CFrame = CF(cx, ROOF - 0.62, 92), Color = C(255, 232, 196), Material = M.Neon, Transparency = 0.15 })
        -- bench props, each booth its own: an ammo can, now and then a mag box or a spotting scope
        local side = (rv:NextNumber() < 0.5) and -1 or 1
        local ax = cx + side * rv:NextNumber(4, 9)
        Q({ Name = "AmmoCan", Size = V(1.3 * rv:NextNumber(0.9, 1.1), 0.85, 0.6), CFrame = CF(ax, G + 4.08, R.LineZ + 0.1) * CFrame.Angles(0, math.rad(rv:NextNumber(-25, 25)), 0),
            Color = C(70, 74, 52):Lerp(C(52, 54, 44), rv:NextNumber()), Material = M.Metal })
        local roll = rv:NextNumber()
        if roll < 0.35 then
            Q({ Name = "MagBox", Size = V(0.9, 0.35, 0.7), CFrame = CF(cx - side * rv:NextNumber(3, 7), G + 3.83, R.LineZ + 0.5) * CFrame.Angles(0, math.rad(rv:NextNumber(-40, 40)), 0), Color = C(130, 104, 66), Material = M.Cardboard })
        elseif roll < 0.6 then
            local sx = cx - side * rv:NextNumber(4, 8)
            Q({ Name = "ScopeLeg", Size = V(0.2, 0.9, 0.2), CFrame = CF(sx, G + 4.1, R.LineZ + 0.6), Color = C(30, 30, 32), Material = M.Metal })
            Q({ Name = "Scope", Shape = Enum.PartType.Cylinder, Size = V(1.5, 0.4, 0.4), CFrame = CF(sx, G + 4.65, R.LineZ + 0.6) * CFrame.Angles(0, math.rad(90 + rv:NextNumber(-12, 12)), math.rad(6)), Color = C(54, 58, 52), Material = M.Metal })
        end
    end
    -- partitions between booths (collide), plywood in a steel cap
    for k = 1, nBays - 1 do
        local x = -W + R.BayW * k
        Q({ Name = "BoothPartition", Size = V(0.35, 6.2, 12.6), CFrame = CF(x, G + 3.1, 92.6), Color = PLY:Lerp(C(90, 82, 72), rv:NextNumber(0, 0.5)), Material = M.WoodPlanks, CanCollide = true })
        Q({ Name = "BoothPartitionCap", Size = V(0.55, 0.3, 12.8), CFrame = CF(x, G + 6.35, 92.6), Color = STEEL_D, Material = M.Metal })
    end
    -- painted firing line + the apron's lane numbers are HubGenerator's LaneNumber (white now)
    Q({ Name = "FiringLine", Size = V(W * 2, 0.05, 0.5), CFrame = CF(0, G + 0.05, S.Front - 0.9), Color = C(214, 170, 52), Material = M.SmoothPlastic, Transparency = 0.15 })

    -- ===== work floods on the fascia, aimed downrange (self-lit lenses, no Light objects)
    for _, x in ipairs({ -138, -96, -54, 54, 96, 138, -18, 18 }) do
        local base = V(x + rv:NextNumber(-1, 1), ROOF + 0.55, S.Front + 0.6)
        Q({ Name = "FloodBracket", Size = V(0.3, 1.0, 0.3), CFrame = CF(base), Color = STEEL_D, Material = M.Metal })
        local aim = CF(base + V(0, 0.75, 0.5), base + V(0, 0.75, 0.5) + V(rv:NextNumber(-0.08, 0.08), -0.38, 1).Unit)
        Q({ Name = "FloodHousing", Size = V(1.8, 1.2, 0.7), CFrame = aim, Color = C(36, 36, 40), Material = M.Metal })
        Q({ Name = "FloodLens", Size = V(1.5, 0.9, 0.08), CFrame = aim * CF(0, 0, -0.38), Color = C(255, 196, 120), Material = M.Neon, Transparency = 0.1 })
    end
    -- RANGE LIVE beacon (a small green dome over the DPS bay)
    Q({ Name = "BeaconBase", Size = V(0.9, 0.4, 0.9), CFrame = CF(0, ROOF + 0.7, S.Front + 0.2), Color = C(30, 30, 32), Material = M.Metal })
    Q({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = V(0.8, 0.8, 0.8), CFrame = CF(0, ROOF + 1.15, S.Front + 0.2), Color = C(90, 230, 120), Material = M.Neon, Transparency = 0.2 })

    -- ===== downrange: chalk lane lines on the dirt, two gantries (distance strip + parked steel targets)
    local LINE_FROM, LINE_TO = S.Apron, R.Z1 - 6
    for k = 1, nBays - 1 do
        Q({ Name = "ChalkLine", Size = V(0.35, 0.06, LINE_TO - LINE_FROM), CFrame = CF(-W + R.BayW * k, G + 0.06, (LINE_FROM + LINE_TO) / 2), Color = C(214, 210, 196), Material = M.SmoothPlastic, Transparency = 0.45 })
    end
    for gi, z in ipairs(S.Gantries) do
        Q({ Name = "ChalkLine", Size = V(W * 2 - 2, 0.06, 0.35), CFrame = CF(0, G + 0.06, z), Color = C(214, 210, 196), Material = M.SmoothPlastic, Transparency = 0.5 })
        local y0 = G + 30
        Q({ Name = "GantryChord", Size = V(W * 2 + 3, 0.6, 0.6), CFrame = CF(0, y0, z), Color = STEEL, Material = M.Metal })
        Q({ Name = "GantryChord", Size = V(W * 2 + 3, 0.6, 0.6), CFrame = CF(0, y0 + 2.6, z), Color = STEEL, Material = M.Metal })
        for k = 0, nBays do
            local x = -W + R.BayW * k
            Q({ Name = "GantryStrut", Size = V(0.3, 2.6, 0.3), CFrame = CF(x, y0 + 1.3, z), Color = STEEL_D, Material = M.Metal })
            if k < nBays then -- a diagonal in every bay: a truss
                local a, b = V(x + 0.4, y0 + 0.2, z), V(x + R.BayW - 0.4, y0 + 2.4, z)
                Q({ Name = "GantryBrace", Size = V(0.22, 0.22, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = STEEL_D, Material = M.Metal })
            end
        end
        for _, sx in ipairs({ -1, 1 }) do
            Q({ Name = "GantryLeg", Size = V(0.9, y0 + 2.9 - G, 0.9), CFrame = CF(sx * (W + 1.2), (G + y0 + 2.9) / 2, z), Color = STEEL, Material = M.Metal })
        end
        -- distance strip under the bottom chord: one part, one label per lane
        local strip = Q({ Name = "GantrySign", Size = V(W * 2, 1.4, 0.15), CFrame = CF(0, y0 - 1.0, z - 0.1), Color = C(30, 31, 34), Material = M.Metal })
        local sg = Instance.new("SurfaceGui")
        sg.Name = "Sign"; sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 10
        sg.LightInfluence = 0.75; sg.Brightness = 1.2; sg.Parent = strip
        local list = Instance.new("UIListLayout"); list.FillDirection = Enum.FillDirection.Horizontal; list.Parent = sg
        for _ = 1, nBays do
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1 / nBays, 1); l.TextScaled = true
            l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); l:SetAttribute("KeepFont", true)
            l.TextColor3 = C(230, 226, 212); l.Text = tostring(z - R.LineZ); l.Parent = sg
        end
        -- parked steel targets on their trolleys (gantry 1 only), above the bots' box
        if gi == 1 then
            for i = 1, nBays do
                local x = -W + R.BayW * (i - 0.5) + rv:NextNumber(-5, 5)
                Q({ Name = "TargetTrolley", Size = V(1.0, 0.5, 1.2), CFrame = CF(x, y0 - 0.55, z + 0.9), Color = STEEL_D, Material = M.Metal })
                Q({ Name = "TargetHanger", Size = V(0.12, 1.4, 0.12), CFrame = CF(x, y0 - 1.5, z + 0.9), Color = C(24, 24, 26), Material = M.Metal })
                local tilt = CFrame.Angles(0, math.rad(rv:NextNumber(-10, 10)), math.rad(rv:NextNumber(-3, 3)))
                local white = C(200, 192, 168):Lerp(C(150, 140, 120), rv:NextNumber())
                Q({ Name = "SteelTarget", Size = V(2.0, 2.6, 0.18), CFrame = CF(x, y0 - 3.5, z + 0.9) * tilt, Color = white, Material = M.Metal })
                Q({ Name = "SteelTargetHead", Shape = Enum.PartType.Cylinder, Size = V(0.18, 1.2, 1.2), CFrame = CF(x, y0 - 1.75, z + 0.9) * tilt * CFrame.Angles(0, math.rad(90), 0), Color = white, Material = M.Metal })
            end
        end
    end

    -- ===== RANGE RULES board on the south row's back wall, left of the doorway
    local board = Q({ Name = "RulesBoard", Size = V(12, 7, 0.3), CFrame = CF(-36, G + 7.5, H.FLOOR_HALF + 4.55), Color = C(28, 30, 32), Material = M.Metal })
    local sg = Instance.new("SurfaceGui")
    sg.Name = "Sign"; sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30
    sg.LightInfluence = 0.75; sg.Brightness = 1.2; sg.Parent = board
    local lines = { { "RANGE RULES", 0.04, 0.2, C(214, 170, 52) },
        { "1   STEP ON A BAY'S PAD TO START IT", 0.3, 0.12 }, { "2   N  MORE OR FEWER BOTS", 0.45, 0.12 },
        { "3   Z / X  BOT SKILL DOWN / UP", 0.6, 0.12 }, { "4   STEP OFF THE PAD TO STOP", 0.75, 0.12 } }
    for _, ln in ipairs(lines) do
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(0.88, ln[3]); l.Position = UDim2.fromScale(0.06, ln[2]); l.TextScaled = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); l:SetAttribute("KeepFont", true)
        l.TextColor3 = ln[4] or C(226, 222, 210); l.Text = ln[1]; l.Parent = sg
    end
end

-- PLAZA DIM (2026-10-10, owner: "make the spawn darker without the weapons / sleeves getting darker"): the hub's LIGHT
-- stays as it is (a dimmer light darkens your gear too, and a textured gun can't be brightened past its texture -- tested:
-- SurfaceAppearance.Color clamps at white, emissive masks don't render here). Instead the plaza's SURFACES get darker:
-- every non-Neon part built so far (the city, gates, shopfronts, boards -- not the training grounds, built after) has its
-- colour scaled by PLAZA_DIM once at build time, window-band Textures / Decals too. Neon signs, lights, players and
-- their gear are untouched. (No runtime cost: one pass when the hub is built.)
HubCity.PLAZA_DIM = 0.62 -- (UPDATE 4 NIGHT: 0.72 -> 0.5 -- dark city surfaces, the neon / signs / lit rooms / lanterns pop)
-- (HUBFIX 2026-10-24, owner: "The hub is incredibly dark and hard to see now": 0.5 -> 0.62 with the DEPTH shaping softened
-- below and the hub profile's exposure +0.14 (AimRngClient LIGHT_PROFILES.Hub) -- still a night city, readable again)
-- (HUB LOOK v2 2026-10-24, owner: "the lighting can be fixed for sure, just dont overdo it"): the night had ONE flat dim
-- over everything, so nothing had depth. The same one-pass surface dim, now shaped by WHERE a surface is (the light itself
-- and GearLight are untouched -- the gun reads exactly as before):
--   * CORNERS + far ends sink into shadow: x(1 - DEPTH.Corner) where both |x| and |z| are far from the plaza's middle
--   * the towers fade upward into the night sky: x(1 - DEPTH.Height) from y 40 to 110 (lit rooms are Neon: untouched)
--   * the lit SHOPFRONTS keep more of their colour (DEPTH.Shop instead of PLAZA_DIM): the rooms glow against the street
--   * the street itself a touch darker (DEPTH.Street), so the self-lit lamp / neon pools on it read as pools
-- center = the area's middle (the city's 0,0; the Bazaar passes its own).
HubCity.DEPTH = { Corner = 0.15, CornerFrom = 34, CornerTo = 66, Height = 0.12, HeightFrom = 40, HeightTo = 110, Shop = 0.72, Street = 0.95 } -- (HUBFIX: was Corner 0.3 / Height 0.2 / Shop 0.62 / Street 0.86 -- the corners + street sank to black)
function HubCity.DimPlaza(hub: Folder, center: Vector3?)
    local k = HubCity.PLAZA_DIM
    if k >= 1 then return end
    local D = HubCity.DEPTH
    local c0 = center or Vector3.zero
    local function Smooth(a: number, b: number, x: number): number
        local t = math.clamp((x - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)
    end
    local function Factor(part: Instance?): number
        if not (part and part:IsA("BasePart")) then return k end
        local p = part.Position - c0
        local f = k
        local m = part:FindFirstAncestorOfClass("Model")
        if m and string.sub(m.Name, 1, 5) == "Shop_" then f = D.Shop end
        if part.Name == "Street" then f *= D.Street end
        f *= 1 - D.Corner * Smooth(D.CornerFrom, D.CornerTo, math.min(math.abs(p.X), math.abs(p.Z)))
        f *= 1 - D.Height * Smooth(D.HeightFrom, D.HeightTo, part.Position.Y - (center and center.Y or 0))
        return f
    end
    local function Dim(c: Color3, f: number): Color3 return Color3.new(c.R * f, c.G * f, c.B * f) end
    for _, d in ipairs(hub:GetDescendants()) do
        if d:IsA("BasePart") then
            if d.Material ~= M.Neon and d.Transparency < 1 and not d:GetAttribute("NoDim") then d.Color = Dim(d.Color, Factor(d)) end
        elseif (d:IsA("Texture") or d:IsA("Decal")) and not d:GetAttribute("NoDim") and not (d.Parent and d.Parent:GetAttribute("NoDim")) then
            d.Color3 = Dim(d.Color3, Factor(d.Parent))
        elseif d:IsA("SurfaceAppearance") then -- (UPDATE 4: the kit meshes' textures)
            local f = Factor(d.Parent)
            pcall(function() d.Color = Dim(d.Color, f) end)
        end
    end
end

-- the Centerpiece rings (HubGenerator's) as a neon hologram
function HubCity.TintCenterpiece(cp: Model)
    for _, d in ipairs(cp:GetDescendants()) do
        if d:IsA("BasePart") then
            if d.Parent and d.Parent.Name == "OuterRing" then d.Color = NEON.Cyan; d.Material = M.Neon; d.Reflectance = 0; d.Transparency = 0.15
            elseif d.Parent and d.Parent.Name == "InnerRing" then d.Color = NEON.Pink; d.Material = M.Neon; d.Reflectance = 0; d.Transparency = 0.15
            elseif d.Name == "ReticleCore" then d.Color = NEON.White end
        end
        if d:IsA("PointLight") then d.Color = NEON.Cyan end
    end
end

-- SIGN KEEP-OUT (HUBFIX 2026-10-24, owner: "the main sign has a prop sticking through it" -- a facade balcony cage ran
-- through the 瞄準城 city sign; the same check found AC units through both gate walls, blade signs and Bazaar signs).
-- The facade relief is placed per bay by random draws that don't know about signs, so it runs ONCE after an area is built:
-- every facade kit prop (FACADE_PROPS) whose box overlaps a sign / board / gate frame (SIGN_PARTS, + margin) is removed.
-- Nothing is moved and no draw changes, so everything else stands where it did. Returns the number removed.
HubCity.SIGN_PARTS = { CitySign = true, CitySignNeon = true, ShopBoard = true, ShopBoardNeon = true, StreetBoard = true, GateBoard = true,
    BoardPanel = true, BoardFrame = true, BoardEdge = true, BoardsHeader = true, BoardsHeaderFrame = true, BoardsCabinet = true,
    BayHeader = true, MenuBoard = true, RangeSign = true, RangeSignNeon = true, RangeDoorSign = true, DoorSign = true, BackDoorSign = true,
    BladeSign = true, BladeNeon = true, KioskSign = true, TradeBoard = true, BoothBoard = true, CartBoard = true, RoofSign = true,
    GateBack = true, GatePillar = true, GateTrim = true, GateReveal = true, GateBlade = true, GateBladeNeon = true, GateNeon = true }
HubCity.FACADE_PROPS = { ACUnit = true, BalconyCage = true, RoofShack = true, WaterTank = true, MeterBox = true, DepthOriel = true, DepthBalcony = true, DepthBand = true } -- (+ the HUBFIX DEPTH oriels / balconies)
function HubCity.ClearSignProps(root: Instance, margin: number?): number
    local pad = margin or 0.4
    local signs, props = {}, {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("BasePart") and HubCity.SIGN_PARTS[d.Name] and d.Transparency < 1 then
            table.insert(signs, d)
        elseif d:IsA("Model") and HubCity.FACADE_PROPS[d.Name] then
            table.insert(props, d)
        end
    end
    local removed = 0
    for _, m in ipairs(props) do
        local cf, size = m:GetBoundingBox()
        local h = size / 2
        local hit = false
        for _, s in ipairs(signs) do
            -- the prop's box seen in the sign's frame (its 8 corners -> an axis box there), vs the sign + margin
            local sc = s.CFrame
            if (sc.Position - cf.Position).Magnitude < s.Size.Magnitude / 2 + size.Magnitude / 2 + pad then
                local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
                for ix = -1, 1, 2 do for iy = -1, 1, 2 do for iz = -1, 1, 2 do
                    local p = sc:PointToObjectSpace((cf * CFrame.new(h.X * ix, h.Y * iy, h.Z * iz)).Position)
                    lo = lo:Min(p); hi = hi:Max(p)
                end end end
                local e = s.Size / 2 + Vector3.new(pad, pad, pad)
                if lo.X < e.X and hi.X > -e.X and lo.Y < e.Y and hi.Y > -e.Y and lo.Z < e.Z and hi.Z > -e.Z then hit = true; break end
            end
        end
        if hit then m:Destroy(); removed += 1 end
    end
    -- drain pipes + overhead cables (thin and long: tested along their centre line). A cable is two sag segments that share
    -- a point -- both go, with any string lanterns hanging on them.
    local lines, lanterns = {}, {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("BasePart") and HubCity.FACADE_LINES[d.Name] then table.insert(lines, d)
        elseif d:IsA("BasePart") and d.Name == "StringLantern" then table.insert(lanterns, d) end
    end
    local function Axis(p: BasePart): (Vector3, number, number)
        local s = p.Size
        if s.X >= s.Y and s.X >= s.Z then return p.CFrame.RightVector, s.X, math.max(s.Y, s.Z) end
        if s.Y >= s.Z then return p.CFrame.UpVector, s.Y, math.max(s.X, s.Z) end
        return p.CFrame.LookVector, s.Z, math.max(s.X, s.Y)
    end
    local function Crosses(p: BasePart): boolean
        local ax, len, thick = Axis(p)
        for _, s in ipairs(signs) do
            if (s.Position - p.Position).Magnitude < s.Size.Magnitude / 2 + len / 2 + 1 then
                local e = s.Size / 2 + Vector3.new(1, 1, 1) * (0.15 + thick / 2)
                for t = -len / 2, len / 2, 0.5 do
                    local q = s.CFrame:PointToObjectSpace(p.Position + ax * t)
                    if math.abs(q.X) < e.X and math.abs(q.Y) < e.Y and math.abs(q.Z) < e.Z then return true end
                end
            end
        end
        return false
    end
    local gone = {}
    for _, p in ipairs(lines) do
        if not gone[p] and Crosses(p) then
            local kill = { p }
            if p.Name == "Cable" then
                local ax, len = Axis(p)
                local ends = { p.Position + ax * len / 2, p.Position - ax * len / 2 }
                for _, o in ipairs(lines) do
                    if o ~= p and o.Name == "Cable" and not gone[o] then
                        local ax2, len2 = Axis(o)
                        for _, e1 in ipairs(ends) do
                            if (o.Position + ax2 * len2 / 2 - e1).Magnitude < 0.1 or (o.Position - ax2 * len2 / 2 - e1).Magnitude < 0.1 then table.insert(kill, o); break end
                        end
                    end
                end
            end
            for _, k in ipairs(kill) do
                gone[k] = true
                if k.Name == "Cable" then
                    local ax, len = Axis(k)
                    for _, l in ipairs(lanterns) do
                        local v = l.Position - k.Position
                        local t = v:Dot(ax)
                        if math.abs(t) <= len / 2 + 0.5 and (v - ax * t).Magnitude < 1.2 then l:Destroy() end
                    end
                end
                k:Destroy(); removed += 1
            end
        end
    end
    return removed
end
HubCity.FACADE_LINES = { Pipe = true, Cable = true }

-- ===================================================================================== a gate surround
-- the alley mouth round each rift: a concrete portal frame, a neon arch outline, a big vertical sign and a board.
function HubCity.Gate(hub: Folder, cx: number, t: any, H: any)
    local P, Light = H.P, H.Light
    local F, HALF = H.GROUND or H.FLOOR_TOP, H.FLOOR_HALF
    local m = Instance.new("Model"); m.Name = t.ModelName .. "City"; m.Parent = hub
    local cf = CFrame.lookAt(Vector3.new(cx, F, -HALF + 10), Vector3.new(cx, F, 0))
    local function Q(props) local p = P(m, props); p.CastShadow = false; if props.CanQuery == nil then p.CanQuery = false end; return p end
    local main = t.Main
    local grng = Random.new(math.floor(cx * 31 + 911))
    -- UPDATE 4 GATEWAY (owner: "breathtaking and intentional", not "robloxy"): the rift sits in a built alley-mouth -- two
    -- clad pillars on plinths with capitals, a stepped cornice, a recessed steel reveal with a double neon tube, a rolled-up
    -- shutter, lit lightbox signs stacked on the pillars, hanging paper lanterns, cables, a threshold
    -- plate. Same footprint and contract: the rift / vortex / prompt are HubGenerator's, the back wall closes the doorway.
    local CON, CON2, STEEL = C(64, 61, 58), C(48, 46, 44), C(38, 39, 42)
    -- steps + threshold
    Q({ Name = "GateStep", Size = Vector3.new(31, 0.4, 11), CFrame = cf * CFrame.new(0, 0.2, 2.5), Color = C(58, 56, 54), Material = M.Concrete })
    Q({ Name = "GateStep", Size = Vector3.new(26, 0.4, 7), CFrame = cf * CFrame.new(0, 0.6, 4.5), Color = C(52, 50, 48), Material = M.Concrete })
    Q({ Name = "GateThreshold", Size = Vector3.new(21, 0.12, 2.4), CFrame = cf * CFrame.new(0, 0.86, 3.6), Color = C(70, 70, 72), Material = M.DiamondPlate })
    Q({ Name = "GateEdgePaint", Size = Vector3.new(26, 0.06, 0.35), CFrame = cf * CFrame.new(0, 0.82, 1.15), Color = C(196, 160, 40), Material = M.SmoothPlastic })
    for _, sx in ipairs({ -1, 1 }) do
        -- the pillar: plinth, shaft, capital; two raised trim bands up its face
        Q({ Name = "GatePlinth", Size = Vector3.new(6.4, 2.6, 7.2), CFrame = cf * CFrame.new(sx * 13.2, 1.3, 4.6), Color = CON2, Material = M.Concrete })
        Q({ Name = "GatePillar", Size = Vector3.new(5.2, 34.4, 6), CFrame = cf * CFrame.new(sx * 13.2, 2.6 + 17.2, 4.6), Color = CON, Material = M.Concrete })
        for _, bx in ipairs({ -2.15, 2.15 }) do
            Q({ Name = "GateTrim", Size = Vector3.new(0.5, 33, 0.3), CFrame = cf * CFrame.new(sx * 13.2 + bx, 2.6 + 16.6, 1.45), Color = CON2, Material = M.Concrete })
        end
        Q({ Name = "GateCapital", Size = Vector3.new(6.6, 1.4, 7.2), CFrame = cf * CFrame.new(sx * 13.2, 37.6, 4.6), Color = CON2, Material = M.Concrete })
        -- the steel reveal round the rift + the double neon tube on it
        Q({ Name = "GateReveal", Size = Vector3.new(1.3, 34, 1.4), CFrame = cf * CFrame.new(sx * 11.25, 18.9, 3.4), Color = STEEL, Material = M.Metal })
        Q({ Name = "GateNeon", Size = Vector3.new(0.32, 33.2, 0.32), CFrame = cf * CFrame.new(sx * 10.85, 18.9, 2.6), Color = main, Material = M.Neon })
        Q({ Name = "GateNeon2", Size = Vector3.new(0.2, 33.2, 0.2), CFrame = cf * CFrame.new(sx * 11.7, 18.9, 2.6), Color = main:Lerp(C(255, 255, 255), 0.25), Material = M.Neon, Transparency = 0.15 })
        -- lightbox signs stacked down the pillar (self-lit faces: a SurfaceGui panel ignores the scene light)
        for k = 0, (HubCity.CALM.GateLightBoxes and 2 or -1) do -- (HUB DECLUTTER: off -- random shop words round the gate)
            local y = 9 + k * 6.2 + grng:NextNumber(-0.6, 0.6)
            local bw = grng:NextNumber(3.6, 4.6)
            local box = Q({ Name = "LightBox", Size = Vector3.new(bw, 2.6, 0.7), CFrame = cf * CFrame.new(sx * (13.2 + grng:NextNumber(-0.3, 0.3)), y, 0.95), Color = C(30, 30, 32), Material = M.Metal })
            local faceCol = ({ C(242, 236, 214), C(250, 214, 90), C(236, 70, 60), C(90, 190, 230), C(244, 244, 238) })[grng:NextInteger(1, 5)]
            local ink = (faceCol.R + faceCol.G + faceCol.B > 2) and ({ C(170, 24, 24), C(20, 30, 70), C(20, 20, 22) })[grng:NextInteger(1, 3)] or C(250, 246, 236)
            local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30
            sg.LightInfluence = 0; sg.Brightness = 1.15; sg.Parent = box
            local fr = Instance.new("Frame"); fr.Size = UDim2.new(1, -6, 1, -6); fr.Position = UDim2.fromOffset(3, 3); fr.BackgroundColor3 = faceCol; fr.BorderSizePixel = 0; fr.Parent = sg
            local tl = Instance.new("TextLabel"); tl.BackgroundTransparency = 1; tl.Size = UDim2.fromScale(0.92, 0.84); tl.Position = UDim2.fromScale(0.04, 0.08)
            tl.Font = Enum.Font.GothamBlack; tl.TextScaled = true; tl.TextColor3 = ink; tl.Text = SIGNS[grng:NextInteger(1, #SIGNS)]; tl:SetAttribute("KeepFont", true); tl.Parent = fr
            Q({ Name = "LightBoxStain", Size = Vector3.new(0.5, grng:NextNumber(2, 4), 0.05), CFrame = cf * CFrame.new(sx * 13.2 + grng:NextNumber(-1.5, 1.5), y - 3, 1.28), Color = C(60, 40, 26), Material = M.SmoothPlastic, Transparency = 0.45 })
        end
        -- a junction box + its conduit up the pillar
        if HubCity.CALM.GateConduit then Q({ Name = "JunctionBox", Size = Vector3.new(1.4, 1.8, 0.6), CFrame = cf * CFrame.new(sx * 15.4, 5.5, 1.35), Color = C(110, 112, 108), Material = M.Metal })
        Q({ Name = "Conduit", Size = Vector3.new(0.3, 30, 0.3), CFrame = cf * CFrame.new(sx * 15.4, 21, 1.4), Color = C(70, 70, 72), Material = M.Metal }) end
    end
    -- lintel + stepped cornice; the rolled-up shutter in its box under it
    Q({ Name = "GateLintel", Size = Vector3.new(32, 3.6, 5.6), CFrame = cf * CFrame.new(0, 40.1, 4.6), Color = CON, Material = M.Concrete })
    Q({ Name = "GateCornice", Size = Vector3.new(33.4, 0.9, 6.4), CFrame = cf * CFrame.new(0, 42.35, 4.6), Color = CON2, Material = M.Concrete })
    Q({ Name = "GateCornice", Size = Vector3.new(32.6, 0.6, 6), CFrame = cf * CFrame.new(0, 43.1, 4.8), Color = CON, Material = M.Concrete })
    Q({ Name = "GateHead", Size = Vector3.new(23.8, 1.3, 1.4), CFrame = cf * CFrame.new(0, 36.0, 3.4), Color = STEEL, Material = M.Metal })
    Q({ Name = "GateNeon", Size = Vector3.new(22, 0.32, 0.32), CFrame = cf * CFrame.new(0, 35.5, 2.6), Color = main, Material = M.Neon })
    Q({ Name = "GateNeon2", Size = Vector3.new(23.6, 0.2, 0.2), CFrame = cf * CFrame.new(0, 36.5, 2.6), Color = main:Lerp(C(255, 255, 255), 0.25), Material = M.Neon, Transparency = 0.15 })
    Q({ Name = "ShutterBox", Size = Vector3.new(22.6, 1.8, 1.6), CFrame = cf * CFrame.new(0, 37.9, 3.6), Color = C(86, 88, 92), Material = M.Metal })
    Q({ Name = "ShutterLip", Size = Vector3.new(21.4, 0.35, 0.4), CFrame = cf * CFrame.new(0, 36.95, 3.1), Color = C(120, 122, 126), Material = M.DiamondPlate })
    -- (owner 2026-10-05: "portals are missing the back wall so you can walk out of map"): a thick back wall closes the
    -- doorway behind the 1-stud rift (dashes tunnelled through it) and reads as the alcove's back
    Q({ Name = "GateBack", Size = Vector3.new(31, 46, 6), CFrame = cf * CFrame.new(0, 23, 11), Color = C(30, 28, 32), Material = M.Concrete, CanQuery = true })
    -- the title board over it (owner 2026-10-05: "the signs in the hub are too neon and hard to read"): the plain English
    -- title big and crisp, the Chinese name + the hint small underneath -- now in a steel frame on two brackets
    local board = Q({ Name = "GateBoard", Size = Vector3.new(26, 6, 0.8), CFrame = cf * CFrame.new(0, 47.2, 1.1), Color = C(14, 12, 16), Material = M.Metal })
    Text(board, Enum.NormalId.Front, t.Title, main, { PPS = 20, Sub = (t.ZH and (t.ZH .. "  •  ") or "") .. string.upper(t.Sub or ""), SubColor = C(225, 222, 215),
        Brightness = 1.5, Stroke = C(10, 6, 8), StrokeT = 0.2, Font = Enum.Font.GothamBlack })
    for _, e in ipairs({ { Vector3.new(26.8, 0.4, 1), Vector3.new(0, 50.4, 1.1) }, { Vector3.new(26.8, 0.4, 1), Vector3.new(0, 44.0, 1.1) },
        { Vector3.new(0.4, 6.8, 1), Vector3.new(-13.2, 47.2, 1.1) }, { Vector3.new(0.4, 6.8, 1), Vector3.new(13.2, 47.2, 1.1) } }) do
        Q({ Name = "BoardFrame", Size = e[1], CFrame = cf * CFrame.new(e[2]), Color = C(52, 52, 56), Material = M.Metal })
    end
    for _, bx in ipairs({ -9, 9 }) do
        Q({ Name = "BoardBracket", Size = Vector3.new(0.5, 0.5, 3.4), CFrame = cf * CFrame.new(bx, 45.6, 2.7), Color = C(40, 40, 44), Material = M.Metal })
    end
    Light(board, "PointLight", { Range = 30, Brightness = 1.4, Color = main, Shadows = false })
    -- paper lanterns hanging from the cornice
    for _, lx in ipairs(HubCity.CALM.GateLanterns and { -7.5, 7.5 } or {}) do
        local top = cf * CFrame.new(lx, 42.0, 0.9)
        Q({ Name = "LanternCord", Size = Vector3.new(0.08, 2.2, 0.08), CFrame = top * CFrame.new(0, -1.1, 0), Color = C(20, 16, 14), Material = M.SmoothPlastic })
        HubCity.PaperLantern(Q, top * CFrame.new(0, -3.4, 0), 1.25, C(206, 34, 34))
    end
    -- a tall vertical neon sign on the outer side (now on a bracket off the facade)
    local side = (cx < 0) and -1 or 1
    local v = Q({ Name = "GateBlade", Size = Vector3.new(0.8, 24, 4.4), CFrame = cf * CFrame.new(side * 18.2, 26, 0.4), Color = C(14, 12, 16), Material = M.Metal })
    for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
        Text(v, face, Vertical(t.ZH or ""), t.Accent, { PPS = 18, Brightness = 1.6, Stroke = C(10, 6, 8), StrokeT = 0.3 })
    end
    Q({ Name = "GateBladeNeon", Size = Vector3.new(0.9, 24.4, 0.3), CFrame = v.CFrame * CFrame.new(0, 0, 2.3), Color = t.Accent, Material = M.Neon })
    Q({ Name = "GateBladeNeon", Size = Vector3.new(0.9, 24.4, 0.3), CFrame = v.CFrame * CFrame.new(0, 0, -2.3), Color = t.Accent, Material = M.Neon })
    for _, by in ipairs({ 36, 16 }) do
        Q({ Name = "BladeArm", Size = Vector3.new(0.4, 0.4, 3.2), CFrame = cf * CFrame.new(side * 18.2, by, 3.6), Color = C(40, 40, 44), Material = M.Metal })
    end
    -- (UPDATE 4, owner: "the gate openings are dark flat rectangles") a glowing VORTEX fills the opening: the dungeon portals'
    -- self-lit image layers (tunnel, counter-turning swirls, rim) on one invisible face in front of the rift, spun by HubLife
    do
        local face = Instance.new("Part")
        face.Name = "GateVortex"; face.Size = Vector3.new(20.6, 32.6, 0.05); face.CFrame = cf * CFrame.new(0, 18.9, 3.9)
        face.Anchored = true; face.Transparency = 1; face.CanCollide, face.CanQuery, face.CanTouch, face.CastShadow = false, false, false, false
        face.Parent = m
        local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 20; sg.LightInfluence = 0; sg.Brightness = 1.4; sg.ClipsDescendants = true; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = face
        local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = main:Lerp(C(0, 0, 0), 0.85); bg.BorderSizePixel = 0; bg.Parent = sg
        for i, L in ipairs({ { "115595887092843", 1.5, 0, 0, 0.1 }, { "74215633658541", 1.45, -30, 0.25, 0.15 }, { "93462311289317", 1.4, 55, 0.35, 0.25 }, { "122867097434751", 1.55, 10, 0.5, 0 } }) do
            local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.AnchorPoint = Vector2.new(0.5, 0.5); im.Position = UDim2.fromScale(0.5, 0.5)
            im.Size = UDim2.fromScale(L[2], L[2]); im.Image = "rbxassetid://" .. L[1]; im.ImageColor3 = main:Lerp(C(255, 255, 255), L[4]); im.ImageTransparency = L[5]; im.ZIndex = i
            local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = 1; ar.DominantAxis = Enum.DominantAxis.Width; ar.Parent = im
            im.Parent = sg
            if L[3] ~= 0 then im:SetAttribute("SpinRate", L[3]); CS:AddTag(im, "HubSpin") end
        end
    end
    -- the reflection of the gate's neon in the wet street (a soft streak decal on the ground)
    HubCity.WetGlow(Q, cf * CFrame.new(0, 0.04, -12.2), 18, 12, main, 0.55)
    m.WorldPivot = cf
end

-- (UPDATE 4) per-station shopfront variants: Sign "Tubes" (full neon frame) | "Lightbox" (projecting box sign) | nil,
-- Awning "Stripe" (default) | "Solid" | "Valance", Extra "Lanterns" | "Plants" | "AFrame" | "Crates" | "AC", Flicker
HubCity.SHOP_VARIANT = {
    -- (HUB LOOK 2026-10-24, owner: "copy and paste items"): Shelves = which side walls carry the shelves of packed goods
    -- ("Both" / "L" / "R" / "None"). All eight shops had the same two walls of bottles -- a forge, a locker room and a gun
    -- shop full of the corner shop's tins. Now only the shops that sell things keep them; the rest show their own scene.
    ShopStand = { Sign = "Lightbox", Awning = "Valance", Extra = "Crates", Shelves = "Both" },
    RollAltar = { Sign = "Tubes", Awning = "Solid", Extra = "Lanterns", Flicker = true, Shelves = "None" },
    UpgradeAnvil = { Awning = "Stripe", Extra = "AC", Shelves = "R" },
    InvLocker = { Sign = "Tubes", Awning = "Valance", Extra = "Plants", Shelves = "None" },
    TreeAltar = { Sign = "Lightbox", Awning = "Solid", Extra = "Lanterns", Shelves = "L" },
    IndexAltar = { Awning = "Stripe", Extra = "AFrame", Flicker = true, Shelves = "Both" },
    ArmoryStand = { Sign = "Tubes", Awning = "Solid", Extra = "Crates", Shelves = "None" },
    SeasonStand = { Sign = "Lightbox", Awning = "Valance", Extra = "Plants", Shelves = "L" },
    Default = { Awning = "Stripe" },
}
-- ===================================================================================== a station storefront
-- cf: the old booth origin (local -Z = the plaza). The ANCHOR (counter, prompt) sits where the booth's counter was.
local THEMES = {}
function THEMES.ShopStand(m, cf, col, Q) -- street food + contraband: roast ducks on hooks, a steaming wok, crates
    for k = -3, 3 do
        Q({ Name = "Duck", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 1.4, 0.9), CFrame = cf * CFrame.new(k * 1.3, 9.2, 0.5), Color = C(200, 110, 40), Material = M.SmoothPlastic, Reflectance = 0.15 })
    end
    Q({ Name = "HookRail", Size = Vector3.new(10, 0.15, 0.15), CFrame = cf * CFrame.new(0, 10.2, 0.5), Color = C(160, 160, 165), Material = M.Metal })
    Q({ Name = "Wok", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.4, 2.4), CFrame = cf * CFrame.new(4, 4.7, -3.5) * CFrame.Angles(0, 0, math.rad(90)), Color = C(30, 30, 32), Material = M.Metal })
    for _, x in ipairs({ -7, -5.5 }) do Q({ Name = "Crate", Size = Vector3.new(2, 2, 2), CFrame = cf * CFrame.new(x, 1, 3), Color = C(90, 70, 46), Material = M.WoodPlanks }) end
end
function THEMES.RollAltar(m, cf, col, Q) -- a backstreet gunsmith's forge: furnace, anvil, sparks
    local furnace = Q({ Name = "Furnace", Size = Vector3.new(5, 6, 3), CFrame = cf * CFrame.new(-5, 3, 3), Color = C(50, 44, 40), Material = M.Brick })
    local mouth = Q({ Name = "FurnaceMouth", Size = Vector3.new(2.6, 2, 0.2), CFrame = cf * CFrame.new(-5, 2.6, 1.45), Color = C(255, 120, 30), Material = M.Neon })
    local f = Instance.new("Fire"); f.Size = 3; f.Heat = 5; f.Color = C(255, 130, 40); f.Parent = mouth
    Q({ Name = "Anvil", Size = Vector3.new(2.6, 1.4, 1.2), CFrame = cf * CFrame.new(2, 4.9, -3.5), Color = C(40, 40, 44), Material = M.Metal })
    local _ = furnace
end
function THEMES.UpgradeAnvil(m, cf, col, Q) -- a repair shop: pegboard of tools, a workbench, a lamp
    Q({ Name = "Pegboard", Size = Vector3.new(14, 6, 0.3), CFrame = cf * CFrame.new(0, 6, 4.6), Color = C(150, 120, 80), Material = M.WoodPlanks })
    for k = -5, 5, 2 do Q({ Name = "Tool", Size = Vector3.new(0.3, 2.4, 0.3), CFrame = cf * CFrame.new(k, 6.4, 4.3) * CFrame.Angles(0, 0, math.rad(k * 4)), Color = C(180, 180, 186), Material = M.Metal }) end
    Q({ Name = "Bench", Size = Vector3.new(8, 0.5, 3), CFrame = cf * CFrame.new(3, 3.4, 2.6), Color = C(80, 62, 44), Material = M.WoodPlanks })
end
function THEMES.InvLocker(m, cf, col, Q) -- a storage lock-up: a wall of steel lockers, a keypad
    for x = -6, 6, 2.4 do
        for y = 0, 1 do
            Q({ Name = "Locker", Size = Vector3.new(2.2, 4.2, 2), CFrame = cf * CFrame.new(x, 2.4 + y * 4.4, 4), Color = C(70, 90, 110), Material = M.DiamondPlate })
        end
    end
    Q({ Name = "Keypad", Size = Vector3.new(0.8, 1.2, 0.2), CFrame = cf * CFrame.new(8.6, 5, 2.8), Color = col, Material = M.Neon })
end
function THEMES.TreeAltar(m, cf, col, Q) -- a street shrine: red altar, a gold figure, incense smoke, lanterns
    Q({ Name = "Altar", Size = Vector3.new(8, 3.4, 3), CFrame = cf * CFrame.new(0, 1.7, 3), Color = C(150, 24, 24), Material = M.Wood })
    Q({ Name = "AltarTop", Size = Vector3.new(8.6, 0.3, 3.4), CFrame = cf * CFrame.new(0, 3.55, 3), Color = C(200, 160, 60), Material = M.Foil })
    Q({ Name = "Idol", Size = Vector3.new(1.8, 3.4, 1.4), CFrame = cf * CFrame.new(0, 5.4, 3.6), Color = C(230, 180, 60), Material = M.Foil })
    Q({ Name = "IdolHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(0, 7.8, 3.6), Color = C(230, 180, 60), Material = M.Foil })
    local inc = Q({ Name = "Incense", Size = Vector3.new(0.12, 1.4, 0.12), CFrame = cf * CFrame.new(1.6, 4.4, 2.4), Color = C(120, 40, 20), Material = M.SmoothPlastic })
    local e = Instance.new("ParticleEmitter"); e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.Rate = 2; e.Lifetime = NumberRange.new(3, 4)
    e.Size = NumberSequence.new(0.3, 1.6); e.Transparency = NumberSequence.new(0.7, 1); e.Speed = NumberRange.new(0.6, 1); e.Color = ColorSequence.new(C(220, 220, 230)); e.Parent = inc
    for _, x in ipairs({ -5, 5 }) do Q({ Name = "ShrineLantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 2.2, 1.8), CFrame = cf * CFrame.new(x, 9, 0), Color = C(230, 40, 40), Material = M.Neon, Transparency = 0.1 }) end
end
function THEMES.IndexAltar(m, cf, col, Q) -- a cramped bookshop: crammed shelves, a glowing CRT
    for _, x in ipairs({ -6, 6 }) do
        Q({ Name = "Shelf", Size = Vector3.new(4, 9, 2), CFrame = cf * CFrame.new(x, 4.5, 4), Color = C(70, 50, 34), Material = M.WoodPlanks })
        for y = 1, 8, 1.6 do Q({ Name = "Books", Size = Vector3.new(3.6, 1.2, 1.6), CFrame = cf * CFrame.new(x, y, 3.6), Color = PAINT[(math.floor(y) % #PAINT) + 1], Material = M.Fabric }) end
    end
    Q({ Name = "CRT", Size = Vector3.new(2.6, 2.2, 2.2), CFrame = cf * CFrame.new(-2, 5.1, -3.5), Color = C(60, 58, 54), Material = M.SmoothPlastic })
    Q({ Name = "CRTScreen", Size = Vector3.new(2, 1.6, 0.1), CFrame = cf * CFrame.new(-2, 5.1, -4.62), Color = col, Material = M.Neon, Transparency = 0.2 })
end
function THEMES.ArmoryStand(m, cf, col, Q) -- a gun shop wall: rifles on a dark board, a glass case
    Q({ Name = "GunWall", Size = Vector3.new(14, 6, 0.3), CFrame = cf * CFrame.new(0, 6.5, 4.6), Color = C(28, 26, 30), Material = M.Fabric })
    for k = -2, 2 do
        Q({ Name = "Rifle", Size = Vector3.new(5, 0.5, 0.25), CFrame = cf * CFrame.new(0, 4.8 + (k + 2) * 0.9, 4.3), Color = C(40, 40, 44), Material = M.Metal })
    end
    Q({ Name = "Case", Size = Vector3.new(6, 1.4, 2), CFrame = cf * CFrame.new(-5, 4.2, -3.5), Color = C(200, 230, 255), Material = M.Glass, Transparency = 0.6 })
end
function THEMES.SeasonStand(m, cf, col, Q) -- an arcade: cabinets inside, a prize shelf
    for _, x in ipairs({ -5, -1.6 }) do
        Q({ Name = "Cabinet", Size = Vector3.new(2.8, 6, 2.6), CFrame = cf * CFrame.new(x, 3, 3), Color = C(24, 22, 30), Material = M.SmoothPlastic })
        Q({ Name = "CabinetScreen", Size = Vector3.new(2.2, 1.8, 0.1), CFrame = cf * CFrame.new(x, 4.4, 1.62), Color = (x < -3) and NEON.Cyan or NEON.Pink, Material = M.Neon, Transparency = 0.15 })
    end
    Q({ Name = "PrizeShelf", Size = Vector3.new(5, 4, 1.6), CFrame = cf * CFrame.new(5, 5, 4), Color = C(70, 50, 34), Material = M.WoodPlanks })
    for k = 0, 3 do Q({ Name = "Prize", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(3.6 + k * 0.95, 7.4, 3.6), Color = NEON_LIST[k + 1], Material = M.SmoothPlastic }) end
end

function HubCity.Shop(hub: Folder, cf: CFrame, t: any, H: any): BasePart
    local P, Light, Prompt = H.P, H.Light, H.Prompt
    cf = cf + Vector3.new(0, (H.GROUND or cf.Y) - cf.Y, 0) -- (stand on the street)
    local m = Instance.new("Model"); m.Name = "Shop_" .. t.Anchor; m.Parent = hub
    local col = t.Color
    local function Q(props)
        local off = props.CFrame
        local p = P(m, props)
        p.CastShadow = false
        if props.CanCollide == nil and p.Size.Magnitude < 3 then p.CanCollide = false end
        local _ = off
        return p
    end
    -- the shop box: floor, side walls, a ceiling slab, a dim glowing back wall (the room runs from z -2 back to the facade at +6)
    -- (UPDATE 4, owner: the shop walls / shelves read as "flat boards"): the room is 4 studs deeper (back wall at +11.3, the
    -- facade line is ~9 behind the old one), a back wall of shelving with real depth, a counter with a kick + a glass case
    local DEEP = 4
    Q({ Name = "ShopFloor", Size = Vector3.new(22, 0.4, 13 + DEEP), CFrame = cf * CFrame.new(0, 0.2, 1 + DEEP / 2), Color = C(54, 50, 48), Material = M.Concrete })
    for _, sx in ipairs({ -1, 1 }) do
        local wall = Q({ Name = "ShopWall", Size = Vector3.new(1.2, 14, 13 + DEEP), CFrame = cf * CFrame.new(sx * 11.4, 7, 1 + DEEP / 2), Color = C(66, 62, 58), Material = M.Concrete })
        HubCity.Img(wall, (sx < 0) and Enum.NormalId.Right or Enum.NormalId.Left, HubCity.IMG.Tiles, 4, C(128, 124, 116)) -- (UPDATE 4: tiled inside; dim: lamp-lit white tiles read as a light box)
    end
    Q({ Name = "ShopCeiling", Size = Vector3.new(24, 1, 13 + DEEP), CFrame = cf * CFrame.new(0, 14.5, 1 + DEEP / 2), Color = C(50, 48, 46), Material = M.Concrete })
    local back = Q({ Name = "ShopBack", Size = Vector3.new(22, 14, 0.4), CFrame = cf * CFrame.new(0, 7, 7.3 + DEEP), Color = C(150, 150, 140):Lerp(col, 0.12), Material = M.Slate })
    -- back shelving: three deep wooden shelves over ONE goods plane (a Texture tiling the packed-shelf strip per shelf)
    for k = 0, 2 do
        Q({ Name = "BackShelf", Size = Vector3.new(18, 0.3, 1.8), CFrame = cf * CFrame.new(0, 2.9 + k * 2.45, 10.2), Color = C(84, 60, 40), Material = M.WoodPlanks, CanCollide = false })
    end
    local gp = Q({ Name = "BackGoods", Size = Vector3.new(17.6, 7.35, 0.05), CFrame = cf * CFrame.new(0, 2.9 + 3.675 + 0.15, 10.95), Transparency = 1, CanCollide = false })
    local gt = HubCity.Img(gp, Enum.NormalId.Front, HubCity.IMG.Goods[(#t.Anchor % 3) + 1], 9)
    if gt then gt.StudsPerTileU = 8.8; gt.StudsPerTileV = 2.45 end
    -- (UPDATE 4: the cracked-slate back read as a cave wall -- glazed wall tiles, faintly tinted by the shop's colour)
    if HubCity.Img(back, Enum.NormalId.Front, HubCity.IMG.Tiles, 4, C(140, 136, 128):Lerp(col, 0.1)) then back.Material = M.SmoothPlastic end
    -- (lived-in clutter: goods on side shelves, peeling posters, two bare bulbs, a menu board)
    local srng = Random.new(#t.Anchor * 97)
    local shelves = (HubCity.SHOP_VARIANT[t.Anchor] or HubCity.SHOP_VARIANT.Default).Shelves or "Both"
    for _, sx in ipairs({ -1, 1 }) do
        local keepSide = shelves == "Both" or (shelves == "L" and sx < 0) or (shelves == "R" and sx > 0)
        for y = 0, 2 do
            if not keepSide then -- (the draws stay in order: the posters below come out the same)
                for _ = 0, 3 do local _ = srng:NextNumber(0.7, 1.4); local _ = srng:NextInteger(1, #PAINT) end
                continue
            end
            Q({ Name = "SideShelf", Size = Vector3.new(1.6, 0.2, 9), CFrame = cf * CFrame.new(sx * 10, 5 + y * 2.6, 1.5), Color = C(70, 56, 40), Material = M.WoodPlanks, CanCollide = false })
            -- (UPDATE 4: four plain blocks per shelf -> one packed shelf of boxes, tins, bottles and jars, a Decal)
            local gk = 0
            for _ = 0, 3 do local gs = srng:NextNumber(0.7, 1.4); gk += math.floor(gs * 10) + srng:NextInteger(1, #PAINT) end
            local gid = HubCity.IMG.Goods[(gk + y) % 3 + 1]
            if gid ~= "rbxassetid://0" then
                local gp = Q({ Name = "Goods", Size = Vector3.new(0.05, 2.25, 8.6), CFrame = cf * CFrame.new(sx * 9.6, 5.1 + y * 2.6 + 1.125, 1.5), Transparency = 1, CanCollide = false })
                HubCity.Img(gp, (sx < 0) and Enum.NormalId.Right or Enum.NormalId.Left, gid)
            end
        end
        local poster = Q({ Name = "Poster", Size = Vector3.new(0.1, 3.2, 2.2), CFrame = cf * CFrame.new(sx * 10.75, 10, -3.8) * CFrame.Angles(math.rad(srng:NextNumber(-4, 4)), 0, 0), Color = ({ C(200, 60, 50), C(230, 200, 120), C(80, 140, 170) })[srng:NextInteger(1, 3)], Material = M.SmoothPlastic, CanCollide = false })
        -- (UPDATE 4: a printed, faded, torn poster instead of a plain coloured slab)
        if HubCity.Img(poster, (sx < 0) and Enum.NormalId.Right or Enum.NormalId.Left, HubCity.IMG.Posters[(#t.Anchor + sx + 2) % 3 + 1]) then poster.Transparency = 1 end
    end
    for _, x in ipairs({ -4, 4 }) do
        Q({ Name = "BulbCord", Size = Vector3.new(0.06, 3, 0.06), CFrame = cf * CFrame.new(x, 12.5, -1), Color = C(20, 20, 20), Material = M.SmoothPlastic, CanCollide = false })
        Q({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = cf * CFrame.new(x, 10.9, -1), Color = C(255, 210, 150), Material = M.Neon, CanCollide = false })
    end
    local menu = Q({ Name = "MenuBoard", Size = Vector3.new(8, 3.2, 0.2), CFrame = cf * CFrame.new(0, 11.4, 6.9 + DEEP), Color = C(24, 22, 20), Material = M.SmoothPlastic, CanCollide = false })
    Text(menu, Enum.NormalId.Front, HubCity.ZH[t.Anchor] or t.Title, C(250, 236, 200), { PPS = 20, Brightness = 1.6, Font = Enum.Font.GothamBold, Sub = string.upper(t.Sub or ""), SubColor = col })
    Q({ Name = "ShopGlow", Size = Vector3.new(20, 0.3, 0.3), CFrame = cf * CFrame.new(0, 13.6, 6.8 + DEEP), Color = col, Material = M.Neon, CanCollide = false })
    Q({ Name = "LampHousing", Size = Vector3.new(7, 0.3, 0.9), CFrame = cf * CFrame.new(0, 13.85, 1), Color = C(170, 172, 168), Material = M.Metal, CanCollide = false })
    local lamp = Q({ Name = "ShopLamp", Size = Vector3.new(6.4, 0.22, 0.22), CFrame = cf * CFrame.new(0, 13.6, 1), Color = C(255, 240, 220), Material = M.Neon, CanCollide = false }) -- (UPDATE 4: a fluorescent tube)
    Light(lamp, "PointLight", { Range = 20, Brightness = 1.6, Color = col:Lerp(C(255, 230, 190), 0.5), Shadows = false })
    -- the half-up roll shutter + its box
    Q({ Name = "ShutterBox", Size = Vector3.new(22, 1.6, 1.4), CFrame = cf * CFrame.new(0, 13.2, -5.2), Color = C(70, 72, 76), Material = M.Metal })
    Q({ Name = "Shutter", Size = Vector3.new(21, 2.4, 0.2), CFrame = cf * CFrame.new(0, 11.4, -5.3), Color = C(104, 106, 110):Lerp(col, 0.1), Material = M.CorrodedMetal, CanCollide = false }) -- (UPDATE 4: tin, not diamond plate)
    -- the awning, sloping out over the street
    local awning = Q({ Name = "Awning", Size = Vector3.new(23, 0.25, 4.6), CFrame = cf * CFrame.new(0, 12.4, -7.4) * CFrame.Angles(math.rad(-18), 0, 0), Color = col:Lerp(C(40, 30, 30), 0.45), Material = M.Fabric, CanCollide = false })
    for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front }) do -- (UPDATE 4: striped canvas)
        local st = HubCity.Img(awning, face, HubCity.IMG.Stripes, 4.6)
        if st then st.StudsPerTileV = 4.6 end
    end
    -- the shop board over the awning: Chinese name + the station's English name
    -- (UPDATE 4: a LIGHTBOX with depth -- 1.6 deep, its front where the flat board's was, steel side caps)
    local board = Q({ Name = "ShopBoard", Size = Vector3.new(22, 4.6, 1.6), CFrame = cf * CFrame.new(0, 16.8, -5.1), Color = C(16, 14, 18), Material = M.Metal })
    for _, sx in ipairs({ -1, 1 }) do
        Q({ Name = "ShopBoardCap", Size = Vector3.new(0.35, 5.1, 1.9), CFrame = cf * CFrame.new(sx * 11.15, 16.8, -5.1), Color = C(54, 56, 62), Material = M.Metal, CanCollide = false })
    end
    -- (readable: the plain title big with low glow + a dark outline, the Chinese name + hint small underneath)
    local bsg = Text(board, Enum.NormalId.Front, t.Title, col, { PPS = 22, Sub = ((HubCity.ZH[t.Anchor] and (HubCity.ZH[t.Anchor] .. "  •  ")) or "") .. string.upper(t.Sub or ""),
        SubColor = C(235, 230, 220), Brightness = 1.5, Stroke = C(10, 6, 8), StrokeT = 0.2, Font = Enum.Font.GothamBlack })
    Q({ Name = "ShopBoardNeon", Size = Vector3.new(22.4, 0.25, 0.25), CFrame = cf * CFrame.new(0, 14.4, -5.95), Color = col, Material = M.Neon, CanCollide = false })
    -- (UPDATE 4: neon-TUBE lettering -- a soft glow stroke in the shop's colour round the title, like a bent glass tube)
    local title = bsg:FindFirstChildWhichIsA("TextLabel")
    if title then
        local gs = Instance.new("UIStroke"); gs.Color = col; gs.Thickness = 2.2; gs.Transparency = 0.45; gs.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; gs.Parent = title
    end
    -- (UPDATE 4) SHOPFRONT VARIANTS (owner: the hub reads repetitive -- 8 shops off one template): each station gets its own
    -- sign frame, awning and street-side extra (deterministic per anchor)
    local VAR = HubCity.SHOP_VARIANT[t.Anchor] or HubCity.SHOP_VARIANT.Default
    if VAR.Sign == "Tubes" then -- a full neon tube frame round the board
        Q({ Name = "ShopBoardNeon", Size = Vector3.new(22.4, 0.25, 0.25), CFrame = cf * CFrame.new(0, 19.25, -5.95), Color = col, Material = M.Neon, CanCollide = false })
        for _, sx in ipairs({ -1, 1 }) do
            Q({ Name = "ShopBoardNeon", Size = Vector3.new(0.25, 5.1, 0.25), CFrame = cf * CFrame.new(sx * 11.2, 16.8, -5.95), Color = col, Material = M.Neon, CanCollide = false })
        end
    elseif VAR.Sign == "Lightbox" and HubCity.CALM.ShopLightbox then -- a projecting lit box sign at the board's end, its Chinese name stacked
        local lb = Q({ Name = "ShopLightbox", Size = Vector3.new(0.9, 7.5, 3), CFrame = cf * CFrame.new(11.6, 16.2, -7.8), Color = C(242, 236, 214), Material = M.SmoothPlastic, CanCollide = false })
        for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
            Text(lb, face, Vertical(HubCity.ZH[t.Anchor] or "店"), C(170, 24, 24), { PPS = 18, Brightness = 1.6, StrokeT = 1 })
        end
    end
    if VAR.Flicker and title then CS:AddTag(title, "HubFlicker") end
    if VAR.Awning == "Solid" then
        for _, d in ipairs(awning:GetChildren()) do if d:IsA("Texture") then d:Destroy() end end
        awning.Color = col:Lerp(C(30, 26, 26), 0.6)
    elseif VAR.Awning == "Valance" then -- a striped valance hanging off the awning's front edge
        local va = Q({ Name = "AwningValance", Size = Vector3.new(23, 1.1, 0.15), CFrame = cf * CFrame.new(0, 11.2, -9.6), Color = col:Lerp(C(40, 30, 30), 0.45), Material = M.Fabric, CanCollide = false })
        local st = HubCity.Img(va, Enum.NormalId.Front, HubCity.IMG.Stripes, 4.6)
        if st then st.StudsPerTileV = 1.1 end
    end
    local ex = cf * CFrame.new(0, 0, -11.5) -- (the sidewalk in front of the shop)
    if not HubCity.CALM.ShopExtra[VAR.Extra or ""] then -- (HUB DECLUTTER: nothing in front of the counter)
    elseif VAR.Extra == "Lanterns" then
        for _, sx in ipairs({ -1, 1 }) do
            Q({ Name = "LanternCord", Size = Vector3.new(0.08, 1.4, 0.08), CFrame = cf * CFrame.new(sx * 10.6, 11.4, -9.4), Color = C(20, 16, 14), Material = M.SmoothPlastic, CanCollide = false })
            HubCity.PaperLantern(Q, cf * CFrame.new(sx * 10.6, 10, -9.4), 1.3, C(210, 36, 34))
        end
    elseif VAR.Extra == "Plants" then
        for _, sx in ipairs({ -1, 1 }) do
            -- (HUB LOOK: two identical ball-on-a-pot twins -> each pot its own size, the plant its own height / lean / green)
            local vr = Random.new(#t.Anchor * 131 + sx * 7)
            local ps, lh = vr:NextNumber(0.85, 1.15), vr:NextNumber(2.6, 4)
            Q({ Name = "PlantPot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6 * ps, 1.8 * ps, 1.8 * ps), CFrame = ex * CFrame.new(sx * 8.5, 0.4 + 0.8 * ps, 1) * CFrame.Angles(0, 0, math.rad(90)), Color = C(150, 70, 46):Lerp(C(110, 96, 84), vr:NextNumber()), Material = M.Concrete })
            Q({ Name = "PlantLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2 * ps, lh, 2.2 * ps), CFrame = ex * CFrame.new(sx * 8.5, 0.4 + 1.6 * ps + lh * 0.42, 1) * CFrame.Angles(math.rad(vr:NextNumber(-6, 6)), 0, math.rad(vr:NextNumber(-6, 6))),
                Color = C(52, 96, 52):Lerp(C(70, 92, 44), vr:NextNumber()), Material = M.LeafyGrass, CanCollide = false })
        end
    elseif VAR.Extra == "AFrame" then -- a chalk menu board out on the sidewalk
        local af = Q({ Name = "AFrame", Size = Vector3.new(2.6, 3.4, 0.2), CFrame = ex * CFrame.new(-7.5, 0.4 + 1.7, 0) * CFrame.Angles(math.rad(-12), math.rad(20), 0), Color = C(28, 30, 30), Material = M.SmoothPlastic, CanCollide = false })
        Text(af, Enum.NormalId.Front, (HubCity.ZH[t.Anchor] or "") .. "\n營業中", C(240, 236, 220), { PPS = 30, Lit = true, Brightness = 1.1, StrokeT = 1, Font = Enum.Font.GothamBold })
    elseif VAR.Extra == "Crates" then
        for k = 0, 2 do
            local cr = Q({ Name = "GoodsCrate", Size = Vector3.new(2.2, 1.8, 1.8), CFrame = ex * CFrame.new(-8 + (k % 2) * 2.3, 0.4 + 0.9 + math.floor(k / 2) * 1.8, 1) * CFrame.Angles(0, math.rad(k * 7), 0), Color = C(120, 90, 56), Material = M.WoodPlanks })
            local gd = HubCity.Img(cr, Enum.NormalId.Front, HubCity.IMG.Goods[(k % 3) + 1])
            if gd then gd.Transparency = 0.1 end
        end
    elseif VAR.Extra == "AC" then
        Q({ Name = "ShopAC", Size = Vector3.new(3, 2, 1.6), CFrame = cf * CFrame.new(-8, 21.5, -6.4), Color = C(176, 172, 164), Material = M.Metal, CanCollide = false })
        Q({ Name = "ShopACGrille", Size = Vector3.new(1.6, 1.6, 0.05), CFrame = cf * CFrame.new(-7.6, 21.5, -7.22), Color = C(40, 40, 40), Material = M.DiamondPlate, CanCollide = false })
    end
    -- a neon blade sign on the shop's left corner at street level (the station's name, vertical; kept below the leaderboards)
    if HubCity.CALM.ShopBlade then
        local blade = Q({ Name = "ShopBlade", Size = Vector3.new(3.2, 11, 0.6), CFrame = cf * CFrame.new(-12.2, 7.5, -7) * CFrame.Angles(0, math.rad(90), 0), Color = C(14, 12, 16), Material = M.Metal })
        for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
            Text(blade, face, Vertical(HubCity.ZH[t.Anchor] or ""), col, { PPS = 18, Brightness = 1.6, Stroke = C(10, 6, 8), StrokeT = 0.3 })
        end
    end
    -- counter (the ANCHOR: name + prompt; same spot as the old booth counter)
    local counter = Q({ Name = t.Anchor, Size = Vector3.new(14, 3.6, 3), CFrame = cf * CFrame.new(0, 2.6, -4), Color = C(62, 52, 44), Material = M.WoodPlanks, CanCollide = true })
    counter.CanQuery = true
    Q({ Name = "CounterTop", Size = Vector3.new(14.3, 0.3, 3.3), CFrame = cf * CFrame.new(0, 4.55, -4), Color = col:Lerp(C(40, 40, 44), 0.6), Material = M.Metal, CanCollide = false })
    Q({ Name = "CounterNeon", Size = Vector3.new(14, 0.2, 0.2), CFrame = cf * CFrame.new(0, 4.3, -5.55), Color = col, Material = M.Neon, CanCollide = false })
    -- (UPDATE 4) a dark recessed kick under the counter's front and a glass display case of goods on its end
    Q({ Name = "CounterKick", Size = Vector3.new(13.4, 0.9, 0.3), CFrame = cf * CFrame.new(0, 1.25, -5.42), Color = C(28, 24, 22), Material = M.Metal, CanCollide = false })
    local case = Q({ Name = "DisplayCase", Size = Vector3.new(4.2, 1.7, 2.4), CFrame = cf * CFrame.new(-4.4, 5.55, -4), Color = C(190, 220, 235), Material = M.SmoothPlastic, Transparency = 0.72, CanCollide = false })
    HubCity.Img(case, Enum.NormalId.Front, HubCity.IMG.Goods[((#t.Anchor + 1) % 3) + 1])
    Prompt(counter, t.PromptName, t.Action, t.Object, 16)
    HubCity.WetGlow(Q, cf * CFrame.new(0, 0.44, -15.5), 11, 16, col, 0.4) -- (UPDATE 4: the shop's neon on the wet sidewalk)
    if THEMES[t.Anchor] then THEMES[t.Anchor](m, cf, col, Q) end
    m.WorldPivot = cf
    counter.Parent = hub -- (the server script finds the prompt by this name under HubWorld)
    return counter
end

return HubCity
