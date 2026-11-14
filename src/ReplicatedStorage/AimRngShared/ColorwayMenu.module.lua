--!nocheck
-- ============================================================================================
-- COLORWAYS window (0.93; owner: "We'll also need a seperate menu selectable from both each individual item AND the
-- bundle if they want to recolor everything"). An overlay over the store / cosmetics window (CosmeticsMenu's COLORWAYS
-- button): the set's colourways as three cards, each with a live 3D preview of the item IN that colourway, its colours,
-- and BUY (Colorways.PRICE BOUND points) / USE ON THIS ITEM / USE ON THE WHOLE SET. Top right: your BOUND points + GET
-- POINTS (Robux packs). Server: CombatServer "ColorwayAction". Data: AimRngShared.Colorways.
--   local cw = ColorwayMenu.Build(panel, { GetState, PlayClick, Toast, OnChanged })
--   cw.Open(entry)   -- a Cosmetics entry: a set piece (that piece) or the set's bundle (the whole set)
--   cw.CanOpen(entry) -> setKind?   cw.Close()
-- ============================================================================================
local RunService = game:GetService("RunService")

local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Colorways = require(Shared:WaitForChild("Colorways"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ColorwayMenu = {}
local S = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text
local GOLD = Color3.fromRGB(255, 196, 60)
local BP_COL = Color3.fromRGB(120, 200, 255)

-- the set a store entry belongs to (only sets that have colourways)
function ColorwayMenu.SetOf(e: any): string?
    if not e then return nil end
    local kind = (e.Src and type(e.Src) == "table" and e.Src.Set) or e.Set or (e.Cat == "KillEffect" and e.FX) or nil
    return Colorways.Has(kind) and kind or nil
end

-- (skins5) a card title in the colourway's second swatch: lifted to a readable value (dark mid-tones such as a black
-- lacquer or gunmetal swatch made the title vanish on the dark card)
local function Readable(c: Color3): Color3
    local h, s, v = c:ToHSV()
    return Color3.fromHSV(h, math.min(s, 0.7), math.max(v, 0.85))
end

-- the set's bundle entry
local function BundleOf(kind: string): any
    for _, b in ipairs(Cosmetics.List("Bundle", true)) do
        if b.Src and b.Src.Set == kind then return b end
    end
    return nil
end
-- the whole base set owned? (the bundle, or every piece of it -- same rule as the server's OwnsSetBase)
local function OwnsBase(st: any, kind: string): boolean
    local b = BundleOf(kind)
    if not b then return false end
    if Cosmetics.Owns(st, b) then return true end
    for _, ref in ipairs(b.Contents or {}) do
        if not table.find((b.Src and b.Src.Added) or {}, ref) then
            local cat, id = string.match(ref, "^(.-):(.*)$")
            local ce = cat and Cosmetics.Find(cat, id)
            if not (ce and Cosmetics.Owns(st, ce)) then return false end
        end
    end
    return true
end

-- a 3D model of one piece in colourway v (nil = no model for it)
local function ModelFor(e: any, kind: string, v: number, st: any): any
    local key = Colorways.Key(kind, v)
    local CosmeticPreview = require(Shared:WaitForChild("CosmeticPreview"))
    if e.Cat == "WeaponSkin" then
        local SkinFX = require(Shared:WaitForChild("SkinFX"))
        local set = SkinFX.Sets[key]
        local skin = (v > 1 and set and set.SkinById and set.SkinById[e.Id]) or e.Src
        return CosmeticPreview.Gun(e.Gun, skin)
    elseif e.Cat == "MeleeSkin" then
        local MeleeData = require(Shared:WaitForChild("MeleeData"))
        local skin = (v > 1 and MeleeData.VariantSkin(kind, v)) or MeleeData.Skins[e.Id]
        local okWG, WorldGear = pcall(require, Shared:WaitForChild("WorldGear"))
        if not (okWG and skin) then return nil end
        local ok, m = pcall(function() return (WorldGear.Melee((st and st.EquippedKnife) or "Knife", skin)) end)
        if not ok or not m then return nil end
        for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
        return m
    elseif e.Cat == "Glove" or e.Cat == "Sleeve" then
        local GloveFX = require(Shared:WaitForChild("GloveFX"))
        local byId = e.Cat == "Sleeve" and GloveFX.SleeveById or GloveFX.GloveById
        local def = (v > 1 and byId[e.Id .. "#" .. v]) or e.Src
        return CosmeticPreview.Glove(def, e.Cat == "Sleeve")
    end
    -- the bundle, a bar, a kill effect: the set's first gun stands in for it
    local b = BundleOf(kind)
    for _, ref in ipairs(b and b.Contents or {}) do
        local cat, id = string.match(ref, "^(.-):(.*)$")
        if cat == "WeaponSkin" then
            local ce = Cosmetics.Find(cat, id)
            if ce then return ModelFor(ce, kind, v, st) end
        end
    end
    return nil
end

function ColorwayMenu.Build(panel: Frame, hooks: any)
    hooks = hooks or {}
    local click = hooks.PlayClick or function() end
    local function State() return hooks.GetState and hooks.GetState() or {} end

    local shade = New("TextButton", { Name = "ColorwayShade", AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
        Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false, Parent = panel })
    local win = New("Frame", { Name = "ColorwayWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(940, 600),
        BackgroundColor3 = Color3.fromRGB(16, 18, 26), BorderSizePixel = 0, ZIndex = 41, Parent = shade }, { UIStyle.Corner(2), UIStyle.Stroke(GOLD, 2) })
    local title = Text({ Size = UDim2.new(1, -440, 0, 34), Position = UDim2.fromOffset(20, 12), TextSize = 26, Text = "COLORWAYS", TextColor3 = GOLD, ZIndex = 42, Parent = win })
    local sub = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -440, 0, 18), Position = UDim2.fromOffset(20, 46), TextSize = 13, TextColor3 = S.Sub, Text = "", ZIndex = 42, Parent = win })
    local close = UIStyle.Button(win, "X", Color3.fromRGB(200, 60, 70), UDim2.fromOffset(36, 32), UDim2.new(1, -48, 0, 14), "Close")
    close.Button.ZIndex = 44
    -- BOUND points + packs
    local bpLbl = Text({ Size = UDim2.fromOffset(200, 32), Position = UDim2.new(1, -404, 0, 14), TextSize = 18, TextColor3 = BP_COL, TextXAlignment = Enum.TextXAlignment.Right,
        Text = "", ZIndex = 42, Parent = win })
    local getBtn = UIStyle.Button(win, "GET POINTS", BP_COL, UDim2.fromOffset(140, 32), UDim2.new(1, -196, 0, 14), "GetPoints")
    getBtn.Label.TextSize = 13
    -- (0.97: seven packs -> a grid of two rows)
    local packRow = New("Frame", { Name = "Packs", BackgroundColor3 = Color3.fromRGB(22, 26, 40), BorderSizePixel = 0, Size = UDim2.new(1, -40, 0, 120), Position = UDim2.fromOffset(20, 72),
        Visible = false, ZIndex = 45, Parent = win }, { UIStyle.Corner(2), UIStyle.Stroke(BP_COL, 1), New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8) }),
        New("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 0, 46), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
    for i, pack in ipairs(Colorways.PACKS) do
        local b = UIStyle.Button(packRow, string.format("%d %s  •  R$ %d%s", pack.Points, Colorways.SHORT, pack.Price, pack.Note and ("  " .. pack.Note) or ""), BP_COL, UDim2.fromOffset(270, 44), nil, "Pack_" .. pack.Id)
        b.Button.LayoutOrder = i
        b.Button.ZIndex = 46
        b.Label.TextSize = 14
        b.Button.MouseButton1Click:Connect(function()
            click()
            local ok, msg = Remotes.GetFunction("ColorwayAction"):InvokeServer("Points", pack.Id)
            if hooks.Toast then
                if ok and msg == "Granted" then hooks.Toast("+" .. pack.Points .. " BOUND points")
                elseif not ok then hooks.Toast(tostring(msg or "Couldn't buy that.")) end
            end
            packRow.Visible = false
        end)
    end
    getBtn.Button.MouseButton1Click:Connect(function() click(); packRow.Visible = not packRow.Visible end)

    local cardsHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -130), Position = UDim2.fromOffset(20, 76), ZIndex = 42, Parent = win }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
    local foot = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -40, 0, 36), Position = UDim2.new(0, 20, 1, -46), TextSize = 12, TextColor3 = S.Sub, TextWrapped = true,
        Text = "", ZIndex = 42, Parent = win })

    local cur = nil -- { Kind, Entry, Ref }
    local lives = {}
    local function Clear()
        for _, c in ipairs(cardsHolder:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        lives = {}
    end

    local function Act(...)
        local ok, msg = Remotes.GetFunction("ColorwayAction"):InvokeServer(...)
        if not ok and hooks.Toast then hooks.Toast(tostring(msg or "Couldn't do that.")) end
        return ok
    end

    local Render
    Render = function()
        if not cur then return end
        Clear()
        local st = State()
        local kind, e, ref = cur.Kind, cur.Entry, cur.Ref
        local list = Colorways.Sets[kind]
        local pts = Colorways.Points(st)
        bpLbl.Text = string.format("%d %s", pts, Colorways.CURRENCY)
        local baseOk = OwnsBase(st, kind)
        local b = BundleOf(kind)
        title.Text = "COLORWAYS  •  " .. string.upper((b and b.Name or kind):gsub("%s*Bundle$", ""))
        sub.Text = ref and ("Recolouring: " .. tostring(e.Name) .. "  (or the whole set)") or "Recolouring the whole set: guns, melee, gloves, sleeves, health bar and every effect"
        local now = Colorways.VariantFor(st, kind, ref)
        local setNow = Colorways.VariantFor(st, kind, nil)
        for v, cw in ipairs(list) do
            local owned = Colorways.Owns(st, kind, v)
            local card = New("Frame", { Name = "Colorway" .. v, BackgroundColor3 = Color3.fromRGB(24, 27, 40), BorderSizePixel = 0, Size = UDim2.fromOffset(282, 450), LayoutOrder = v, ZIndex = 42, Parent = cardsHolder },
                { UIStyle.Corner(2), UIStyle.Stroke(v == now and GOLD or Color3.fromRGB(60, 66, 90), v == now and 2 or 1) })
            local pv = New("Frame", { Name = "Preview", BackgroundColor3 = Color3.fromRGB(10, 12, 20), BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 210), Position = UDim2.fromOffset(8, 8), ZIndex = 43, Parent = card },
                { UIStyle.Corner(2), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(cw.Swatch[1]:Lerp(Color3.new(0, 0, 0), 0.55), Color3.fromRGB(10, 12, 20)) }) })
            local okM, model = pcall(ModelFor, e, kind, v, st)
            if okM and model then
                local CosmeticPreview = require(Shared:WaitForChild("CosmeticPreview"))
                local okV, vp = pcall(CosmeticPreview.Viewport, pv, model, nil, { Spin = "full", Drag = true })
                if okV and vp then
                    for _, d in ipairs(pv:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 44 end end
                    table.insert(lives, vp)
                end
            end
            Text({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 224), TextSize = 20, Text = string.upper(cw.Name) .. (v == 1 and "  (ORIGINAL)" or ""),
                TextColor3 = Readable(cw.Swatch[2]), ZIndex = 43, Parent = card })
            local sw = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 254), ZIndex = 43, Parent = card },
                { New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
            for i, c in ipairs(cw.Swatch) do
                New("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, Size = UDim2.fromOffset(46, 22), LayoutOrder = i, ZIndex = 43, Parent = sw }, { UIStyle.Corner(2), UIStyle.Stroke(Color3.new(0, 0, 0), 1) })
            end
            Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 282), TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                TextColor3 = Color3.fromRGB(200, 208, 228), Text = cw.Desc or "The set as it was made.", ZIndex = 43, Parent = card })
            local status = (v == now) and "✓ IN USE" or (owned and "OWNED" or string.format("%d %s", Colorways.PRICE, Colorways.SHORT))
            Text({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 338), TextSize = 14, Text = status,
                TextColor3 = (v == now and S.Green) or (owned and BP_COL) or GOLD, ZIndex = 43, Parent = card })
            -- buttons: main (buy / use here), and from a single piece also "the whole set"
            local main = UIStyle.Button(card, "", S.Blue, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, ref and -90 or -48), "Main")
            main.Button.ZIndex = 44; main.Label.TextSize = 14
            if not owned then
                if not baseOk then
                    main.SetText("OWN THE SET FIRST"); main.SetColor(S.Sub); main.SetEnabled(false)
                else
                    main.SetText(string.format("BUY  •  %d %s", Colorways.PRICE, Colorways.SHORT)); main.SetColor(GOLD); main.SetEnabled(true)
                    main.Button.MouseButton1Click:Connect(function()
                        click()
                        -- (2026-10-20 owner: a popup with the BOUND points needed before any buy)
                        require(script.Parent:WaitForChild("BoundShop")).Confirm({ Name = tostring(cw.Name) .. " colourway", Price = Colorways.PRICE,
                            Desc = "For the whole set, every piece.", OnBuy = function()
                                local ok, msg = Remotes.GetFunction("ColorwayAction"):InvokeServer("Buy", kind, v)
                                if ok then
                                    if hooks.Toast then hooks.Toast("★ " .. cw.Name .. " unlocked for the whole set") end
                                    task.delay(0.25, function() Render(); if hooks.OnChanged then hooks.OnChanged() end end)
                                end
                                return ok, msg
                            end })
                    end)
                end
            elseif v == now then
                main.SetText("✓ IN USE"); main.SetColor(S.Green); main.SetEnabled(false)
            else
                main.SetText(ref and "USE ON THIS ITEM" or "USE ON THE WHOLE SET"); main.SetColor(S.Blue); main.SetEnabled(true)
                main.Button.MouseButton1Click:Connect(function()
                    click()
                    if Act("Use", kind, v, ref) then task.delay(0.25, function() Render(); if hooks.OnChanged then hooks.OnChanged() end end) end
                end)
            end
            if ref then
                local all = UIStyle.Button(card, "USE ON THE WHOLE SET", Color3.fromRGB(70, 190, 170), UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 1, -46), "WholeSet")
                all.Button.ZIndex = 44; all.Label.TextSize = 12
                local allOk = owned and not (setNow == v and next((Colorways.Rec(st, kind) or {}).Items or {}) == nil)
                all.SetEnabled(allOk)
                if not owned then all.SetColor(S.Sub) end
                all.Button.MouseButton1Click:Connect(function()
                    if not allOk then return end
                    click()
                    if Act("Use", kind, v, nil) then task.delay(0.25, function() Render(); if hooks.OnChanged then hooks.OnChanged() end end) end
                end)
            end
        end
        foot.Text = baseOk and string.format("A colourway costs %d %s and unlocks for the WHOLE set (every piece and every effect). Wear it on everything, or piece by piece. BOUND points: Season Pass premium tiers or GET POINTS.", Colorways.PRICE, Colorways.CURRENCY)
            or "Colourways are for owners of the whole set: get its bundle (or every piece of it) first."
    end

    local stepConn = nil
    local api = {}
    function api.Close()
        shade.Visible = false
        packRow.Visible = false
        Clear()
        cur = nil
        if stepConn then stepConn:Disconnect(); stepConn = nil end
    end
    function api.CanOpen(e: any): string? return ColorwayMenu.SetOf(e) end
    function api.Open(e: any)
        local kind = ColorwayMenu.SetOf(e)
        if not kind then return end
        cur = { Kind = kind, Entry = e, Ref = (e.Cat ~= "Bundle") and (e.Cat .. ":" .. e.Id) or nil }
        shade.Visible = true
        packRow.Visible = false
        Render()
        if not stepConn then
            stepConn = RunService.RenderStepped:Connect(function()
                local now = os.clock()
                for _, vp in ipairs(lives) do pcall(vp.Step, now) end
            end)
        end
    end
    function api.Refresh() if cur and shade.Visible then Render() end end
    close.Button.MouseButton1Click:Connect(function() click(); api.Close() end)
    api.Frame = shade
    return api
end

return ColorwayMenu
