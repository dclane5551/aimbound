--!nocheck
-- ============================================================================================
-- MENU KIT (UI CLEAN R-A "runui", 2026-10-28; contract docs/UI_CLEAN_2026-10-28.md, target docs/ui_target/inventory_target.html).
-- Small helpers that put the older menus (Settings, Challenges / Season, Store + Cosmetics, Profiles, Party Finder, the guide /
-- patch notes / credits, the Index) on the target's language without rebuilding them. The big structure (full-screen field + the
-- top nav of sibling windows + snapped text) comes from UIStyle.MENU_WINDOWS / MenuChrome / MenuField (builder "clean");
-- MenuKit.Register adds the R-A windows to it.
--   MenuKit.Register(UIStyle)          R-A windows -> MENU_WINDOWS / MENU_NAV groups (call BEFORE the windows build)
--   MenuKit.WordTab(api, side?)        a UIStyle.Button api -> a WORD tab: no box; selected = Text + a 2 px off-white underline
--                                      (side "Left": a 2 px left tick instead, for vertical tab lists); rest = Sub; hover = Text.
--                                      Wraps api.SetSelected, so the module's own refresh code keeps working.
--   MenuKit.Card(frame, edge?)         the target's card: the raised surface (Text at RAISE_T), square, no stroke / gradient;
--                                      edge = a colour for ONE 2 px line along the bottom (rarity / meaning), nil = none.
--   MenuKit.Flat(frame)                transparent, no stroke / gradient / corner (a column / an open area)
--   MenuKit.Head(text, role?)          a heading in display caps Text (SectionHead by default); hued heads lose their hue
-- No per-frame work: everything happens once at build / on the module's own refreshes.
-- ============================================================================================
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colors

local MenuKit = {}
MenuKit.RAISE_T = 0.955 -- (the target's --raise: the text colour at ~4.5%)
MenuKit.RAISE2_T = 0.915 -- (hover / selected card: ~8.5%)

-- ===== the R-A windows in the full-screen menu system =====
MenuKit.WINDOWS = {
    SetMenu = { Group = "GAME", Id = "SETTINGS" }, WelcomeGuide = { Group = "GAME", Id = "GUIDE" },
    PatchNotes = { Group = "GAME", Id = "PATCH NOTES" }, Credits = { Group = "GAME", Id = "CREDITS" },
    ChallengesMenu = { Group = "PROGRESS", Id = "CHALLENGES" }, SeasonMenu = { Group = "PROGRESS", Id = "SEASON" },
    CosmeticsWindow = { Id = "STORE" },
    ProfileMenu = { Group = "SOCIAL", Id = "PROFILES" }, PartyFinder = { Group = "SOCIAL", Id = "PARTY FINDER" },
    -- (R-A2 sweep) the duel window, friend invites and the teleport board join the system too
    DuelMenu = { Group = "SOCIAL", Id = "DUEL" }, ReferralMenu = { Group = "SOCIAL", Id = "INVITE" }, TeleportMenu = { Id = "TELEPORT" },
    -- (UI CLEAN audit) the city quarters join PROGRESS
    DistrictsMenu = { Group = "PROGRESS", Id = "QUARTERS" },
}
-- (R-A2 sweep) older windows flattened by MenuKit.Sweep from the client (their build code untouched)
-- (Crew / Hideout windows are builder clean's pass: not swept here)
MenuKit.SWEEP = { DuelMenu = true, ReferralMenu = true, TeleportMenu = true, ChallengesMenu = true, PartyFinder = true }
MenuKit.NAV = {
    GAME = { "SETTINGS", "GUIDE", "PATCH NOTES", "CREDITS" },
    PROGRESS = { "CHALLENGES", "SEASON", "INDEX", "QUARTERS" },
    SOCIAL = { "PROFILES", "PARTY FINDER", "CREW", "TRADE", "DUEL", "INVITE" },
}
function MenuKit.Register(S: any)
    S = S or UIStyle
    if type(S.MENU_WINDOWS) ~= "table" or type(S.MENU_NAV) ~= "table" then return false end
    for name, def in pairs(MenuKit.WINDOWS) do
        if S.MENU_WINDOWS[name] == nil then S.MENU_WINDOWS[name] = def end
    end
    for g, list in pairs(MenuKit.NAV) do S.MENU_NAV[g] = list end
    -- (builder clean: CREW + TRADE join the SOCIAL group)
    if S.MENU_WINDOWS.GuildMenu then S.MENU_WINDOWS.GuildMenu.Group = "SOCIAL" end
    if S.MENU_WINDOWS.TradeMenu then S.MENU_WINDOWS.TradeMenu.Group = "SOCIAL" end
    -- (R-A2 sweep) the SWEEP windows are flattened as they appear in the HUD's Menus folder (ChildAdded only: no polling
    -- once the folder exists; the wait for it gives up after 2 minutes)
    task.spawn(function()
        local lp = game:GetService("Players").LocalPlayer
        local pg = lp and lp:WaitForChild("PlayerGui", 30)
        if not pg then return end
        local folder
        for _ = 1, 240 do
            local f = pg:FindFirstChild("Menus", true)
            if f and f:IsA("Folder") then folder = f break end
            task.wait(0.5)
        end
        if not folder then return end
        local function Try(w: Instance) if MenuKit.SWEEP[w.Name] then task.defer(MenuKit.Sweep, w) end end
        for _, w in ipairs(folder:GetChildren()) do Try(w) end
        folder.ChildAdded:Connect(Try)
    end)
    return true
end

local function Strip(o: Instance)
    for _, c in ipairs(o:GetChildren()) do
        if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then c:Destroy()
        elseif c:IsA("UIGradient") or c:IsA("UICorner") then c:Destroy() end
    end
end
MenuKit.Strip = Strip

function MenuKit.Card(f: GuiObject, edge: Color3?): GuiObject
    if not f then return f end
    Strip(f)
    f.BackgroundColor3 = C.Text
    f.BackgroundTransparency = MenuKit.RAISE_T
    f.BorderSizePixel = 0
    f:SetAttribute("Skinned", true)
    local e = f:FindFirstChild("KitEdge")
    if edge then
        if not e then
            e = Instance.new("Frame")
            e.Name = "KitEdge"; e.BorderSizePixel = 0; e.AnchorPoint = Vector2.new(0, 1); e.Position = UDim2.fromScale(0, 1)
            e.Size = UDim2.new(1, 0, 0, 2); e.ZIndex = f.ZIndex + 1; e:SetAttribute("Skinned", true); e.Parent = f
        end
        e.BackgroundColor3 = edge
    elseif e then
        e:Destroy()
    end
    return f
end

function MenuKit.Flat(f: GuiObject): GuiObject
    if not f then return f end
    Strip(f)
    f.BackgroundTransparency = 1
    f:SetAttribute("Skinned", true)
    return f
end

function MenuKit.Head(t: any, role: string?): any
    if not t then return t end
    UIStyle.TextRole(t, role or "SectionHead")
    t.TextStrokeTransparency = 1
    return t
end

-- a UIStyle.Button api -> a word tab
function MenuKit.WordTab(api: any, side: string?): any
    if not api or not api.Button or api.KitTab then return api end
    api.KitTab = true
    local b, l = api.Button, api.Label
    if api.SetQuiet then api.SetQuiet(true) end
    for _, c in ipairs(b:GetChildren()) do if c:IsA("UIStroke") then c.Enabled = false end end
    b.BackgroundTransparency = 1
    if l then
        UIStyle.TextRole(l, "Tab")
        l:SetAttribute("NoSnap", true)
        if side == "Left" then l.TextXAlignment = Enum.TextXAlignment.Left end
    end
    local mark = Instance.new("Frame")
    mark.Name = "KitMark"; mark.BorderSizePixel = 0; mark.BackgroundColor3 = C.Text; mark.Visible = false; mark.ZIndex = b.ZIndex + 2
    if side == "Left" then
        mark.Size = UDim2.new(0, 2, 1, -12); mark.Position = UDim2.fromOffset(0, 6)
    else
        mark.AnchorPoint = Vector2.new(0.5, 1); mark.Position = UDim2.fromScale(0.5, 1)
        mark.Size = UDim2.new(0, 0, 0, 2) -- (width = the word's width, set on paint)
    end
    mark:SetAttribute("Skinned", true)
    mark.Parent = b
    local on, hov = false, false
    local function Paint()
        b.BackgroundTransparency = 1
        b.BackgroundColor3 = C.Bg2
        if l then l.TextColor3 = (on or hov) and C.Text or C.Sub end
        mark.Visible = on
        if side ~= "Left" and l then
            local w = math.max(l.TextBounds.X, 24)
            mark.Size = UDim2.new(0, math.min(w, math.max(0, b.AbsoluteSize.X)), 0, 2)
        end
        -- (the old selected marks of the button system stay off: one mark only)
        for _, c in ipairs(b:GetChildren()) do
            if c:IsA("Frame") and c ~= mark and (c.Name == "Sel" or c.Name == "SelMark" or c.Name == "AccentGlow" or c.Name == "Mark") then c.Visible = false end
        end
    end
    local orig = api.SetSelected
    api.SetSelected = function(v: boolean, _side: any, _col: any)
        on = v == true
        if orig then pcall(orig, false) end -- (the button system's own selected look off)
        Paint()
    end
    b.MouseEnter:Connect(function() hov = true; Paint() end)
    b.MouseLeave:Connect(function() hov = false; Paint() end)
    b.SelectionGained:Connect(function() hov = true; Paint() end)
    b.SelectionLost:Connect(function() hov = false; Paint() end)
    if l then l:GetPropertyChangedSignal("TextBounds"):Connect(function() if on then Paint() end end) end
    -- (UIStyle.Button's hover writes its own surface on enter: undo after it, once)
    b:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
        if b.BackgroundTransparency ~= 1 then b.BackgroundTransparency = 1 end
    end)
    Paint()
    return api
end

-- ===== SWEEP (UI CLEAN R-A2 consistency sweep): an older hand-built window brought onto the language in one pass, without
-- touching its build code. Run once on the window + on anything it adds later (deferred, event-driven, no per-frame work):
--   * a box stroke in a hue (gold / blue / green / red borders) -> the neutral hairline (Text at 0.84)
--   * a thin coloured side bar (<= 6 px wide, full height) -> the same colour as ONE 2 px line along the bottom
--   * display-face text in a strong hue (gold / orange / green / blue heads, coloured names) -> Text (Good / Bad words stay:
--     red + the success green are kept when they sit in BODY text)
--   * a filled hue button (a TextButton slab in green / blue / red / gold) -> the off-white primary with ink words
-- Artwork (ImageLabels) is never touched. Opt out per object: attr KitKeep.
-- (a HUE = saturated AND bright: dark tinted slates (40,20,40) are saturated in HSV but read as grey -- they stay)
-- (SKIN UI THEMES: a colour of the worn UI theme's palette is the theme's own -- never swept back, or the two re-painted each
-- other forever: UITheme fills UIStyle.ThemeHues)
local function Hue(c: Color3, v0: number?): boolean
    if UIStyle.ThemeHues and UIStyle.ThemeHues[c:ToHex()] then return false end
    local _, s, v = c:ToHSV(); return s > 0.3 and v > (v0 or 0.4)
end
local function IsDisplay(t: any): boolean
    local ff = t.FontFace
    local fam = ff and ff.Family or ""
    return string.find(fam, "Oswald", 1, true) ~= nil or (ff ~= nil and ff.Weight.Value >= Enum.FontWeight.Bold.Value)
        or t:GetAttribute("TypeRole") == "Header" or t:GetAttribute("TypeRole") == "Label"
end
local SweepOne
-- (a window that repaints a button / label on a pick: that object is swept again when ITS colour changes -- event-driven)
-- (a weak table, not an attribute: a Clone() copies attributes but not connections)
local hooked = setmetatable({}, { __mode = "k" })
local function Rehook(o: Instance, ...: string)
    if hooked[o] then return end
    hooked[o] = true
    local function Again() task.defer(function() pcall(SweepOne, o) end) end
    for _, prop in ipairs({ ... }) do o:GetPropertyChangedSignal(prop):Connect(Again) end
end
function SweepOne(o: Instance)
    if o:GetAttribute("KitKeep") then return end
    if o:IsA("UIStroke") then
        Rehook(o, "Color")
        local p = o.Parent
        local textOutline = p and (p:IsA("TextLabel") or p:IsA("TextButton") and p.Text ~= "") and o.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
        if textOutline then
            if Hue(o.Color, 0.3) then o.Transparency = 1 end -- (a coloured letter outline: off)
        elseif p and (p:IsA("Frame") or p:IsA("TextButton") or p:IsA("ImageButton") or p:IsA("ScrollingFrame")) and Hue(o.Color, 0.3) then
            o.Color = C.Text
            o.Transparency = math.max(o.Transparency, 0.84)
            o.Thickness = 1
        end
    elseif o:IsA("Frame") then
        local sz = o.Size
        if sz.Y.Scale >= 0.9 and sz.X.Scale == 0 and sz.X.Offset > 0 and sz.X.Offset <= 6 and o.BackgroundTransparency < 0.5 and Hue(o.BackgroundColor3, 0.3) then
            -- (a coloured side bar -> the same colour as ONE 2 px line along the bottom: the meaning stays, the bar goes; on a
            -- wide strip (a section head: wider than 6x its height) it carries no meaning: a neutral hairline instead)
            o.AnchorPoint = Vector2.zero; o.Position = UDim2.new(0, 0, 1, -2); o.Size = UDim2.new(1, 0, 0, 2)
            local par = o.Parent
            if par and par:IsA("GuiObject") and (par.AbsoluteSize.X > 6 * math.max(1, par.AbsoluteSize.Y) or par:GetAttribute("KitSwept")) then
                o.BackgroundColor3 = C.Text; o.BackgroundTransparency = 0.84; o.Position = UDim2.new(0, 0, 1, -1); o.Size = UDim2.new(1, 0, 0, 1)
            end
        end
    elseif o:IsA("TextButton") then
        Rehook(o, "BackgroundColor3")
        local hasText = o.Text ~= "" or o:FindFirstChildWhichIsA("TextLabel") ~= nil
        if hasText and o.BackgroundTransparency < 0.35 and Hue(o.BackgroundColor3, 0.45) and o.AbsoluteSize.X > 60 then
            o.BackgroundColor3 = C.Accent
            if o.Text ~= "" then o.TextColor3 = C.OnAccent end
            for _, l in ipairs(o:GetDescendants()) do if l:IsA("TextLabel") then l.TextColor3 = C.OnAccent end end
            for _, st in ipairs(o:GetChildren()) do if st:IsA("UIStroke") then st.Transparency = 1 end end
        elseif hasText and o.BackgroundTransparency < 0.35 and (function() local _, sa, v = o.BackgroundColor3:ToHSV(); return sa > 0.4 and v > 0.2 end)() then
            -- (a dark hue-tinted slab = a "picked" state: the raised slate + Text words instead of the tint)
            o.BackgroundColor3 = C.Bg2
            if o.Text ~= "" then o.TextColor3 = C.Text end
        elseif o.Text ~= "" and IsDisplay(o) and Hue(o.TextColor3) and o.BackgroundTransparency > 0.5 then
            o.TextColor3 = C.Text
        end
    elseif o:IsA("TextLabel") then
        Rehook(o, "TextColor3", "FontFace") -- (the type install sets the display face AFTER the build: a head turns "display" late)
        local par = o.Parent
        local onFilled = par and par:IsA("GuiObject") and par.BackgroundTransparency < 0.35 and Hue(par.BackgroundColor3, 0.45)
        if not onFilled and IsDisplay(o) and Hue(o.TextColor3) and not o.RichText then o.TextColor3 = C.Text end
    end
end
function MenuKit.Sweep(root: Instance?)
    if not root or root:GetAttribute("KitSwept") then return end
    root:SetAttribute("KitSwept", true)
    local function All() for _, d in ipairs(root:GetDescendants()) do pcall(SweepOne, d) end end
    All()
    -- (0.1 s later, not deferred: some builders parent first and set the font / colour after a yield)
    root.DescendantAdded:Connect(function(d) task.delay(0.1, function() if d.Parent then pcall(SweepOne, d) end end) end)
    -- (a window that repaints colours on open: once more each time it opens)
    if root:IsA("GuiObject") then root:GetPropertyChangedSignal("Visible"):Connect(function() if (root :: GuiObject).Visible then task.delay(0.2, All) end end) end
end

return MenuKit
