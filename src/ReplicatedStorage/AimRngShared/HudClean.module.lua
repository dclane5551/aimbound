--!nocheck
-- ============================================================================================
-- HUD CLEAN (UI CLEAN pilot P2, 2026-10-28; owner: "the player healthbar and lives in the bottom looks incredibly cheesy";
-- contract docs/UI_CLEAN_2026-10-28.md "HUD"). The bottom HUD column is NUMBERS, NOT BOXES:
--   LV 12  ROOKIE ............................ 0 / 184 XP     small caps + a 2 px XP line
--   101 / 101 ........................ ■ ■ ■   PLATING 0       big display number, small "/ max", lives pips, plating
--   ─────────────────────────────────────────── (4 px HP bar; Ward = a 2 px cyan segment just above it)
--   ● G19 ........................................ 16 / 17      small caps name in its rarity colour, big ammo, small mag
-- No per-row cards, strokes, gradients, facets or colour blocks: ONE flat see-through slate plate (HudPlate, 0.45) sits
-- behind the whole column so the small caps read over bright floors (pink / snow rooms), + a faint text stroke. The weapon stat line, type / trait lines and the "[R] RELOAD | [V] MELEE" hint are off the HUD (the
-- inventory has them); the shift-lock note shows only for a moment when it changes (AimRngClient's SHIFT LOCK block).
-- Phones (UIStyle.IsPhone, incl. the Studio DevPhone preview): the column is centred at the bottom between Roblox's
-- thumbstick (bottom left) and the touch buttons (bottom right), its small text a size up; ToastStack.BOTTOM moves the
-- toasts above it. Premium UI themes still colour the bars (UITheme.SetBars) and the HUD texts keep their roles.
-- Everything here runs once (Init) or on a layout change (Layout: PhoneHUD's Apply -- resize / DevPhone): no per-frame work.
--   HudClean.Init({ UI = UI, Hud = hudGui })   HudClean.Layout(HS, phone) -> fills HS.X / W / heights for the column
--   HudClean.Pips(have, total) -> rich text "■ ■ ■" (filled = off-white, lost = dim) for your lives + PartyHud
-- ============================================================================================
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))

local HudClean = {}
local C = UIStyle.Colors
local ctx: any = nil
HudClean.PIP = "■"
HudClean.PIP_ON = C.Text
HudClean.PIP_OFF = Color3.fromRGB(78, 78, 80)

-- the column sizes (design px at Interface Scale 100%); phone = the compact centred column
-- (UI CLEAN P5 screen grid: the PLATE's outer edge sits on UIStyle.MARGIN from the screen edge, the text PLATE_PAD inside it --
-- the same as the goal tracker under the MENU button: X / Bottom = MARGIN + PLATE_PAD)
HudClean.PLATE_PAD = 10
HudClean.FULL = { X = UIStyle.MARGIN + 10, W = 400, Gap = 12, Bottom = UIStyle.MARGIN + 10, WeaponH = 50, HealthH = 46, LevelH = 22 }
HudClean.PHONE = { X = 0, W = 300, Gap = 8, Bottom = UIStyle.MARGIN + 10, WeaponH = 46, HealthH = 44, LevelH = 22 }
local TYPE = {
    Full = { Big = 44, Ammo = 44, Mag = 20, Name = 17, Small = 15, Lives = 15 },
    Phone = { Big = 44, Ammo = 44, Mag = 21, Name = 19, Small = 17, Lives = 17 },
}

function HudClean.Pips(have: number, total: number): string
    have = math.max(0, math.floor(have))
    total = math.max(have, math.floor(total))
    local on = table.concat(table.create(have, HudClean.PIP), "  ")
    local off = table.concat(table.create(total - have, HudClean.PIP), "  ")
    local gap = (have > 0 and total - have > 0) and "  " or ""
    return string.format('<font color="#%s">%s</font>%s<font color="#%s">%s</font>', HudClean.PIP_ON:ToHex(), on, gap, HudClean.PIP_OFF:ToHex(), off)
end

local function Strip(f: GuiObject?)
    -- the old chrome: strokes, gradients, corners and the left colour block go; the frame itself becomes a clear holder
    if not f then return end
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    for _, c in ipairs(f:GetChildren()) do
        if c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UICorner") then c:Destroy()
        elseif c:IsA("Frame") and c.Name == "Block" then c.Visible = false end
    end
    f:SetAttribute("NoSkin", true)
end
local function Txt(l: TextLabel?, role: string?, col: Color3?)
    if not l then return end
    l.BackgroundTransparency = 1
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextStrokeTransparency = 0.72 -- (a faint stroke: readable over bright floors without the old outlined look)
    if role then l:SetAttribute("TypeRole", role) end
    if col then l.TextColor3 = col end
    for _, c in ipairs(l:GetChildren()) do if c:IsA("UIGradient") or c:IsA("UIStroke") then c:Destroy() end end
end
local function Bar(track: Frame?, fill: Frame?)
    if not track then return end
    track.BackgroundColor3 = C.Well
    track.BackgroundTransparency = 0.3
    track.BorderSizePixel = 0
    for _, c in ipairs(track:GetChildren()) do if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") then c:Destroy() end end
    if fill then
        for _, c in ipairs(fill:GetChildren()) do
            if c:IsA("UICorner") or c:IsA("UIGradient") or (c:IsA("Frame") and c.Name == "Facet") then c:Destroy() end
        end
    end
end
-- keep a label hidden (code that shows it again -- the trait line, the phone layout -- is undone)
local function KeepHidden(l: GuiObject?)
    if not l then return end
    l.Visible = false
    if l:GetAttribute("CleanHidden") then return end
    l:SetAttribute("CleanHidden", true)
    l:GetPropertyChangedSignal("Visible"):Connect(function() if l.Visible then l.Visible = false end end)
end

function HudClean.Init(c: any)
    ctx = c
    local UI = c.UI
    -- LEVEL: "LV 12" + the title + the XP readout, a 2 px XP line under them
    Strip(UI.levelFrame)
    if UI.lvlBadgeGrad then UI.lvlBadgeGrad:Destroy(); UI.lvlBadgeGrad = nil end
    Txt(UI.lvlBadge, "Label", C.Text)
    if UI.lvlBadge then
        UI.lvlBadge.TextScaled = false
        UI.lvlBadge.TextXAlignment = Enum.TextXAlignment.Left
        local cap = UI.lvlBadge:FindFirstChildOfClass("UITextSizeConstraint")
        if cap then cap:Destroy() end
    end
    Txt(UI.titleHeaderLbl, "Label")
    Txt(UI.lvlLabel, "Accent", C.Sub)
    local xpTrack = UI.xpFill and UI.xpFill.Parent
    Bar(xpTrack, UI.xpFill)
    -- HEALTH: the big number, "/ max" small (AimRngClient's HP text), a thin bar, plating small on the right
    Strip(UI.healthFrame)
    if UI.hpStroke then UI.hpStroke:Destroy(); UI.hpStroke = nil end
    local hpTrack = UI.hpFill and UI.hpFill.Parent
    Bar(hpTrack, UI.hpFill)
    if UI.hpChip then UI.hpChip.BackgroundColor3 = Color3.fromRGB(232, 92, 92) end -- (the chunk a hit took: a red sliver that drains)
    Txt(UI.hpLabel, "Header", C.Text)
    if UI.hpLabel then UI.hpLabel.TextYAlignment = Enum.TextYAlignment.Bottom end
    Txt(UI.hpArmor, "Label", C.Sub)
    -- WEAPON: small caps name in its rarity colour, big ammo + small mag, a 2 px ammo line; the rest is off the HUD
    Strip(UI.weaponCard)
    UI.weaponBlock = nil
    Txt(UI.weaponNameLbl, "Label")
    KeepHidden(UI.weaponTypeLbl); KeepHidden(UI.weaponStatsLbl); KeepHidden(UI.weaponTraitLbl); KeepHidden(UI.ammoHintLbl)
    Txt(UI.ammoCounterLbl, "Header")
    if UI.ammoCounterLbl then UI.ammoCounterLbl.TextYAlignment = Enum.TextYAlignment.Bottom end
    Txt(UI.ammoMagLbl, "Accent", C.Sub)
    if UI.ammoMagLbl then
        UI.ammoMagLbl.TextXAlignment = Enum.TextXAlignment.Left
        UI.ammoMagLbl.TextYAlignment = Enum.TextYAlignment.Bottom
        UI.ammoMagLbl.TextTruncate = Enum.TextTruncate.AtEnd
    end
    KeepHidden(UI.ammoBarFill and UI.ammoBarFill.Parent) -- (the number is the ammo readout; a second white line was noise)
    -- the one plate behind the column (follows the health row's visibility: spectating / trials hide the HUD)
    local plate = Instance.new("Frame")
    plate.Name = "HudPlate"
    plate.BackgroundColor3 = C.Bg0
    plate.BackgroundTransparency = 0.45
    plate.BorderSizePixel = 0
    plate.AnchorPoint = Vector2.new(0, 1)
    plate.ZIndex = 0 -- (under every HUD sibling: the weapon card sits at 1)
    plate.Active = false
    plate:SetAttribute("NoSkin", true)
    plate:SetAttribute("Skinned", true)
    plate.Parent = c.Hud
    c.Plate = plate
    local function Vis() plate.Visible = UI.healthFrame.Visible and UI.weaponCard.Visible end
    UI.healthFrame:GetPropertyChangedSignal("Visible"):Connect(Vis)
    UI.weaponCard:GetPropertyChangedSignal("Visible"):Connect(Vis)
    Vis()
end

-- Fill HS (UI.HudStack) for this screen and place every piece inside the three rows. Called by PhoneHUD's Apply.
function HudClean.Layout(HS: any, phone: boolean)
    if not ctx then return end
    local UI, hud = ctx.UI, ctx.Hud
    local L = phone and HudClean.PHONE or HudClean.FULL
    for k, v in pairs(L) do HS[k] = v end
    if phone then
        -- centred between the thumbstick and the touch buttons (in the HUD gui's own units)
        local sc = hud:FindFirstChildOfClass("UIScale")
        local k = (sc and sc.Scale or 1)
        local cam = workspace.CurrentCamera
        local vx = cam and cam.ViewportSize.X or 1280
        HS.X = math.max(8, math.floor((vx / math.max(k, 0.05) - HS.W) / 2))
    end
    HS.HealthY = -(HS.Bottom + HS.WeaponH + HS.Gap)
    HS.LevelY = HS.HealthY - HS.HealthH - HS.Gap
    HS.TopY = HS.LevelY - HS.LevelH - HS.Gap
    local T = phone and TYPE.Phone or TYPE.Full
    if ctx.Plate then
        local PAD = HudClean.PLATE_PAD
        ctx.Plate.Position = UDim2.new(0, HS.X - PAD, 1, -(HS.Bottom - PAD))
        ctx.Plate.Size = UDim2.new(0, HS.W + PAD * 2, 0, HS.LevelH + HS.HealthH + HS.WeaponH + HS.Gap * 2 + PAD * 2)
    end
    -- level row
    if UI.lvlBadge then
        UI.lvlBadge.TextSize = T.Small + 2
        UI.lvlBadge.Size = UDim2.new(0, 60, 0, HS.LevelH - 4)
        UI.lvlBadge.Position = UDim2.new(0, 0, 0, 0)
    end
    if UI.titleHeaderLbl then
        UI.titleHeaderLbl.TextSize = T.Small
        UI.titleHeaderLbl.Position = UDim2.new(0, phone and 66 or 56, 0, 0)
        UI.titleHeaderLbl.Size = UDim2.new(0.55, -60, 0, HS.LevelH - 4)
    end
    if UI.lvlLabel then
        UI.lvlLabel.TextSize = T.Small - 1
        UI.lvlLabel.AnchorPoint = Vector2.new(1, 0)
        UI.lvlLabel.Position = UDim2.new(1, 0, 0, 0)
        UI.lvlLabel.Size = UDim2.new(0.45, 0, 0, HS.LevelH - 4)
    end
    local xpTrack = UI.xpFill and UI.xpFill.Parent
    if xpTrack then xpTrack.Position = UDim2.new(0, 0, 1, -2); xpTrack.Size = UDim2.new(1, 0, 0, 2) end
    -- health row
    local hpTrack = UI.hpFill and UI.hpFill.Parent
    if hpTrack then hpTrack.Position = UDim2.new(0, 0, 1, -4); hpTrack.Size = UDim2.new(1, 0, 0, 4) end
    local ward = hpTrack and hpTrack:FindFirstChild("WardFill")
    if ward then ward.Parent = UI.healthFrame end
    ward = UI.healthFrame:FindFirstChild("WardFill")
    if ward then
        ward.Position = UDim2.new(0, 0, 1, -8)
        ward.Size = UDim2.new(ward.Size.X.Scale, 0, 0, 2)
    end
    if UI.hpLabel then
        UI.hpLabel.TextSize = T.Big
        UI.hpLabel.Position = UDim2.new(0, -1, 0, 0)
        UI.hpLabel.Size = UDim2.new(1, -150, 1, -9)
    end
    if UI.hpArmor then
        UI.hpArmor.TextSize = T.Small - 1
        UI.hpArmor.AnchorPoint = Vector2.new(1, 0)
        UI.hpArmor.Position = UDim2.new(1, 0, 1, -28)
        UI.hpArmor.Size = UDim2.new(0, 220, 0, 18)
    end
    -- weapon row
    if UI.weaponNameLbl then
        UI.weaponNameLbl.TextSize = T.Name
        UI.weaponNameLbl.Position = UDim2.new(0, 0, 1, -8 - (T.Name + 6))
        UI.weaponNameLbl.Size = UDim2.new(1, -170, 0, T.Name + 6)
    end
    if UI.ammoContainer then
        UI.ammoContainer.AnchorPoint = Vector2.new(1, 0)
        UI.ammoContainer.Position = UDim2.new(1, 0, 0, 0)
        UI.ammoContainer.Size = UDim2.new(0, 190, 1, -6)
    end
    if UI.ammoCounterLbl then
        UI.ammoCounterLbl.Position = UDim2.new(0, 0, 0, 0)
        UI.ammoCounterLbl.Size = UDim2.new(1, -62, 1, 0)
        local cap = UI.ammoCounterLbl:FindFirstChildOfClass("UITextSizeConstraint")
        if cap then cap.MaxTextSize = T.Ammo; cap.MinTextSize = 14 end
    end
    if UI.ammoMagLbl then
        UI.ammoMagLbl.TextSize = T.Mag
        UI.ammoMagLbl.Position = UDim2.new(1, -58, 0, 0)
        UI.ammoMagLbl.Size = UDim2.new(0, 58, 1, -4)
    end
    local ammoTrack = UI.ammoBarFill and UI.ammoBarFill.Parent
    if ammoTrack then
        ammoTrack.AnchorPoint = Vector2.new(0, 1)
        ammoTrack.Position = UDim2.new(0, 0, 1, 0)
        ammoTrack.Size = UDim2.new(1, 0, 0, 2)
    end
    -- the lives pips: top-right of the health row
    local lives = hud:FindFirstChild("LivesHearts")
    if lives then
        lives.TextSize = T.Lives
        lives.Size = UDim2.fromOffset(160, T.Lives + 6)
    end
    -- toasts sit above the column on a phone (it is centred there)
    local okT, TS = pcall(function() return require(script.Parent:WaitForChild("ToastStack", 2)) end)
    if okT and TS and TS.SetBottom then TS.SetBottom(phone and (HS.TopY - 52) or -128) end
    return T
end
-- where the lives pips go (PhoneHUD's rows table): the top-right corner of the health row
function HudClean.LivesPos(HS: any): UDim2
    return UDim2.new(0, HS.X + HS.W, 1, HS.HealthY - HS.HealthH + (ctx and ctx.LivesH or 22))
end

return HudClean
