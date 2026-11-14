--!nocheck
-- ============================================================================================
-- RUN HUD LOOK (UI CLEAN R-C "runui", 2026-10-28; contract docs/UI_CLEAN_2026-10-28.md, target docs/ui_target/inventory_target.html).
-- ONE plate style for every run / HUD piece that floats over the world: the top currency row, the floor banner, the SAFE ZONE
-- line, the floor-modifier / objective / clock lines, the room objective strip, toasts, the life-lost card, the boss banner.
--   PLATE   flat Colors.Bg0 at PLATE_T (see-through over the world), square, NO stroke / gradient / corner / coloured edge bar.
--   CARD    the same slate nearly opaque (CARD_T) for pieces that hold buttons or read like a small window (out of lives,
--           ready check, popups) -- still no edge bar; one 1 px hairline at most.
--   TYPE    heads = small caps display (Label role, Sub), names / numbers = display (Text), sentences = Roboto body.
--           Text on a plate has NO text stroke (the plate carries the contrast).
--   MARKS   one at most per piece: a 2 px line (a progress line, a selected tick) -- in Text, or in a meaning colour
--           (Good when done, rarity on loot). Never a coloured slab, never a glow.
-- API (all small, no per-frame work):
--   RunHud.Strip(obj)                       remove old chrome children (UIStroke / UIGradient / UICorner / Block / Pip / Shadow)
--   RunHud.Plate(obj, t?)                   Strip + flat Bg0 at t (default PLATE_T); marks it NoSkin + Skinned
--   RunHud.Role(text, role, opts?)          UIStyle.TextRole + the role's face set directly + no text stroke
--   RunHud.Num(text, size, color?)          a display number (Oswald SemiBold), no stroke
--   RunHud.Pad(obj, l, r, t?, b?)           a UIPadding
--   RunHud.Currency(parent, defs) -> { [key] = TextLabel }   the top currency row (icon + display number, one plate)
-- ============================================================================================
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colors

local RunHud = {}
RunHud.PLATE_T = 0.45 -- HUD plates over the world: the SAME as the bottom HUD plate (HudClean HudPlate) + the goal tracker
RunHud.CARD_T = 0.06 -- small cards with buttons (out of lives, ready check, popups): the window body's transparency
RunHud.GAP = 4 -- between stacked top-centre lines

local CHROME = { Block = true, Pip = true, Shadow = true, AccentGlow = true, Glow = true, Gloss = true, Tick = false }
function RunHud.Strip(o: Instance)
    for _, c in ipairs(o:GetChildren()) do
        if string.sub(c.Name, 1, 6) == "RunHud" then
            continue -- (our own pieces)
        elseif c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UICorner") then
            c:Destroy()
        elseif (c:IsA("Frame") or c:IsA("ImageLabel")) and CHROME[c.Name] then
            c:Destroy()
        end
    end
end

function RunHud.Plate(o: GuiObject, t: number?): GuiObject
    RunHud.Strip(o)
    o.BackgroundColor3 = C.Bg0
    o.BackgroundTransparency = t or RunHud.PLATE_T
    o.BorderSizePixel = 0
    o:SetAttribute("NoSkin", true)
    o:SetAttribute("Skinned", true)
    return o
end

local FACE = { Header = "Header", Label = "Label", SemiBold = "SemiBold", Body = "Body" }
function RunHud.Role(o: any, role: string, opts: { [string]: any }?): any
    UIStyle.TextRole(o, role, opts)
    local r = UIStyle.TEXT_ROLES[role]
    if r then o.FontFace = UIStyle.RoleFace(FACE[r.Face] or "Body") end
    o.TextStrokeTransparency = 1
    return o
end

function RunHud.Num(o: any, size: number, color: Color3?): any
    o:SetAttribute("TypeRole", "Accent")
    o:SetAttribute("TextRole", "Number") -- (a display number: its size is its own -- the probe lists it by this role)
    o.FontFace = UIStyle.RoleFace("Accent")
    o.TextSize = size
    o.TextColor3 = color or C.Text
    o.TextStrokeTransparency = 1
    return o
end

function RunHud.Pad(o: Instance, l: number, r: number, t: number?, b: number?): UIPadding
    local p = Instance.new("UIPadding")
    p.PaddingLeft, p.PaddingRight = UDim.new(0, l), UDim.new(0, r)
    p.PaddingTop, p.PaddingBottom = UDim.new(0, t or 0), UDim.new(0, b or 0)
    p.Parent = o
    return p
end

-- a top-centre info LINE (floor modifiers, objective, daily / map clock, Loot Storm, City Broadcast): the plate sized to its
-- text (AutomaticSize X, centred by its AnchorPoint), LINE_H tall, display caps 14 in Text (rich-text colours inside stay).
RunHud.LINE_H = 24
function RunHud.Line(lbl: TextLabel, maxW: number?): TextLabel
    RunHud.Plate(lbl)
    lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.Size = UDim2.fromOffset(0, RunHud.LINE_H)
    lbl.TextWrapped = false
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    if not lbl:FindFirstChildOfClass("UIPadding") then RunHud.Pad(lbl, 10, 10) end
    local cap = lbl:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
    cap.MaxSize = Vector2.new(maxW or 860, RunHud.LINE_H)
    cap.Parent = lbl
    RunHud.Role(lbl, "SectionHead") -- (Text; callers that tint a line set TextColor3 after)
    lbl.TextSize = 14
    return lbl
end

-- a plain TextButton (older hand-built HUD buttons) in the UIStyle.Button roles without rebuilding it:
--   "Primary"   filled accent (Colors.Accent), OnAccent caps          "Secondary" transparent, 1 px hairline, Text caps
-- RunHud.BtnState(b, kind, enabled) re-applies it (disabled = secondary, Muted words). Hover = one surface step.
function RunHud.Btn(b: TextButton, kind: string?, enabled: boolean?): TextButton
    RunHud.Strip(b)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b:SetAttribute("NoSkin", true); b:SetAttribute("Skinned", true)
    local st = b:FindFirstChild("RunHudEdge") :: UIStroke?
    if not st then
        st = Instance.new("UIStroke"); st.Name = "RunHudEdge"; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Thickness = 1; st.Color = C.Text
        st.Parent = b
        RunHud.Role(b, "Button")
        b.MouseEnter:Connect(function() if b:GetAttribute("RunHudOn") ~= false then b:SetAttribute("RunHudHover", true); RunHud.BtnState(b) end end)
        b.MouseLeave:Connect(function() b:SetAttribute("RunHudHover", nil); RunHud.BtnState(b) end)
    end
    RunHud.BtnState(b, kind, enabled)
    return b
end
function RunHud.BtnState(b: TextButton, kind: string?, enabled: boolean?)
    if kind then b:SetAttribute("RunHudKind", kind) end
    if enabled ~= nil then b:SetAttribute("RunHudOn", enabled) end
    local k = b:GetAttribute("RunHudKind") or "Secondary"
    local on = b:GetAttribute("RunHudOn") ~= false
    local hov = b:GetAttribute("RunHudHover") == true and on
    local st = b:FindFirstChild("RunHudEdge") :: UIStroke?
    if k == "Primary" and on then
        b.BackgroundColor3 = hov and C.Accent:Lerp(Color3.new(1, 1, 1), 0.12) or C.Accent
        b.BackgroundTransparency = 0
        b.TextColor3 = C.OnAccent
        if st then st.Transparency = 1 end
    else
        b.BackgroundColor3 = C.Bg2
        b.BackgroundTransparency = hov and 0.2 or 1
        b.TextColor3 = on and C.Text or C.Muted
        if st then st.Transparency = on and 0.78 or 0.88 end
    end
    b.Active = on
end

-- THE TOP CURRENCY ROW (target: icon + display number pairs, no box per currency). parent = the CurrencyHUD frame (right
-- anchored on the screen grid); defs = { { Key, Icon, Color, Order } }. One plate behind the whole row. Returns the number
-- labels by key (the client's refresh code writes .Text exactly as it did into the old chips).
RunHud.CUR_H = 32
function RunHud.Currency(parent: Frame, defs: { any }): { [string]: TextLabel }
    RunHud.Plate(parent)
    parent.AutomaticSize = Enum.AutomaticSize.X
    parent.Size = UDim2.fromOffset(0, RunHud.CUR_H)
    for _, c in ipairs(parent:GetChildren()) do if c:IsA("UIListLayout") or c:IsA("UIPadding") then c:Destroy() end end
    local lay = Instance.new("UIListLayout")
    lay.FillDirection = Enum.FillDirection.Horizontal
    lay.VerticalAlignment = Enum.VerticalAlignment.Center
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 16)
    lay.Parent = parent
    RunHud.Pad(parent, 12, 12)
    local out = {}
    for i, d in ipairs(defs) do
        local item = Instance.new("Frame")
        item.Name = d.Key
        item.BackgroundTransparency = 1
        item.AutomaticSize = Enum.AutomaticSize.X
        item.Size = UDim2.fromOffset(0, RunHud.CUR_H)
        item.LayoutOrder = d.Order or i
        item.Parent = parent
        local il = Instance.new("UIListLayout")
        il.FillDirection = Enum.FillDirection.Horizontal
        il.VerticalAlignment = Enum.VerticalAlignment.Center
        il.SortOrder = Enum.SortOrder.LayoutOrder
        il.Padding = UDim.new(0, 6)
        il.Parent = item
        if d.Icon and UIStyle.HasIcon(d.Icon) then
            UIStyle.Icon(d.Icon, { Name = "Icon", Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = item })
        else -- (an icon not uploaded: a small square in the currency's colour)
            local sq = Instance.new("Frame")
            sq.Name = "Icon"; sq.BorderSizePixel = 0; sq.BackgroundColor3 = d.Color or C.Sub; sq.Size = UDim2.fromOffset(8, 8); sq.LayoutOrder = 1
            sq.Parent = item
        end
        local t = Instance.new("TextLabel")
        t.Name = "Value"
        t.BackgroundTransparency = 1
        t.AutomaticSize = Enum.AutomaticSize.X
        t.Size = UDim2.fromOffset(0, RunHud.CUR_H)
        t.Text = "0"
        t.LayoutOrder = 2
        t:SetAttribute("NoSkin", true)
        t.Parent = item
        RunHud.Num(t, 17, C.Text)
        out[d.Key] = t
    end
    return out
end

return RunHud
