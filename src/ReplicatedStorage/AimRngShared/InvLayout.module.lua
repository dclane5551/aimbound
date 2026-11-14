--!nocheck
-- ============================================================================================
-- INVENTORY LAYOUT (UI CLEAN round 2, job INV, 2026-10-28): the full-screen inventory the owner accepted as THE target
-- (docs/ui_target/inventory_target.html; renders art/preview/uiclean/target_inventory.png + target_hover.png). This module
-- only BUILDS + PAINTS the pieces; AimRngClient keeps every action (equip / sell / lock / stash / search / sort / pickers /
-- tooltips / pad) and calls in here. Pieces:
--   Chrome(frame, hooks)  -> top bar (nav INVENTORY / STASH / FORGE / EXCHANGE / PASSIVES, currencies, close) + the three
--                            zones (Left identity + power, Centre loadout, Right bag) split by hairlines; Layout(phone) places them
--   Identity(zone)        -> class icon, name, LEVEL n · CLASS · TITLE, XP line, TOTAL DPS (big), HEALTH / PLATING / EVADE /
--                            CRIT, ATTRIBUTES (STR / DEX / INT), OFFENSE rows, ALL STATS link; :Set(data)
--   SlotCard(parent, key, label) -> ONE card for every equip slot (gun included): slot label, name in the rarity colour,
--                            one stat line, the icon in a RESERVED right area (never under the name; aspect kept); PaintSlot
--   PaintTile(tile, item, name, icon, badges) -> a bag tile (image-led, name smaller than slot names, ▲ / E badges)
--   Sockets(parent, item, opts) -> a gun's sockets as coloured dots + link bars (bag tiles, the GUN slot card, ItemRow, the
--                            stash list, the Exchange rows; 2026-11-09)
--   IconFor(item, slotKey) -> { Image, RectOffset?, RectSize?, Aspect } from AimRngShared/ItemIcons when it exists, else the
--                            gear-type glyph (a placeholder until the drawn icons land); ApplyIcon(img, spec, boxW, boxH)
-- Rules: flat (no gradients / glow), hairlines, the rarity is a 2 px bottom edge + a faint tint + the name colour; text on the
-- UIStyle roles; nothing per frame; one ImageLabel per icon (no ViewportFrames).
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local InvLayout = {}
local C = UIStyle.Colors
InvLayout.TOP_H = 64
InvLayout.LEFT_W = 284
InvLayout.CENTRE_W = 548
InvLayout.PAD = 24
InvLayout.SLOT_H = 90
InvLayout.TILE_H = 94
InvLayout.ART_W, InvLayout.ART_H = 104, 46 -- (the reserved icon box on a slot card: the same on every card, the name never runs into it)
InvLayout.DIM = Color3.fromRGB(107, 105, 100) -- (an empty slot's "EMPTY")

local function New(class: string, props: { [string]: any }): Instance
    local o = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
    if props.Parent then o.Parent = props.Parent end
    return o
end
local function Mark(o: Instance) o:SetAttribute("Skinned", true); return o end
local function Txt(parent: Instance, role: string, props: { [string]: any }): TextLabel
    props.BackgroundTransparency = 1
    props.Parent = parent
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
    props.Font = props.Font or ((role == "Label" or role == "Body" or role == "Meta" or role == "Value") and Enum.Font.GothamMedium or Enum.Font.GothamBlack)
    local l = Mark(New("TextLabel", props)) :: TextLabel
    UIStyle.TextRole(l, role, props.TextColor3 and { Keep = true } or nil)
    return l
end
InvLayout.Txt = Txt
local function Rule(parent: Instance, props: { [string]: any }): Frame
    props.BorderSizePixel = 0
    props.BackgroundColor3 = C.Text
    props.BackgroundTransparency = props.BackgroundTransparency or 0.9
    props.Parent = parent
    return Mark(New("Frame", props)) :: Frame
end
InvLayout.Rule = Rule
-- a section head: caps + a hairline after the text
function InvLayout.Head(parent: Instance, text: string, y: number, x: number?, rightPad: number?): TextLabel
    local l = Txt(parent, "SectionHead", { Name = "Head_" .. text, Text = text, Position = UDim2.fromOffset(x or InvLayout.PAD, y),
        Size = UDim2.new(1, -(x or InvLayout.PAD) * 2, 0, 18), AutomaticSize = Enum.AutomaticSize.None })
    local rule = Rule(l, { Name = "Rule", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 1), Size = UDim2.new(1, 0, 0, 1) })
    local function Place()
        local w = l.TextBounds.X + 10
        rule.Position = UDim2.new(0, w, 0.5, 1)
        rule.Size = UDim2.new(1, -w - (rightPad or 0), 0, 1)
    end
    l:GetPropertyChangedSignal("TextBounds"):Connect(Place)
    task.defer(Place)
    return l
end
-- a quiet secondary button (1 px hairline, display caps)
function InvLayout.Btn(parent: Instance, text: string, props: { [string]: any }?): TextButton
    local p = props or {}
    local b = New("TextButton", { Name = p.Name or ("Btn_" .. text), Text = text, AutoButtonColor = false, BackgroundColor3 = C.Bg2,
        BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = C.Text, TextSize = 14,
        Size = p.Size or UDim2.fromOffset(100, 30), Position = p.Position or UDim2.new(), AnchorPoint = p.AnchorPoint or Vector2.zero,
        Parent = parent }) :: TextButton
    b:SetAttribute("NoNeon", true); Mark(b)
    UIStyle.TextRole(b, "Button")
    local st = New("UIStroke", { Color = C.Text, Transparency = 0.78, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
    local function Hov(on) b.BackgroundTransparency = on and 0.4 or 1; st.Transparency = on and 0.55 or 0.78 end
    b.MouseEnter:Connect(function() Hov(true) end); b.MouseLeave:Connect(function() Hov(false) end)
    b.SelectionGained:Connect(function() Hov(true) end); b.SelectionLost:Connect(function() Hov(false) end)
    return b
end

-- ===== ICONS =====
local GLYPH = { Weapon = "g_aim", Melee = "cat_knife", Helmet = "cat_crown", ChestPiece = "cat_shirt", Chest = "cat_shirt", Leggings = "cat_shield",
    Legs = "cat_shield", Gloves = "cat_glove", Boots = "cat_boot", Necklace = "cat_heart", Amulet = "cat_heart", Ring = "cat_charm",
    Ring1 = "cat_charm", Ring2 = "cat_charm" }
InvLayout.GLYPH = GLYPH
local itemIcons, iconsChecked = nil, 0
local function Icons()
    if itemIcons then return itemIcons end
    if os.clock() - iconsChecked < 5 then return nil end -- (looked for at most every 5 s until the module exists)
    iconsChecked = os.clock()
    local m = Shared:FindFirstChild("ItemIcons")
    if m then
        local ok, mod = pcall(require, m)
        if ok and type(mod) == "table" and mod.For then itemIcons = mod end
    end
    return itemIcons
end
-- the picture for an item (or an empty slot key): the drawn icon when AimRngShared/ItemIcons exists, else the type glyph
function InvLayout.IconFor(item: any?, slotKey: string?): any
    local II = Icons()
    if II then
        local ok, spec = pcall(II.For, item or slotKey)
        -- (an item without a known BaseId -- a listing summary, a legacy id -- still gets a drawn icon: its kind's own art)
        if not (ok and type(spec) == "table" and spec.Image and spec.Image ~= "") and item then
            local key = item.Slot and ItemData.GearType(item.Slot) or (item.Kind == "Melee" and "Melee") or slotKey or "Weapon"
            ok, spec = pcall(II.For, key)
        end
        if ok and type(spec) == "table" and spec.Image and spec.Image ~= "" then
            -- (ItemIcons: guns / melee share one wide canvas -> the art box; gear art is square -> drawn like a glyph, full strength)
            return { Image = spec.Image, RectOffset = spec.RectOffset, RectSize = spec.RectSize, Aspect = spec.Aspect, Kind = spec.Kind,
                TightOffset = spec.TightOffset, TightSize = spec.TightSize, TightAspect = spec.TightAspect,
                Square = spec.Kind == "Gear" or (tonumber(spec.Aspect) or 1) <= 1.2 }
        end
    end
    local key = slotKey
    if item then
        if item.Slot then key = ItemData.GearType(item.Slot) elseif item.Kind == "Melee" then key = "Melee" else key = key or "Weapon" end
    end
    local id = UIStyle.Icons[GLYPH[key or "Weapon"] or "g_aim"]
    return { Image = id or "", Aspect = 1, Glyph = true }
end
-- draw a spec into an ImageLabel inside a box of boxW x boxH (the ImageLabel is anchored by the caller): the picture keeps its
-- aspect -- a wide gun fills the width, a square glyph sits at the box's height (never squished, never wider than the box)
-- a rarity colour made readable on its card: lifted toward white until it reaches 4.6:1 on bg (Mythic red FF143C sat at 4.2 on
-- its own tinted card; the hue stays, only the light text gets lighter)
local function Lum(c: Color3): number
    local function L(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * L(c.R) + 0.7152 * L(c.G) + 0.0722 * L(c.B)
end
function InvLayout.Readable(col: Color3, bg: Color3): Color3
    local lb = Lum(bg)
    local c = col
    for _ = 1, 12 do
        if (Lum(c) + 0.05) / (lb + 0.05) >= 4.6 then return c end
        c = c:Lerp(Color3.new(1, 1, 1), 0.08)
    end
    return c
end

function InvLayout.ApplyIcon(img: ImageLabel, spec: any, boxW: number, boxH: number, glyphH: number?)
    img.Image = spec.Image or ""
    -- (ItemIcons' TIGHT rect = the art trimmed to its outline: a pistol fills the box height, a rifle stays width-limited)
    local rs, ro = spec.TightSize or spec.RectSize, spec.TightOffset or spec.RectOffset
    if rs then img.ImageRectOffset = ro or Vector2.zero; img.ImageRectSize = rs
    else img.ImageRectOffset = Vector2.zero; img.ImageRectSize = Vector2.zero end
    img.ScaleType = Enum.ScaleType.Fit
    local a = tonumber(spec.TightAspect) or tonumber(spec.Aspect) or 1
    if spec.Glyph or spec.Square then
        local s = glyphH or math.min(boxW, boxH)
        img.Size = UDim2.fromOffset(s, s)
    else
        local w = math.min(boxW, boxH * a)
        img.Size = UDim2.fromOffset(math.floor(w), math.floor(w / a))
    end
end

-- the selected nav word (the inventory's STASH tab underlines STASH)
function InvLayout.SetNav(ui: any, id: string)
    for nid, b in pairs(ui.Nav or {}) do
        local on = nid == id
        if b:GetAttribute("Sel") ~= on then
            b:SetAttribute("Sel", on)
            UIStyle.TextRole(b, on and "WindowTitle" or "Title", { Color = on and "Text" or "Sub" })
            local u = b:FindFirstChild("Under"); if u then u.Visible = on end
        end
    end
end

-- ===== TOP BAR + ZONES =====
-- hooks: { Nav = { { Id, Text, OnClick } }, Selected = id, OnClose = fn, Currencies = { { Key, Icon, Color } } }
function InvLayout.Chrome(frame: Frame, hooks: any)
    local ui = { Nav = {}, Cur = {} }
    local content = Mark(New("Frame", { Name = "InvContent", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = frame })) :: Frame
    ui.Content = content
    local top = Mark(New("Frame", { Name = "TopBar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, InvLayout.TOP_H), Parent = content })) :: Frame
    ui.Top = top
    Rule(top, { Name = "Bottom", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1) })
    local nav = Mark(New("Frame", { Name = "Nav", BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -460, 1, 0), Parent = top })) :: Frame
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 28), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center, Parent = nav })
    for i, n in ipairs(hooks.Nav or {}) do
        local on = n.Id == hooks.Selected
        local b = New("TextButton", { Name = "Nav_" .. n.Id, Text = n.Text, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = Enum.Font.GothamBlack, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = nav }) :: TextButton
        b:SetAttribute("NoNeon", true); Mark(b)
        UIStyle.TextRole(b, on and "WindowTitle" or "Title", { Color = on and "Text" or "Sub" })
        local u = Rule(b, { Name = "Under", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0 })
        u.Visible = on
        b:SetAttribute("Sel", on)
        b.MouseEnter:Connect(function() if not b:GetAttribute("Sel") then b.TextColor3 = C.Text end end)
        b.MouseLeave:Connect(function() if not b:GetAttribute("Sel") then b.TextColor3 = C.Sub end end)
        b.SelectionGained:Connect(function() if not b:GetAttribute("Sel") then b.TextColor3 = C.Text end end)
        b.SelectionLost:Connect(function() if not b:GetAttribute("Sel") then b.TextColor3 = C.Sub end end)
        if n.OnClick then b.Activated:Connect(n.OnClick) end
        ui.Nav[n.Id] = b
    end
    -- currencies (right) + the close X
    local cur = Mark(New("Frame", { Name = "Currencies", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -78, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 24), Parent = top })) :: Frame
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center, Parent = cur })
    for i, c in ipairs(hooks.Currencies or {}) do
        local f = Mark(New("Frame", { Name = "Cur_" .. c.Key, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = cur }))
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center, Parent = f })
        if UIStyle.HasIcon(c.Icon) then UIStyle.Icon(c.Icon, { Name = "Icon", Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, Parent = f }) end
        local v = Txt(f, "SectionHead", { Name = "Value", Text = "0", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2,
            TextTruncate = Enum.TextTruncate.None })
        v.TextSize = 16
        ui.Cur[c.Key] = v
    end
    if hooks.OnClose then
        local holder = Mark(New("Frame", { Name = "CloseHolder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
            Size = UDim2.fromOffset(36, 36), Parent = top }))
        local x = UIStyle.CloseButton(holder, hooks.OnClose, 36)
        x.Button.Position = UDim2.new(0, 0, 0, 0)
        x.SetQuiet(false)
        ui.Close = x
    end
    -- the three zones
    local body = Mark(New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, InvLayout.TOP_H), Size = UDim2.new(1, 0, 1, -InvLayout.TOP_H), Parent = content })) :: Frame
    ui.Body = body
    -- (a scrolling zone: the identity is ~590 tall -- short windows / phones scroll it; a taller zone never shows a bar)
    ui.Left = Mark(New("ScrollingFrame", { Name = "LeftZone", BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        CanvasSize = UDim2.fromOffset(0, 590), ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.Text, ScrollBarImageTransparency = 0.7, Parent = body })) :: Frame
    return ui
end
-- place the zones: desktop = left 284 | centre 548 | right (the rest); phone = no left column (its ALL STATS view takes the
-- centre when asked), centre + right half / half. Zones are frames the client parents its columns to.
function InvLayout.Layout(ui: any, centre: GuiObject, right: GuiObject, phone: boolean, insetTop: number)
    ui.Content.Position = UDim2.fromOffset(0, insetTop)
    ui.Content.Size = UDim2.new(1, 0, 1, -insetTop)
    local LW, CW = InvLayout.LEFT_W, InvLayout.CENTRE_W
    if phone then
        ui.Left.Visible = ui.PhoneLeft == true
        ui.Left.Position = UDim2.new(0, 0, 0, 0); ui.Left.Size = UDim2.new(0.5, 0, 1, 0)
        centre.Visible = not ui.PhoneLeft
        centre.Position = UDim2.new(0, 0, 0, 0); centre.Size = UDim2.new(0.5, 0, 1, 0)
        right.Position = UDim2.new(0.5, 0, 0, 0); right.Size = UDim2.new(0.5, 0, 1, 0)
    else
        ui.Left.Visible = true
        ui.Left.Position = UDim2.new(0, 0, 0, 0); ui.Left.Size = UDim2.new(0, LW, 1, 0)
        centre.Visible = true
        centre.Position = UDim2.new(0, LW, 0, 0); centre.Size = UDim2.new(0, CW, 1, 0)
        right.Position = UDim2.new(0, LW + CW, 0, 0); right.Size = UDim2.new(1, -(LW + CW), 1, 0)
    end
end

-- ===== LEFT: identity + power =====
function InvLayout.Identity(zone: Frame, onAllStats: (() -> ())?)
    local P = InvLayout.PAD
    local id = { Zone = zone }
    id.Icon = Mark(New("ImageLabel", { Name = "ClassIcon", BackgroundTransparency = 1, Position = UDim2.fromOffset(P, 22), Size = UDim2.fromOffset(44, 44),
        ScaleType = Enum.ScaleType.Fit, Parent = zone })) :: ImageLabel
    id.Name = Txt(zone, "WindowTitle", { Name = "PlayerName", Text = "", Position = UDim2.fromOffset(P + 56, 20), Size = UDim2.new(1, -(P * 2 + 56), 0, 30) })
    id.Meta = Txt(zone, "Meta", { Name = "Meta", Text = "", RichText = true, Position = UDim2.fromOffset(P + 56, 50), Size = UDim2.new(1, -(P * 2 + 56), 0, 16) })
    local xp = Rule(zone, { Name = "XpTrack", Position = UDim2.fromOffset(P, 80), Size = UDim2.new(1, -P * 2, 0, 2), BackgroundTransparency = 0.86 })
    id.Xp = Rule(xp, { Name = "XpFill", Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0 })
    Txt(zone, "Meta", { Name = "DpsLbl", Text = "TOTAL DPS", Position = UDim2.fromOffset(P, 96), Size = UDim2.new(1, -P * 2, 0, 16) })
    id.Dps = Txt(zone, "WindowTitle", { Name = "Dps", Text = "0", Position = UDim2.fromOffset(P, 110), Size = UDim2.new(1, -P * 2, 0, 56) })
    id.Dps.TextSize = 52
    id.Dps:SetAttribute("TextRole", "Big")
    id.Pair = {}
    for i, k in ipairs({ "HEALTH", "PLATING", "EVADE", "CRIT" }) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = P + col * 126, 176 + row * 54
        Txt(zone, "Meta", { Name = "L_" .. k, Text = k, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(118, 16) })
        id.Pair[k] = Txt(zone, "Title", { Name = "V_" .. k, Text = "0", Position = UDim2.fromOffset(x, y + 16), Size = UDim2.fromOffset(118, 26) })
    end
    InvLayout.Head(zone, "ATTRIBUTES", 290)
    id.Attr = {}
    local attrRow = Mark(New("Frame", { Name = "AttrRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(P, 318), Size = UDim2.new(1, -P * 2, 0, 58), Parent = zone }))
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = attrRow })
    for i, k in ipairs({ "STR", "DEX", "INT" }) do
        local box = Mark(New("Frame", { Name = "A_" .. k, BackgroundColor3 = C.Text, BackgroundTransparency = 0.955, BorderSizePixel = 0, LayoutOrder = i,
            Size = UDim2.new(1 / 3, -4, 1, 0), Parent = attrRow }))
        Txt(box, "Meta", { Name = "K", Text = k, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 16) })
        id.Attr[k] = Txt(box, "Title", { Name = "V", Text = "0", Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 26) })
    end
    InvLayout.Head(zone, "OFFENSE", 392)
    id.Rows = {}
    for i = 1, 4 do
        local y = 418 + (i - 1) * 25
        local l = Txt(zone, "Label", { Name = "RL" .. i, Text = "", Position = UDim2.fromOffset(P, y), Size = UDim2.new(0.62, -P, 0, 25) })
        local v = Txt(zone, "Value", { Name = "RV" .. i, Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -P, 0, y), Size = UDim2.new(0.38, -P, 0, 25),
            TextXAlignment = Enum.TextXAlignment.Right })
        id.Rows[i] = { L = l, V = v }
    end
    id.AllStats = InvLayout.Btn(zone, "ALL STATS", { Name = "AllStats", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, P, 1, -22), Size = UDim2.new(1, -P * 2, 0, 34) })
    id.AllStats.TextXAlignment = Enum.TextXAlignment.Left
    New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = id.AllStats })
    Txt(id.AllStats, "Button", { Name = "Chevron", Text = "›", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 20, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right })
    if onAllStats then id.AllStats.Activated:Connect(onAllStats) end
    function id.Set(d: any)
        id.Icon.Image = d.Icon or ""
        id.Icon.Visible = d.Icon ~= nil and d.Icon ~= ""
        id.Name.Text = d.Name or ""
        id.Meta.Text = d.Meta or ""
        id.Xp.Size = UDim2.fromScale(math.clamp(d.Xp or 0, 0, 1), 1)
        id.Dps.Text = d.Dps or "0"
        for k, v in pairs(d.Pair or {}) do if id.Pair[k] then id.Pair[k].Text = v end end
        for k, v in pairs(d.Attr or {}) do if id.Attr[k] then id.Attr[k].Text = v end end
        for i, r in ipairs(id.Rows) do
            local row = d.Rows and d.Rows[i]
            r.L.Text = row and row[1] or ""; r.V.Text = row and row[2] or ""
        end
    end
    return id
end

-- ===== SOCKETS (2026-11-09, builder inv; owner: "there needs to be an indicator in the inventory for the # of slots like POE") =====
-- A gun's sockets (item.Sockets "R-G-B B": '-' linked, ' ' a new group) as a row of round dots in their colours, LINKED
-- neighbours joined by a short bar behind them, a wider gap between groups. A socket with a mod in it (item.SocketMods[i])
-- gets an off-white ring; an empty one is the plain colour. Static: one Frame + UICorner per dot, one Frame per link.
-- opts = { Dot (px, 10), Link (bar gap, 4), Split (group gap, 8), MaxW (shrinks the dots to fit, never under 6), AnchorPoint,
-- Position, ZIndex }. Returns the holder (nil = no sockets) and its width.
InvLayout.SOCKET_COLORS = { W = Color3.fromRGB(232, 228, 220) }
for k, hex in pairs((ItemData.SOCKETS and ItemData.SOCKETS.Hex) or {}) do InvLayout.SOCKET_COLORS[k] = Color3.fromHex(hex) end
InvLayout.LINK_COLOR = Color3.fromRGB(214, 196, 160) -- (a warm light bar: reads as "joined" on every rarity tint)
function InvLayout.SocketsWidth(n: number, links: number, d: number, link: number, split: number): number
    return n * d + links * link + math.max(0, n - 1 - links) * split
end
function InvLayout.Sockets(parent: Instance, item: any, opts: any?): (Frame?, number)
    local list = (ItemData.ParseSockets and item and type(item.Sockets) == "string") and ItemData.ParseSockets(item.Sockets) or {}
    if #list == 0 then return nil, 0 end
    opts = opts or {}
    local d, link, split = opts.Dot or 10, opts.Link or 4, opts.Split or 8
    local links = 0
    for i = 2, #list do if list[i][2] then links += 1 end end
    if opts.MaxW then
        while d > 6 and InvLayout.SocketsWidth(#list, links, d, link, split) > opts.MaxW do
            d -= 1
            if d <= 8 then link, split = 3, 5 end
        end
    end
    local w = InvLayout.SocketsWidth(#list, links, d, link, split)
    local z = opts.ZIndex or ((parent:IsA("GuiObject") and (parent :: GuiObject).ZIndex) or 1)
    local holder = Mark(New("Frame", { Name = "Sockets", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = opts.AnchorPoint or Vector2.new(0.5, 0.5),
        Position = opts.Position or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, d), ZIndex = z, Parent = parent })) :: Frame
    holder:SetAttribute("Sockets", item.Sockets) -- (the Studio check reads it back)
    local mods = type(item.SocketMods) == "table" and item.SocketMods or {}
    local x = 0
    local barH = (d >= 10) and 3 or 2
    for i, s in ipairs(list) do
        if i > 1 then
            if s[2] then
                Mark(New("Frame", { Name = "Link", BorderSizePixel = 0, BackgroundColor3 = InvLayout.LINK_COLOR, Position = UDim2.fromOffset(x - d / 2, math.floor((d - barH) / 2)),
                    Size = UDim2.fromOffset(d + link, barH), ZIndex = z, Parent = holder }))
                x += link
            else
                x += split
            end
        end
        local col = InvLayout.SOCKET_COLORS[s[1]] or C.Text
        local filled = mods[i] ~= nil or mods[tostring(i)] ~= nil
        local dot = Mark(New("Frame", { Name = "S" .. i, BorderSizePixel = 0, BackgroundColor3 = filled and col or col:Lerp(C.Bg0, 0.18), Position = UDim2.fromOffset(x, 0),
            Size = UDim2.fromOffset(d, d), ZIndex = z + 1, Parent = holder })) :: Frame
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
        if filled then
            New("UIStroke", { Color = C.Text, Thickness = (d >= 10) and 2 or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = dot })
        end
        x += d
    end
    return holder, w
end

-- ===== SLOT CARD (the ONE equipped-slot component) =====
-- returns the slot table the client fills: { Btn, Cap, Name, Sub, X, Strip, Icon, Stroke, Key }
function InvLayout.SlotCard(parent: Instance, key: string, label: string): any
    local b = New("TextButton", { Name = "Slot_" .. key, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = C.Bg1,
        ClipsDescendants = true, Parent = parent }) :: TextButton
    b:SetAttribute("NoNeon", true); Mark(b)
    local st = New("UIStroke", { Color = C.Text, Transparency = 0.93, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b }) :: UIStroke
    local strip = Mark(New("Frame", { Name = "RarityEdge", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2), Parent = b })) :: Frame
    local cap = Txt(b, "Meta", { Name = "Cap", Text = label, Position = UDim2.fromOffset(12, 9), Size = UDim2.new(1, -24, 0, 16) })
    local reserved = InvLayout.ART_W + 18
    local nm = Txt(b, "ItemName", { Name = "ItemName", Text = "", Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -(12 + reserved), 0, 22) })
    nm.TextSize = 17
    local sub = Txt(b, "Meta", { Name = "Sub", Text = "", Position = UDim2.new(0, 12, 1, -25), Size = UDim2.new(1, -24, 0, 16) })
    local icon = Mark(New("ImageLabel", { Name = "SlotIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 2), Size = UDim2.fromOffset(46, 46), ScaleType = Enum.ScaleType.Fit, ZIndex = b.ZIndex, Parent = b })) :: ImageLabel
    local x = New("TextButton", { Name = "Unequip", Text = "×", AutoButtonColor = false, BackgroundColor3 = C.Bg2, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(20, 20), Visible = false, ZIndex = b.ZIndex + 2,
        Font = Enum.Font.GothamBold, TextColor3 = C.Text, TextSize = 16, Parent = b }) :: TextButton
    x:SetAttribute("NoNeon", true); Mark(x)
    x:SetAttribute("TextRole", "Button")
    local slot = { Btn = b, Cap = cap, Name = nm, Sub = sub, X = x, Strip = strip, Icon = icon, Stroke = st, Key = key, Item = nil }
    local hover = false
    local function Bg()
        local col = slot.Col
        if slot.Item and col then
            b.BackgroundColor3 = C.Bg1:Lerp(col, hover and 0.13 or 0.07)
            b.BackgroundTransparency = 0
        else
            b.BackgroundColor3 = hover and C.Bg2 or C.Bg1
            b.BackgroundTransparency = hover and 0.2 or 0.45
        end
        x.Visible = slot.CanUnequip == true and slot.Item ~= nil and (hover or slot.ShowX == true)
    end
    slot.Repaint = Bg
    b.MouseEnter:Connect(function() hover = true; Bg() end)
    b.MouseLeave:Connect(function() hover = false; Bg() end)
    b.SelectionGained:Connect(function() hover = true; Bg() end)
    b.SelectionLost:Connect(function() hover = false; Bg() end)
    return slot
end
-- paint a slot: item = nil -> the same card dimmed ("EMPTY", "Nothing equipped", a faint glyph)
function InvLayout.PaintSlot(slot: any, item: any?, col: Color3?, name: string?, sub: string?, canUnequip: boolean?, spec: any?)
    slot.Item, slot.Col, slot.CanUnequip = item, col, canUnequip
    local on = item ~= nil
    slot.Name.Text = on and string.upper(name or "") or "EMPTY"
    -- (the name is read against the hover tint = the worst case it sits on)
    slot.Name.TextColor3 = on and InvLayout.Readable(col or C.Text, C.Bg1:Lerp(col or C.Text, 0.13)) or InvLayout.DIM
    slot.Sub.Text = on and (sub or "") or "Nothing equipped"
    slot.Sub.TextColor3 = on and C.Sub or C.Muted
    slot.Cap.TextColor3 = on and C.Sub or C.Muted
    slot.Strip.Visible = on
    slot.Strip.BackgroundColor3 = col or C.Line
    slot.Stroke.Transparency = on and 1 or 0.93
    local s = spec or InvLayout.IconFor(item, slot.Key)
    local img = slot.Icon
    img.AnchorPoint = Vector2.new(1, 0.5)
    if s.Glyph or s.Square then
        img.Position = UDim2.new(1, -16, 0, 40)
        InvLayout.ApplyIcon(img, s, InvLayout.ART_W, InvLayout.ART_H, 40)
    else
        img.Position = UDim2.new(1, -10, 0, 40)
        InvLayout.ApplyIcon(img, s, InvLayout.ART_W, InvLayout.ART_H)
    end
    img.ImageColor3 = on and C.Text or C.Text
    img.ImageTransparency = on and 0.15 or 0.84
    -- (2026-11-09 SOCKETS) the equipped gun's sockets under its icon; the sub-line gives up the icon column while they show
    if slot.SocketRow then slot.SocketRow:Destroy(); slot.SocketRow = nil end
    slot.SocketRow = on and InvLayout.Sockets(slot.Btn, item, { Dot = 10, MaxW = InvLayout.ART_W + 6, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -(10 + InvLayout.ART_W / 2), 1, -17), ZIndex = slot.Btn.ZIndex + 1 }) or nil
    slot.Sub.Size = slot.SocketRow and UDim2.new(1, -(24 + InvLayout.ART_W + 8), 0, 16) or UDim2.new(1, -24, 0, 16)
    slot.Repaint()
end

-- ===== ITEM ROW CARD (UI CLEAN R-B) =====
-- ONE list card for an item in every window that lists items (Forge, Exchange, Buyback, Lost Loot, Trade, Mods, Stash tabs):
-- the slot card's language in a row -- flat Bg1 with a faint rarity tint, a 2 px rarity edge at the bottom, the name in the
-- display face in the (readable) rarity colour, one Label sub-line, the icon in a RESERVED right box (aspect kept), an optional
-- right-side tag (price / count / EQUIPPED). Selected = a stronger tint + a 1 px off-white edge. Returns the TextButton (the
-- caller connects its own click) with fields in a table: { Btn, Name, Sub, Tag, Icon, Set(selected) }.
-- opts = { Item, Name, Sub, Color, Selected, Height (56), Order, Tag, TagColor, SlotKey, NoIcon, Width (UDim), RightPad,
-- ArtW / ArtH (a narrow list: a smaller icon box, e.g. 56 x 24) }
InvLayout.ROW_H = 56
InvLayout.ROW_ART_W, InvLayout.ROW_ART_H = 84, 34
function InvLayout.ItemRow(parent: Instance, opts: any): any
    local col = opts.Color or (opts.Item and ItemData.ItemColor and ItemData.ItemColor(opts.Item)) or C.Text
    local h = opts.Height or InvLayout.ROW_H
    local b = Mark(New("TextButton", { Name = opts.Name and ("Row_" .. string.sub(tostring(opts.Name), 1, 24)) or "Row", Text = "", AutoButtonColor = false,
        BorderSizePixel = 0, BackgroundColor3 = C.Bg1, BackgroundTransparency = 0, Size = opts.Width and UDim2.new(opts.Width, UDim.new(0, h)) or UDim2.new(1, 0, 0, h),
        LayoutOrder = opts.Order or 0, ClipsDescendants = true, Parent = parent })) :: TextButton
    b:SetAttribute("NoNeon", true)
    local st = Mark(New("UIStroke", { Thickness = 1, Color = C.Text, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b }))
    Mark(New("Frame", { Name = "RarityEdge", BorderSizePixel = 0, BackgroundColor3 = col, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2), Parent = b }))
    local r = { Btn = b }
    local reserved = 12
    if not opts.NoIcon then
        local spec = InvLayout.IconFor(opts.Item, opts.SlotKey)
        local img = Mark(New("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -1),
            ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.Text, ImageTransparency = spec.Glyph and 0.3 or 0.1, Parent = b })) :: ImageLabel
        local aw, ah = opts.ArtW or InvLayout.ROW_ART_W, opts.ArtH or InvLayout.ROW_ART_H
        -- (2026-11-09 SOCKETS) a gun's sockets under its icon, in the icon's column (the icon shrinks / lifts to make room)
        local socks = (not opts.NoSockets) and opts.Item and InvLayout.Sockets(b, opts.Item, { Dot = 8, MaxW = aw + 16, AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(1, -(12 + aw / 2), 1, -6), ZIndex = b.ZIndex + 1 }) or nil
        if socks then
            ah = math.min(ah, h - 24)
            img.Position = UDim2.new(1, -12, 0, math.floor((h - 12) / 2) - 1)
        end
        InvLayout.ApplyIcon(img, spec, aw, ah, math.min(28, ah))
        r.Icon, r.Sockets = img, socks
        reserved = aw + 24
    end
    local tagW = 0
    if opts.Tag then
        tagW = 96
        r.Tag = Txt(b, "Value", { Name = "Tag", Text = tostring(opts.Tag), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -reserved, 0.5, -1),
            Size = UDim2.fromOffset(tagW, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = opts.TagColor or C.Text })
    end
    r.Reserved = reserved -- (a caller's own buttons go at UDim2.new(1, -(r.Reserved + their width), ...) with opts.RightPad = that room)
    local textW = -(12 + reserved + (tagW > 0 and tagW + 8 or 0) + (opts.RightPad or 0))
    r.Name = Txt(b, "ItemName", { Name = "ItemName", Text = string.upper(tostring(opts.Name or "")), Position = UDim2.fromOffset(12, h >= 50 and 8 or 4),
        Size = UDim2.new(1, textW, 0, 20), TextColor3 = col })
    r.Name.TextSize = 17 -- (the slot cards' name size: Oswald caps at 15 read smaller than the body sub-line under them)
    r.Sub = Txt(b, "Label", { Name = "Sub", Text = tostring(opts.Sub or ""), Position = UDim2.fromOffset(12, h >= 50 and 29 or 24),
        Size = UDim2.new(1, textW, 0, 17) })
    r.Sub.TextSize = 13
    local hover = false
    local selected = opts.Selected == true
    local function Paint()
        b.BackgroundColor3 = C.Bg1:Lerp(col, selected and 0.16 or (hover and 0.11 or 0.06))
        st.Transparency = selected and 0.55 or 1
        r.Name.TextColor3 = InvLayout.Readable(col, C.Bg1:Lerp(col, 0.16))
    end
    function r.Set(on: boolean) selected = on; Paint() end
    b.MouseEnter:Connect(function() hover = true; Paint() end)
    b.MouseLeave:Connect(function() hover = false; Paint() end)
    b.SelectionGained:Connect(function() hover = true; Paint() end)
    b.SelectionLost:Connect(function() hover = false; Paint() end)
    Paint()
    return r
end

-- ===== BAG TILE =====
-- tile = the TextButton the client made; paints it as an image tile (rarity tint + 2 px bottom edge, the icon centred, the name
-- small at the bottom in the rarity colour, ▲ = an upgrade, E = equipped). Returns { Icon, Name, Up, Eq }.
function InvLayout.PaintTile(tile: TextButton, item: any, name: string, col: Color3, up: boolean, equipped: boolean, spec: any?)
    tile.Text = ""
    tile.AutoButtonColor = false
    tile.BorderSizePixel = 0
    tile.ClipsDescendants = true
    tile.BackgroundColor3 = C.Bg1:Lerp(col, 0.07)
    tile.BackgroundTransparency = 0
    tile:SetAttribute("NoNeon", true)
    local t = {}
    Mark(New("Frame", { Name = "RarityEdge", BorderSizePixel = 0, BackgroundColor3 = col, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2), Parent = tile }))
    local s = spec or InvLayout.IconFor(item, nil)
    t.Icon = Mark(New("ImageLabel", { Name = "TileIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0),
        ScaleType = Enum.ScaleType.Fit, ImageTransparency = s.Glyph and 0.25 or 0, Parent = tile })) :: ImageLabel
    InvLayout.ApplyIcon(t.Icon, s, 92, 36, 34)
    -- (2026-11-09 SOCKETS) a gun's sockets + links between the icon (lifted 6 px) and the name, like the reference game's art
    t.Sockets = InvLayout.Sockets(tile, item, { Dot = 11, MaxW = 108, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 61), ZIndex = tile.ZIndex + 1 })
    if t.Sockets then t.Icon.Position = UDim2.new(0.5, 0, 0, 31) end
    t.Name = Txt(tile, "Meta", { Name = "TileName", Text = string.upper(name), Font = Enum.Font.GothamBlack, TextColor3 = InvLayout.Readable(col, tile.BackgroundColor3),
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -7), Size = UDim2.new(1, -16, 0, 16) })
    t.Name:SetAttribute("TypeRole", "Label") -- (the display face at the small size: tile names are smaller than slot names)
    if up then
        t.Up = Txt(tile, "Meta", { Name = "Up", Text = "▲", TextColor3 = C.Good, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 5),
            Size = UDim2.fromOffset(16, 14), TextXAlignment = Enum.TextXAlignment.Right })
    end
    if equipped then
        t.Eq = Txt(tile, "Meta", { Name = "Eq", Text = "E", TextColor3 = C.Text, Font = Enum.Font.GothamBlack, Position = UDim2.fromOffset(7, 6),
            Size = UDim2.fromOffset(16, 16), TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 1 })
        t.Eq.BackgroundColor3 = C.Text
        t.Eq.BackgroundTransparency = 0.86
        t.Eq:SetAttribute("TypeRole", "Label")
    end
    local hover = false
    local edge = New("UIStroke", { Color = C.Text, Transparency = 1, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tile }) :: UIStroke
    local function Bg()
        tile.BackgroundColor3 = C.Bg1:Lerp(col, hover and 0.13 or 0.07):Lerp(C.Text, hover and 0.03 or 0)
        edge.Transparency = hover and 0.65 or 1
    end
    tile.MouseEnter:Connect(function() hover = true; Bg() end)
    tile.MouseLeave:Connect(function() hover = false; Bg() end)
    tile.SelectionGained:Connect(function() hover = true; Bg() end)
    tile.SelectionLost:Connect(function() hover = false; Bg() end)
    return t
end
-- lay a tile's action buttons (lock / STASH / EQUIP / price / dismantle / R1 / R2 ...) into a row along its TOP, right to left,
-- wrapping downward (the name at the bottom stays readable); each button's width = its attr TileW
function InvLayout.TileActions(tile: GuiObject, acts: { GuiObject })
    local k = math.max(tile.AbsoluteSize.Y / InvLayout.TILE_H, 0.01)
    local w = tile.AbsoluteSize.X / k
    local x, y = w - 4, 4
    for i = #acts, 1, -1 do
        local a = acts[i]
        local bw = (a:GetAttribute("TileW") or 44)
        if x - bw < 4 then x = w - 4; y += 24 end
        a.AnchorPoint = Vector2.new(1, 0)
        a.Position = UDim2.fromOffset(x, y)
        a.Size = UDim2.fromOffset(bw, 22)
        x -= bw + 3
    end
end

return InvLayout
