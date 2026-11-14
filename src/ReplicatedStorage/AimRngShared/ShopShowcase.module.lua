--!nocheck
-- ============================================================================================
-- SHOP SHOWCASE (Update 6, owner: "Every cosmetic should have a full preview video that can be played in the shop. Just a
-- short 3 second video or so, except for the bundles that can be tried" -> agreed: a LOOPING ANIMATED 3D PREVIEW).
-- The store's DETAIL panel (CosmeticsMenu ShowPreview) plays a ~3.4 s loop per category instead of a still turntable:
--   gun skins  = the skinned gun turning, a short fire burst (muzzle flash + tracer in the skin's colour, a recoil kick),
--                then an inspect beat (a full roll along its length)
--   melee      = a swing (a quick arc) + an inspect beat (turned over along its blade)
--   arms       = the gloved hand + sleeve holding a plain gun, the glove's own Fire / Kill / Inspect effects firing
--   kill fx    = a training dummy that pops in the set's colour + the set's REAL kill banner counting its streak up
--   UI themes  = the theme's mini window replaying its open (a pop + a flash in the theme's open colour)
--   health bar = CosmeticsMenu's BarDemo (already a loop of hits) + a target name
-- Cheap by design: ONE live showcase (the detail panel; cards keep their small previews), only while the window is
-- visible (CosmeticsMenu's RenderStepped returns while it's hidden), a handful of parts, no lights, no particles.
-- ViewportFrames draw parts only (no particles / beams / billboards), so a set's world kill effect can't play in here:
-- TRY IN FIRST PERSON (K) shows the real one.
-- ============================================================================================
local ShopShowcase = {}
local Shared = script.Parent
local CosmeticPreview = require(Shared:WaitForChild("CosmeticPreview"))

ShopShowcase.LOOP = 3.4 -- seconds per loop
local V = Vector3.new

local function Ease(x: number): number
    x = math.clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

-- a Neon flash part inside the viewport model (hidden until used)
local function FxPart(parent: Instance, color: Color3, ball: boolean?): BasePart
    local p = Instance.new("Part")
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Shape = ball and Enum.PartType.Ball or Enum.PartType.Block
    p.Size = V(0.1, 0.1, 0.1)
    p.Transparency = 1
    p:SetAttribute("SkinDeco", true) -- (NeonTamer leaves cosmetic glow alone)
    p.Parent = parent
    return p
end

-- the colour a skin's shots / glow read in
local function SkinColor(skin: any): Color3
    if type(skin) ~= "table" then return Color3.fromRGB(255, 220, 150) end
    if typeof(skin.TracerColor) == "Color3" then return skin.TracerColor end
    if typeof(skin.Color) == "Color3" then return skin.Color end
    local ok, SkinFX = pcall(require, Shared:WaitForChild("SkinFX"))
    local set = ok and skin.FX and SkinFX.Sets[skin.FX]
    if set and set.Colors and typeof(set.Colors.Glow) == "Color3" then return set.Colors.Glow end
    return Color3.fromRGB(255, 220, 150)
end

-- ===== GUN: turn + fire burst + inspect roll =====
function ShopShowcase.Gun(pv: GuiObject, e: any): any
    local model = CosmeticPreview.Gun(e.Gun, e.Src)
    if not model then return nil end
    local frame = model:FindFirstChild("Frame", true)
    local vp = CosmeticPreview.Viewport(pv, model, nil, { Drag = true, Spin = "full", Fit = 0.78, BaseYaw = 0.32, Sway = 0.3 })
    local pivot0 = model:GetPivot()
    -- the muzzle: the Frame's +X end (gun space +X = muzzle), at the base gun's muzzle height
    local muzzleLocal = V(0, 0, 0)
    if frame then
        local okW, WR = pcall(require, Shared:WaitForChild("WeaponRigs"))
        local def = okW and WR.Guns and WR.Guns[e.Gun]
        local my = 0
        local wa = Shared:FindFirstChild("WeaponAssets")
        local base = wa and wa:FindFirstChild(e.Gun)
        local bf = base and base:FindFirstChild("Frame")
        if def and def.Points and def.Points.Muzzle and bf and bf:IsA("BasePart") and bf.Size.X > 0 then
            my = def.Points.Muzzle.Position.Y * (frame.Size.X / bf.Size.X)
        end
        muzzleLocal = pivot0:PointToObjectSpace(frame.CFrame:PointToWorldSpace(V(frame.Size.X / 2, my, 0)))
    end
    local col = SkinColor(e.Src)
    local flash = FxPart(model, col:Lerp(Color3.new(1, 1, 1), 0.2), true)
    local tracer = FxPart(model, col)
    local t0 = os.clock()
    local self = { Viewport = vp }
    function self.Step(now: number)
        local t = (now - t0) % ShopShowcase.LOOP
        local cf = pivot0
        local shotK = -1
        -- FIRE BURST 1.0 .. 1.6 s: 5 shots, a small recoil kick each
        if t >= 1.0 and t < 1.6 then
            local i = math.floor((t - 1.0) / 0.12)
            shotK = (t - 1.0) - i * 0.12
            local kick = math.exp(-shotK * 30)
            cf = cf * CFrame.new(-0.06 * kick, 0, 0) * CFrame.Angles(0, 0, math.rad(3 * kick))
        end
        -- INSPECT 2.0 .. 3.1 s: a full roll along the gun's length
        if t >= 2.0 and t < 3.1 then
            cf = cf * CFrame.Angles(Ease((t - 2.0) / 1.1) * math.pi * 2, 0, 0)
        end
        model:PivotTo(cf)
        local mz = cf:PointToWorldSpace(muzzleLocal)
        local fwd = cf.XVector
        if shotK >= 0 and shotK < 0.05 then
            flash.Size = V(0.17, 0.17, 0.17)
            flash.CFrame = CFrame.new(mz + fwd * 0.12)
            flash.Transparency = 0.1
        else
            flash.Transparency = 1
        end
        if shotK >= 0 and shotK < 0.08 then
            local len = 7
            tracer.Size = V(len, 0.035, 0.035)
            tracer.CFrame = CFrame.lookAt(mz + fwd * (0.3 + len / 2), mz + fwd * 10) * CFrame.Angles(0, math.rad(90), 0)
            tracer.Transparency = 0.2 + shotK / 0.08 * 0.8
        else
            tracer.Transparency = 1
        end
        vp.Step(now)
    end
    return self
end

-- ===== MELEE: a swing + an inspect turn =====
function ShopShowcase.Melee(pv: GuiObject, e: any, st: any): any
    local model = CosmeticPreview.Melee(st and st.EquippedKnife or "Knife", e.Id)
    if not model then return nil end
    local vp = CosmeticPreview.Viewport(pv, model, nil, { Drag = true, Spin = "full", Fit = 0.7, BaseYaw = 0.32, Sway = 0.25 })
    local pivot0 = model:GetPivot()
    local bcf, bsize = model:GetBoundingBox()
    -- the long axis of the weapon (blade / haft) and its centre
    local axis = (bsize.X >= bsize.Y and bsize.X >= bsize.Z) and bcf.XVector or ((bsize.Y >= bsize.Z) and bcf.YVector or bcf.ZVector)
    local centre = bcf.Position
    local function About(cf: CFrame, ax: Vector3, ang: number): CFrame
        return CFrame.new(centre) * CFrame.fromAxisAngle(ax, ang) * CFrame.new(-centre) * cf
    end
    local t0 = os.clock()
    local self = { Viewport = vp }
    function self.Step(now: number)
        local t = (now - t0) % ShopShowcase.LOOP
        local cf = pivot0
        -- SWING 0.7 .. 1.3 s: drawn back, a fast cut through, a settle
        if t >= 0.7 and t < 1.3 then
            local k = (t - 0.7) / 0.6
            local a = (k < 0.25) and (-0.5 * Ease(k / 0.25)) or (k < 0.55 and (-0.5 + 1.6 * Ease((k - 0.25) / 0.3)) or (1.1 * (1 - Ease((k - 0.55) / 0.45))))
            cf = About(cf, Vector3.yAxis, a)
        end
        -- INSPECT 1.7 .. 3.0 s: turned over along its length, held, back
        if t >= 1.7 and t < 3.0 then
            cf = About(cf, axis, Ease((t - 1.7) / 1.3) * math.pi * 2)
        end
        model:PivotTo(cf)
        vp.Step(now)
    end
    return self
end

-- ===== ARMS: the gloved hand + sleeve holding a plain gun, the glove's own effects firing =====
function ShopShowcase.Arms(pv: GuiObject, e: any): any
    local model = CosmeticPreview.Arms(e.Src and e.Src.Glove, e.Src and e.Src.Sleeve)
    if not model then return nil end
    local hand = model.PrimaryPart
    local gun = CosmeticPreview.Gun("MP5", nil)
    if gun and hand then
        -- the gun sits on the fist like the first-person hold: across the hand, the muzzle away from the forearm
        local ext = gun:GetExtentsSize()
        gun:PivotTo(hand.CFrame * CFrame.new(0, hand.Size.Y * 0.5 + ext.Y * 0.32, -0.15) * CFrame.Angles(0, math.rad(90), 0))
        gun.Parent = model
    end
    local vp = CosmeticPreview.Viewport(pv, model, nil, { Drag = true, Fit = 0.8, BaseYaw = 0.9, Sway = 0.3 })
    local okG, GloveFX = pcall(require, Shared:WaitForChild("GloveFX"))
    local dressed = CosmeticPreview.Dressed and CosmeticPreview.Dressed[model] or {}
    local t0, lastBeat = os.clock(), -1
    local BEATS = { { 0.9, "Fire" }, { 1.05, "Fire" }, { 1.2, "Fire" }, { 2.0, "Kill" }, { 2.7, "Inspect" } }
    local self = { Viewport = vp }
    function self.Step(now: number)
        local t = (now - t0) % ShopShowcase.LOOP
        if okG then
            for i, b in ipairs(BEATS) do
                local loop = math.floor((now - t0) / ShopShowcase.LOOP)
                local key = loop * 10 + i
                if t >= b[1] and key > lastBeat then
                    lastBeat = key
                    for _, x in ipairs(dressed) do pcall(GloveFX.Event, x[1], b[2]) end
                end
            end
        end
        vp.Step(now)
    end
    return self
end

-- ===== KILL EFFECT: a dummy that pops in the set's colour + the set's real banner counting up =====
function ShopShowcase.Kill(pv: GuiObject, e: any, st: any?): any
    local okS, SkinFX = pcall(require, Shared:WaitForChild("SkinFX"))
    local fx = (okS and e.FX and st and SkinFX.KillFX) and SkinFX.KillFX(st, e.FX, "KillEffect:" .. tostring(e.Id)) or e.FX -- (your colourway)
    local set = okS and fx and SkinFX.Sets[fx]
    local col = (set and set.Colors and typeof(set.Colors.Glow) == "Color3") and set.Colors.Glow or Color3.fromRGB(255, 200, 90)
    -- the dummy: a capsule bot like the pill enemies (body + head) on a little plinth
    local m = Instance.new("Model")
    local function P(size, cf, color, mat, shape)
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
        p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.SmoothPlastic
        if shape then p.Shape = shape end
        p.Parent = m
        return p
    end
    local plinth = P(V(0.4, 3.2, 3.2), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(38, 40, 48), nil, Enum.PartType.Cylinder)
    local body = P(V(1.6, 2.6, 1.6), CFrame.new(0, 2.0, 0), Color3.fromRGB(150, 156, 170))
    local head = P(V(1.1, 1.1, 1.1), CFrame.new(0, 3.85, 0), Color3.fromRGB(190, 196, 210), nil, Enum.PartType.Ball)
    local ring = FxPart(m, col)
    m.PrimaryPart = plinth
    local vp = CosmeticPreview.Viewport(pv, m, { V(0, 2.4, 0), 13 }, { Drag = true })
    -- the banner: the set's own Banner drawn into this panel (its H.BannerRoot hands back our frame, not the HUD's)
    local holder = Instance.new("Frame")
    -- (2026-10-14, owner: the streak banner "completely block[s] the kill effect preview ... make them smaller and move
    -- them"): a small banner in the top-left corner under the rarity tag, clear of the dummy and its floor finish
    holder.Name = "ShowcaseBanner"; holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(0, 0)
    holder.Position = UDim2.new(0, 8, 0, 34); holder.Size = UDim2.fromOffset(130, 60); holder.ZIndex = 6; holder.Parent = pv
    local broot, H
    if set and set.Banner then
        H = setmetatable({}, { __index = SkinFX.H })
        H.BannerRoot = function(name, size)
            if not broot or not broot.Parent then
                broot = Instance.new("Frame")
                broot.Name = "Root"; broot.BackgroundTransparency = 1; broot.AnchorPoint = Vector2.new(0, 0)
                broot.Position = UDim2.fromScale(0, 0); broot.Parent = holder
                local s = Instance.new("UIScale"); s.Parent = broot
            end
            broot.Size = UDim2.fromOffset(size.X, size.Y)
            local sc = broot:FindFirstChildOfClass("UIScale")
            if sc then sc.Scale = math.min(0.55, 125 / math.max(1, size.X), 58 / math.max(1, size.Y)) end
            return holder, broot
        end
    end
    local body0, head0 = body.CFrame, head.CFrame
    local t0, streak, lastLoop = os.clock(), 0, -1
    local self = { Viewport = vp }
    function self.Step(now: number)
        local t = (now - t0) % ShopShowcase.LOOP
        local loop = math.floor((now - t0) / ShopShowcase.LOOP)
        -- the kill at 1.0 s: a flash in the set's colour, the dummy shrinks away, a ring opens; back at 2.6 s
        local dead = t >= 1.0 and t < 2.6
        local k = dead and math.clamp((t - 1.0) / 0.35, 0, 1) or 0
        local s = dead and (1 - Ease(k)) or 1
        body.Size = V(1.6, 2.6, 1.6) * math.max(0.02, s); body.CFrame = body0 * CFrame.new(0, -(1 - s) * 1.2, 0)
        head.Size = V(1.1, 1.1, 1.1) * math.max(0.02, s); head.CFrame = head0 * CFrame.new(0, -(1 - s) * 2.2, 0)
        local fl = dead and math.exp(-(t - 1.0) * 6) or 0
        body.Color = Color3.fromRGB(150, 156, 170):Lerp(col, fl)
        head.Color = Color3.fromRGB(190, 196, 210):Lerp(col, fl)
        body.Transparency = (s < 0.05) and 1 or 0
        head.Transparency = (s < 0.05) and 1 or 0
        if dead and t < 1.8 then
            local rk = (t - 1.0) / 0.8
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = V(0.06, 1 + rk * 5, 1 + rk * 5)
            ring.CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90))
            ring.Transparency = 0.25 + rk * 0.75
        else
            ring.Transparency = 1
        end
        -- the banner counts the streak up: one more pip each kill (1 .. 5, then again)
        if H and loop ~= lastLoop and t >= 1.05 then
            lastLoop = loop
            streak = streak % 5 + 1
            pcall(set.Banner, H, streak)
            if broot then broot.Visible = true end
            -- (the window's GUIs are Global-ZIndex: lift the banner's pieces over the 3D preview)
            for _, d in ipairs(holder:GetDescendants()) do
                if d:IsA("GuiObject") and not d:GetAttribute("ZUp") then d:SetAttribute("ZUp", true); d.ZIndex += 10 end
            end
        end
        vp.Step(now)
    end
    function self.Destroy() if broot then broot:Destroy() end end
    return self
end

-- ===== UI THEME: the mini window replaying its open =====
function ShopShowcase.Theme(pv: GuiObject, e: any): any
    local okT, UITheme = pcall(require, Shared:WaitForChild("UITheme"))
    if not okT then return nil end
    UITheme.Preview(pv, e.Src)
    local root = pv:FindFirstChild("UITPreview")
    if not root then return nil end
    local scale = Instance.new("UIScale"); scale.Parent = root
    local col = (e.Src and (e.Src.OpenColor or e.Src.Accent)) or Color3.new(1, 1, 1)
    local flashF = Instance.new("Frame")
    flashF.Name = "OpenFlash"; flashF.BackgroundColor3 = col; flashF.BackgroundTransparency = 1; flashF.BorderSizePixel = 0
    flashF.Size = UDim2.fromScale(1, 1); flashF.ZIndex = 9; flashF.Parent = root
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = flashF
    local t0 = os.clock()
    local self = {}
    -- (v3 FX audit) a theme with its own open motion (Set.Theme.OpenFn) replays THAT, not the shared colour wash
    local own = e.Src and type(e.Src.OpenFn) == "function"
    local lastLoop = -1
    function self.Step(now: number)
        local t = (now - t0) % ShopShowcase.LOOP
        local loop = math.floor((now - t0) / ShopShowcase.LOOP)
        if own and loop ~= lastLoop then lastLoop = loop; pcall(UITheme.PreviewOpen, root) end
        -- closes at 2.9 s, opens again at 0: a pop from 0.9 with the theme's open colour washing over it
        if not UITheme.OPEN_FX then -- (2026-10-15) theme open effects are off: the window just sits there
            scale.Scale = 1; flashF.BackgroundTransparency = 1; root.Visible = true
            return
        end
        local open = (t < 0.35) and Ease(t / 0.35) or ((t > 3.05) and (1 - Ease((t - 3.05) / 0.35)) or 1)
        scale.Scale = 0.88 + 0.12 * open
        flashF.BackgroundTransparency = own and 1 or (1 - 0.55 * math.exp(-t * 5))
        root.Visible = open > 0.02
    end
    return self
end

-- the showcase for an entry in the big detail panel, or nil (the caller falls back to its still preview)
function ShopShowcase.For(pv: GuiObject, e: any, st: any): any
    local catDef = e and e.Cat
    if catDef == "WeaponSkin" and e.Gun then return ShopShowcase.Gun(pv, e) end
    if catDef == "MeleeSkin" then return ShopShowcase.Melee(pv, e, st) end
    if catDef == "Arms" then return ShopShowcase.Arms(pv, e) end
    if catDef == "KillEffect" and e.FX then return ShopShowcase.Kill(pv, e, st) end
    if catDef == "HudTheme" and e.Src and e.Src.Panel then return ShopShowcase.Theme(pv, e) end
    return nil
end

return ShopShowcase
