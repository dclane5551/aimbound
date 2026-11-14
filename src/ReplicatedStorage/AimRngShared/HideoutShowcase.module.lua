--!nocheck
-- ============================================================================================
-- HIDEOUT SHOWCASE (UPDATE 6, owner: "Add way more interactables into hideout (display your titles instead of just showing
-- colors, other potential ideas)" -> picked all six). The client side of the showcase pieces (HideoutData catalog entries
-- with a `Show` field; server: Hideouts.Showcase publishes the OWNER's data as the owner attr "HideoutShowcase" JSON):
--   Titles   (TitleWall)    the owner's titles by name on plaques, rarest first; the worn one on the banner; a full list
--   Stats    (StatsBoard)   lifetime numbers chalked on a slate; the window has the whole sheet
--   Trophies (TrophyShelf)  a cup per boss trial cleared (bronze / silver / gold / platinum by tier), an exotic crystal per
--                           exotic owned, the best full clear on the banner; the window lists everything
--   Rack     (WeaponRack)   the owner's three racked guns as real models in their skins (+ colourway); the window:
--                           inspect, EQUIP (owner), SET a slot from your guns, EMPTY it
--   Jukebox  (Jukebox)      the owner picks a track (HideoutData.MUSIC); everyone inside hears it; MUTE FOR ME is local
--   Arcade   (ArcadeCabinet) AIM ARCADE: 20 s of targets, faster hits score more, server-checked personal best
-- Everything here works in every theme (they're furniture). Owner-only actions are refused by the server too.
--   HideoutShowcase.Init(menuFolder, hooks, act) -> api { Dress(model, def, data), Open(kind, data, isOwn), Music(data, here),
--   Step(t) (the jukebox glow), Data(owner) }
-- ============================================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HD = require(Shared:WaitForChild("HideoutData"))

local HideoutShowcase = {}
local C = UIStyle.Colors
local New = UIStyle.New
local V, CF, ANG, R = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local FN = ItemData.FormatNumber
local CHALK, DIM = Color3.fromRGB(236, 236, 226), Color3.fromRGB(120, 124, 132)
local TIER_COL = { -- (trophy metal by the best tier cleared)
    { 2, Color3.fromRGB(176, 112, 62), "BRONZE" }, { 4, Color3.fromRGB(196, 202, 214), "SILVER" },
    { 7, Color3.fromRGB(240, 196, 80), "GOLD" }, { 99, Color3.fromRGB(170, 228, 255), "PLATINUM" },
}

local function Dur(sec: number): string
    sec = math.max(0, math.floor(sec))
    local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%dm %02ds", m, sec % 60)
end
local function RarCol(r: string?): Color3 return (r and ItemData.RarityColors[r]) or C.Text end
local function TierCol(t: number): (Color3, string)
    for _, e in ipairs(TIER_COL) do if t <= e[1] then return e[2], e[3] end end
    return TIER_COL[#TIER_COL][2], TIER_COL[#TIER_COL][3]
end
local function TierName(t: number): string
    local tr = HD and require(Shared:WaitForChild("BossTrials")).Tiers[t]
    return tr and (tr.Name .. "  (" .. tr.Difficulty .. ")") or ("TIER " .. t)
end
-- a self-lit text face on a part (its Front = the piece's front)
local function Surface(part: BasePart, pps: number?): SurfaceGui
    local old = part:FindFirstChild("ShowGui")
    if old then old:Destroy() end
    local sg = Instance.new("SurfaceGui")
    sg.Name = "ShowGui"; sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = pps or 60; sg.LightInfluence = 0; sg.Brightness = 1.25; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = part
    return sg
end
local function TL(parent: Instance, text: string, props: any): TextLabel
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Text = text; t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.TextColor3 = CHALK
    t.Size = UDim2.fromScale(1, 1)
    t:SetAttribute("KeepFont", true)
    for k, v in pairs(props or {}) do t[k] = v end
    t.Parent = parent
    return t
end
local function Deco(m: Instance, cf: CFrame, size: Vector3, col: Color3, mat: Enum.Material?, o: any?): BasePart
    local p = Instance.new((o and o.Shape == "Cyl") and "Part" or "Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Size = size; p.CFrame = cf; p.Color = col; p.Material = mat or Enum.Material.SmoothPlastic
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    if o and o.Shape == "Cyl" then p.Shape = Enum.PartType.Cylinder end
    if o and o.Shape == "Ball" then p.Shape = Enum.PartType.Ball end
    if o and o.T then p.Transparency = o.T end
    p.Parent = m
    return p
end
local function Cyl(m, cf, len, dia, col, mat, o) -- along cf's Y
    o = o or {}; o.Shape = "Cyl"
    return Deco(m, cf * ANG(0, 0, R(90)), V(len, dia, dia), col, mat, o)
end

function HideoutShowcase.Init(menuFolder: Instance, hooks: any, act: (...any) -> (any, any))
    local api = {}
    local SkinFX, WorldGear
    local function Gear()
        if WorldGear == nil then
            local ok, m = pcall(require, Shared:WaitForChild("WorldGear"))
            WorldGear = ok and m or false
            local ok2, s = pcall(require, Shared:WaitForChild("SkinFX"))
            SkinFX = ok2 and s or false
        end
        return WorldGear
    end
    function api.Data(owner: Player?): any
        local js = owner and owner:GetAttribute("HideoutShowcase")
        if type(js) ~= "string" then return {} end
        local ok, t = pcall(HttpService.JSONDecode, HttpService, js)
        return (ok and type(t) == "table") and t or {}
    end
    -- the gun model for a rack entry (its skin + colourway; exotic mark) -> model (anchored, decoration only)
    local function RackGun(e: any): Model?
        if not (e and e.g) or not Gear() then return nil end
        local skin = e.s and SkinFX and SkinFX.GunSkinById[e.s] or nil
        if skin and (e.v or 1) > 1 and skin.Set then
            local ok, vs = pcall(function() return SkinFX.Sets[skin.Set .. "#" .. e.v] end)
            local alt = ok and vs and vs.SkinById and vs.SkinById[e.s]
            if alt then skin = alt end
        end
        local ok, model = pcall(WorldGear.Gun, e.g, skin, e.x)
        if not (ok and model) then return nil end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
        end
        return model
    end
    -- put a model on a spot: its bounding box centred on the spot's X / Z, its bottom at the spot's Y + lift, at most `maxLen` long
    -- the box of a model's visible parts in a frame's space (exact: every corner of every part)
    local function LocalBox(model: Model, frame: CFrame): (Vector3, Vector3)
        local mn, mx = V(1e9, 1e9, 1e9), V(-1e9, -1e9, -1e9)
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.98 then
                local h = p.Size / 2
                for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
                    local q = frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(V(h.X * sx, h.Y * sy, h.Z * sz)))
                    mn, mx = mn:Min(q), mx:Max(q)
                end end end
            end
        end
        return mn, mx
    end
    -- lay a gun on a spot: its frame along the spot (barrel along X), scaled to `fitLen` long, centred, resting on the spot + lift
    local function SitOn(model: Model, spot: CFrame, lift: number, fitLen: number, maxH: number?)
        local fr = model:FindFirstChild("Frame")
        if fr and fr:IsA("BasePart") then model:PivotTo(spot * fr.CFrame:ToObjectSpace(model:GetPivot())) else model:PivotTo(spot) end
        local mn, mx = LocalBox(model, spot)
        local len, ht = math.max(mx.X - mn.X, 0.1), math.max(mx.Y - mn.Y, 0.1)
        model:ScaleTo(model:GetScale() * math.clamp(math.min(fitLen / len, (maxH or 99) / ht), 0.4, 3)) -- (long guns by length, pistols by height)
        mn, mx = LocalBox(model, spot)
        local c = (mn + mx) / 2
        model:PivotTo(model:GetPivot() + spot:VectorToWorldSpace(V(-c.X, lift - mn.Y, -c.Z)))
    end

    -- ===================== dressing the pieces =====================
    local function DressTitles(m: Model, data: any)
        local T = data.T or {}
        local banner = m:FindFirstChild("TitleBanner", true)
        if banner then
            local eq = data.E and ItemData.Titles[data.E]
            local sg = Surface(banner, 50)
            TL(sg, eq and string.upper(eq.Title) or ((#T > 0) and "NO TITLE WORN" or "NO TITLES YET"),
                { TextColor3 = eq and RarCol(eq.Rarity) or Color3.fromRGB(240, 220, 190), Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1) })
        end
        for i = 1, 8 do
            local pl = m:FindFirstChild("TitlePlaque" .. i, true)
            local edge = m:FindFirstChild("TitleEdge" .. i, true)
            local t = T[i] and ItemData.Titles[T[i]]
            if pl then
                local sg = Surface(pl, 60)
                if t then
                    local col = RarCol(t.Rarity)
                    TL(sg, string.upper(t.Title), { TextColor3 = col, Size = UDim2.fromScale(0.9, 0.56), Position = UDim2.fromScale(0.05, 0.1), TextWrapped = true })
                    TL(sg, string.upper(t.Rarity or ""), { TextColor3 = Color3.fromRGB(200, 196, 186), Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.8, 0.2), Position = UDim2.fromScale(0.1, 0.72) })
                    if edge then edge.Color = col end
                else
                    TL(sg, "•", { TextColor3 = DIM, Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.25, 0.25) })
                    if edge then edge.Color = Color3.fromRGB(70, 70, 76) end
                end
            end
        end
    end
    local function StatRows(data: any): { any }
        local s = data.S or {}
        local function N(k) return tonumber(s[k]) or 0 end
        local acc = (N("s") > 0) and string.format("%.1f%%", 100 * N("i") / N("s")) or "-"
        local kd = (N("d") > 0) and string.format("%.2f", N("o") / N("d")) or ((N("o") > 0) and "NO DEATHS" or "-")
        return {
            { "KILLS", FN(N("k")) }, { "WEAK-SPOT KILLS", FN(N("w")) }, { "DEATHS", FN(N("d")) }, { "KILLS / DEATH", kd },
            { "BOSSES", FN(N("b")) }, { "ELITES", FN(N("e")) }, { "RUNS / CLEARED", FN(N("r")) .. " / " .. FN(N("c")) },
            { "DEEPEST FLOOR", (N("h") > 0) and ("FLOOR " .. N("h")) or "-" }, { "ACCURACY", acc }, { "TIME PLAYED", Dur(N("t")) },
            { "FLOORS CLEARED", FN(N("f")) }, { "MELEE KILLS", FN(N("m")) }, { "BEST STREAK", FN(N("q")) }, { "LEVEL", tostring(N("l")) },
        }
    end
    local function DressStats(m: Model, data: any)
        local scr = m:FindFirstChild("StatsScreen", true)
        if not scr then return end
        local sg = Surface(scr, 50)
        TL(sg, string.upper(tostring(data.N or "")) .. "'S RECORD", { TextColor3 = Color3.fromRGB(255, 214, 140), Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.05, 0.03) })
        local rows = StatRows(data)
        for i = 1, 10 do
            local r = rows[i]
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            local x, y = 0.05 + col * 0.47, 0.19 + row * 0.16
            TL(sg, r[1], { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(170, 190, 180), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.42, 0.06), Position = UDim2.fromScale(x, y) })
            TL(sg, r[2], { TextColor3 = CHALK, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.42, 0.085), Position = UDim2.fromScale(x, y + 0.058) })
        end
    end
    local function Cup(m: Model, at: CFrame, tier: number)
        local col = TierCol(tier)
        Deco(m, at * CF(0, 0.14, 0), V(0.95, 0.28, 0.95), Color3.fromRGB(30, 28, 34), Enum.Material.Marble)
        Cyl(m, at * CF(0, 0.5, 0), 0.45, 0.18, col, Enum.Material.Metal)
        Cyl(m, at * CF(0, 1.0, 0), 0.62, 0.7, col, Enum.Material.Metal)
        Cyl(m, at * CF(0, 1.33, 0), 0.05, 0.78, col:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon, { T = 0.2 })
        for sx = -1, 1, 2 do Deco(m, at * CF(sx * 0.43, 1.05, 0), V(0.22, 0.38, 0.1), col, Enum.Material.Metal) end
        if tier >= 5 then Deco(m, at * CF(0, 0.85, -0.36) * ANG(0, 0, R(45)), V(0.16, 0.16, 0.06), Color3.fromRGB(255, 240, 200), Enum.Material.Neon) end
    end
    local function Crystal(m: Model, at: CFrame) -- (an exotic: a faceted orange crystal standing in a dark iron setting)
        local col = ItemData.EXOTIC_COLOR or Color3.fromRGB(255, 150, 40)
        Deco(m, at * CF(0, 0.16, 0), V(0.8, 0.32, 0.8), Color3.fromRGB(28, 24, 22), Enum.Material.Basalt)
        Cyl(m, at * CF(0, 0.38, 0), 0.14, 0.62, Color3.fromRGB(60, 50, 44), Enum.Material.Metal)
        Deco(m, at * CF(0, 0.95, 0) * ANG(0, R(45), 0), V(0.42, 0.95, 0.42), col, Enum.Material.Neon, { T = 0.15 })
        Deco(m, at * CF(0, 1.5, 0) * ANG(0, R(45), 0) * ANG(R(45), 0, 0), V(0.3, 0.3, 0.3), col, Enum.Material.Neon, { T = 0.15 })
        Deco(m, at * CF(0.22, 0.75, 0.1) * ANG(0, R(20), R(-25)), V(0.2, 0.5, 0.2), col:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Neon, { T = 0.2 })
    end
    local function DressTrophies(m: Model, data: any)
        local list = {}
        local BossTrials = require(Shared:WaitForChild("BossTrials"))
        for _, b in ipairs(BossTrials.Bosses) do
            local t = data.B and tonumber(data.B[b.Id])
            if t and t > 0 then table.insert(list, { "Cup", t }) end
        end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for _, x in ipairs(data.X or {}) do table.insert(list, { "Exotic", x }) end
        local ORDER = { 4, 5, 6, 7, 8, 9, 1, 2, 3 } -- (the middle shelf first: eye level, then the top, then the bottom)
        for k = 1, 9 do
            local slot = m:FindFirstChild("TrophySlot" .. ORDER[k], true)
            local e = list[k]
            if slot and e then
                if e[1] == "Cup" then Cup(m, slot.CFrame, e[2]) else Crystal(m, slot.CFrame) end
            end
        end
        local ban = m:FindFirstChild("TrophyBanner", true)
        if ban then
            local sg = Surface(ban, 50)
            TL(sg, data.C and ("BEST CLEAR: " .. string.upper(data.C)) or "NO FULL CLEAR YET", { TextColor3 = Color3.fromRGB(255, 214, 140), Size = UDim2.fromScale(0.94, 0.7), Position = UDim2.fromScale(0.03, 0.15) })
        end
    end
    local function DressRack(m: Model, data: any)
        for i = 1, 3 do
            local e = data.K and data.K[tostring(i)]
            local slot = m:FindFirstChild("RackSlot" .. i, true)
            local tag = m:FindFirstChild("RackTag" .. i, true)
            if slot and e then
                local g = RackGun(e)
                if g then
                    g.Name = "RackGun" .. i
                    g.Parent = m
                    SitOn(g, slot.CFrame, -0.25, 5.6, 1.05)
                end
            end
            if tag then
                local sg = Surface(tag, 60)
                TL(sg, e and string.upper(e.n or e.g) or "EMPTY", { TextColor3 = e and RarCol(e.r) or DIM, Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1) })
            end
        end
    end
    local function DressJukebox(m: Model, data: any)
        local lab = m:FindFirstChild("JukeLabel", true)
        if not lab then return end
        local t = data.M and HD.MusicById[data.M]
        local sg = Surface(lab, 60)
        TL(sg, t and ("NOW PLAYING  •  " .. string.upper(t.Name)) or "JUKEBOX OFF", { TextColor3 = t and Color3.fromRGB(255, 200, 120) or DIM, Size = UDim2.fromScale(0.94, 0.7), Position = UDim2.fromScale(0.03, 0.15) })
        m:SetAttribute("Playing", t ~= nil)
    end
    local function DressArcade(m: Model, data: any)
        local scr = m:FindFirstChild("ArcadeScreen", true)
        if not scr then return end
        local sg = Surface(scr, 60)
        local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.fromRGB(10, 6, 24); bg.BorderSizePixel = 0; bg.Parent = sg
        local grad = Instance.new("UIGradient"); grad.Rotation = 90
        grad.Color = ColorSequence.new(Color3.fromRGB(40, 14, 70), Color3.fromRGB(8, 10, 30)); grad.Parent = bg
        TL(bg, "AIM ARCADE", { TextColor3 = Color3.fromRGB(255, 110, 190), Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.05, 0.06) })
        TL(bg, "HI-SCORE", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(110, 230, 255), Size = UDim2.fromScale(0.6, 0.11), Position = UDim2.fromScale(0.2, 0.34) })
        TL(bg, FN(tonumber(data.P) or 0), { TextColor3 = Color3.fromRGB(255, 236, 140), Size = UDim2.fromScale(0.8, 0.24), Position = UDim2.fromScale(0.1, 0.46) })
        TL(bg, string.upper(tostring(data.N or "")), { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 196, 220), Size = UDim2.fromScale(0.8, 0.09), Position = UDim2.fromScale(0.1, 0.71) })
        TL(bg, "20 SECONDS  •  PRESS TO PLAY", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 255, 170), Size = UDim2.fromScale(0.9, 0.08), Position = UDim2.fromScale(0.05, 0.86) })
    end
    function api.Dress(m: Model, def: any, data: any)
        local k = def.Show
        local ok, err = pcall(function()
            if k == "Titles" then DressTitles(m, data)
            elseif k == "Stats" then DressStats(m, data)
            elseif k == "Trophies" then DressTrophies(m, data)
            elseif k == "Rack" then DressRack(m, data)
            elseif k == "Jukebox" then DressJukebox(m, data)
            elseif k == "Arcade" then DressArcade(m, data) end
        end)
        if not ok then warn("[Showcase] " .. tostring(k) .. ": " .. tostring(err)) end
    end

    -- ===================== the music =====================
    -- (2026-10-24 JUKEBOX v2) a station = a list of licensed-library tracks (HideoutData.MUSIC Tracks), played in order from a
    -- random one and round again; Volume = the track's measured trim (the city music's level) on the Music sound group, so the
    -- Settings > Audio > Music slider applies. Attr "Station" on the Sound while one is on: HubMusic yields to it (also while
    -- the next track loads).
    local music: Sound? = nil
    local muted = false
    local playingId = nil
    local queue, qi = nil, 0
    local LEVEL = 1
    pcall(function() LEVEL = require(Shared:WaitForChild("HubMusic")).LEVEL or 1 end)
    local function PlayTrack()
        local tr = queue and queue[qi]
        if not (music and tr) then return end
        music.SoundId = "rbxassetid://" .. tostring(tr.Id)
        music.Volume = (tr.Volume or 0.45) * LEVEL
        music.TimePosition = 0
        music:Play()
    end
    function api.Music(data: any?, holder: Instance?)
        local id = data and data.M
        local t = id and HD.MusicById[id]
        if not (t and holder) or muted then
            api.StopMusic()
            return
        end
        if not music or music.Parent ~= holder then
            if music then music:Destroy() end
            local s = Instance.new("Sound")
            s.Name = "HideoutMusic"; s.Looped = false; s.Volume = 0.45
            s.SoundGroup = game:GetService("SoundService"):FindFirstChild("AimRngMix_Music")
            s.Ended:Connect(function()
                if music == s and playingId and queue then
                    qi = qi % #queue + 1
                    -- (a Play() inside the Ended callback is ignored by the engine -- measured: the next track sat at 0:00)
                    local st = playingId
                    task.delay(0.1, function()
                        if music == s and playingId == st then PlayTrack() end
                    end)
                end
            end)
            music = s
            playingId = nil
            s.Parent = holder
        end
        if playingId ~= id then
            playingId = id
            queue = t.Tracks
            qi = math.random(1, #queue)
            music:SetAttribute("Station", id)
            PlayTrack()
        end
    end
    function api.StopMusic()
        if music then music:Stop(); music:SetAttribute("Station", nil) end
        playingId = nil
    end
    function api.NowPlaying(): any? -- (the jukebox window's NOW line: this client's current track)
        return playingId and queue and queue[qi] or nil
    end

    -- ===================== the windows =====================
    local panels = {}
    local function Win(kind: string, title: string, sub: string, accent: Color3): (Frame, Frame)
        local pp = panels[kind]
        if not pp then
            local panel = UIStyle.Panel(menuFolder, { Name = "Showcase" .. kind, Size = UDim2.fromOffset(820, 600), Accent = accent })
            UIStyle.TitleBar(panel, title, accent, sub, function() hooks.CloseAll() end)
            local body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 80), Size = UDim2.new(1, -32, 1, -96), Parent = panel })
            pp = { panel, body }
            panels[kind] = pp
        end
        for _, c in ipairs(pp[2]:GetChildren()) do c:Destroy() end
        return pp[1], pp[2]
    end
    local function Scroll(parent: Instance, pos: UDim2, size: UDim2): ScrollingFrame
        local sf = New("ScrollingFrame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = pos, Size = size, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent }, { UIStyle.Corner(2) })
        New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
        New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6), Parent = sf })
        return sf
    end
    local function Text(parent: Instance, props: any): TextLabel props.Parent = parent return UIStyle.Text(props) end
    local function Show(panel: Frame)
        if not panel.Visible then hooks.OpenFrame(panel) end
    end
    local Open -- (forward)

    local function OpenTitles(data: any)
        local panel, body = Win("Titles", "TITLE WALL", "every title " .. tostring(data.N or "") .. " has earned, rarest first", C.Gold)
        local T = data.T or {}
        local eq = data.E and ItemData.Titles[data.E]
        Text(body, { Text = string.format("%d TITLES EARNED%s", #T, eq and ("  •  WEARING: " .. string.upper(eq.Title)) or ""), TextSize = 16, TextColor3 = C.Gold, Size = UDim2.new(1, 0, 0, 24) })
        local list = Scroll(body, UDim2.fromOffset(0, 32), UDim2.new(1, 0, 1, -32))
        if #T == 0 then Text(list, { Text = "No titles yet. Titles come from clears, bosses, kills and streaks (Index > Titles).", TextSize = 14, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40) }) end
        for i, id in ipairs(T) do
            local t = ItemData.Titles[id]
            if t then
                local col = RarCol(t.Rarity)
                local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, Parent = list }, { UIStyle.Corner(2) })
                New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 5, 1, -8), Position = UDim2.fromOffset(4, 4), Parent = row })
                Text(row, { Text = string.upper(t.Title) .. ((id == data.E) and "   (WORN)" or ""), TextSize = 16, TextColor3 = col, Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -150, 0, 22) })
                Text(row, { Text = (t.Description or "") .. ((t.Requirement and ("  •  " .. t.Requirement)) or ""), TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -150, 0, 18) })
                Text(row, { Text = string.upper(t.Rarity or ""), TextSize = 13, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -140, 0, 0), Size = UDim2.new(0, 130, 1, 0) })
            end
        end
        Show(panel)
    end
    local function OpenStats(data: any)
        local panel, body = Win("Stats", "STATS BOARD", tostring(data.N or "") .. "'s lifetime numbers", C.Info) -- (PLAYTEST 2026-10-31: "(most count from Update 5 on)" was stale after the launch wipes)
        local list = Scroll(body, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0))
        for i, r in ipairs(StatRows(data)) do
            local row = New("Frame", { BackgroundColor3 = C.Bg1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, Parent = list }) -- (UI CLEAN audit: open rows + a hairline, no zebra)
            do local hl = New("Frame", { BackgroundColor3 = C.Text, BackgroundTransparency = 0.92, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), Parent = row }); hl:SetAttribute("Skinned", true) end
            UIStyle.TextRole(Text(row, { Text = r[1], TextSize = 15, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.6, 0, 1, 0) }), "Label")
            UIStyle.TextRole(Text(row, { Text = r[2], TextSize = 17, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -14, 1, 0) }), "Title")
        end
        Show(panel)
    end
    local function OpenTrophies(data: any)
        local panel, body = Win("Trophies", "TROPHY SHELF", tostring(data.N or "") .. "'s boss trials, relics and best clears", C.Gold)
        local list = Scroll(body, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0))
        local n = 0
        local function Head(t) n += 1; local h = UIStyle.SectionHeader(list, t, { Height = 30 }); h.LayoutOrder = n end
        local function Row(a, b, col)
            n += 1
            local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = n, Parent = list }, { UIStyle.Corner(2) })
            Text(row, { Text = a, TextSize = 15, TextColor3 = col or C.Text, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.55, 0, 1, 0) })
            Text(row, { Text = b, TextSize = 14, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -14, 1, 0) })
        end
        Head("BOSS TRIALS")
        local any = false
        for _, b in ipairs(require(Shared:WaitForChild("BossTrials")).Bosses) do
            local t = data.B and tonumber(data.B[b.Id])
            if t and t > 0 then
                any = true
                local col, metal = TierCol(t)
                Row(b.Name, metal .. "  •  BEST " .. TierName(t), col)
            end
        end
        if not any then Row("No boss trial cleared yet", "Challenges > BOSSES", C.Sub) end
        Head("RELICS")
        if #(data.X or {}) == 0 then Row("No relics yet", "bosses, trials and maps drop them", C.Sub) end
        for _, x in ipairs(data.X or {}) do
            local ex = ItemData.Exotics and ItemData.Exotics[x]
            Row("◆ " .. string.upper(ex and ex.Name or tostring(x)), ex and (ex.Kind or ex.Type or "RELIC") or "RELIC", ItemData.EXOTIC_COLOR or C.Warn)
        end
        Head("BEST CLEARS")
        Row("Best full run cleared", data.C and string.upper(data.C) or "none yet", C.Gold)
        Row("The Proving", (tonumber(data.A) or 0) > 0 and ("TIER " .. data.A) or "-", C.Text)
        Row("Highest map tier", (tonumber(data.R) or 0) > 0 and ("TIER " .. data.R) or "-", C.Text)
        Show(panel)
    end
    local function GunView(parent: Instance, e: any, size: UDim2, pos: UDim2)
        local vp = New("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(44, 42, 50), Size = size, Position = pos, Ambient = Color3.fromRGB(235, 232, 236),
            LightColor = Color3.fromRGB(255, 248, 240), LightDirection = V(0.4, -0.6, 1), Parent = parent }, { UIStyle.Corner(2) })
        local g = RackGun(e)
        if g then
            g.Parent = vp
            local cf, sz = g:GetBoundingBox()
            local r = math.max(sz.X, sz.Y, sz.Z)
            local cam = Instance.new("Camera")
            cam.FieldOfView = 30
            cam.CFrame = CFrame.lookAt(cf.Position + cf:VectorToWorldSpace(V(0, r * 0.15, -r * 1.9)), cf.Position)
            cam.Parent = vp
            vp.CurrentCamera = cam
        end
        return vp
    end
    local function MyGuns(): { any }
        local st = hooks.GetState() or {}
        local out = {}
        if st.EquippedWeapon then table.insert(out, { st.EquippedWeapon, "IN HAND" }) end
        for _, w in ipairs(st.Inventory or {}) do table.insert(out, { w, "BAG" }) end
        local h = type(st.Hideout) == "table" and st.Hideout or {}
        local _ = h
        for _, t in ipairs(require(script.Parent:WaitForChild("StashTabs")).List(st)) do -- (UPDATE 7: every stash tab)
            for _, w in ipairs(t.Box and type(t.Box.W) == "table" and t.Box.W or {}) do table.insert(out, { w, t.Name }) end
        end
        return out
    end
    local function OpenPicker(slot: number, isOwn: boolean, data: any)
        local panel, body = Win("RackPick", "RACK SLOT " .. slot, "pick one of your guns to hang here", C.Gold)
        local list = Scroll(body, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, -54))
        for i, gw in ipairs(MyGuns()) do
            local w = gw[1]
            local col = ItemData.ItemColor and ItemData.ItemColor(w) or RarCol(w.Rarity)
            local row = New("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, Parent = list }, { UIStyle.Corner(2) })
            Text(row, { Text = ItemData.DisplayName(w), TextSize = 15, TextColor3 = col, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0) })
            Text(row, { Text = gw[2], TextSize = 12, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -140, 0, 0), Size = UDim2.new(0, 128, 1, 0) })
            row.MouseButton1Click:Connect(function()
                hooks.Click()
                if act("SetRack", slot, w.Uid) then task.delay(0.5, function() Open("Rack", nil, isOwn) end) end
            end)
        end
        local back = UIStyle.Button(body, "BACK", C.Steel, UDim2.fromOffset(160, 42), UDim2.new(0, 0, 1, -44))
        back.Button.MouseButton1Click:Connect(function() hooks.Click(); Open("Rack", data, isOwn) end)
        Show(panel)
    end
    local function OpenRack(data: any, isOwn: boolean)
        local panel, body = Win("Rack", "WEAPON RACK", tostring(data.N or "") .. "'s favourite guns, in their skins", C.Gold)
        for i = 1, 3 do
            local e = data.K and data.K[tostring(i)]
            local card = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, (i - 1) * 160), Parent = body }, { UIStyle.Corner(2) })
            if e then
                GunView(card, e, UDim2.fromOffset(260, 134), UDim2.fromOffset(8, 8))
                Text(card, { Text = string.upper(e.n or e.g), TextSize = 19, TextColor3 = RarCol(e.r), Position = UDim2.fromOffset(282, 10), Size = UDim2.new(1, -470, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd })
                Text(card, { Text = (e.t or "") , TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(282, 40), Size = UDim2.new(1, -470, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
                Text(card, { Text = e.d and ("WEAPON DPS  " .. e.d) or "", TextSize = 15, TextColor3 = C.Text, Position = UDim2.fromOffset(282, 64), Size = UDim2.new(1, -470, 0, 20) })
                Text(card, { Text = (e.w == "stash") and "IN THE STASH" or ((e.w == "equipped") and "IN HAND" or "IN THE BAG"), TextSize = 12, TextColor3 = C.Muted, Position = UDim2.fromOffset(282, 90), Size = UDim2.new(1, -470, 0, 18) })
            else
                Text(card, { Text = "EMPTY PEG", TextSize = 18, TextColor3 = C.Muted, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -220, 1, 0) })
            end
            if isOwn then
                local y = 10
                local function B(label, col, fn, enabled)
                    local b = UIStyle.Button(card, label, col, UDim2.fromOffset(170, 38), UDim2.new(1, -180, 0, y))
                    b.SetEnabled(enabled ~= false)
                    b.Button.MouseButton1Click:Connect(function() hooks.Click(); fn() end)
                    y += 44
                end
                if e then
                    B("EQUIP", C.Accent, function()
                        local ok, res = pcall(function() return Remotes.GetFunction("EquipWeapon"):InvokeServer(e.u) end)
                        if ok and res then hooks.Toast("Equipped " .. tostring(e.n)) elseif e.w == "stash" then hooks.Toast("Take it out of the stash first.") end
                        task.delay(0.4, function() act("Showcase") end)
                    end, e.w == "bag")
                end
                B(e and "CHANGE GUN" or "HANG A GUN", C.Steel, function() OpenPicker(i, isOwn, data) end)
                if e then B("EMPTY PEG", C.Red, function() if act("SetRack", i, "") then task.delay(0.5, function() Open("Rack", nil, isOwn) end) end end) end
            end
        end
        Show(panel)
    end
    local function OpenJukebox(data: any, isOwn: boolean)
        local panel, body = Win("Jukebox", "JUKEBOX", isOwn and "pick your hideout's music: everyone inside hears it" or ("what's playing in " .. tostring(data.N or "") .. "'s hideout"), C.Pink)
        local cur = data.M
        local list = Scroll(body, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, -54))
        -- (JUKEBOX v2: with no station on, the city's chill DnB plays in the hideout -- the first row says so)
        local rows = { { Id = "", Name = "City DnB", By = "" } }
        for _, t in ipairs(HD.MUSIC) do table.insert(rows, t) end
        local now = api.NowPlaying()
        for i, t in ipairs(rows) do
            local on = (t.Id == "" and not cur) or t.Id == cur
            local sub
            if t.Id == "" then
                sub = "no station: the city's chill drum and bass plays"
            elseif on and now then
                sub = "now: " .. now.Name .. " by " .. now.By .. "  •  " .. #t.Tracks .. " tracks"
            else
                sub = (t.Mood or "") .. "  •  " .. #t.Tracks .. " tracks"
            end
            local row = New("Frame", { BackgroundColor3 = on and UIStyle.Lighten(C.Card, 0.1) or C.Card, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, Parent = list }, { UIStyle.Corner(2), UIStyle.Stroke(on and C.Pink or C.Border, on and 2 or 1) })
            Text(row, { Text = string.upper(t.Name) .. (on and "   •  PLAYING" or ""), TextSize = 17, TextColor3 = on and C.Pink or C.Text, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -200, 0, 24) })
            Text(row, { Text = sub, TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -200, 0, 16) })
            if isOwn then
                local b = UIStyle.Button(row, on and "ON" or "PLAY", on and C.Off or C.Pink, UDim2.fromOffset(150, 38), UDim2.new(1, -160, 0, 6))
                b.SetEnabled(not on)
                b.Button.MouseButton1Click:Connect(function() hooks.Click(); if act("SetMusic", t.Id) then task.delay(0.5, function() Open("Jukebox", nil, isOwn) end) end end)
            end
        end
        local mb = UIStyle.Button(body, muted and "UNMUTE FOR ME" or "MUTE FOR ME", C.Steel, UDim2.fromOffset(220, 42), UDim2.new(0, 0, 1, -44))
        mb.Button.MouseButton1Click:Connect(function()
            hooks.Click()
            muted = not muted
            if muted then api.StopMusic() elseif api.OnMuteChanged then api.OnMuteChanged() end
            Open("Jukebox", data, isOwn)
        end)
        Show(panel)
    end

    -- ===================== THE AIM ARCADE =====================
    local A = HD.ARCADE
    local arc = UIStyle.Panel(menuFolder, { Name = "AimArcade", Size = UDim2.fromOffset(900, 640), Accent = C.Pink })
    UIStyle.TitleBar(arc, "AIM ARCADE", C.Pink, "hit every target as fast as you can: " .. A.Time .. " seconds, quicker hits score more, a miss costs 25", function() hooks.CloseAll() end)
    local hud = Text(arc, { Text = "", TextSize = 18, TextColor3 = C.Text, Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 0, 26) })
    local field = New("TextButton", { Name = "Field", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Bg0, Position = UDim2.fromOffset(20, 110),
        Size = UDim2.new(1, -40, 1, -130), ClipsDescendants = true, Parent = arc }, { UIStyle.Stroke(C.Line, 1) }) -- (UI CLEAN audit: a flat field + hairline, no purple)
    do -- a faint grid on the field
        local g = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = field })
        for k = 1, 9 do
            New("Frame", { BackgroundColor3 = C.Text, BackgroundTransparency = 0.95, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(k / 10, 0), Parent = g })
            if k < 6 then New("Frame", { BackgroundColor3 = C.Text, BackgroundTransparency = 0.95, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, k / 6), Parent = g }) end
        end
    end
    local msg = Text(field, { Text = "", TextSize = 22, TextColor3 = C.Text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
        Position = UDim2.fromScale(0.1, 0.22), Size = UDim2.fromScale(0.8, 0.3) })
    local startB = UIStyle.Button(field, "START", C.Accent, UDim2.fromOffset(220, 52), UDim2.new(0.5, -110, 0.6, 0)) -- (the primary)
    local target = New("TextButton", { Name = "Target", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(255, 80, 150), AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false, ZIndex = 4, Parent = field }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), UIStyle.Stroke(Color3.fromRGB(255, 240, 250), 3) })
    New("Frame", { BackgroundColor3 = Color3.fromRGB(255, 255, 255), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), ZIndex = 5, Parent = target },
        { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local round = { On = false }
    local rng = Random.new()
    local function Hud()
        local left = round.On and math.max(0, A.Time - (os.clock() - round.T0)) or A.Time
        hud.Text = string.format("TIME  %.1f     SCORE  %s     HITS  %d     MISSES  %d     YOUR BEST  %s", left, FN(round.Score or 0), round.Hits or 0, round.Miss or 0, FN(round.Best or 0))
    end
    local function NextTarget()
        local prog = math.clamp((os.clock() - round.T0) / A.Time, 0, 1)
        local d = math.floor(70 - 34 * prog) -- (targets shrink as the round goes on)
        target.Size = UDim2.fromOffset(d, d)
        local fs = field.AbsoluteSize
        target.Position = UDim2.fromOffset(rng:NextInteger(d, math.max(d + 1, math.floor(fs.X) - d)), rng:NextInteger(d, math.max(d + 1, math.floor(fs.Y) - d)))
        target.Visible = true
        round.Spawn = os.clock()
    end
    local function Finish()
        if not round.On then return end
        round.On = false
        target.Visible = false
        local shots = (round.Hits or 0) + (round.Miss or 0)
        local ok, res = act("ArcadeEnd", round.Score, round.Hits)
        local pb = ok and type(res) == "string" and string.find(res, "NEW BEST") ~= nil
        if pb then round.Best = round.Score end
        msg.Text = string.format("%s\nSCORE %s   •   %d HITS   •   ACCURACY %s", pb and "NEW PERSONAL BEST!" or "TIME!", FN(round.Score), round.Hits,
            shots > 0 and string.format("%d%%", math.floor(100 * round.Hits / shots)) or "-")
        msg.Visible = true
        startB.Label.Text = "PLAY AGAIN"
        startB.Button.Visible = true
        Hud()
    end
    target.MouseButton1Down:Connect(function()
        if not round.On then return end
        local rt = os.clock() - (round.Spawn or os.clock())
        round.Hits += 1
        round.Score += 100 + math.floor(100 * math.clamp(1 - rt / 1.1, 0, 1))
        hooks.Sound("Click")
        NextTarget()
        Hud()
    end)
    field.MouseButton1Down:Connect(function()
        if not round.On then return end
        round.Miss += 1
        round.Score = math.max(0, round.Score - 25)
        Hud()
    end)
    startB.Button.MouseButton1Click:Connect(function()
        if round.On then return end
        hooks.Click()
        if not act("ArcadeStart") then return end
        startB.Button.Visible = false
        round.On, round.Score, round.Hits, round.Miss = false, 0, 0, 0
        for k = 3, 1, -1 do msg.Text = tostring(k); msg.Visible = true; task.wait(0.6) end
        msg.Visible = false
        if not arc.Visible then return end
        round.On = true
        round.T0 = os.clock()
        NextTarget()
        task.spawn(function()
            while round.On and arc.Visible and os.clock() - round.T0 < A.Time do Hud(); task.wait(0.05) end
            if round.On and not arc.Visible then round.On = false; target.Visible = false return end -- (closed mid-round: no score)
            Finish()
        end)
    end)
    local function OpenArcade(data: any)
        local st = hooks.GetState() or {}
        local h = type(st.Hideout) == "table" and st.Hideout or {}
        round.On = false
        target.Visible = false
        round.Best = math.floor(tonumber(h.ArcadeBest) or 0)
        round.Score, round.Hits, round.Miss = 0, 0, 0
        msg.Text = string.format("HI-SCORE HERE: %s (%s)\nClick the targets. 100 a hit + up to 100 for speed. %d seconds.", FN(tonumber(data.P) or 0), tostring(data.N or "?"), A.Time)
        msg.Visible = true
        startB.Label.Text = "START"
        startB.Button.Visible = true
        Hud()
        Show(arc)
    end

    Open = function(kind: string, data: any?, isOwn: boolean)
        if not data then
            local owner = Players:GetPlayerByUserId(Players.LocalPlayer:GetAttribute("HideoutOf") or Players.LocalPlayer.UserId)
            data = api.Data(owner)
        end
        if kind == "Titles" then OpenTitles(data)
        elseif kind == "Stats" then OpenStats(data)
        elseif kind == "Trophies" then OpenTrophies(data)
        elseif kind == "Rack" then OpenRack(data, isOwn)
        elseif kind == "Jukebox" then OpenJukebox(data, isOwn)
        elseif kind == "Arcade" then OpenArcade(data) end
    end
    api.Open = Open
    api.Muted = function() return muted end
    return api
end

return HideoutShowcase
