--!nocheck
-- Shared look for every menu. UI CLEAN (2026-10-28, owner: "The UI still looks really bad ... clean up the text style,
-- overall style / aesthetic of the inventory, cards, menus etc. Lets shift to a more valorant style text and style, and
-- focus on clean setups"; contract docs/UI_CLEAN_2026-10-28.md). It replaces the v3 icon look (facet + ink edge) and the
-- v4 NEON chrome (glow halos, neon edges, bloom, shadows). The look is FLAT, SHARP, QUIET and TYPE-LED -- our own palette:
--   * SURFACES   flat dark slate (Bg0 window ~0.06 transparent over the world, Bg1 raised rows / cards, Bg2 hover /
--                selected, Well inset). NO gradients, glow / halo / bloom, facets, ink edges, drop shadows, scanlines.
--                Corners square (2 px max). UIStyle.Facet / FacetGrad / Gradient are FLAT now (the lit colour only).
--   * LINES      1 px hairlines (Colors.Line / Border) for structure. ONE accent mark at most per element: the 2 px
--                underline under a selected tab, a 2-3 px left tick on a selected row / a window title.
--   * TYPE       two families. DISPLAY = Oswald (the most condensed face Roblox ships; tall narrow caps) Bold for titles /
--                section heads / big numbers, SemiBold for buttons, tabs, labels and data (TypeKits.Default Header /
--                Label / Accent). BODY = Roboto (the plainest grotesk Roblox ships, readable at 12-14 px) for descriptions,
--                stat lines, lists, in sentence case. Text: warm off-white Text, Sub ~62% (>= 4.5:1 on Bg1), Muted ~42%.
--                TYPE SCALE UIStyle.Size Display 34 / Title 26 / Heading 20 / Subhead 17 / Body 15 / Label 14 / Caption
--                13; floor MIN_TEXT 12 (ApplyType lifts it); roles via attrs TypeRole / KeepFont (see TYPE SYSTEM).
--   * COLOUR     neutral surfaces + off-white text carry the screen. ONE accent (Colors.Accent, picked by
--                UIStyle.ACCENT_VARIANT: "W" = off-white = the Text colour (round 2: the owner's accepted target; the
--                red-coral "A" is dropped), "B" = the old cyan) for the primary action and
--                selection only. Good / Warn / Bad stay, quieter (text or a thin mark). Rarity colours unchanged (names,
--                a thin rarity edge). Gold = currency only.
--   * BUTTONS    UIStyle.Button(parent, text, colour, size, pos): the colour is its ROLE -- primary (Accent / Gold / the
--                old gold) = filled accent, ink or light text by contrast; dark colours = secondary: transparent with a
--                1 px hairline and off-white caps; other hues = a faint tint of the hue, its hue on the label + edge;
--                api.SetStrong(true) = filled in its hue. Hover = surface one step lighter (no glow, no grow), pressed =
--                darker, gamepad selection = hover (+ PadMenus' accent edge). api.SetSelected(on, "Left"|nil) = the
--                accent mark; api.SetQuiet(true) = no hairline at rest (tabs).
--   * MOTION     short fades on open / value change only (Motion.Open veil, CountUp). No loops, no per-frame work.
--   * LAYERS     UIStyle.Z HUD 5, windows 10, phone windows 12, popups 30, toasts 50, tooltips 200.
--   * TEXT ROLES UIStyle.TEXT_ROLES / TextRole (P4): WindowTitle 26 / Title 20 / SectionHead 15 / ItemName 15 / Tab 15 /
--                Value 15 / Button 14 / Label 14 / Body 14 / Meta 13. A head is never dimmer or smaller than what it heads;
--                labels Sub, values Text, hints Muted. A rarity name is lifted to >= 4.6:1 on its card (InvLayout.Readable).
--   * BIG MENUS  (round 2, the inventory TARGET = docs/ui_target/inventory_target.html) a window in MENU_WINDOWS opens over a
--                full-screen dark field with the TOP BAR (MenuTop): its group's window names as a nav (selected = off-white
--                + 2 px underline; NavOpen[id] opens a sibling), the subtitle quiet, the X far right; the window's own box /
--                title hide on desktop (phones keep them). MenuField does the same for a non-Panel window (the tree). Texts
--                built before the roles are snapped once onto the role sizes / neutrals (SnapText). Items in lists = ONE
--                row card (InvLayout.ItemRow: rarity edge + tint, display name, Label sub-line, the icon in a reserved box,
--                aspect kept -- AimRngShared/ItemIcons art when it exists); every action row of a kind looks the same.
--   * COMPONENTS Panel, TitleBar, CloseButton, Button, Card, Chip, TabBar, SectionHeader, StatRow, Divider, KeyCap,
--                EmptyState, StyleScroll; Skin / SkinWindow / NeonButton re-skin older hand-built UI the same way.
--                Glow / GlowTo / HoverGlow / Shadow / NeonEdge / InkEdge still exist for callers but draw nothing.
-- Premium UI themes (UITheme / HudThemes) still apply on top (UIT_* tags, AccentGlow colour, SetBars); Default = this.
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local UIStyle = {}
-- UI themes (UITheme): what these builders make is tagged so the equipped theme restyles it -- window surfaces,
-- title bars, cards and chips (the client tags its HUD panels).
local function Tag(inst, tag) CollectionService:AddTag(inst, tag) end

UIStyle.Font = Enum.Font.FredokaOne -- headers, buttons, numbers (remapped to the type system below at runtime)

-- ===== TYPE SYSTEM v2 (2026-10-02, owner: "the text is insanely inconsistent throughout all menus ... fonts should
-- follow actual design protocol: a header choice, a body choice and an accent choice, per UI theme, universal").
-- Every text object in the game (PlayerGui + world boards / tags) gets ONE role, worked out once from the font its
-- code built it with, and the equipped theme's KIT decides the face for each role:
--   Header -- window titles, section headings, hero text (big display text)      kit.Header
--   Label  -- buttons, tabs, chips, badges, small caps labels (small display text) kit.Label (default: Body ExtraBold)
--   Body   -- descriptions, lists, stat lines (keeps its Medium / SemiBold / Bold)   kit.Body family
--   Accent -- numbers and data: currencies, ammo, prices, timers, keybinds, mono     kit.Accent
-- Body faces are always clean sans serifs (readable at 11-14 px); display / serif / techno faces only go on Header
-- (and Label / Accent where the kit says so). Code that changes .Font later is caught and re-mapped (that was the
-- "old text" mixed into new menus: the legacy skin pass set FredokaOne after the type pass had run).
-- Opt out: attribute KeepFont = true. Force a role: attribute TypeRole = "Header" | "Label" | "Body" | "Accent".
local W = Enum.FontWeight
local function FF(family: string, weight: Enum.FontWeight?): Font
    return Font.new("rbxasset://fonts/families/" .. family .. ".json", weight or W.Regular)
end
UIStyle.FF = FF
local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
UIStyle.Type = { -- (kept for callers that set a face directly)
    Display = Font.new(FAMILY, W.Heavy), Heading = Font.new(FAMILY, W.ExtraBold), Bold = Font.new(FAMILY, W.Bold),
    SemiBold = Font.new(FAMILY, W.SemiBold), Body = Font.new(FAMILY, W.Medium),
    Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", W.Bold),
}
-- one kit per UI theme id (HudThemes); a theme without its own kit uses Default
UIStyle.TypeKits = {
    -- (Update 5: numbers / data in Roboto Condensed -- compact, plain, the same family as the body; Sarpanch's wide
    -- techno digits read as a novelty face at HUD sizes. Headers + labels stay Oswald: the condensed caps of the icons.)
    -- (UI CLEAN 2026-10-28: numbers / data in the display face too -- Oswald SemiBold, tall and tight like the titles)
    Default = { Header = FF("Oswald", W.Bold), Body = "Roboto", Accent = FF("Oswald", W.SemiBold), Label = FF("Oswald", W.SemiBold) },
    Midnight = { Header = FF("Montserrat", W.ExtraBold), Body = "Montserrat", Accent = FF("RobotoMono", W.Bold) },
    Emerald = { Header = FF("TitilliumWeb", W.Heavy), Body = "TitilliumWeb", Accent = FF("Jura", W.Bold) },
    Crimson = { Header = FF("Oswald", W.Bold), Body = "Roboto", Accent = FF("RobotoCondensed", W.Bold), Label = FF("Oswald", W.SemiBold) },
    Ocean = { Header = FF("Jura", W.Bold), Body = "Nunito", Accent = FF("RobotoMono", W.Bold) },
    Sunset = { Header = FF("Montserrat", W.Heavy), Body = "Nunito", Accent = FF("Oswald", W.SemiBold) },
    Royal = { Header = FF("Merriweather", W.Heavy), Body = "Nunito", Accent = FF("Montserrat", W.Bold) },
    Frost = { Header = FF("JosefinSans", W.Bold), Body = "Montserrat", Accent = FF("Jura", W.Bold) },
    GoldRush = { Header = FF("Merriweather", W.Heavy), Body = "Montserrat", Accent = FF("Oswald", W.SemiBold), Label = FF("Oswald", W.SemiBold) },
    -- premium themes: a signature header face; buttons / chips / numbers in the accent face
    Seraphim = { Header = FF("RomanAntique"), Body = "Nunito", Accent = FF("Merriweather", W.Bold), LabelAccent = true },
    NeonCyber = { Header = FF("Michroma"), Body = "TitilliumWeb", Accent = FF("Sarpanch", W.Bold), LabelAccent = true },
    Inferno = { Header = FF("GrenzeGotisch", W.ExtraBold), Body = "Roboto", Accent = FF("Oswald", W.SemiBold), LabelAccent = true },
    VoidRift = { Header = FF("Sarpanch", W.ExtraBold), Body = "Montserrat", Accent = FF("Jura", W.Bold), LabelAccent = true },
    Prismatic = { Header = FF("TitilliumWeb", W.Heavy), Body = "Nunito", Accent = FF("Montserrat", W.ExtraBold), LabelAccent = true },
}
local kit = UIStyle.TypeKits.Default

local DISPLAY = { FredokaOne = true, GothamBlack = true, Arcade = true, LuckiestGuy = true, Bangers = true, Cartoon = true, Highway = true }
local BOLD = { GothamBold = true, SourceSansBold = true, ArialBold = true, RobotoBold = true }
local SEMI = { GothamMedium = true, GothamSemibold = true, SourceSansSemibold = true }
local MONO = { Code = true, RobotoMono = true }
-- the build-time font -> base: "Display" | "Bold" | "SemiBold" | "Body" | "Mono" (nil = a deliberate custom face)
-- ===== v3 TOKENS (sizes in design pixels at Interface Scale 100%) =====
UIStyle.Size = { Display = 34, Title = 26, Heading = 20, Subhead = 17, Body = 15, Label = 14, Caption = 13 }
UIStyle.MIN_TEXT = 12 -- the floor: nothing in the game is drawn smaller (ApplyType lifts it; scaled text never shrinks below 11)
UIStyle.MIN_SCALED = 11
UIStyle.PHONE_MIN_TEXT, UIStyle.PHONE_MIN_SCALED = 14, 13 -- (phones, text in windows: see ApplyType)
UIStyle.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32 }
-- SCREEN GRID (UI CLEAN P5): every screen-edge HUD piece sits MARGIN design px from the safe edge (left column: the MENU
-- button, the goal tracker under it; right column: the currency chips, the minimap), stacked with GAP between pieces.
UIStyle.MARGIN, UIStyle.GAP = 16, 8
-- TEXT ROLES (UI CLEAN P4, owner: "very inconsistent with the contrast between the headers and the text"): ONE size + ONE
-- colour + ONE face per role -- UIStyle.TextRole(obj, role, opts?) applies it (attr TextRole, read by tools/ui_text_probe.luau).
-- Rules: a header is never dimmer or smaller than the text it heads; labels Sub, values Text; hints Muted (>= 4.5:1).
-- 5 sizes (26 / 20 / 15 / 14 / 13), 3 colours (Text / Sub / Muted) -- rarity / Good / Bad only where they mean something.
-- Two families: the condensed display face (Header / Label) for heads, names, tabs, buttons; Roboto for everything you read,
-- values included (Oswald digits at list sizes read SMALLER than Roboto labels beside them -- the probe's first pass).
--   WindowTitle  26 Text  display bold caps      the window's title
--   Title        20 Text  display caps           item names (rarity colour), big tile numbers, the item card title
--   SectionHead  15 Text  display caps           column heads, sheet sections, tile captions, card sections
--   ItemName     15 Text  display caps           names in small tiles / lists (rarity colour)
--   Tab          15 Sub   display caps           a tab at rest (selected = Text + the 2 px accent underline)
--   Value        15 Text  body semibold          the value right of a label
--   Button       14 Text  display caps           button labels
--   Label        14 Sub   body                   row labels, sub-lines under a name
--   Body         14 Text  body                   descriptions, card lines
--   Meta         13 Muted body                   hints, footnotes
UIStyle.TEXT_ROLES = {
    WindowTitle = { Size = 26, Color = "Text", Face = "Header" },
    Title = { Size = 20, Color = "Text", Face = "Label" },
    SectionHead = { Size = 15, Color = "Text", Face = "Label" },
    ItemName = { Size = 15, Color = "Text", Face = "Label" },
    Tab = { Size = 15, Color = "Sub", Face = "Label" },
    Value = { Size = 15, Color = "Text", Face = "SemiBold" },
    Button = { Size = 14, Color = "Text", Face = "Label" },
    Label = { Size = 14, Color = "Sub", Face = "Body" },
    Body = { Size = 14, Color = "Text", Face = "Body" },
    Meta = { Size = 13, Color = "Muted", Face = "Body" },
}
-- opts: Keep = keep the object's colour (rarity / semantic), Color = a colour NAME from Colors ("Text" / "Sub" / "Muted").
function UIStyle.TextRole(o: Instance, role: string, opts: { [string]: any }?)
    local r = UIStyle.TEXT_ROLES[role]
    if not r or not o then return o end
    local p = opts or {}
    local t = o :: any
    t:SetAttribute("TextRole", role)
    t:SetAttribute("TypeRole", r.Face)
    if t.TextScaled then
        local c = t:FindFirstChildOfClass("UITextSizeConstraint")
        if not c then
            c = Instance.new("UITextSizeConstraint")
            c.Parent = t
        end
        c.MaxTextSize = r.Size
        c.MinTextSize = math.min(UIStyle.MIN_SCALED, r.Size)
    end
    t.TextSize = r.Size
    if not p.Keep then t.TextColor3 = UIStyle.Colors[p.Color or r.Color] end
    return o
end
UIStyle.Z = { Hud = 5, Window = 10, PhoneWindow = 12, Popup = 30, Toast = 50, Tooltip = 200 }

local function Base(o): string?
    local ok, f = pcall(function() return o.Font end)
    if ok and f ~= Enum.Font.Unknown then
        local n = f.Name
        return DISPLAY[n] and "Display" or BOLD[n] and "Bold" or SEMI[n] and "SemiBold" or MONO[n] and "Mono" or "Body"
    end
    local ff = o.FontFace
    local fam = ff.Family
    if fam == FAMILY then
        local w = ff.Weight
        if w == W.Heavy or w == W.ExtraBold then return "Display" end
        return (w == W.Bold and "Bold") or (w == W.SemiBold and "SemiBold") or "Body"
    elseif string.find(fam, "RobotoMono", 1, true) or string.find(fam, "BuilderMono", 1, true) then
        return "Mono"
    end
    return nil
end
local function Digity(txt: string): boolean
    local _, d = string.gsub(txt, "%d", "")
    return d > 0 and d >= #txt * 0.3
end
local function Big(o): boolean
    if o.TextScaled then return o.AbsoluteSize.Y >= 30 end
    return o.TextSize >= 20
end
local function Role(o, base: string): string
    local forced = o:GetAttribute("TypeRole")
    if forced then return forced end
    if base == "Mono" then return "Accent" end
    if base == "Display" then
        if Digity(o.Text) then return "Accent" end
        return Big(o) and "Header" or "Label"
    end
    return base -- Body / SemiBold / Bold
end
local function Face(role: string): Font
    if role == "Header" then return kit.Header end
    if role == "Accent" then return kit.Accent end
    if role == "Label" then return kit.Label or (kit.LabelAccent and kit.Accent) or FF(kit.Body, W.ExtraBold) end
    return FF(kit.Body, (role == "Bold" and W.Bold) or (role == "SemiBold" and W.SemiBold) or W.Medium)
end
local function Key(f: Font): string return f.Family .. "|" .. f.Weight.Name end

local tracked = {} -- text object -> true (strong; pruned of destroyed objects)
local function ApplyType(o)
    if not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then return end
    if o:GetAttribute("KeepFont") or not o.Parent then return end
    -- (Roblox's own chat measures its text with an Enum.Font: a custom face broke it -- "Enum.Font.Unknown can't be
    -- passed to TextService:GetTextSize()")
    if o:FindFirstAncestor("Chat") or o:FindFirstAncestor("BubbleChat") or o:FindFirstAncestor("ExperienceChat") then return end
    if o.RichText and string.find(o.Text, "face=", 1, true) then return end -- rich text picks its own faces
    local base = o:GetAttribute("TypeBase")
    if not base then
        base = Base(o)
        if not base then return end
        o:SetAttribute("TypeBase", base)
    end
    local face = Face(Role(o, base))
    o:SetAttribute("TypeFace", Key(face))
    if o.FontFace ~= face then o.FontFace = face end
    -- (v3 TEXT FLOOR: nothing is drawn below MIN_TEXT; shrink-to-fit text stops at MIN_SCALED. Opt out: AllowTiny)
    -- (PHONE FLOOR 2026-10-13: in a window on a phone -- the Menus folder, drawn at ~0.8x -- the floor is PHONE_MIN_TEXT
    -- 14 design px (~11-12 pt) and scaled text stops at PHONE_MIN_SCALED 13 (an absolute pixel cap). Decided once per
    -- text object, so a Studio preview switched on after the windows were built keeps the desktop floor.)
    if not o:GetAttribute("AllowTiny") then
        local phone = UIStyle.IsPhone and UIStyle.IsPhone() and o:FindFirstAncestor("Menus") ~= nil
        local minText = phone and UIStyle.PHONE_MIN_TEXT or UIStyle.MIN_TEXT
        local minScaled = phone and UIStyle.PHONE_MIN_SCALED or UIStyle.MIN_SCALED
        if o.TextScaled then
            local c = o:FindFirstChildOfClass("UITextSizeConstraint")
            if c and c.MinTextSize < minScaled then c.MinTextSize = math.min(minScaled, c.MaxTextSize) end
        elseif o.TextSize < minText and o.TextSize > 1 then
            o.TextSize = minText
        end
    end
    if not tracked[o] then
        tracked[o] = true
        -- code that sets .Font / .FontFace afterwards (legacy skins, old menus): re-map from what it set
        o:GetPropertyChangedSignal("FontFace"):Connect(function()
            if o:GetAttribute("TypeFace") ~= Key(o.FontFace) then
                o:SetAttribute("TypeBase", nil)
                ApplyType(o)
            end
        end)
        if base == "Display" then -- numbers vs words decides Header / Label vs Accent
            o:GetPropertyChangedSignal("Text"):Connect(function() ApplyType(o) end)
        end
    end
end
UIStyle.ApplyType = ApplyType
function UIStyle.InstallType(root: Instance)
    for _, d in ipairs(root:GetDescendants()) do ApplyType(d) end
    -- deferred twice: code usually sets .Font / .Text right after parenting
    root.DescendantAdded:Connect(function(d)
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            task.defer(function() task.defer(ApplyType, d) end)
        end
    end)
end
-- the equipped UI theme's kit (UITheme.Apply calls this); re-faces every text in the game
-- (owner 2026-10-04: "the seraphim set replaces the old font, I think fonts should be consistent"): themes restyle
-- colours, art and effects only -- every theme keeps the Default (Mega-City) type. Set true to bring theme faces back.
UIStyle.THEME_FONTS = false
function UIStyle.SetTypeKit(themeId: string?)
    if not UIStyle.THEME_FONTS then themeId = "Default" end
    local k = UIStyle.TypeKits[themeId or "Default"] or UIStyle.TypeKits.Default
    if k == kit then return end
    kit = k
    for o in pairs(tracked) do
        if o.Parent then ApplyType(o) else tracked[o] = nil end
    end
end
-- every tracked text again (a Studio DevPhone preview switched on: the phone floor; floors only ever lift)
function UIStyle.ReapplyType()
    for o in pairs(tracked) do
        if o.Parent then ApplyType(o) else tracked[o] = nil end
    end
end
function UIStyle.TypeKit() return kit end
function UIStyle.RoleFace(role: string): Font return Face(role) end
task.spawn(function()
    while true do
        task.wait(15)
        for o in pairs(tracked) do if not o.Parent then tracked[o] = nil end end
    end
end)

-- ===== ICONS v2 (tools/make_theme_icons.py -> art/ui/icons_line, uploaded): pure-white Lucide line glyphs, tinted in
-- game with ImageColor3 (the dock follows the UI theme's accent) + the full-colour currencies (tools/make_ui_icons.py) =====
-- (0.53 MEGA-CITY ICON SET, tools/make_city_icons.py -- hand-built stencil glyphs replacing the stock line icons + emoji;
-- ids in tools/city_icon_ids.json. g_* = welcome guide cards, c_* = classes, b_* = biomes)
UIStyle.Icons = {
    -- (0.89 world biomes: tools/make_city_icons.py)
    b_abyss = "rbxassetid://135479284185190", b_autumn = "rbxassetid://92422401969515", b_aztec = "rbxassetid://103266611599480", b_bayou = "rbxassetid://95529416478106", b_desert = "rbxassetid://85806245784203", b_fungal = "rbxassetid://107710369005925",
    b_gothic = "rbxassetid://86885772149526", b_jungle = "rbxassetid://127593134820298", b_sakura = "rbxassetid://96375881837598", b_sky = "rbxassetid://76631445249111", b_station = "rbxassetid://83209838342357", b_waste = "rbxassetid://126797410564846",
    b_cyber = "rbxassetid://104254928999657", b_dream = "rbxassetid://78630188603722", b_fire = "rbxassetid://116827815485271", b_flats = "rbxassetid://128405696105090",
    b_ice = "rbxassetid://92416827968479", b_storm = "rbxassetid://119617832879516", b_void = "rbxassetid://138370566264735", bag = "rbxassetid://88386781877267",
    c_arcwright = "rbxassetid://104498895962855", c_breacher = "rbxassetid://73405474452545", c_gunslinger = "rbxassetid://129702151856627", c_marksman = "rbxassetid://130973600018861",
    c_vanguard = "rbxassetid://115601304647578", cat_boot = "rbxassetid://120163746785455", cat_bundle = "rbxassetid://101256688498038", cat_charm = "rbxassetid://95254890633278",
    cat_crown = "rbxassetid://127834752010227", cat_glove = "rbxassetid://96094361162066", cat_hand = "rbxassetid://123539022234766", cat_heart = "rbxassetid://125558432169031",
    cat_hud = "rbxassetid://90294344730833", cat_knife = "rbxassetid://80861381005148", cat_palette = "rbxassetid://107316037615757", cat_shield = "rbxassetid://127029391274676",
    cat_shirt = "rbxassetid://94069512669149", cat_sleeve = "rbxassetid://125538003139929", cat_star = "rbxassetid://113684258011896", cosmetics = "rbxassetid://118557582528391",
    g_aim = "rbxassetid://89508926673802", g_build = "rbxassetid://126986771549694", g_endgame = "rbxassetid://131655797471451", g_loot = "rbxassetid://108243427591990",
    g_move = "rbxassetid://73740515559344", g_style = "rbxassetid://74180226977666", g_survive = "rbxassetid://122324367343778", g_team = "rbxassetid://74308751314256",
    guide = "rbxassetid://91081901827117", lostgear = "rbxassetid://74328680040515", notes = "rbxassetid://134849169597330", settings = "rbxassetid://130611446498487",
    stash = "rbxassetid://110712863146935", store = "rbxassetid://76391777434858", teleport = "rbxassetid://75228964605956",
    cur_gold = "rbxassetid://78863137141521", cur_scrap = "rbxassetid://81236276906918", cur_alloy = "rbxassetid://126466271813647", cur_prism = "rbxassetid://108308075120992", cur_sp = "rbxassetid://136396306413699",
    -- (0.61f custom icons replacing Roblox emoji: tools/make_city_icons.py, list in tools/city_icons_new.txt)
    mat_reforge = "rbxassetid://100043733878813", mat_tuning = "rbxassetid://82467046841067", mat_catalyst = "rbxassetid://128562991061212", mat_seal = "rbxassetid://107891706789249", mat_fate = "rbxassetid://115764193681841",
    mat_rebirth = "rbxassetid://90237141309839", f_upgrade = "rbxassetid://124785492207844", f_relevel = "rbxassetid://102927139360150", f_imprint = "rbxassetid://124406325666271", s_audio = "rbxassetid://140586536065055",
    s_interface = "rbxassetid://112299594885029", s_crosshair = "rbxassetid://113161496205073", s_controls = "rbxassetid://89548359885648", s_enemy = "rbxassetid://96672330754753", duel = "rbxassetid://111140816407942",
    trade = "rbxassetid://119877678224976", hideout = "rbxassetid://85434687519976", lock = "rbxassetid://105246759102897",
    credits = "rbxassetid://76885613742811", -- (UPDATE 4 wrap-up: the CREDITS window -- a rosette, tools/make_city_icons.py)
    mat_infusion = "rbxassetid://121237705967405", mat_purge = "rbxassetid://74856902101094", mat_ascend = "rbxassetid://136361901332519", mat_schematic = "rbxassetid://97695982846911",
}
-- an icon image (key from UIStyle.Icons or a raw asset id)
-- is this icon key uploaded (a real asset id)? Placeholder keys ("rbxassetid://0") render nothing until then.
function UIStyle.HasIcon(key: string?): boolean
    local id = key and UIStyle.Icons[key]
    return type(id) == "string" and id ~= "rbxassetid://0" and id ~= ""
end
-- (Update 5) fetch every icon once at start on the client: an icon used to arrive a moment after its window opened,
-- so tabs / action tiles / lock marks showed as empty coloured squares on the first look
if game:GetService("RunService"):IsClient() then
    task.spawn(function()
        local ids = {}
        for _, id in pairs(UIStyle.Icons) do if type(id) == "string" and id ~= "rbxassetid://0" then table.insert(ids, id) end end
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
    end)
end
function UIStyle.Icon(key: string, props: { [string]: any }): ImageLabel
    props.Image = UIStyle.Icons[key] or key
    props.BackgroundTransparency = 1
    props.ScaleType = props.ScaleType or Enum.ScaleType.Fit
    return UIStyle.New("ImageLabel", props) :: ImageLabel -- (New is defined further down)
end
UIStyle.BodyFont = Enum.Font.GothamBold
-- ACCENT (UI CLEAN): ONE token picks the accent for the whole game. "W" = off-white (the Text colour: selected tabs, primary
-- buttons with ink text -- round 2, the owner's accepted target; the red-coral variant is dropped), "B" = the v4 cyan.
UIStyle.ACCENT_VARIANT = "W"
UIStyle.ACCENTS = { W = Color3.fromRGB(236, 232, 225), B = Color3.fromRGB(48, 226, 255) }
local ACCENT = UIStyle.ACCENTS[UIStyle.ACCENT_VARIANT] or UIStyle.ACCENTS.W
UIStyle.Colors = { -- (UI CLEAN: flat neutral slate, warm off-white text in three steps, one accent, quiet semantics)
    -- surfaces
    Bg0 = Color3.fromRGB(16, 18, 22), -- window body
    Bg1 = Color3.fromRGB(25, 28, 34), -- raised: cards, rows
    Bg2 = Color3.fromRGB(36, 40, 48), -- hover / selected row
    Well = Color3.fromRGB(10, 11, 14), -- inset fields, bar tracks
    Field = Color3.fromRGB(13, 16, 21), -- the full-screen menu field (MenuChrome / MenuField / the inventory)
    Line = Color3.fromRGB(46, 49, 56), -- hairlines + dividers (= the text colour at ~0.88 transparency over Bg0)
    -- (older names, same family; callers keep working)
    BgTop = Color3.fromRGB(16, 18, 22),
    BgBottom = Color3.fromRGB(16, 18, 22),
    Card = Color3.fromRGB(25, 28, 34),
    CardDark = Color3.fromRGB(13, 15, 18),
    Border = Color3.fromRGB(52, 56, 64), -- hairline edges (UITheme re-tints exactly this colour)
    -- text in three steps (UI CLEAN P4: on Bg1 Text 13.6:1, Sub 7.9:1, Muted 4.9:1 -- Muted still >= 4.5:1 on Bg0 / Bg1 / Bg2)
    Text = Color3.fromRGB(236, 232, 225),
    Sub = Color3.fromRGB(176, 173, 167),
    Muted = Color3.fromRGB(144, 142, 138),
    Off = Color3.fromRGB(30, 33, 39),
    -- THE accent (primary action, selection, focus) + text on it (set below by contrast)
    Accent = ACCENT,
    OnAccent = Color3.fromRGB(10, 10, 12),
    Neon = ACCENT, -- (v4 names: one accent now)
    Neon2 = ACCENT,
    Violet = Color3.fromRGB(150, 110, 230),
    -- semantic (quieter: text or a thin mark)
    Info = Color3.fromRGB(110, 170, 230),
    Good = Color3.fromRGB(96, 206, 140),
    Warn = Color3.fromRGB(236, 170, 70),
    Bad = Color3.fromRGB(232, 92, 92),
    -- named hues (button / chip colours callers pick; a coloured button is drawn as a faint tint of its hue)
    Gold = Color3.fromRGB(240, 190, 70), -- gold: currency only (a Gold BUTTON is the primary accent)
    Blue = Color3.fromRGB(70, 140, 210),
    Green = Color3.fromRGB(70, 180, 112),
    Orange = Color3.fromRGB(236, 136, 52),
    Purple = Color3.fromRGB(140, 100, 220),
    Pink = Color3.fromRGB(232, 92, 160),
    Red = Color3.fromRGB(214, 64, 70),
    Steel = Color3.fromRGB(30, 33, 39),
    Ink = Color3.fromRGB(10, 10, 12),
}
UIStyle.Art = { Halo = "rbxassetid://107435436505806" } -- (v4: tools/make_neon_ui.py -- a hollow 9-slice soft halo)
UIStyle.Art.Hazard = "rbxassetid://123887840862473" -- (tools/make_dredd_ui.py; v3 + v4 draw neither)
UIStyle.Art.Scanlines = "rbxassetid://79561084921498"
local C = UIStyle.Colors
do -- text on the accent: ink or off-white, whichever has the higher contrast (WCAG)
    local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    local L = 0.2126 * ch(C.Accent.R) + 0.7152 * ch(C.Accent.G) + 0.0722 * ch(C.Accent.B)
    C.OnAccent = ((L + 0.05) / 0.053 > 0.87 / (L + 0.05)) and C.Ink or C.Text
end
-- the old v3 gold (callers still pass Color3.fromRGB(255, 184, 28) by hand: it means "primary")
local OLD_GOLD = Color3.fromRGB(255, 184, 28)

local function New(class: string, props: { [string]: any }, children: { Instance }?): Instance
    local inst = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end
UIStyle.New = New

local function Lighten(c: Color3, t: number): Color3 return c:Lerp(Color3.new(1, 1, 1), t) end
local function Darken(c: Color3, t: number): Color3 return c:Lerp(Color3.new(0, 0, 0), t) end
UIStyle.Lighten, UIStyle.Darken = Lighten, Darken

-- (Mega-City: square corners -- a radius only survives on things meant to be round, r >= 40)
function UIStyle.Corner(r: number?): UICorner
    local rr = r or 2
    if rr < 40 then rr = math.min(rr, 2) end
    return New("UICorner", { CornerRadius = UDim.new(0, rr) }) :: UICorner
end
function UIStyle.Stroke(col: Color3?, th: number?): UIStroke
    return New("UIStroke", { Color = col or C.Border, Thickness = math.min(th or 1.5, 2), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter }) :: UIStroke
end
-- gold L-brackets in a frame's four corners (the Mega-City HUD frame); len / th in pixels
function UIStyle.Brackets(parent: GuiObject, color: Color3?, len: number?, th: number?, z: number?)
    local col, L, T = color or C.Gold, len or 14, th or 2
    local holder = New("Frame", { Name = "Brackets", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z or 5, Parent = parent })
    holder:SetAttribute("Skinned", true)
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local ax, ay = c[1], c[2]
        for _, horiz in ipairs({ true, false }) do
            local f = New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, AnchorPoint = Vector2.new(ax, ay),
                Position = UDim2.new(ax, ax == 0 and -1 or 1, ay, ay == 0 and -1 or 1),
                Size = horiz and UDim2.fromOffset(L, T) or UDim2.fromOffset(T, L), ZIndex = z or 5, Parent = holder })
            f:SetAttribute("Skinned", true)
        end
    end
    return holder
end
-- a strip of hazard stripes (tiled art)
function UIStyle.Hazard(parent: GuiObject, props: { [string]: any }): ImageLabel
    props.Image = UIStyle.Art.Hazard
    props.BackgroundTransparency = 1
    props.ScaleType = Enum.ScaleType.Tile
    props.TileSize = props.TileSize or UDim2.fromOffset(16, 16)
    props.Parent = parent
    local im = New("ImageLabel", props) :: ImageLabel
    im:SetAttribute("Skinned", true)
    return im
end
-- (UI CLEAN: no gradients, no facets -- these keep their names for callers and draw ONE flat colour: the lit / top one)
function UIStyle.Gradient(top: Color3, _bottom: Color3, rotation: number?): UIGradient
    return New("UIGradient", { Color = ColorSequence.new(top), Rotation = rotation or 90 }) :: UIGradient
end
UIStyle.FACET_ROT = 20
function UIStyle.Facet(lit: Color3, _shade: Color3?, _at: number?): ColorSequence
    return ColorSequence.new(lit)
end
function UIStyle.FacetGrad(lit: Color3, shade: Color3?, at: number?): UIGradient
    return New("UIGradient", { Color = UIStyle.Facet(lit, shade, at), Rotation = UIStyle.FACET_ROT }) :: UIGradient
end
-- (UI CLEAN: no ink edges -- an invisible stroke; code that colours it later, e.g. a bar's edge, can still show it)
function UIStyle.InkEdge(th: number?): UIStroke
    return New("UIStroke", { Color = C.Ink, Thickness = th and math.min(th, 1) or 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter }) :: UIStroke
end

-- ===================== v4 NEON helpers + MOTION =====================
local function Near(a: Color3, b: Color3): boolean
    return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.06
end
UIStyle.Near = Near
-- is this colour "the primary" (the accent, or the v3 gold every older caller still passes)?
UIStyle.PRIMARY_KNOWN = UIStyle.PRIMARY_KNOWN or {} -- (SKIN UI THEMES: every theme accent worn this session -- UITheme adds them)
function UIStyle.IsPrimary(c: Color3): boolean
    if Near(c, C.Accent) or Near(c, C.Gold) or Near(c, OLD_GOLD) or Near(c, ACCENT) then return true end
    for _, a in ipairs(UIStyle.PRIMARY_KNOWN) do if Near(c, a) then return true end end
    return false
end
-- a window's neon edge for the accent it asked for: the magenta family for pink / purple / red, cyan for the rest
-- (owner: "one neon accent edge per window (magenta + cyan family)")
function UIStyle.NeonOf(_c: Color3?): Color3
    return C.Accent -- (UI CLEAN: one accent for every window)
end
-- dark slab tinted toward a hue (tinted-ghost buttons, selected rows)
function UIStyle.Tint(c: Color3, k: number?): Color3
    return C.Bg1:Lerp(c, k or 0.16)
end
-- readable label colour for a hue drawn on a dark slab
function UIStyle.OnDark(c: Color3): Color3
    local L = UIStyle.Luma and UIStyle.Luma(c) or 0.3
    if L < 0.18 then return c:Lerp(Color3.new(1, 1, 1), 0.45) end
    return c:Lerp(Color3.new(1, 1, 1), 0.18)
end

local function Tw(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
    local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
UIStyle.Motion = { Tween = Tw, OPEN_T = 0.14, HOVER_T = 0.12, PRESS_T = 0.05, OPEN_SCALE = 0.975 }

-- (UI CLEAN: no glow. Glow returns a hidden, imageless label so callers that keep / tween it still work; GlowTo is a no-op.)
function UIStyle.Glow(parent: GuiObject, _color: Color3?, _pad: number?): ImageLabel
    local g = New("ImageLabel", { Name = "NeonGlow", BackgroundTransparency = 1, ImageTransparency = 1, Visible = false,
        Size = UDim2.fromScale(1, 1), Parent = parent }) :: ImageLabel
    g:SetAttribute("Skinned", true)
    return g
end
function UIStyle.GlowTo(_g: ImageLabel?, _on: boolean, _strength: number?) end

-- WINDOW OPEN: the content fades up from the window's own body colour (a veil over it fades out) and the window
-- settles from 97.5% to its size. 0.14 s, eased out, no overshoot; phones skip the scale (their fit + scroll own it).
-- pop = the window's PopScale (its fitted scale is the target).
function UIStyle.Motion.Open(root: GuiObject, pop: UIScale?)
    if not root or not root.Parent then return end
    -- (a window whose own children are laid out by a list / grid would take the veil as an item: scale only)
    local laid = root:FindFirstChildOfClass("UIListLayout") or root:FindFirstChildOfClass("UIGridLayout")
    local veil = (not laid) and root:FindFirstChild("OpenVeil")
    if not veil and not laid and not root:GetAttribute("MenuField") then -- (a full-screen menu has no box to veil)
        veil = New("Frame", { Name = "OpenVeil", BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 999, Active = false,
            BackgroundColor3 = C.Bg0, Parent = root })
        veil:SetAttribute("Skinned", true)
        veil:SetAttribute("NoSkin", true)
    end
    if veil then
        -- the body's colour (a premium UI theme may have recoloured it)
        local body = root:FindFirstChild("Body") or root
        local grad = body:FindFirstChildOfClass("UIGradient")
        local col = grad and grad.Color.Keypoints[#grad.Color.Keypoints].Value or (body :: any).BackgroundColor3 or C.Bg0
        veil.BackgroundColor3 = col
        veil.BackgroundTransparency = 0.05
        veil.Visible = true
        local tw = Tw(veil, UIStyle.Motion.OPEN_T + 0.03, { BackgroundTransparency = 1 })
        tw.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then veil.Visible = false end
        end)
    end
    if pop and not (UIStyle.IsPhone and UIStyle.IsPhone()) then
        local target = pop.Scale
        if target > 0 then
            pop.Scale = target * UIStyle.Motion.OPEN_SCALE
            Tw(pop, UIStyle.Motion.OPEN_T, { Scale = target }, Enum.EasingStyle.Quart)
        end
    end
end

-- Hover / selection feel for a hand-built button (UI CLEAN: no halo, no lift -- the stroke brightens to the text colour on
-- hover / gamepad selection). Returns a hidden glow (callers keep it).
function UIStyle.HoverGlow(btn: GuiButton, _color: Color3?, stroke: UIStroke?, _pad: number?)
    local g = UIStyle.Glow(btn)
    local st = stroke
    local base, baseT = st and st.Color, st and st.Transparency
    local function On(on: boolean)
        if st and base then Tw(st, UIStyle.Motion.HOVER_T, { Color = on and C.Text or base, Transparency = on and 0.35 or baseT }) end
    end
    btn.MouseEnter:Connect(function() On(true) end)
    btn.MouseLeave:Connect(function() On(false) end)
    btn.SelectionGained:Connect(function() On(true) end)
    btn.SelectionLost:Connect(function() On(false) end)
    return g
end

-- NUMBER COUNT-UP: a label showing a number rolls to its new value (fmt(n) -> text). Runs only while it changes
-- (a NumberValue tween), first set is instant. Use on values that change from play (currencies, totals, levels).
local counters = setmetatable({}, { __mode = "k" })
function UIStyle.CountUp(lbl: TextLabel, value: number, fmt: ((number) -> string)?, dur: number?)
    local f = fmt or function(n) return tostring(math.floor(n + 0.5)) end
    local rec = counters[lbl]
    if not rec then
        local nv = Instance.new("NumberValue")
        nv.Value = value
        rec = { NV = nv, Fmt = f }
        counters[lbl] = rec
        nv.Changed:Connect(function(v) if lbl.Parent then lbl.Text = rec.Fmt(v) end end)
        lbl.Text = f(value)
        return
    end
    rec.Fmt = f
    if rec.Tw then rec.Tw:Cancel() end
    if rec.NV.Value == value then lbl.Text = f(value); return end
    rec.Tw = Tw(rec.NV, dur or 0.35, { Value = value }, Enum.EasingStyle.Quart)
end

-- Text with the theme font; Stroke = true gives the outlined "game" look.
function UIStyle.Text(props: { [string]: any }): TextLabel
    local stroke = props.Stroke
    props.Stroke = nil
    props.BackgroundTransparency = 1
    props.Font = props.Font or UIStyle.Font
    props.TextColor3 = props.TextColor3 or C.Text
    props.TextSize = props.TextSize or 16
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    local lbl = New("TextLabel", props) :: TextLabel
    local _ = stroke -- (owner 2026-10-04: "remove the weird outline / highlight" -- text carries no outline at all now)
    return lbl
end

-- (UI CLEAN: no grow on hover, no dip -- hover is a surface change. Kept for callers.)
function UIStyle.Hover(_btn: GuiButton, _amount: number?) end

-- (v3) the label size a control of height h gets: 52+ -> 20, 40+ -> 18, 32+ -> 16, else 15 (never below the floor)
function UIStyle.LabelSizeFor(h: number): number
    -- (Oswald is all caps: its cap height is ~0.7 of the size, so labels sit a step above body text)
    if h >= 52 then return 20 elseif h >= 40 then return 18 elseif h >= 32 then return 16 end
    return 15
end
-- relative luminance (WCAG) of a colour, 0..1
function UIStyle.Luma(c: Color3): number
    local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
end
-- the text colour that reads on a slab of colour c: ink on bright faces (the icons' ink), light text on dark ones
function UIStyle.TextOn(c: Color3): Color3
    local L = UIStyle.Luma(c)
    -- contrast with ink vs with the light text: pick the higher
    local withInk = (L + 0.05) / 0.053
    local withText = 0.87 / (L + 0.05)
    return (withInk > withText) and C.Ink or C.Text
end

-- Button. Returns { Button, Label, SetEnabled(bool), SetText(str), SetColor(c), SetStrong(on), SetSelected(on, side?, col?),
-- SetQuiet(on) }. UI CLEAN: the colour is its ROLE --
--   primary (Colors.Accent / Gold / the old gold)  -> filled accent, ink or off-white caps by contrast
--   neutral (any dark colour: Steel, Bg1, Card ...) -> SECONDARY: transparent, a 1 px hairline, off-white caps
--   any other hue (Green, Red, Blue, rarity ...)    -> a faint tint of the hue, the hue on the label + a thin edge
-- Hover = the surface one step lighter (no glow, no grow); pressed = darker; gamepad selection = hover. Square corners.
local function ButtonRole(c: Color3): string
    if UIStyle.IsPrimary(c) then return "Primary" end
    local _, s, v = c:ToHSV()
    if v < 0.42 or s < 0.18 then return "Neutral" end -- (dark slates like (58, 68, 100) read as "not selected")
    return "Tint"
end
UIStyle.ButtonRole = ButtonRole
-- a dark code colour that is really "no surface" (Bg1 / Steel / Card / near-black): drawn transparent
local function Ghostly(c: Color3): boolean
    return (c.R + c.G + c.B) <= (C.Bg1.R + C.Bg1.G + C.Bg1.B) + 0.09
end
UIStyle.Ghostly = Ghostly
function UIStyle.Button(parent: Instance, text: string, color: Color3?, size: UDim2?, position: UDim2?, name: string?)
    local col = color or C.Blue
    -- The button's own Text stays empty: its children draw over it, so the label is a child carrying the text.
    local btn = New("TextButton", {
        Name = name or "Button", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Bg1, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = size or UDim2.fromOffset(160, 44), Position = position or UDim2.new(), Parent = parent,
    }, { UIStyle.Corner(2) }) :: TextButton
    local hover, down = false, false
    local border = New("UIStroke", { Color = C.Text, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter, Parent = btn })
    local h0 = (size and size.Y.Offset) or 44
    local ts = UIStyle.LabelSizeFor(h0 > 0 and h0 or 44)
    local fitCap = New("UITextSizeConstraint", { MaxTextSize = ts, MinTextSize = math.min(UIStyle.MIN_SCALED, ts) })
    local label = New("TextLabel", {
        Name = "Label", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UIStyle.Font, TextSize = ts,
        TextColor3 = C.Text, Text = string.upper(text), TextScaled = true, Parent = btn,
    }, {
        -- (a long label shrinks to fit, down to the floor)
        fitCap,
        New("UIPadding", { Name = "LabelPad", PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
    }) :: TextLabel
    label:SetAttribute("TypeRole", "Label")
    -- (a caller that pads the label itself -- e.g. room for an icon -- wins: Roblox uses one UIPadding per object)
    label.ChildAdded:Connect(function(c)
        if c:IsA("UIPadding") and c.Name ~= "LabelPad" then
            local mine = label:FindFirstChild("LabelPad")
            if mine then mine:Destroy() end
        end
    end)
    -- callers that size the label themselves keep working: a set TextSize becomes the cap
    label:GetPropertyChangedSignal("TextSize"):Connect(function()
        fitCap.MaxTextSize = math.max(label.TextSize, 14)
        fitCap.MinTextSize = math.min(UIStyle.MIN_SCALED, fitCap.MaxTextSize)
    end)
    label:GetPropertyChangedSignal("AutomaticSize"):Connect(function()
        if label.AutomaticSize ~= Enum.AutomaticSize.None then label.TextScaled = false; label.TextWrapped = false end
    end)
    local enabled = true
    local selected = false
    local strong = false -- (api.SetStrong: a big call to action drawn FILLED in its hue)
    local quiet = false -- (api.SetQuiet: no hairline at rest -- tabs)
    local function Paint()
        local face, faceT, edge, edgeT, txt
        if not enabled then
            face, faceT, edge, edgeT, txt = C.Bg1, 0.35, C.Text, 0.92, C.Muted
        else
            local role = ButtonRole(col)
            if role == "Primary" or (strong and role == "Tint") then
                local nc = (role == "Primary") and C.Accent or col
                face = down and Darken(nc, 0.14) or (hover and Lighten(nc, 0.1) or nc)
                faceT, edge, edgeT, txt = 0, nc, 1, UIStyle.TextOn(nc)
            elseif role == "Neutral" then
                if selected then
                    face, faceT = down and C.Bg1 or (hover and Lighten(C.Bg2, 0.04) or C.Bg2), 0
                elseif Ghostly(col) then
                    face, faceT = down and C.Bg1 or C.Bg2, (hover or down) and 0 or 1
                else
                    face, faceT = down and Darken(col, 0.15) or (hover and Lighten(col, 0.06) or col), 0
                end
                edge = C.Text
                edgeT = (quiet or selected) and 1 or (hover and 0.6 or 0.84)
                txt = (quiet and not selected and not hover) and C.Sub or C.Text -- (a tab at rest: Sub; selected / hover: Text)
            else
                face = down and UIStyle.Tint(col, 0.08) or UIStyle.Tint(col, hover and 0.24 or 0.12)
                faceT, edge, edgeT, txt = 0, col, hover and 0.2 or 0.55, UIStyle.OnDark(col)
            end
        end
        btn.BackgroundColor3, btn.BackgroundTransparency = face, faceT
        border.Color, border.Transparency = edge, edgeT
        label.TextColor3 = txt
    end
    Paint()
    local function Hov(on: boolean)
        hover = on
        if not on then down = false end
        Paint()
    end
    btn.MouseEnter:Connect(function() Hov(true) end)
    btn.MouseLeave:Connect(function() Hov(false) end)
    btn.MouseButton1Down:Connect(function() if btn.Active then down = true; Paint() end end)
    btn.MouseButton1Up:Connect(function() down = false; Paint() end)
    -- gamepad selection reads like hover
    btn.SelectionGained:Connect(function() Hov(true) end)
    btn.SelectionLost:Connect(function() Hov(false) end)
    btn:SetAttribute("Skinned", true)
    label:SetAttribute("Skinned", true)
    local api = { Button = btn, Label = label }
    function api.SetColor(c: Color3) col = c; Paint() end
    function api.SetEnabled(on: boolean)
        btn.Active = on
        enabled = on
        Paint()
    end
    function api.SetText(t: string) label.Text = string.upper(t) end
    function api.SetStrong(on: boolean) strong = on; Paint() end
    function api.SetQuiet(on: boolean) quiet = on; Paint() end
    -- SELECTED (tabs, side navs, filters): a raised slab, bright label and the 2 px accent mark -- "Left" (side navs)
    -- or "Bottom" (tab rows, the default).
    local selBar
    function api.SetSelected(on: boolean, side: string?, color: Color3?)
        selected = on
        if not selBar then
            selBar = New("Frame", { Name = "SelBar", BorderSizePixel = 0, ZIndex = btn.ZIndex + 1, Parent = btn })
            selBar:SetAttribute("Skinned", true)
        end
        selBar.BackgroundColor3 = color or C.Accent
        if side == "Left" then
            selBar.AnchorPoint = Vector2.new(0, 0.5); selBar.Position = UDim2.new(0, 0, 0.5, 0); selBar.Size = UDim2.new(0, 2, 1, 0)
        else
            selBar.AnchorPoint = Vector2.new(0.5, 1); selBar.Position = UDim2.new(0.5, 0, 1, 0); selBar.Size = UDim2.new(1, 0, 0, 2)
        end
        selBar.Visible = on
        if ButtonRole(col) ~= "Neutral" then col = C.Bg1 end
        Paint()
    end
    return api
end

-- Inner card: a flat raised slab (one step lighter than the window) with a barely-there hairline; an accent card keeps
-- its hue on the edge, dimmed.
function UIStyle.Card(parent: Instance, props: { [string]: any }, accent: Color3?): Frame
    props.BackgroundColor3 = props.BackgroundColor3 or C.Bg1
    props.BorderSizePixel = 0
    props.Parent = parent
    local card = New("Frame", props, { UIStyle.Corner(2) }) :: Frame
    local s = UIStyle.Stroke(accent and accent:Lerp(C.Bg1, 0.4) or C.Border, 1)
    s.Transparency = accent and 0.35 or 0.55
    s.Parent = card
    Tag(card, "UIT_Card")
    return card
end

-- PHONE LAYOUT (0.89, owner: "Mobile: real phone layouts"; v2 2026-10-13 after the owner's real phone + tablet test: "we
-- need to fix mobile / menu layouts, especially for phones, a lot of stuff is either too big or doesnt work. tablets did
-- better than phone"). Before 0.89 every window was a desktop window shrunk until it fit the screen: on a ~390 pt tall
-- phone that is ~0.5x and the text is unreadable. On a phone (IsPhone) a window now:
--   * Fit (windows sized in pixels): fits the screen WIDTH (up to its design size) and, when that makes it taller than
--     the screen, starts at the top and scrolls with a vertical swipe (or the mouse wheel).
--   * Sheet (windows sized in screen fractions: inventory, skill tree): fills the usable screen at PhoneScale.
--   * never sits under the Roblox top bar (TopInset): the usable area starts below it.
--   * PHONE CHROME (one ScreenGui, updated only when a window moves / opens / closes -- no per-frame loop): a scroll bar
--     on the right edge, a "▼ MORE" pill at the bottom while there is more below (tap = scroll down), and a pinned close
--     button once the window's own X has scrolled off the top.
--   * close buttons get a bigger invisible touch pad (UIStyle.CloseButton) on touch screens.
-- Studio preview: Player attribute DevPhone = a phone height in points (e.g. 390: that height with the Studio window's
-- shape) or an exact screen "WxH" (e.g. "844x390": drawn centred in the Studio view, outlined in white). Text with an
-- absolute size cap (TextScaled + UITextSizeConstraint, e.g. button labels) looks too SMALL in the preview: the preview
-- magnifies everything ~2x but those caps are real pixels. On a real phone they are relatively bigger.
local UIS_ = game:GetService("UserInputService")
local GuiService_ = game:GetService("GuiService")
local Players_ = game:GetService("Players")
local function DevPhoneWH(): (number?, number?)
    local lp = Players_.LocalPlayer
    local v = lp and lp:GetAttribute("DevPhone")
    if type(v) == "string" then
        local w, h = string.match(v, "^%s*(%d+)%s*[xX]%s*(%d+)%s*$")
        w, h = tonumber(w), tonumber(h)
        if w and h and h >= 200 and w >= 200 then return w, h end
    end
    v = tonumber(v)
    if v and v >= 200 then return nil, v end
    return nil, nil
end
local function DevPhoneH(): number?
    local _, h = DevPhoneWH()
    return h
end
-- The screen the layout is planned for (the simulated phone in a DevPhone preview).
function UIStyle.Screen(): Vector2
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local w, h = DevPhoneWH()
    if h then return Vector2.new(w or math.floor(h * vs.X / math.max(1, vs.Y)), h) end
    return vs
end
-- Real pixels per planned pixel (1 unless previewing a phone).
function UIStyle.SimK(): number
    local w, h = DevPhoneWH()
    local cam = workspace.CurrentCamera
    if not h or not cam then return 1 end
    local vs = cam.ViewportSize
    return w and math.min(vs.X / w, vs.Y / h) or vs.Y / h
end
function UIStyle.IsPhone(): boolean
    if DevPhoneH() then return true end
    if not (UIS_.TouchEnabled and not UIS_.KeyboardEnabled) then return false end
    local s = UIStyle.Screen()
    return math.min(s.X, s.Y) <= 520
end
-- The HUD's automatic interface scale (short screens shrink the HUD so it doesn't overlap).
function UIStyle.HudAuto(): number
    return math.clamp(UIStyle.Screen().Y / 820, 0.55, 1) * UIStyle.SimK()
end
-- The Roblox top bar's height in planned pixels (its buttons sit over the top-left of the screen). In the Studio preview
-- this is Studio's own top bar (58), the same as the 2024+ bar on phones.
function UIStyle.TopInset(): number
    local ok, ins = pcall(function() return GuiService_:GetGuiInset() end)
    return ok and ins.Y or 0
end
-- Design px -> planned px for a phone SHEET: the usable height (below the top bar) / PHONE_REF_H. 390 pt phone with a
-- 58 pt bar = 0.79 (body text 15 -> 11.9 pt), 360 pt = 0.72.
UIStyle.PHONE_REF_H = 420
function UIStyle.PhoneScale(): number
    local s = UIStyle.Screen()
    return math.clamp((s.Y - UIStyle.TopInset()) / UIStyle.PHONE_REF_H, 0.72, 1)
end

-- Fit a window `root` (designed w x h, centred) with its own UIScale `fit`. Desktop: shrink to fit both ways. Phone:
-- fit the width, scroll vertically. Registers the window once; call again on any change (opening, resize).
local fitted = {} -- (strong keys: weak Instance keys lose entries; destroyed windows are dropped in RefitAll)
local closeFns = setmetatable({}, { __mode = "k" }) -- close button -> its onClose (the pinned phone close calls it)
local menuFit = setmetatable({}, { __mode = "k" }) -- full-screen menu window -> its desktop fit (UI CLEAN R-B, MenuChrome)
local Chrome -- (forward: the phone chrome, below)
local function HudK(root: GuiObject): number
    local gui = root:FindFirstAncestorWhichIsA("LayerCollector")
    local s = gui and gui:FindFirstChildOfClass("UIScale")
    return s and s.Scale or 1
end
local function Rec(root: GuiObject)
    local rec = fitted[root]
    if not rec then
        rec = { Y = 0, BaseY = root.Position.Y.Offset, Z0 = root.ZIndex }
        fitted[root] = rec
        root:GetPropertyChangedSignal("Visible"):Connect(function()
            if root.Visible then rec.UserScrolled = false end -- (the MORE pill shows again on every open)
            if Chrome then Chrome() end
        end)
    end
    return rec
end
function UIStyle.Fit(root: GuiObject, fit: UIScale, w: number, h: number, margin: number?): number
    local m = margin or 16
    local k = HudK(root)
    local sk = UIStyle.SimK()
    local vs = UIStyle.Screen() -- planned screen (a phone in a preview)
    local kk = k / sk -- the HUD scale on that screen
    local rec = Rec(root)
    rec.Kind, rec.W, rec.H, rec.M, rec.Fit = "Fit", w, h, m, fit
    local phone = UIStyle.IsPhone()
    local s
    -- (a phone window covers the screen: it draws over the HUD -- layers 1-5 -- but under popups, loot cards and
    -- tooltips -- 30+)
    root.ZIndex = phone and math.max(rec.Z0, 12) or rec.Z0
    if phone then
        -- (up to 1 / kk: the HUD's own short-screen shrink is undone, a window may use the full design size)
        local top = UIStyle.TopInset()
        local availH = vs.Y - top - 4
        s = math.clamp((vs.X - m) / (w * kk), 0.4, math.max(1, 1 / kk))
        rec.Top, rec.AvailH = top, availH
        -- RESHAPE (attr PhoneMinH on the window, design px): a window whose layout stretches with its height (lists,
        -- pages, columns sized 1, -x) is made only as tall as the phone has room for -- never under PhoneMinH -- so it
        -- fits without scrolling (or scrolls a little). Desktop gets its own height back.
        local minH = root:GetAttribute("PhoneMinH")
        if type(minH) == "number" and root.Size.X.Scale == 0 and root.Size.Y.Scale == 0 then
            local hh = math.floor(math.clamp(availH / (kk * s), math.min(minH, h), h))
            root.Size = UDim2.fromOffset(root.Size.X.Offset, hh)
            rec.Reshaped, rec.SizeSet = true, root.Size
            h = hh
        end
        rec.Scroll = h * kk * s > availH + 0.5
        rec.Span = rec.Scroll and (h * kk * s - availH) or 0 -- how far it can scroll (planned px)
    else
        if rec.Reshaped then root.Size = UDim2.fromOffset(root.Size.X.Offset, h); rec.Reshaped = false end
        s = math.clamp(math.min((vs.X - m) / (w * kk), (vs.Y - m) / (h * kk)), 0.4, 1)
        rec.Scroll, rec.Span = false, 0
    end
    rec.Phone = phone
    -- Roblox applies only ONE UIScale per object: windows that added their own "FitScale" next to the panel's PopScale
    -- were never fitted at all (Dungeons / Challenges / Settings / Forge / Store on small screens, found 0.89). The fit
    -- goes on the PopScale when there is one.
    local target = root:FindFirstChild("PopScale") or fit
    if target ~= fit then fit.Scale = 1 end
    target.Scale = s
    target:SetAttribute("Fit", s) -- (UITheme's open effects tween back to this)
    if rec.Scroll and not rec.Placed then rec.Y = 0 end -- (opens at the top)
    rec.Placed = rec.Scroll
    UIStyle.PlaceFitted(root)
    return s
end
-- A window sized in screen FRACTIONS (inventory, skill tree; `pop` = its PopScale): desktop keeps its own size; a phone
-- fills the usable screen (under the top bar, 8 px side gutters) at PhoneScale -- the design gets wider / shorter to the
-- phone's shape instead of shrinking. Its UISizeConstraint is lifted on a phone (restored on desktop).
function UIStyle.Sheet(root: GuiObject, pop: UIScale): number
    local rec = fitted[root]
    if not rec then
        rec = Rec(root)
        rec.Size0, rec.Pos0, rec.AP0 = root.Size, root.Position, root.AnchorPoint
        local c = root:FindFirstChildOfClass("UISizeConstraint")
        if c then rec.Cons, rec.Min0, rec.Max0 = c, c.MinSize, c.MaxSize end
    end
    rec.Kind, rec.Fit = "Sheet", pop
    rec.Scroll, rec.Span, rec.Y = false, 0, 0
    local phone = UIStyle.IsPhone()
    rec.Phone = phone
    if not phone then
        root.Size, root.Position, root.AnchorPoint, root.ZIndex = rec.Size0, rec.Pos0, rec.AP0, rec.Z0
        if rec.Cons then rec.Cons.MinSize, rec.Cons.MaxSize = rec.Min0, rec.Max0 end
        pop.Scale = 1
        pop:SetAttribute("Fit", 1)
        if Chrome then Chrome() end
        return 1
    end
    local vs = UIStyle.Screen()
    local kk = HudK(root) / UIStyle.SimK()
    local top = UIStyle.TopInset()
    local availH = vs.Y - top - 4
    local e = UIStyle.PhoneScale()
    local p = e / kk
    rec.Top, rec.AvailH = top, availH
    if rec.Cons then rec.Cons.MinSize, rec.Cons.MaxSize = Vector2.zero, Vector2.new(100000, 100000) end
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Size = UDim2.fromOffset(math.floor((vs.X - 16) / e), math.floor(availH / e))
    root.Position = UDim2.new(0.5, 0, 0.5, ((top + 2 + availH / 2) - vs.Y / 2) / kk)
    root.ZIndex = math.max(rec.Z0, 12)
    pop.Scale = p
    pop:SetAttribute("Fit", p)
    if Chrome then Chrome() end
    return p
end
-- Position a fitted window. Phone: rec.Y 0 = top edge just under the top bar .. Span = bottom edge on screen.
function UIStyle.PlaceFitted(root: GuiObject)
    local rec = fitted[root]
    if not rec or rec.Kind == "Sheet" then return end
    if not rec.Phone then
        root.Position = UDim2.new(root.Position.X.Scale, root.Position.X.Offset, root.Position.Y.Scale, rec.BaseY)
        if Chrome then Chrome() end
        return
    end
    rec.Y = math.clamp(rec.Y or 0, 0, rec.Span or 0)
    local vs = UIStyle.Screen()
    local kk = HudK(root) / UIStyle.SimK()
    -- centre (planned px) relative to the screen middle, then into the HUD gui's own units (/ kk)
    local off = (rec.Top + 2 + rec.AvailH / 2) - vs.Y / 2 + (rec.Span / 2 - rec.Y)
    root.Position = UDim2.new(root.Position.X.Scale, root.Position.X.Offset, root.Position.Y.Scale, off / kk)
    if Chrome then Chrome() end
end
-- Scroll a fitted phone window by dy planned px (+ = further down the window).
function UIStyle.ScrollFitted(root: GuiObject, dy: number)
    local rec = fitted[root]
    if not rec or not rec.Scroll then return end
    rec.Y = (rec.Y or 0) + dy
    rec.UserScrolled = true
    UIStyle.PlaceFitted(root)
end
-- the window a phone touch at (x, y) / the phone chrome belongs to: the visible fitted phone window on top
local function TopPhoneWindow(x: number?, y: number?): GuiObject?
    local best, bestZ
    for root, rec in pairs(fitted) do
        if rec.Phone and root.Parent and root.Visible then
            local inside = true
            if x then
                local p, sz = root.AbsolutePosition, root.AbsoluteSize
                inside = x >= p.X and x <= p.X + sz.X and y >= p.Y and y <= p.Y + sz.Y
            end
            if inside then
                local z = root.ZIndex
                if not best or z >= bestZ then best, bestZ = root, z end
            end
        end
    end
    return best
end
-- the close function of a window (its UIStyle.CloseButton), looked up once
local function CloseFnOf(root: GuiObject, rec: any): (() -> ())?
    if rec.CloseFn then return rec.CloseFn end
    if os.clock() < (rec.CloseLook or 0) then return nil end
    rec.CloseLook = os.clock() + 2
    for _, d in ipairs(root:GetDescendants()) do
        local fn = closeFns[d]
        if fn then rec.CloseFn = fn; return fn end
    end
    return nil
end

-- PHONE CHROME: scroll bar + MORE pill + pinned close for the phone window on top (rebuilt state only on events)
do
    local ui -- { Gui, Area, Scale, Track, Thumb, More, Close }
    local function Build(): any
        if ui and ui.Gui.Parent then return ui end
        local lp = Players_.LocalPlayer
        local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        local gui = New("ScreenGui", { Name = "PhoneWindowChrome", ResetOnSpawn = false, IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2, Enabled = false, Parent = pg })
        local area = New("Frame", { Name = "Area", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Parent = gui })
        local scale = New("UIScale", { Parent = area })
        local track = New("Frame", { Name = "Track", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
            BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(5, 100), Parent = area })
        local thumb = New("Frame", { Name = "Thumb", BackgroundColor3 = C.Accent or C.Gold, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30), Parent = track })
        local more = New("TextButton", { Name = "More", AutoButtonColor = false, Text = "▼ MORE", TextSize = 14,
            Font = UIStyle.Font, TextColor3 = C.Ink or Color3.new(0, 0, 0), BackgroundColor3 = C.Accent or C.Gold,
            AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(92, 32), Parent = area }, { UIStyle.InkEdge(2) })
        more:SetAttribute("TypeRole", "Label")
        local closeHolder = New("Frame", { Name = "CloseHolder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.fromOffset(46, 46), Parent = area })
        local close = UIStyle.Button(closeHolder, "X", C.Steel, UDim2.fromOffset(46, 46), UDim2.new(), "PinnedClose")
        close.Label.TextSize = 22
        ui = { Gui = gui, Area = area, Scale = scale, Track = track, Thumb = thumb, More = more, Close = closeHolder, CloseBtn = close.Button }
        more.Activated:Connect(function()
            local root = TopPhoneWindow()
            local rec = root and fitted[root]
            if rec and rec.Scroll then UIStyle.ScrollFitted(root, rec.AvailH * 0.7) end
        end)
        close.Button.Activated:Connect(function()
            local root = TopPhoneWindow()
            local rec = root and fitted[root]
            local fn = rec and CloseFnOf(root, rec)
            if fn then fn() end
        end)
        return ui
    end
    -- (Roblox's own thumbstick + jump button sit over the bottom corners of a phone window and take its taps: they are
    -- hidden while a phone window is open -- you can't walk behind a full-screen window anyway -- and come back after)
    local touchHidden = false
    local function TouchControls(windowOpen: boolean)
        if windowOpen and not touchHidden then
            local ok, on = pcall(function() return GuiService_.TouchControlsEnabled end)
            if ok and on then
                touchHidden = true
                pcall(function() GuiService_.TouchControlsEnabled = false end)
            end
        elseif not windowOpen and touchHidden then
            touchHidden = false
            pcall(function() GuiService_.TouchControlsEnabled = true end)
        end
    end
    Chrome = function()
        local root = TopPhoneWindow()
        local rec = root and fitted[root]
        TouchControls(root ~= nil)
        if not (rec and rec.Scroll) then
            if ui then ui.Gui.Enabled = false end
            return
        end
        local u = Build()
        if not u then return end
        local vs = UIStyle.Screen()
        u.Scale.Scale = UIStyle.SimK()
        u.Area.Size = UDim2.fromOffset(vs.X, vs.Y)
        local top, availH = rec.Top or 0, rec.AvailH or vs.Y
        local total = availH + rec.Span
        u.Track.Position = UDim2.fromOffset(vs.X - 2, top + 2)
        u.Track.Size = UDim2.fromOffset(5, availH)
        local th = math.max(28, availH * availH / total)
        u.Thumb.Size = UDim2.new(1, 0, 0, th)
        u.Thumb.Position = UDim2.fromOffset(0, (availH - th) * (rec.Span > 0 and rec.Y / rec.Span or 0))
        u.More.Position = UDim2.fromOffset(vs.X - 12, vs.Y - 8) -- (bottom-right, by the scroll bar: off the content)
        -- (only until the player has scrolled once: it sits over the window's bottom-right corner, where buttons live)
        u.More.Visible = rec.Y < rec.Span - 8 and not rec.UserScrolled
        u.Close.Position = UDim2.fromOffset(vs.X - 14, top + 6)
        u.Close.Visible = rec.Y > 40 and CloseFnOf(root, rec) ~= nil
        u.Gui.Enabled = true
    end
end

-- one input handler for every scrolling window: a vertical swipe that starts inside a visible scrolling window moves
-- it (not when it starts on a list that scrolls by itself); the window's buttons are switched off while it moves, so
-- letting go over a button doesn't press it.
do
    local drag -- { root, startY, startPos, input, moved }
    local function Top(x: number, y: number): GuiObject?
        local root = TopPhoneWindow(x, y)
        local rec = root and fitted[root]
        return (rec and rec.Scroll) and root or nil
    end
    local function OverList(root: GuiObject, x: number, y: number): boolean
        local pg = Players_.LocalPlayer and Players_.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return false end
        for _, o in ipairs(pg:GetGuiObjectsAtPosition(x, y)) do
            if o:IsA("ScrollingFrame") and o:IsDescendantOf(root) and o.ScrollingEnabled
                and o.AbsoluteCanvasSize.Y > o.AbsoluteWindowSize.Y + 2 then return true end
        end
        return false
    end
    local function Begin(input: InputObject)
        local pos = input.Position
        local root = Top(pos.X, pos.Y)
        if not root or OverList(root, pos.X, pos.Y) then return end
        drag = { root = root, startY = pos.Y, startPos = fitted[root].Y, input = input, moved = false }
    end
    UIS_.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or (input.UserInputType == Enum.UserInputType.MouseButton1 and DevPhoneH()) then Begin(input) end
    end)
    UIS_.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local p = UIS_:GetMouseLocation()
            local inset = GuiService_:GetGuiInset()
            local root = Top(p.X - inset.X, p.Y - inset.Y)
            if root and not OverList(root, p.X - inset.X, p.Y - inset.Y) then
                UIStyle.ScrollFitted(root, -input.Position.Z * 60)
            end
            return
        end
        if not drag then return end
        local same = (input == drag.input) or (drag.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement)
        if not same then return end
        local dy = (input.Position.Y - drag.startY) / UIStyle.SimK()
        if not drag.moved and math.abs(dy) < 10 then return end
        if not drag.moved then
            drag.moved = true
            pcall(function() (drag.root :: any).Interactable = false end)
        end
        local rec = fitted[drag.root]
        if rec then rec.Y = drag.startPos - dy; rec.UserScrolled = true; UIStyle.PlaceFitted(drag.root) end
    end)
    UIS_.InputEnded:Connect(function(input)
        if not drag then return end
        if input == drag.input or (drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
            local root, moved = drag.root, drag.moved
            drag = nil
            if moved then task.delay(0.05, function() pcall(function() (root :: any).Interactable = true end) end) end
        end
    end)
    -- refit every window when the screen (or the preview) changes
    local function RefitAll()
        for root, rec in pairs(fitted) do
            if not root.Parent then fitted[root] = nil
            elseif rec.Kind == "Sheet" then UIStyle.Sheet(root, rec.Fit)
            else UIStyle.Fit(root, rec.Fit, rec.W, rec.H, rec.M) end
        end
        if Chrome then Chrome() end
    end
    UIStyle.RefitAll = RefitAll
    -- (the preview outline: DevPhone "WxH" draws the simulated phone's edge in the Studio view)
    local outline
    local function Outline()
        local w, h = DevPhoneWH()
        if not (w and h) then if outline then outline.Enabled = false end return end
        local pg = Players_.LocalPlayer and Players_.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        if not outline then
            outline = New("ScreenGui", { Name = "DevPhoneOutline", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, Parent = pg })
            New("Frame", { Name = "Edge", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Parent = outline }, { New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })
        end
        local k = UIStyle.SimK()
        outline.Edge.Size = UDim2.fromOffset(w * k, h * k)
        outline.Enabled = true
    end
    task.defer(function()
        local lp = Players_.LocalPlayer
        if lp then lp:GetAttributeChangedSignal("DevPhone"):Connect(function() task.defer(RefitAll); task.defer(Outline); task.defer(UIStyle.ReapplyType) end) end
        local cam = workspace.CurrentCamera
        -- (on a resize / rotation the HUD scale is set by its own listener first: refit a frame later)
        if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(RefitAll); task.defer(Outline) end) end
        Outline()
    end)
end

-- An older hand-built window (SkinWindow: inventory, tree, shop, armory, index, roll, class picker) on a phone: sized in
-- screen fractions -> a Sheet, in pixels -> Fit. Desktop keeps them exactly as built (no fit) unless the window was
-- fitted before (a phone preview turned off: it goes back through the desktop branch).
function UIStyle.PhoneFitWindow(frame: GuiObject, pop: UIScale)
    -- (menus only: SkinWindow also dresses HUD banners -- the victory banner must not become a full-screen phone window)
    if not (frame.Parent and frame.Parent:IsA("Folder")) then return end
    local rec = fitted[frame]
    if not (UIStyle.IsPhone() or rec) then return end
    if frame.Size.X.Scale > 0 or frame.Size.Y.Scale > 0 or (rec and rec.Kind == "Sheet") then
        UIStyle.Sheet(frame, pop)
    else
        local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
        if rec and rec.Reshaped and rec.SizeSet == frame.Size then w, h = rec.W, rec.H end
        -- (these old windows are centred with a corner anchor -- (0.5, -w/2, 0.5, -h/2): Fit's phone placement needs the
        -- centre anchor or the scaled window slides off to the bottom-right. Desktop gets its own anchor back.)
        rec = Rec(frame)
        if not rec.AP0 then rec.AP0, rec.Pos0 = frame.AnchorPoint, frame.Position end
        if UIStyle.IsPhone() then
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Position = UDim2.fromScale(0.5, 0.5)
        else
            frame.AnchorPoint, frame.Position = rec.AP0, rec.Pos0
        end
        UIStyle.Fit(frame, pop, w, h, 16)
    end
end

-- PHONE SCROLL CARD: a detail card built as a fixed stack (text rows at y offsets, buttons pinned to the bottom) is
-- taller than a phone window. On a phone its stacked children (top-anchored, fixed height) move into a ScrollingFrame
-- over the card minus `reserve` px at the bottom (where the bottom-pinned buttons stay); off a phone nothing happens.
-- Call it after the card is filled (a re-render builds a new card).
function UIStyle.PhoneScrollCard(card: GuiObject, reserve: number?): ScrollingFrame?
    if not UIStyle.IsPhone() then return nil end
    return UIStyle.ScrollCard(card, reserve)
end
-- The same on every screen (2026-10-13, owner: the boss card's rows ran under its SOLO / WITH PARTY / FASTEST CLEARS row on
-- a PC too): everything placed by offset above the last `reserve` px moves into a ScrollingFrame (no bar when it fits).
function UIStyle.ScrollCard(card: GuiObject, reserve: number?): ScrollingFrame?
    local sf = New("ScrollingFrame", { Name = "PhoneScroll", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -(reserve or 0)),
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.Sub,
        ZIndex = card.ZIndex, Parent = card }) :: ScrollingFrame
    local maxY = 0
    for _, c in ipairs(card:GetChildren()) do
        if c ~= sf and c:IsA("GuiObject") and c.Position.Y.Scale == 0 and c.Size.Y.Scale == 0 then
            maxY = math.max(maxY, c.Position.Y.Offset + c.Size.Y.Offset)
            c.Parent = sf
        end
    end
    sf.CanvasSize = UDim2.fromOffset(0, maxY + 10)
    return sf
end

-- Hover info with a TAP equivalent (owner rule: hints on hover -- a phone has no hover): the mouse shows / hides it as
-- before; a touch on the object shows it for `secs` (3.5) and hides it again (another tap restarts the timer).
function UIStyle.HoverTip(gui: GuiObject, show: () -> (), hide: () -> (), secs: number?)
    gui.MouseEnter:Connect(show)
    gui.MouseLeave:Connect(hide)
    local token = 0
    gui.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.Touch then
            token += 1
            local my = token
            show()
            task.delay(secs or 3.5, function() if token == my then hide() end end)
        end
    end)
end

-- PHONE BOOST for HUD pieces that are not windows (a pop-up card, the victory banner, the boon cards): the HUD's
-- short-screen scale (0.55 on a phone) leaves them ~7 pt text and 20 pt buttons. PhoneBoostK = the extra factor that
-- draws a w x h design piece at PhoneScale, capped to the screen (1 off a phone). PhoneBoost(obj, w, h) puts it on the
-- object's own UIScale "PhoneBoost" (obj must have no other UIScale; it grows round its AnchorPoint) and keeps it up to
-- date on a resize / preview change.
function UIStyle.PhoneBoostK(obj: GuiObject, w: number, h: number): number
    if not UIStyle.IsPhone() then return 1 end
    local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
    local hs = gui and gui:FindFirstChildOfClass("UIScale")
    local kk = (hs and hs.Scale or 1) / UIStyle.SimK()
    local vs = UIStyle.Screen()
    local k = math.min(UIStyle.PhoneScale(), (vs.X - 16) / w, (vs.Y - UIStyle.TopInset() - 8) / h)
    return math.max(1, k / math.max(kk, 0.1))
end
-- BELOW THE TOP BAR: HUD pieces placed a fixed distance from the top (y in the HUD's own units) slide UNDER the Roblox
-- top bar on a phone -- the HUD's 0.55 scale shrinks the distance, the bar doesn't shrink (the hub's GUIDE / PATCH NOTES /
-- CREDITS buttons sat under the Roblox menu + chat buttons and couldn't be tapped). BelowTopBarY = the y to use.
function UIStyle.BelowTopBarY(obj: GuiObject, baseY: number): number
    if not UIStyle.IsPhone() then return baseY end
    local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
    local hs = gui and gui:FindFirstChildOfClass("UIScale")
    local kk = (hs and hs.Scale or 1) / UIStyle.SimK()
    return math.max(baseY, math.ceil((UIStyle.TopInset() + 6) / math.max(kk, 0.1)))
end
local belowBar = {} -- obj -> base y
function UIStyle.BelowTopBar(obj: GuiObject, baseY: number)
    belowBar[obj] = baseY
    local p = obj.Position
    obj.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, UIStyle.BelowTopBarY(obj, baseY))
end
local boosted = {} -- obj -> { w, h }
function UIStyle.PhoneBoost(obj: GuiObject, w: number, h: number): number
    local sc = obj:FindFirstChild("PhoneBoost") or New("UIScale", { Name = "PhoneBoost", Parent = obj })
    boosted[obj] = { w, h }
    sc.Scale = UIStyle.PhoneBoostK(obj, w, h)
    return sc.Scale
end
task.defer(function()
    local function Refresh()
        for o, y in pairs(belowBar) do
            if o.Parent then UIStyle.BelowTopBar(o, y) else belowBar[o] = nil end
        end
        for o, wh in pairs(boosted) do
            if o.Parent then
                local sc = o:FindFirstChild("PhoneBoost")
                if sc then sc.Scale = UIStyle.PhoneBoostK(o, wh[1], wh[2]) end
            else boosted[o] = nil end
        end
    end
    local lp = Players_.LocalPlayer
    if lp then lp:GetAttributeChangedSignal("DevPhone"):Connect(function() task.delay(0.1, Refresh) end) end
    local cam = workspace.CurrentCamera
    if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.delay(0.1, Refresh) end) end
end)

-- (UI CLEAN: no drop shadows. Kept for callers: a hidden, imageless label.)
function UIStyle.Shadow(win: GuiObject, _pad: number?): ImageLabel
    local sh = New("ImageLabel", { Name = "Shadow", BackgroundTransparency = 1, ImageTransparency = 1, Visible = false,
        Size = UDim2.fromScale(1, 1), ZIndex = -2, Parent = win }) :: ImageLabel
    sh:SetAttribute("Skinned", true)
    return sh
end
-- (UI CLEAN: no neon line along a window's top. AccentGlow stays as an INVISIBLE carrier of the window's accent colour --
-- UITheme recolours it and the title tick follows it.)
function UIStyle.NeonEdge(body: GuiObject, col: Color3, z: number?): Frame
    local line = New("Frame", { Name = "AccentGlow", BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), ZIndex = z or 1,
        Visible = false, Parent = body }) :: Frame
    line:SetAttribute("Skinned", true)
    return line
end
UIStyle.WINDOW_T = 0.04 -- a window body's transparency over the world (UI CLEAN: "slightly translucent"; 0.06 let bright HUD text bleed through)

-- Main window: a flat dark slate body (slightly see-through), a 1 px hairline edge; fades up for 0.14 s when it opens.
function UIStyle.Panel(parent: Instance, opts: { Name: string, Size: UDim2, Accent: Color3? }): Frame
    -- The window is a clear container: children always draw above their parent, so the body is a sibling of the
    -- content with a lower ZIndex (the HUD gui uses Sibling ZIndex behavior).
    local panel = New("Frame", {
        Name = opts.Name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = opts.Size,
        BackgroundTransparency = 1, Visible = false, ZIndex = UIStyle.Z.Window, Parent = parent,
    }) :: Frame
    -- (windows draw on the WINDOW layer, over the HUD 1-5)
    panel:SetAttribute("UIStyled", true) -- UIStyle.Skin leaves built-in-style windows alone
    local bodyFrame = New("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Bg0, BackgroundTransparency = UIStyle.WINDOW_T,
        BorderSizePixel = 0, ZIndex = -1, Parent = panel }, { UIStyle.Corner(2) })
    New("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter, Parent = bodyFrame })
    UIStyle.NeonEdge(bodyFrame, UIStyle.NeonOf(opts.Accent))
    Tag(bodyFrame, "UIT_Window")
    -- pop-in
    local pop = New("UIScale", { Name = "PopScale", Parent = panel }) :: UIScale
    -- fit small screens (phones / tablets): shrink the whole window until it fits the viewport (with the HUD's own
    -- interface-scale UIScale on the ScreenGui taken into account). Windows with their own "FitScale" do it themselves.
    local function FitScale(): number
        local rec = fitted[panel]
        if rec and rec.Fit ~= pop then return UIStyle.Fit(panel, rec.Fit, rec.W, rec.H, rec.M) end -- (a window's own size)
        if panel:FindFirstChild("FitScale") then return 1 end
        -- (the design size: a phone RESHAPE changes panel.Size, the registry keeps the real one -- unless the window
        -- resized itself since, e.g. the run summary fitting its rows)
        local w, h = panel.Size.X.Offset, panel.Size.Y.Offset
        if rec and rec.Reshaped and rec.SizeSet == panel.Size then w, h = rec.W, rec.H end
        if w <= 0 or h <= 0 then return 1 end
        return UIStyle.Fit(panel, pop, w, h, 16) -- (phone: fits the width and scrolls, see PHONE LAYOUT)
    end
    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if panel.Visible then
            local fit = FitScale()
            if menuFit[panel] then fit = menuFit[panel]() or fit end -- (a full-screen menu on desktop: placed under its top bar)
            pop:SetAttribute("Fit", fit) -- (UITheme's open effects tween back to this)
            pop.Scale = fit
            UIStyle.Motion.Open(panel, pop) -- (a short fade-up + settle, no bounce)
        end
    end)
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if panel.Visible then pop.Scale = (menuFit[panel] and menuFit[panel]()) or FitScale(); pop:SetAttribute("Fit", pop.Scale) end
        end)
    end
    return panel
end

-- Title bar across the top of a panel (UI CLEAN): no box -- the title in big condensed caps after a 3 px accent tick, the
-- subtitle in body Sub under it, a hairline under the bar, and the close button. Returns bar, subtitle label.
function UIStyle.TitleBar(panel: Frame, title: string, accent: Color3?, subtitle: string?, onClose: (() -> ())?)
    local col = UIStyle.NeonOf(accent)
    local bar = New("Frame", { Name = "TitleBar", BackgroundColor3 = C.Bg0, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, -16, 0, 58), Position = UDim2.fromOffset(8, 8), Parent = panel }, { UIStyle.Corner(2) })
    local block = New("Frame", { Name = "Block", BackgroundColor3 = col, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 6, 0, subtitle and 20 or 29), Size = UDim2.fromOffset(3, 22), Parent = bar })
    block:SetAttribute("Skinned", true)
    -- (the tick follows the window's accent carrier: a premium theme / a window that recolours its accent)
    local wbody = panel:FindFirstChild("Body")
    local wline = wbody and wbody:FindFirstChild("AccentGlow")
    if wline then
        local function Sync() block.BackgroundColor3 = wline.BackgroundColor3 end
        Sync()
        wline:GetPropertyChangedSignal("BackgroundColor3"):Connect(Sync)
    end
    local rule = New("Frame", { Name = "Rule", BackgroundColor3 = C.Line, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -8, 1, 2), Size = UDim2.new(1, 16, 0, 1), Parent = bar })
    rule:SetAttribute("Skinned", true)
    local titleLbl = UIStyle.Text({ Name = "Title", Text = string.upper(title), TextSize = UIStyle.Size.Title, Position = UDim2.fromOffset(18, subtitle and 4 or 0),
        Size = UDim2.new(1, -150, 0, subtitle and 32 or 58), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar })
    UIStyle.TextRole(titleLbl, "WindowTitle")
    local sub
    if subtitle then
        sub = UIStyle.Text({ Name = "Subtitle", Text = subtitle, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = C.Sub, Position = UDim2.fromOffset(18, 35),
            Size = UDim2.new(1, -170, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar })
        UIStyle.TextRole(sub, "Label")
    end
    local ownClose = onClose and UIStyle.CloseButton(bar, onClose, 40) or nil
    Tag(bar, "UIT_Title")
    local menuDef = UIStyle.MENU_WINDOWS[panel.Name] or (string.sub(panel.Name, 1, 8) == "Showcase" and { Id = string.upper(title) }) or nil -- (hideout showcase windows)
    if menuDef then UIStyle.MenuChrome(panel, bar, title, subtitle, onClose, ownClose, menuDef) end
    return bar, sub
end

-- ===== FULL-SCREEN MENUS (UI CLEAN R-B, the inventory TARGET's language for every big window) =====
-- A window named in MENU_WINDOWS opens over a full-screen dark field (<Name>_Field, a sibling under it) with the target's TOP
-- BAR at the screen top: the window names of its group as a nav (selected = off-white + a 2 px underline, the others Sub; a
-- click opens that window through UIStyle.NavOpen[id], which the client fills), the window's subtitle as a quiet line, and the
-- close X on the far right. The window's own body box, title, tick and X hide; its content sits centred under the bar
-- (desktop: placed below it, fitted to the room left). PHONES keep the window's own title bar (the room is the window's):
-- the field only. Shown / hidden with the window (no per-frame work); UIStyle.OnMenuField(on) lets the client hide the HUD.
UIStyle.MENU_WINDOWS = {
    DungMenu = { Id = "DUNGEONS" }, UpgMenu = { Group = "GEAR", Id = "FORGE" }, MarketMenu = { Group = "GEAR", Id = "EXCHANGE" },
    ShotModMenu = { Group = "GEAR", Id = "MODS" }, TradeMenu = { Id = "TRADE" }, GuildMenu = { Id = "CREW" },
    HideoutMenu = { Id = "HIDEOUT" }, MapDeviceMenu = { Id = "MAP DEVICE" }, LostGearMenu = { Id = "LOST LOOT" }, AimArcade = { Id = "AIM ARCADE" },
    DropRulesWindow = { Id = "LOOT LENS" },
}
UIStyle.MENU_NAV = {
    GEAR = { "INVENTORY", "STASH", "FORGE", "MODS", "EXCHANGE", "PASSIVES" },
}
UIStyle.NavOpen = {} -- [nav id] = function() (the client: opens that window)
UIStyle.OnMenuField = nil :: ((boolean) -> ())?
UIStyle.MENU_TOP_H = 64
local menuFieldsOpen = 0
function UIStyle.MenuTop(parent: Instance, items: { any }, selected: string?, onClose: (() -> ())?, meta: string?): Frame
    local top = New("Frame", { Name = "MenuTop", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UIStyle.MENU_TOP_H), Parent = parent }) :: Frame
    top:SetAttribute("Skinned", true)
    local rule = New("Frame", { Name = "Rule", BackgroundColor3 = C.Text, BackgroundTransparency = 0.88, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), Parent = top })
    rule:SetAttribute("Skinned", true)
    local nav = New("Frame", { Name = "Nav", BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0), Parent = top }) :: Frame
    nav:SetAttribute("Skinned", true)
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 28), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center, Parent = nav })
    for i, it in ipairs(items) do
        local id = type(it) == "table" and it.Id or it
        local on = id == selected
        local b = New("TextButton", { Name = "Nav_" .. id, Text = id, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = Enum.Font.GothamBlack, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = nav }) :: TextButton
        b:SetAttribute("NoNeon", true); b:SetAttribute("Skinned", true)
        UIStyle.TextRole(b, on and "WindowTitle" or "Title", { Color = on and "Text" or "Sub" })
        if on then
            local u = New("Frame", { Name = "Under", BackgroundColor3 = C.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
                Size = UDim2.new(1, 0, 0, 2), Parent = b })
            u:SetAttribute("Skinned", true)
        else
            b.MouseEnter:Connect(function() b.TextColor3 = C.Text end)
            b.MouseLeave:Connect(function() b.TextColor3 = C.Sub end)
            b.SelectionGained:Connect(function() b.TextColor3 = C.Text end)
            b.SelectionLost:Connect(function() b.TextColor3 = C.Sub end)
            b.Activated:Connect(function()
                local fn = UIStyle.NavOpen[id]
                if fn then fn() end
            end)
        end
    end
    if meta and meta ~= "" then -- (the window's subtitle: after the nav, quiet)
        local m = UIStyle.Text({ Name = "Meta", Text = meta, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = top })
        UIStyle.TextRole(m, "Meta")
        local function Place()
            local x = 28 + nav.AbsoluteSize.X / math.max(HudK(top), 0.05) + 36
            m.Position = UDim2.new(0, x, 0.5, 0)
            m.Size = UDim2.new(1, -(x + 90), 0, 18)
        end
        nav:GetPropertyChangedSignal("AbsoluteSize"):Connect(Place)
        task.defer(Place)
    end
    if onClose then
        local holder = New("Frame", { Name = "CloseHolder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
            Size = UDim2.fromOffset(36, 36), Parent = top })
        holder:SetAttribute("Skinned", true)
        local x = UIStyle.CloseButton(holder, onClose, 36)
        x.Button.Position = UDim2.new(0, 0, 0, 0)
        x.SetQuiet(false)
    end
    return top
end
-- SNAP (UI CLEAN R-B): a text in a full-screen menu that was built before the text roles (no TextRole attr) is snapped ONCE,
-- when it appears, onto the role scale: size -> the nearest of 13 / 14 / 15 / 20 / 26 (a big display number >= 30 stays; no
-- body text under 13), a NEUTRAL colour (grey / off-white) -> the nearest of Text / Sub / Muted by lightness, any letter outline
-- off. Hued colours
-- (rarity, Good / Bad, gold) are kept. TextScaled objects are left alone (their cap is their size). Event-driven only.
local SNAP_SIZES = { 13, 14, 15, 20, 26 }
function UIStyle.SnapText(o: Instance)
    if not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then return end
    -- (an outline on the letters -- the old "Stroke = 2" text -- goes in every big menu, role or not)
    for _, st in ipairs(o:GetChildren()) do
        if st:IsA("UIStroke") and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then st.Enabled = false end
    end
    if o:GetAttribute("TextRole") or o:GetAttribute("NoSnap") then return end
    local t = o :: TextLabel
    if not t.TextScaled then
        local sz = t.TextSize
        if sz < 30 then
            local best, bd = 13, math.huge
            for _, v in ipairs(SNAP_SIZES) do
                local d = math.abs(v - sz)
                if d < bd then best, bd = v, d end
            end
            if sz >= 17 and sz <= 18 then best = 15 end -- (old 17-18 px list names read as the 15 role, not a 20 title)
            if sz >= 22 and sz < 24 then best = 20 end
            t.TextSize = best
        end
    end
    local c = t.TextColor3
    local _, sat, val = c:ToHSV()
    if sat < 0.15 then
        local L = UIStyle.Luma(c)
        if L >= 0.55 then t.TextColor3 = C.Text
        elseif L >= 0.3 then t.TextColor3 = C.Sub
        elseif L >= 0.08 then t.TextColor3 = C.Muted end -- (darker = ink on a light button: kept)
    end
    local _ = val
end
-- WORD TAB (UI CLEAN audit): the target's tab -- a word in the display face, Sub at rest, Text + a 2 px underline when picked,
-- no slab. For tab rows and filter chips inside windows (lay them out with a horizontal UIListLayout). size = text size (15).
function UIStyle.WordTab(parent: Instance, text: string, selected: boolean, onClick: (() -> ())?, size: number?): TextButton
    local b = New("TextButton", { Name = "Tab_" .. text, Text = text, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = Enum.Font.GothamBlack, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 30),
        LayoutOrder = #parent:GetChildren(), Parent = parent }) :: TextButton -- (creation order: a list layout sorts by name otherwise)
    b:SetAttribute("NoNeon", true); b:SetAttribute("Skinned", true)
    UIStyle.TextRole(b, "Tab", { Color = selected and "Text" or "Sub" })
    b.TextSize = size or 15
    local pad = New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), Parent = b })
    local _ = pad
    local u = New("Frame", { Name = "Under", BackgroundColor3 = C.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2), Visible = selected, Parent = b })
    u:SetAttribute("Skinned", true)
    if not selected then
        b.MouseEnter:Connect(function() b.TextColor3 = C.Text end)
        b.MouseLeave:Connect(function() b.TextColor3 = C.Sub end)
        b.SelectionGained:Connect(function() b.TextColor3 = C.Text end)
        b.SelectionLost:Connect(function() b.TextColor3 = C.Sub end)
    end
    if onClick then b.Activated:Connect(onClick) end
    return b
end

-- The same field + top bar for a window that is NOT a UIStyle.Panel (the passive tree): opts = { Items, Selected, OnClose,
-- Meta, Place = function(barBottom: number, phone: boolean) -- the window places itself under the bar }. Returns the field.
function UIStyle.MenuField(frame: GuiObject, opts: any): Frame
    if frame.ZIndex <= 1 then frame.ZIndex = 2 end -- (the field sits one layer under the window)
    local field = New("Frame", { Name = frame.Name .. "_Field", BackgroundColor3 = C.Field, BackgroundTransparency = 0.06, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = math.max(1, frame.ZIndex - 1), Active = true, Parent = frame.Parent }) :: Frame
    field:SetAttribute("Skinned", true); field:SetAttribute("NoSkin", true); field:SetAttribute("MenuFieldFor", frame.Name)
    Tag(field, "UIT_Field") -- (SKIN UI THEMES: a theme's signature touches live on the field)
    local top = UIStyle.MenuTop(field, opts.Items or {}, opts.Selected, opts.OnClose, opts.Meta)
    local wasOpen = false
    local function Apply()
        local on = frame.Visible and frame.Parent ~= nil
        local phone = UIStyle.IsPhone()
        field.Visible = on and not phone
        field.ZIndex = math.max(1, frame.ZIndex - 1)
        local k = math.max(HudK(frame), 0.05)
        top.Position = UDim2.fromOffset(0, math.floor(UIStyle.TopInset() * UIStyle.SimK() / k + 0.5))
        if on ~= wasOpen then
            wasOpen = on
            menuFieldsOpen = math.max(0, menuFieldsOpen + (on and 1 or -1))
            if UIStyle.OnMenuField then pcall(UIStyle.OnMenuField, menuFieldsOpen > 0) end
        end
        if on and opts.Place then pcall(opts.Place, top.Position.Y.Offset + UIStyle.MENU_TOP_H, phone) end
    end
    frame:GetPropertyChangedSignal("Visible"):Connect(Apply)
    frame:GetPropertyChangedSignal("ZIndex"):Connect(function() field.ZIndex = math.max(1, frame.ZIndex - 1) end)
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if frame.Visible then task.defer(Apply) end end)
    end
    local lp = Players_.LocalPlayer
    if lp then lp:GetAttributeChangedSignal("DevPhone"):Connect(function() task.delay(0.15, Apply) end) end
    Apply()
    return field
end
function UIStyle.MenuChrome(panel: Frame, bar: Frame, title: string, subtitle: string?, onClose: (() -> ())?, ownClose: any?, menuDef: any?)
    local def = menuDef or UIStyle.MENU_WINDOWS[panel.Name]
    local items = def.Group and UIStyle.MENU_NAV[def.Group] or { def.Id or string.upper(title) }
    local field = New("Frame", { Name = panel.Name .. "_Field", BackgroundColor3 = C.Field, BackgroundTransparency = 0.06, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = panel.ZIndex - 1, Active = true, Parent = panel.Parent }) :: Frame
    field:SetAttribute("Skinned", true); field:SetAttribute("NoSkin", true); field:SetAttribute("MenuFieldFor", panel.Name)
    Tag(field, "UIT_Field") -- (SKIN UI THEMES: a theme's signature touches live on the field)
    local top = UIStyle.MenuTop(field, items, def.Id, onClose, subtitle)
    local body = panel:FindFirstChild("Body")
    local wasOpen = false
    local function Apply()
        local on = panel.Visible and panel.Parent ~= nil
        local phone = UIStyle.IsPhone()
        field.Visible = on
        field.ZIndex = panel.ZIndex - 1
        local k = HudK(panel)
        top.Position = UDim2.fromOffset(0, phone and 0 or math.floor(UIStyle.TopInset() * UIStyle.SimK() / math.max(k, 0.05) + 0.5))
        top.Visible = not phone
        -- the window's own chrome: hidden on desktop (the bar has it), back on phones
        for _, n in ipairs({ "Title", "Block", "Rule", "Subtitle" }) do
            local o = bar:FindFirstChild(n)
            if o and o:IsA("GuiObject") then o.Visible = phone end
        end
        if ownClose then ownClose.Button.Visible = phone end
        if body then
            body.BackgroundTransparency = phone and UIStyle.WINDOW_T or 1
            local st = body:FindFirstChildOfClass("UIStroke")
            if st then st.Enabled = phone end
        end
        if on ~= wasOpen then
            wasOpen = on
            menuFieldsOpen = math.max(0, menuFieldsOpen + (on and 1 or -1))
            if UIStyle.OnMenuField then pcall(UIStyle.OnMenuField, menuFieldsOpen > 0) end
        end
    end
    -- desktop: the content (the window minus its 66 px title strip) sits under the bar, fitted to the room left; returns the
    -- scale (nil on phones: the phone fit stays). Called by Panel's open / resize handlers BEFORE the open motion.
    menuFit[panel] = function(): number?
        if UIStyle.IsPhone() then return nil end
        local pop = panel:FindFirstChild("PopScale")
        local w, h = panel.Size.X.Offset, panel.Size.Y.Offset
        if not pop or w <= 0 or h <= 0 then return nil end
        local k = math.max(HudK(panel), 0.05)
        local cam = workspace.CurrentCamera
        local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local V, W = vs.Y / k, vs.X / k
        local B = math.floor(UIStyle.TopInset() * UIStyle.SimK() / k + 0.5) + UIStyle.MENU_TOP_H
        local s = math.clamp(math.min(1, (V - B - 24) / math.max(1, h - 66), (W - 32) / w), 0.4, 1)
        local off = math.floor(B + 10 - 66 * s + h * s / 2 - V / 2 + 0.5)
        local rec = fitted[panel]
        if rec then rec.BaseY = off end
        panel.Position = UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, panel.Position.Y.Scale, off)
        return s
    end
    panel:SetAttribute("MenuField", true)
    -- (text built before the roles: snapped once when it appears -- the window's rows are rebuilt on refresh, so new ones too)
    for _, d in ipairs(panel:GetDescendants()) do UIStyle.SnapText(d) end
    panel.DescendantAdded:Connect(function(d)
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then task.defer(UIStyle.SnapText, d) end
    end)
    panel:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(Apply) end)
    -- (a phone fit raises the window to layer 12 after it opens: the field follows, always one under it)
    panel:GetPropertyChangedSignal("ZIndex"):Connect(function() field.ZIndex = panel.ZIndex - 1 end)
    panel.AncestryChanged:Connect(function() if not panel.Parent then field:Destroy() end end)
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if panel.Visible then task.defer(Apply) end end)
    end
    local lp = Players_.LocalPlayer
    if lp then lp:GetAttributeChangedSignal("DevPhone"):Connect(function() task.delay(0.15, Apply) end) end
    Apply()
end

-- The window close button (UI CLEAN): a quiet transparent square with an X in the secondary colour; hover / selection
-- = a raised surface and the X in full text colour (no red slab, no glow). Sits at the right end of a title bar.
function UIStyle.CloseButton(bar: GuiObject, onClose: () -> (), size: number?)
    local s = size or 40
    local close = UIStyle.Button(bar, "X", C.Bg1, UDim2.fromOffset(s, s), UDim2.new(1, -(s + 9), 0.5, -s / 2), "Close")
    close.Label.TextSize = math.floor(s * 0.5)
    close.SetQuiet(true)
    local function Idle() close.Label.TextColor3 = C.Sub end
    Idle()
    close.Button.MouseLeave:Connect(Idle)
    close.Button.SelectionLost:Connect(Idle)
    close.Button.MouseButton1Click:Connect(onClose)
    closeFns[close.Button] = onClose -- (the pinned phone close button finds it)
    -- (phones: an invisible pad 12 px wider on every side -- a 40 px X lands at ~32 pt on a phone, under the 44 pt a
    -- finger needs)
    if UIS_.TouchEnabled then
        local pad = New("TextButton", { Name = "HitPad", Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 24, 1, 24),
            ZIndex = close.Button.ZIndex + 1, Parent = close.Button })
        pad:SetAttribute("Skinned", true)
        pad.Activated:Connect(onClose)
        closeFns[pad] = onClose
    end
    return close
end

-- Chip (icon + value), e.g. currencies (UI CLEAN): a flat dark plate, a 2 px mark in its colour, the value in the data face.
function UIStyle.Chip(parent: Instance, color: Color3, order: number?, icon: string?): TextLabel
    if icon and UIStyle.Icons[icon] and not UIStyle.HasIcon(icon) then icon = nil end -- (not uploaded yet -> plain chip)
    local chip = New("Frame", { BackgroundColor3 = C.Bg0, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.fromOffset(0, 30),
        AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 0, Parent = parent }, {
        UIStyle.Corner(2), New("UIPadding", { PaddingLeft = UDim.new(0, icon and 10 or 14), PaddingRight = UDim.new(0, 12) }),
    })
    local pip = New("Frame", { Name = "Pip", BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, -14), Position = UDim2.new(0, icon and -10 or -14, 0, 7), Parent = chip })
    pip:SetAttribute("Skinned", true)
    Tag(chip, "UIT_Chip")
    if icon then
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chip })
        UIStyle.Icon(icon, { Name = "Icon", Size = UDim2.fromOffset(22, 22), LayoutOrder = 1, Parent = chip })
    end
    local t = UIStyle.Text({ Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, TextSize = 16, TextColor3 = color, LayoutOrder = 2, Parent = chip })
    t:SetAttribute("TypeRole", "Accent")
    return t
end

-- ===================== Skin: bring older hand-built GUI into the same look =====================
-- UIStyle.Skin(root) restyles every existing AND future descendant of root: chunky outlined fonts,
-- glossy gradients that keep each element's own color (so code that recolors things still works),
-- thick dark borders, rounded corners and hover-bounce buttons. UIStyle.SkinWindow turns an old
-- menu Frame (plus its header label) into a themed window with a colored title bar and close button.
-- Anything under a UIStyle.Panel (attribute UIStyled) or marked NoSkin is left untouched.
-- (UI CLEAN: older hand-built slabs are drawn FLAT in their own colour -- old gloss / facet gradients are removed, none
-- are added; corners clamp to 2 px; no new strokes on plain frames; buttons take the Button roles via NeonButton)
local SKIP_NAMES = { Crosshair = true, Hitmarker = true, SniperScopeOverlay = true }

local function OldGradient(g: UIGradient): boolean
    -- the previous chrome used a translucent white gloss; the new look is fully opaque gradients
    for _, k in ipairs(g.Transparency.Keypoints) do if k.Value > 0.01 then return true end end
    return false
end

local function Excluded(inst: Instance, root: Instance): boolean
    local p = inst
    while p and p ~= root.Parent do
        if p:GetAttribute("UIStyled") or p:GetAttribute("NoSkin") or SKIP_NAMES[p.Name] then return true end
        if p:IsA("ViewportFrame") or p:IsA("BillboardGui") or p:IsA("SurfaceGui") then return true end
        p = p.Parent
    end
    return false
end

local function EnsureCorner(g: GuiObject, r: number)
    -- (UI CLEAN: square -- a missing corner stays missing (square already); a rounded one clamps to r, unless it is
    -- meant to be round: a radius >= 40 or a scale radius)
    local c = g:FindFirstChildOfClass("UICorner")
    if c and c.CornerRadius.Scale == 0 and c.CornerRadius.Offset > r and c.CornerRadius.Offset < 40 then
        c.CornerRadius = UDim.new(0, r)
    end
end

local function BorderStroke(g: GuiObject): UIStroke?
    for _, st in ipairs(g:GetChildren()) do
        if st:IsA("UIStroke") and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then return st end
    end
    return nil
end

local function EnsureGloss(g: GuiObject, _seq: ColorSequence?)
    -- (UI CLEAN: flat -- only the old translucent white gloss is removed; nothing is added)
    local grad = g:FindFirstChildOfClass("UIGradient")
    if grad and OldGradient(grad) then grad:Destroy() end
end

-- The theme fonts run a little wider than the old ones: a label whose text no longer fits wraps (when
-- it has room for 2+ lines) or shrinks, instead of spilling past its box. Re-checked when text changes.
local function FitText(t: any)
    local function Check()
        if t.TextScaled or not t.Parent or t.AbsoluteSize.X <= 0 or t.TextFits then return end
        if not t.TextWrapped and t.AbsoluteSize.Y >= t.TextSize * 2.2 then
            t.TextWrapped = true
            if t.TextFits then return end
        end
        if not t:FindFirstChildOfClass("UITextSizeConstraint") then
            -- (v3: shrink no further than the floor -- this pass used to take labels down to 8 px)
            New("UITextSizeConstraint", { MaxTextSize = math.max(t.TextSize, UIStyle.MIN_SCALED), MinTextSize = UIStyle.MIN_SCALED, Parent = t })
        end
        t.TextScaled = true
    end
    task.defer(Check)
    t:GetPropertyChangedSignal("Text"):Connect(function() task.defer(Check) end)
end

local function SkinText(t: any, isButton: boolean)
    if t.RichText and t.Text:find("<font") then -- rich text picks its own faces; just outline it
        t.TextStrokeTransparency = math.min(t.TextStrokeTransparency, 0.55)
        return
    end
    local header = isButton or t.TextSize >= 17 or t.Font == Enum.Font.GothamBlack or t.Font == Enum.Font.Arcade
    if header then
        t.Font = UIStyle.Font
        local filled = t.BackgroundTransparency < 0.95
        if filled or t:FindFirstChildOfClass("UIStroke") then
            -- its UIStroke slot is (or will be) the border: use the built-in text outline
            t.TextStrokeTransparency = 1 -- (no outlines: owner 2026-10-04)
        else
            t.TextStrokeTransparency = 1
        end
    elseif t.Font ~= Enum.Font.Code and t.Font ~= Enum.Font.RobotoMono then
        t.Font = UIStyle.BodyFont
    end
end

-- An older hand-built filled button drawn in the Button roles (UI CLEAN): the colour its code sets is read as the ROLE --
-- primary (gold / accent) = a filled accent slab, a bright hue = a faint tint of it (edge + label in the hue), dark =
-- its own flat colour with a hairline (so code that marks a selected tab with a lighter slab still shows it). The code's
-- own colour is kept in attr NeonCode (each later set is re-read). Hover = one step lighter, pressed = darker.
local neonCode = setmetatable({}, { __mode = "k" })
local function NeonFace(code: Color3): (Color3, Color3, Color3?, string)
    local role = UIStyle.ButtonRole(code)
    if role == "Primary" then return C.Accent, C.Accent, C.OnAccent, role end
    if role == "Tint" then return UIStyle.Tint(code, 0.14), code, UIStyle.OnDark(code), role end
    return code, C.Text, nil, role
end
UIStyle.NeonFace = NeonFace
local function NeonButton(b: GuiButton)
    local applying = false
    local st = BorderStroke(b)
    local ownStroke = false
    if not st then st = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter, Parent = b }); ownStroke = true end
    st.Thickness = 1
    local hover, down = false, false
    local function Paint()
        local code = neonCode[b] or b.BackgroundColor3
        local face, edge, _, role = NeonFace(code)
        if down then face = Darken(face, 0.14)
        elseif hover then face = (role == "Primary") and Lighten(face, 0.1) or Lighten(face, 0.06) end
        applying = true
        b.BackgroundColor3 = face
        applying = false
        if role == "Primary" then
            st.Transparency = 1
        elseif role == "Tint" then
            st.Color, st.Transparency = edge, hover and 0.2 or 0.55
        elseif ownStroke then
            st.Color, st.Transparency = C.Text, hover and 0.6 or 0.86
        end
        b:SetAttribute("NeonRole", role)
    end
    neonCode[b] = b.BackgroundColor3
    b:SetAttribute("NeonCode", b.BackgroundColor3)
    b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
        if applying then return end
        neonCode[b] = b.BackgroundColor3
        b:SetAttribute("NeonCode", b.BackgroundColor3)
        Paint()
    end)
    local function Hov(on: boolean)
        hover = on
        if not on then down = false end
        Paint()
    end
    b.MouseEnter:Connect(function() Hov(true) end)
    b.MouseLeave:Connect(function() Hov(false) end)
    b.SelectionGained:Connect(function() Hov(true) end)
    b.SelectionLost:Connect(function() Hov(false) end)
    b.MouseButton1Down:Connect(function() if b.Active then down = true; Paint() end end)
    b.MouseButton1Up:Connect(function() down = false; Paint() end)
    Paint()
end

-- A filled button's UIStroke is its border, so its text gets a clean outline from a mirrored child
-- label (kept in sync with the button's Text / color / size, so existing code keeps working).
local function OutlineButtonText(b: TextButton)
    if b.Text == "" or b.RichText or b.TextTransparency >= 1 then return end
    local lbl = New("TextLabel", {
        Name = "SkinText", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UIStyle.Font,
        TextXAlignment = b.TextXAlignment, TextYAlignment = b.TextYAlignment, TextWrapped = b.TextWrapped,
        TextScaled = b.TextScaled, TextTruncate = b.TextTruncate, ZIndex = b.ZIndex, Parent = b,
    }) :: TextLabel
    lbl:SetAttribute("Skinned", true)
    local hadCap = false
    for _, c in ipairs(b:GetChildren()) do
        if c:IsA("UITextSizeConstraint") then c:Clone().Parent = lbl; hadCap = true end
    end
    -- (v3: an older button's caps never read under 14; a long label shrinks to fit from there, to the 11 px floor --
    -- these were drawn at 10-12 px and the fit pass took them to 8)
    local cap = lbl:FindFirstChildOfClass("UITextSizeConstraint")
    if not hadCap and not b.TextScaled and b.AutomaticSize == Enum.AutomaticSize.None then
        cap = New("UITextSizeConstraint", { MaxTextSize = math.max(b.TextSize, 14), MinTextSize = UIStyle.MIN_SCALED, Parent = lbl }) :: UITextSizeConstraint
        lbl.TextScaled = true
        New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = lbl })
    end
    local function Sync()
        lbl.Text, lbl.TextColor3, lbl.TextSize = b.Text, b.TextColor3, b.TextSize
        if cap and not hadCap then cap.MaxTextSize = math.max(b.TextSize, 14) end
        -- (v4: the label follows the slab's role -- ink on the neon primary, the hue on a tinted ghost, and dark text
        -- the code meant for a bright slab turns light on a dark one)
        if b.BackgroundTransparency < 0.5 then
            local code = b:GetAttribute("NeonCode")
            if typeof(code) == "Color3" then
                local _, _, txt, role = NeonFace(code)
                if role == "Primary" then
                    lbl.TextColor3 = txt
                elseif role == "Tint" then
                    -- (text the code coloured on purpose, e.g. a rarity name, keeps its colour when it reads on dark)
                    lbl.TextColor3 = (UIStyle.Luma(b.TextColor3) > 0.55 or UIStyle.Luma(b.TextColor3) < 0.12) and txt or b.TextColor3
                elseif UIStyle.Luma(b.TextColor3) < 0.12 then
                    lbl.TextColor3 = C.Text
                end
            end
        end
    end
    b:GetAttributeChangedSignal("NeonRole"):Connect(Sync)
    b:GetPropertyChangedSignal("BackgroundColor3"):Connect(Sync)
    Sync()
    b:GetPropertyChangedSignal("Text"):Connect(Sync)
    b:GetPropertyChangedSignal("TextColor3"):Connect(Sync)
    b:GetPropertyChangedSignal("TextSize"):Connect(Sync)
    b.TextTransparency = 1
    b.TextStrokeTransparency = 1
end

local function SkinOne(inst: Instance)
    if not inst:IsA("GuiObject") or inst:GetAttribute("Skinned") then return end
    inst:SetAttribute("Skinned", true)
    local g = inst :: GuiObject
    local abs = g.AbsoluteSize
    local minDim = math.min(abs.X, abs.Y)
    if minDim > 0 and minDim <= 6 then return end -- crosshair ticks, thin dividers
    local filled = g.BackgroundTransparency < 0.95

    if g:IsA("TextButton") or g:IsA("ImageButton") then
        if g:IsA("TextButton") then SkinText(g, true) end
        if filled then
            g.BorderSizePixel = 0
            g.AutoButtonColor = false
            -- (UI CLEAN: older windows' buttons take the Button roles -- see NeonButton)
            EnsureGloss(g)
            EnsureCorner(g, 2)
            if not g:GetAttribute("NoNeon") then NeonButton(g) end
            if g:IsA("TextButton") then OutlineButtonText(g) end
        end
        return
    end
    if g:IsA("TextLabel") or g:IsA("TextBox") then
        SkinText(g, false)
        if g:IsA("TextLabel") and g.TextTruncate == Enum.TextTruncate.None then FitText(g) end
    end
    if g:IsA("ScrollingFrame") then
        UIStyle.StyleScroll(g)
    end
    if not filled then return end
    -- panels, cards, rows, bars
    local bordered = g.BorderSizePixel > 0
    local borderCol = g.BorderColor3
    g.BorderSizePixel = 0
    if minDim > 0 and minDim <= 14 then
        -- bars / fills: flat and square, no border (v3: no gloss on bars)
        local og = g:FindFirstChildOfClass("UIGradient")
        if og and OldGradient(og) then og:Destroy() end
        EnsureCorner(g, 1)
        return
    end
    EnsureGloss(g)
    EnsureCorner(g, 2)
    -- (UI CLEAN: an existing edge becomes a hairline; a plain slab gets none -- fills carry structure, not outlines)
    local st = BorderStroke(g)
    if st then
        st.Thickness = 1
        st.Transparency = math.max(st.Transparency, 0.35)
        st.LineJoinMode = Enum.LineJoinMode.Miter
    elseif bordered then
        local ns = UIStyle.Stroke(Darken(borderCol, 0.2), 1)
        ns.Transparency = 0.4
        ns.Parent = g
    end
end

function UIStyle.Skin(root: Instance)
    local function Try(d: Instance)
        if d:IsA("GuiObject") and not Excluded(d, root) then SkinOne(d) end
    end
    for _, d in ipairs(root:GetDescendants()) do Try(d) end
    -- rows/cards built later (inventory refreshes, loot popups...): skin once they have a size
    root.DescendantAdded:Connect(function(d)
        if d:IsA("GuiObject") then task.defer(function() if d.Parent then Try(d) end end) end
    end)
end

-- An old menu Frame -> themed window: gradient body, thick border, accent glow, pop-in, and its header
-- label becomes a colored title bar with an X button.
function UIStyle.SkinWindow(frame: Frame, header: TextLabel?, onClose: (() -> ())?)
    local oldStroke = BorderStroke(frame)
    local accent = C.Accent -- (UI CLEAN: one accent)
    local _ = oldStroke
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("UIGradient") or (c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then c:Destroy() end
    end
    frame:SetAttribute("Skinned", true)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = UIStyle.WINDOW_T
    frame.BackgroundColor3 = C.Bg0 -- (UI CLEAN: the same flat slate as UIStyle.Panel)
    New("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Miter, Parent = frame })
    EnsureCorner(frame, 2)
    -- (the accent carrier for the title tick / premium themes; invisible)
    local laid = frame:FindFirstChildOfClass("UIListLayout") or frame:FindFirstChildOfClass("UIGridLayout")
    if not laid then UIStyle.NeonEdge(frame, accent, -1) end
    Tag(frame, "UIT_Window")
    -- (v4: the HUD chrome's coloured block down a window's left edge is a second accent -- the top line is the one)
    local oldBlock = frame:FindFirstChild("Block")
    if oldBlock and oldBlock:IsA("Frame") and oldBlock.Size.Y.Scale == 1 then oldBlock.Visible = false end
    local pop = frame:FindFirstChild("PopScale") or New("UIScale", { Name = "PopScale", Parent = frame })
    frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if frame.Visible then
            pop.Scale = 1 -- (owner 2026-10-04: "I dont want the inventory to shake when you open it" -- no bounce)
            -- (a HUD banner with attrs PhoneBoostW / H -- the victory banner -- is drawn bigger on a phone: PhoneBoostK)
            local bw, bh = frame:GetAttribute("PhoneBoostW"), frame:GetAttribute("PhoneBoostH")
            if bw and bh then pop.Scale = UIStyle.PhoneBoostK(frame, bw, bh) end
            UIStyle.PhoneFitWindow(frame, pop)
            -- (v4: the short fade-up + settle every window gets; menus only -- HUD banners keep their own entrances)
            if frame:FindFirstAncestor("Menus") and not frame:GetAttribute("NoOpenMotion") then UIStyle.Motion.Open(frame, pop) end
        end
    end)
    if header then
        header:SetAttribute("Skinned", true)
        header.BorderSizePixel = 0
        header.BackgroundTransparency = 1
        header.BackgroundColor3 = C.Bg0
        -- always a full-width bar, so the X lands in the window's top-right corner
        header.Size = UDim2.new(1, -12, header.Size.Y.Scale, header.Size.Y.Offset - 4)
        header.Position = UDim2.new(0, 6, header.Position.Y.Scale, header.Position.Y.Offset + 4)
        -- the bar's own text is hidden; an outlined title label on top carries it (kept in sync)
        local title = New("TextLabel", {
            Name = "Title", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UIStyle.Font,
            -- (the same title size on every older window; the header's own size varied 14..20)
            TextSize = UIStyle.Size.Title, TextColor3 = C.Text, TextXAlignment = header.TextXAlignment,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
        }) :: TextLabel
        title:SetAttribute("Skinned", true)
        UIStyle.TextRole(title, "WindowTitle")
        title.TextStrokeTransparency = 1
        local function Sync()
            -- the "[KEY / ESC to Close]" hints move to the X button
            title.Text = (header.Text:gsub("%s*%[[^%]]*[Cc]lose%]", ""))
        end
        Sync()
        header:GetPropertyChangedSignal("Text"):Connect(Sync)
        header.TextTransparency = 1
        header.TextStrokeTransparency = 1
        for _, c in ipairs(header:GetChildren()) do if c:IsA("UIGradient") or c:IsA("UIStroke") then c:Destroy() end end
        -- (UI CLEAN header: no box -- a 3 px accent tick before the title, a hairline under it)
        EnsureCorner(header, 2)
        local block = New("Frame", { Name = "Block", BackgroundColor3 = accent, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(3, 22), Position = UDim2.new(0, -10, 0.5, 0), Parent = header })
        block:SetAttribute("Skinned", true)
        if header.TextXAlignment == Enum.TextXAlignment.Center then block.Visible = false end -- (a centred title: no stray tick)
        local wline = frame:FindFirstChild("AccentGlow")
        if wline then
            local function Sync() block.BackgroundColor3 = wline.BackgroundColor3 end
            Sync()
            wline:GetPropertyChangedSignal("BackgroundColor3"):Connect(Sync)
        end
        local hr = New("Frame", { Name = "Rule", BackgroundColor3 = C.Line, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -14, 1, 4),
            Size = UDim2.new(1, onClose and 66 or 28, 0, 1), Parent = header })
        hr:SetAttribute("Skinned", true)
        New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, onClose and 52 or 14), Parent = header })
        if onClose then
            local close = UIStyle.CloseButton(header, onClose, 34)
            close.Button.Position = UDim2.new(1, 6, 0.5, -17)
        end
        Tag(header, "UIT_Title")
    end
end

-- ===================== v3 COMPONENTS (Update 5) =====================
-- Scroll bars: a slim neutral thumb on every list (it was a pale blue 6 px bar on some lists, the Roblox default on others)
function UIStyle.StyleScroll(sf: ScrollingFrame, thick: number?)
    sf.ScrollBarImageColor3 = C.Sub -- (a slim quiet thumb)
    sf.ScrollBarImageTransparency = 0.6
    sf.ScrollBarThickness = math.max(math.min(thick or 3, 6), 3)
    sf.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    sf.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    sf.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    sf.BorderSizePixel = 0
end

-- A section header inside a window: condensed caps in the secondary colour with a hairline rule after it.
-- Returns the holder frame (its Label child carries the text).
function UIStyle.SectionHeader(parent: Instance, text: string, props: { [string]: any }?): Frame
    local p = props or {}
    local h = p.Height or 24
    local f = New("Frame", { Name = p.Name or "Section", BackgroundTransparency = 1, Size = p.Size or UDim2.new(1, 0, 0, h), Position = p.Position or UDim2.new(),
        LayoutOrder = p.LayoutOrder or 0, Parent = parent })
    f:SetAttribute("Skinned", true)
    local lbl = UIStyle.Text({ Name = "Label", Text = string.upper(text), TextSize = 15,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Parent = f })
    UIStyle.TextRole(lbl, "SectionHead") -- (P4: a head is never dimmer than its rows)
    if p.Color then lbl.TextColor3 = p.Color end
    lbl:SetAttribute("Skinned", true)
    local rule = New("Frame", { Name = "Rule", BackgroundColor3 = C.Line, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 0, Parent = f })
    rule:SetAttribute("Skinned", true)
    -- the rule starts after the text
    local function Place()
        local w = lbl.TextBounds.X + 10
        rule.Position = UDim2.new(0, w, 0.5, 1)
        rule.Size = UDim2.new(1, -w, 0, 1)
    end
    lbl:GetPropertyChangedSignal("TextBounds"):Connect(Place)
    task.defer(Place)
    return f
end

-- A thin divider line.
function UIStyle.Divider(parent: Instance, props: { [string]: any }?): Frame
    local p = props or {}
    local d = New("Frame", { Name = "Divider", BackgroundColor3 = C.Line, BorderSizePixel = 0, Size = p.Size or UDim2.new(1, 0, 0, 1), Position = p.Position or UDim2.new(),
        LayoutOrder = p.LayoutOrder or 0, Parent = parent })
    d:SetAttribute("Skinned", true)
    return d
end

-- A key cap ("TAB", "E", "LMB"): a small dark block with the key in the data face. Used in hints and hover flags.
function UIStyle.KeyCap(parent: Instance, key: string, props: { [string]: any }?): TextLabel
    local p = props or {}
    local k = New("TextLabel", { Name = p.Name or "Key", BackgroundColor3 = C.Well, BorderSizePixel = 0, Text = string.upper(key), TextColor3 = p.Color or C.Text,
        TextSize = p.TextSize or 13, Font = Enum.Font.Code, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, p.Height or 22),
        LayoutOrder = p.LayoutOrder or 0, Position = p.Position or UDim2.new(), Parent = parent }, {
        UIStyle.Corner(2), New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }), UIStyle.Stroke(C.Line, 1),
    }) :: TextLabel
    k:SetAttribute("Skinned", true)
    return k
end

-- (v4) A neon underline that SLIDES to the selected tab of any tab row: UIStyle.TabUnderline(holder, color?) -> api
-- with .To(button) (tweens under that button, 0.16 s) and .Line. holder = a frame WITHOUT a layout that contains the
-- row (the underline must not become a layout item).
function UIStyle.TabUnderline(holder: GuiObject, color: Color3?, thick: number?)
    local line = New("Frame", { Name = "TabUnderline", BackgroundColor3 = color or C.Neon, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
        Size = UDim2.fromOffset(0, thick or 2), Position = UDim2.new(0, 0, 1, 0), ZIndex = ((holder :: any).ZIndex or 1) + 2, Visible = false, Parent = holder }) :: Frame
    line:SetAttribute("Skinned", true)
    line:SetAttribute("NoSkin", true)
    local api = { Line = line }
    local placed = false
    function api.To(btn: GuiObject?)
        if not btn or not btn.Parent or holder.AbsoluteSize.X <= 0 then line.Visible = false; placed = false; return end
        -- (in fractions of the holder: right under any UIScale above it)
        local hw = holder.AbsoluteSize.X
        local x = (btn.AbsolutePosition.X - holder.AbsolutePosition.X) / hw
        local w = btn.AbsoluteSize.X / hw
        local target = { Position = UDim2.new(x, 0, 1, 0), Size = UDim2.new(w, 0, 0, line.Size.Y.Offset) }
        line.Visible = true
        if placed then Tw(line, 0.16, target, Enum.EasingStyle.Quart) else line.Position, line.Size = target.Position, target.Size end
        placed = true
    end
    return api
end

-- A row of tabs. tabs = { { Id, Text, Color? } }; onSelect(id). (v4: quiet dark tabs, the selected one in bright text
-- with the neon underline sliding to it -- one colour carries "selected"). Returns
-- { Frame, Buttons = { [id] = api }, Select(id), Selected() }.
function UIStyle.TabBar(parent: Instance, tabs: { any }, onSelect: (string) -> (), props: { [string]: any }?)
    local p = props or {}
    local h = p.Height or 36
    local bar = New("Frame", { Name = p.Name or "Tabs", BackgroundTransparency = 1, Size = p.Size or UDim2.new(1, 0, 0, h), Position = p.Position or UDim2.new(),
        LayoutOrder = p.LayoutOrder or 0, Parent = parent })
    bar:SetAttribute("Skinned", true)
    local row = New("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = bar }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, p.Gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = p.Align or Enum.HorizontalAlignment.Left }),
    })
    row:SetAttribute("Skinned", true)
    local api = { Frame = bar, Buttons = {} }
    local current
    local accent = UIStyle.NeonOf(p.Accent)
    local under = UIStyle.TabUnderline(bar, accent)
    local w = p.TabWidth
    for i, t in ipairs(tabs) do
        local b = UIStyle.Button(row, t.Text, C.Bg1, UDim2.new(w and 0 or 1 / #tabs, w or -(p.Gap or 6), 0, h), nil, "Tab_" .. t.Id)
        b.SetQuiet(true) -- (UI CLEAN: tabs are words; the accent underline marks the selected one)
        b.Label.TextSize = 15; b.Label:SetAttribute("TextRole", "Tab")
        b.Button.LayoutOrder = i
        api.Buttons[t.Id] = b
        b.Button.MouseButton1Click:Connect(function()
            api.Select(t.Id)
            onSelect(t.Id)
        end)
    end
    function api.Select(id: string)
        current = id
        for tid, b in pairs(api.Buttons) do
            b.SetColor(C.Bg1)
            b.Label.TextColor3 = tid == id and C.Text or C.Sub
        end
        local sel = api.Buttons[id]
        task.defer(function() under.To(sel and sel.Button) end)
    end
    function api.Selected() return current end
    bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() local sel = current and api.Buttons[current]; if sel then under.To(sel.Button) end end)
    return api
end

-- One label / value row (stats panels, details). Returns the row; .Value is the value label.
function UIStyle.StatRow(parent: Instance, label: string, value: string, props: { [string]: any }?): Frame
    local p = props or {}
    local h = p.Height or 30
    local row = New("Frame", { Name = p.Name or "Row", BackgroundColor3 = C.Bg1, BackgroundTransparency = p.Zebra and 0 or 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, h), LayoutOrder = p.LayoutOrder or 0, Parent = parent }, {
        New("UIPadding", { PaddingLeft = UDim.new(0, p.Inset or 0), PaddingRight = UDim.new(0, p.Inset or 0) }), -- (P4: rows on the head's inset)
    })
    row:SetAttribute("Skinned", true)
    local l = UIStyle.Text({ Name = "Label", Text = label, Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub,
        Size = UDim2.new(0.62, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
    UIStyle.TextRole(l, "Label")
    l:SetAttribute("Skinned", true)
    local v = UIStyle.Text({ Name = "Value", Text = value, TextSize = 15, TextColor3 = p.ValueColor or C.Text,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
    UIStyle.TextRole(v, "Value", p.ValueColor and { Keep = true } or nil)
    v:SetAttribute("Skinned", true)
    return row
end

-- An empty state: a short title and one line of help, centred (instead of a blank list or "empty").
function UIStyle.EmptyState(parent: Instance, title: string, body: string?, props: { [string]: any }?): Frame
    local p = props or {}
    local f = New("Frame", { Name = p.Name or "Empty", BackgroundTransparency = 1, Size = p.Size or UDim2.new(1, 0, 0, 80), Position = p.Position or UDim2.new(),
        LayoutOrder = p.LayoutOrder or 0, Parent = parent })
    f:SetAttribute("Skinned", true)
    local t = UIStyle.Text({ Name = "Title", Text = string.upper(title), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.5, body and -24 or -12), Parent = f })
    UIStyle.TextRole(t, "SectionHead")
    if body then
        local b = UIStyle.Text({ Name = "Body", Text = body, Font = UIStyle.BodyFont, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
            TextWrapped = true, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 0.5, 2), Parent = f })
        UIStyle.TextRole(b, "Meta")
    end
    return f
end

-- ===== INTERFACE SCALE (Settings > Interface > Interface Scale) for every HUD-like ScreenGui, not just the main HUD:
-- UIStyle.InterfaceScale() = the setting x the short-screen factor (HudAuto); UIStyle.ScaleGui(gui) adds one UIScale
-- named "InterfaceScale" to a ScreenGui and keeps it in step. Screen-projected guis (hit numbers, enemy bars) are NOT
-- scaled this way (their positions are screen pixels).
local scaledGuis = {}
function UIStyle.InterfaceScale(): number
    local ok, GS = pcall(function() return require(script.Parent:WaitForChild("GameSettings")) end)
    local pct = ok and tonumber(GS.Get("UIScale")) or 100
    return (pct / 100) * UIStyle.HudAuto()
end
function UIStyle.ScaleGui(gui: LayerCollector)
    if scaledGuis[gui] then return end
    local s = gui:FindFirstChild("InterfaceScale") or New("UIScale", { Name = "InterfaceScale", Parent = gui })
    scaledGuis[gui] = s
    s.Scale = UIStyle.InterfaceScale()
    gui.AncestryChanged:Connect(function() if not gui.Parent then scaledGuis[gui] = nil end end)
end
function UIStyle.RescaleGuis()
    local k = UIStyle.InterfaceScale()
    for gui, s in pairs(scaledGuis) do
        if gui.Parent then s.Scale = k else scaledGuis[gui] = nil end
    end
end
task.defer(function()
    local ok, GS = pcall(function() return require(script.Parent:WaitForChild("GameSettings")) end)
    if ok and GS.OnChanged then GS.OnChanged("UIScale", function() UIStyle.RescaleGuis() end) end
    local cam = workspace.CurrentCamera
    if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() UIStyle.RescaleGuis() end) end
end)

return UIStyle
