--!nocheck
-- TRY IT ON (client): inspect a cosmetic before you buy it (owner, 2026-10-02: "make sure everything can be inspected
-- in both third and first person where it would apply"). Opened from the store's detail panel.
--   "FP"  -- first person: the gun skin / melee skin / gloves / sleeves / UI theme (or a whole bundle) is put on YOU,
--            locally, in your own view: fire, inspect [T], reload [R], take out the melee [Q], and shoot the target
--            dummy (or press [K]) to see the kill effect + banner. Nothing is saved or sent to the server.
--   "TP"  -- third person: a slow showcase orbit around your character wearing the armor / bundle / gloves / gun skin
--            (drag to turn). Again only on your screen.
-- [X] or the EXIT button ends it and reopens the store on the item.
-- (Update 6 TRY RANGE, owner: "Trialing bundles should bring you to its own more lit area, as the hub doesn't properly
-- showcase them") "FP" takes you to your own evenly lit studio range (AimRngShared/TryRange: three target stands, the
-- Showcase light profile) and brings you back to where you stood when it ends; without a Teleport hook it stays in place.
-- hooks (from AimRngClient): { State(), Rebuild(weapon), Rig(), CloseMenus(), Reopen(entry), Toast(text),
--   ApplyTheme(theme), RefreshTheme(), SelectSlot(slot), Teleport(cframe) }
local TryOn = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Shared = script.Parent
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local SkinFX = require(Shared:WaitForChild("SkinFX"))
local GloveFX = require(Shared:WaitForChild("GloveFX"))
local HudThemes = require(Shared:WaitForChild("HudThemes"))
local ArmorFX = require(Shared:WaitForChild("ArmorFX"))
local MeleeData = require(Shared:WaitForChild("MeleeData"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local function Clone(t) local o = {}; for k, v in pairs(type(t) == "table" and t or {}) do o[k] = v end; return o end
local Zones = require(Shared:WaitForChild("Zones"))
local TryRange = require(Shared:WaitForChild("TryRange"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local LocalPlayer = Players.LocalPlayer
local active = nil -- the running session

-- (owner 2026-10-07: "the guns being trialed should actually shoot the gun that the skin is for, not your currently
-- equipped gun") the preview gun is a real instance of the skin's gun -- its own class, fire rate, pellets, magazine --
-- at your gun's rarity + level, with no procs / trait (it only ever hits the try-on dummy)
local function PreviewGun(baseId: string, real: any): any
    local w = ItemData.GenerateWeaponOfBase and ItemData.GenerateWeaponOfBase(baseId, (real and real.Rarity) or "Rare", (real and real.ItemLevel) or 1)
    if type(w) ~= "table" then
        w = Clone(real)
        w.BaseId = baseId
    end
    w.Uid = "__tryon"
    w.Procs, w.Proc, w.UniqueTrait, w.Trait, w.Exotic = nil, nil, nil, nil, nil
    return w
end
-- previews only in the hub city (not the Training Grounds, the Bazaar, a hideout or a run)
local function InHub(): boolean
    if LocalPlayer:GetAttribute("RunId") then return false end
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    return root ~= nil and Zones.Kind(root.Position) == "city"
end
-- still where a try-on may run: the hub city or your own try range
local function InTryArea(): boolean
    if InHub() then return true end
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    return root ~= nil and not LocalPlayer:GetAttribute("RunId") and Zones.Kind(root.Position) == "showcase"
end

local function Split(ref) return ref:match("^(.-):(.*)$") end

-- what an entry puts on (a bundle = all of its contents)
local function Contents(e)
    if e.Cat ~= "Bundle" then return { e } end
    local out = {}
    for _, ref in ipairs(e.Contents or {}) do
        local cat, id = Split(ref)
        local ce = Cosmetics.Find(cat, id)
        if ce then table.insert(out, ce) end
    end
    return out
end

-- the local override: apply the entry's items onto a copy of the state -> (new CosmeticsEquipped, new MeleeSkinFor,
-- preview gun BaseId or nil, theme or nil, armor defs, glove def or nil)
local function Override(st, items)
    local ce, msf = Clone(st.CosmeticsEquipped), Clone(st.MeleeSkinFor)
    local gun, theme, armor, glove, skinFx = nil, nil, {}, nil, nil
    local guns = {} -- every gun skin in it: { Gun, Skin } (a bundle can hold several -- [N] cycles them)
    for _, it in ipairs(items) do
        if it.Cat == "WeaponSkin" then
            ce[SkinFX.EquipKey(it.Gun)] = it.Id
            gun = gun or it.Gun
            skinFx = skinFx or SkinFX.GunSkinById[it.Id]
            table.insert(guns, { Gun = it.Gun, Skin = SkinFX.GunSkinById[it.Id] })
        elseif it.Cat == "Glove" then ce.Glove = it.Id; glove = GloveFX.GloveById[it.Id]
        elseif it.Cat == "Sleeve" then ce.Sleeve = it.Id
        elseif it.Cat == "Arms" then -- (0.97 ARMS: glove + sleeve as one piece)
            ce.Glove, ce.Sleeve, ce.Arms = it.Glove, it.Sleeve, it.Id
            glove = GloveFX.GloveById[it.Glove or ""]
        elseif it.Cat == "HudTheme" then theme = HudThemes.ById[it.Id]
        elseif it.Cat == "KillEffect" then -- (FX audit 2026-10-14: trying on a kill effect alone played nothing -- no skin carried its FX)
            ce.KillEffect = it.Id
            if it.FX then skinFx = skinFx or { FX = SkinFX.KillFX(st, it.FX, "KillEffect:" .. it.Id) } end
        elseif it.Cat == "MeleeSkin" then
            for id in pairs(MeleeData.Rigs or {}) do msf[id] = it.Id end
            for id in pairs(require(Shared:WaitForChild("ItemData")).MeleeWeapons or {}) do msf[id] = it.Id end
        elseif it.Cat == "Armor" then
            local d = ArmorFX.PieceById[it.Id]
            if d then table.insert(armor, d) end
        end
    end
    return ce, msf, gun, theme, armor, glove, skinFx, guns
end

-- ===== the overlay =====
local function Overlay(e, how, onExit)
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "TryOnOverlay"; gui.ResetOnSpawn = false; gui.DisplayOrder = 20; gui.IgnoreGuiInset = true
    gui.Parent = pg
    local rc = Cosmetics.RarityColor[e.Rarity] or Color3.new(1, 1, 1)
    local bar = UIStyle.New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(640, 92),
        BackgroundColor3 = Color3.fromRGB(14, 16, 26), BackgroundTransparency = 0.12, Parent = gui }, { UIStyle.Corner(14) })
    UIStyle.New("UIStroke", { Color = rc, Thickness = 2.5, Parent = bar })
    local fit = UIStyle.New("UIScale", { Parent = bar })
    local cam = workspace.CurrentCamera
    if cam then fit.Scale = math.min(1, (cam.ViewportSize.X - 20) / 660) end
    UIStyle.Text({ Text = (how == "FP" and "TRYING ON" or "VIEWING") .. "  •  " .. string.upper(e.Rarity), TextSize = 12, TextColor3 = rc, Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -220, 0, 16), Parent = bar })
    UIStyle.Text({ Text = e.Name, TextSize = 24, Stroke = 2, Position = UDim2.fromOffset(18, 24), Size = UDim2.new(1, -220, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd, Parent = bar })
    local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local multi = active and active.Guns and #active.Guns > 1
    local hint = (how == "FP") and (touch and "Shoot the target  •  INSPECT / KILL buttons" or ("Shoot the target  •  [T] inspect  •  [R] reload  •  [Q] melee  •  [K] kill effect" .. (multi and "  •  [N] next gun" or "") .. "  •  [X] exit"))
        or (touch and "Drag to turn" or "Drag to turn  •  [X] exit")
    UIStyle.Text({ Font = UIStyle.BodyFont, Text = hint, TextSize = 12, TextColor3 = Color3.fromRGB(190, 200, 225), Position = UDim2.fromOffset(18, 60), Size = UDim2.new(1, -220, 0, 22), Parent = bar })
    local exit = UIStyle.Button(bar, "EXIT", Color3.fromRGB(230, 70, 80), UDim2.fromOffset(90, 40), UDim2.new(1, -104, 0.5, -20), "Exit")
    exit.Button.MouseButton1Click:Connect(onExit)
    local st = active and active.Hooks.State() or {}
    if not Cosmetics.Owns(st, e) and e.Unlock == "Robux" and e.Price then
        -- (2026-10-14: the store sells for BOUND points since 0.97 -- this still said "R$ <old Robux price>")
        local buy = UIStyle.Button(bar, tostring(Cosmetics.BPPrice(e) or e.Price) .. " BP", Color3.fromRGB(255, 190, 50), UDim2.fromOffset(96, 40), UDim2.new(1, -208, 0.5, -20), "Buy")
        buy.Button.MouseButton1Click:Connect(function() -- (2026-10-20: the BOUND popup first: price, balance, how many more)
            require(script.Parent:WaitForChild("BoundShop")).Confirm({ Name = e.Name, Price = Cosmetics.BPPrice(e) or 0, OnBuy = function()
                local ok, msg = Remotes.GetFunction("CosmeticAction"):InvokeServer("Buy", e.Cat, e.Id)
                if ok then
                    if active and active.Hooks.Toast then active.Hooks.Toast("★ " .. e.Name .. " is yours!") end
                    buy.Button.Visible = false
                end
                return ok, msg
            end })
        end)
    end
    -- touch: buttons for the keys
    if how == "FP" and touch then
        local row = UIStyle.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -170), Size = UDim2.fromOffset(390, 52), Parent = gui },
            { UIStyle.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
        local ins = UIStyle.Button(row, "INSPECT", Color3.fromRGB(110, 120, 255), UDim2.fromOffset(120, 48))
        local kill = UIStyle.Button(row, "KILL FX", Color3.fromRGB(255, 190, 50), UDim2.fromOffset(120, 48))
        ins.Button.MouseButton1Click:Connect(function() local r = active and active.Hooks.Rig(); if r then r:Play("Inspect") end end)
        if multi then
            local nx = UIStyle.Button(row, "NEXT GUN", Color3.fromRGB(70, 190, 170), UDim2.fromOffset(120, 48))
            nx.Button.MouseButton1Click:Connect(function() if active and active.NextGun then active.NextGun() end end)
        end
        kill.Button.MouseButton1Click:Connect(function() if active and active.Kill then active.Kill() end end)
    end
    -- (a UI theme being tried on must not restyle the try-on controls themselves -- a display font made EXIT unreadable)
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then d:SetAttribute("KeepFont", true) end
    end
    return gui
end

-- ===== the target dummy (first person) =====
local function Dummy(onKill, at: CFrame?)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local m = Instance.new("Model")
    m.Name = "TryOnDummy"
    local face
    if at then
        face = at -- (the try range's stand: on its floor, facing where you start)
    else
        local look = root.CFrame.LookVector
        local base = root.Position + Vector3.new(look.X, 0, look.Z).Unit * 13 - Vector3.new(0, 1.5, 0)
        local ray = workspace:Raycast(base + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0))
        if ray then base = ray.Position end
        face = CFrame.lookAt(base, Vector3.new(root.Position.X, base.Y, root.Position.Z))
    end
    local parts = {}
    local function P(name, size, cf, color, mat)
        local p = Instance.new("Part")
        p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = true; p.CastShadow = false
        p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = m
        table.insert(parts, p)
        return p
    end
    P("Stand", Vector3.new(1.6, 0.3, 1.6), face * CFrame.new(0, 0.15, 0), Color3.fromRGB(40, 44, 54), Enum.Material.Metal)
    P("Pole", Vector3.new(0.25, 1.6, 0.25), face * CFrame.new(0, 1.1, 0), Color3.fromRGB(60, 64, 74), Enum.Material.Metal)
    local body = P("Body", Vector3.new(1.9, 2.2, 0.9), face * CFrame.new(0, 3.0, 0), Color3.fromRGB(70, 76, 92))
    local head = P("Head", Vector3.new(1.1, 1.1, 1.1), face * CFrame.new(0, 4.75, 0), Color3.fromRGB(86, 92, 110))
    P("Eye", Vector3.new(0.5, 0.5, 0.06), face * CFrame.new(0, 4.8, -0.58), Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
    local label = Instance.new("BillboardGui")
    label.Size = UDim2.fromOffset(160, 40); label.StudsOffset = Vector3.new(0, 1.2, 0); label.AlwaysOnTop = true; label.Adornee = head
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.TextScaled = true; t.FontFace = UIStyle.Type.Display
    t.TextColor3 = Color3.new(1, 1, 1); t.TextStrokeTransparency = 0.3; t.Text = "TARGET  ■■■■■"; t.Parent = label
    label.Parent = m
    m.Parent = workspace
    local d = { Model = m, Hp = 5, Parts = parts, Label = t, Body = body, Head = head, Dead = false }
    function d.Hit(inst)
        if d.Dead or not inst:IsDescendantOf(m) then return false end
        d.Hp -= (inst == head) and 2 or 1
        for _, p in ipairs({ body, head }) do
            local c = p.Color
            p.Color = Color3.new(1, 1, 1)
            TweenService:Create(p, TweenInfo.new(0.12), { Color = c }):Play()
        end
        t.Text = "TARGET  " .. string.rep("■", math.max(0, d.Hp)) .. string.rep("□", 5 - math.max(0, d.Hp))
        if d.Hp <= 0 then
            d.Dead = true
            onKill(head.Position)
            for _, p in ipairs(parts) do p.Transparency = 1 end
            label.Enabled = false
            task.delay(1.4 / ((SkinFX.DevSlow and SkinFX.DevSlow()) or 1), function() -- (FX audit: slow motion keeps the stand down)
                if not m.Parent then return end
                for _, p in ipairs(parts) do p.Transparency = 0 end
                label.Enabled = true
                d.Hp = 5; d.Dead = false; t.Text = "TARGET  ■■■■■"
            end)
        end
        return true
    end
    return d
end

-- ===== start / stop =====
function TryOn.Active() return active ~= nil end
-- (FX AUDIT 2026-10-14, Studio test hook: client DevAct "trykill:<i>") kill target stand i through its real hit path
function TryOn.DevKill(i: number?)
    local s = active
    if not s then return false end
    local d = (s.Dummies and s.Dummies[i or 2]) or (s.Dummies and s.Dummies[1]) or s.Dummy
    if not (d and d.Head) or d.Dead then return false end
    for _ = 1, 5 do if not d.Dead then d.Hit(d.Head) end end
    return true
end

function TryOn.Stop(noReopen: boolean?)
    local s = active
    if not s then return end
    if noReopen then s.NoReopen = true end
    active = nil
    for _, c in ipairs(s.Conns) do c:Disconnect() end
    if s.Gui then s.Gui:Destroy() end
    if s.Dummy then s.Dummy.Model:Destroy() end
    for _, d in ipairs(s.Dummies or {}) do d.Model:Destroy() end
    if s.Range then TryRange.Leave(s.Range, s.Hooks.Teleport or function() end) end -- (back to where you stood)
    if s.LocalModels then for _, m in ipairs(s.LocalModels) do m:Destroy() end end
    for inst, props in pairs(s.Restore or {}) do
        if inst.Parent then for k, v in pairs(props) do pcall(function() inst[k] = v end) end end
    end
    for _, sh in ipairs(s.Shells or {}) do
        local a = (s.ShellAttr or {})[sh] or {}
        sh:SetAttribute("LookKind", a.LookKind); sh:SetAttribute("LookId", a.LookId); sh:SetAttribute("Side", a.Side)
        pcall(GloveFX.ForgetShell, sh)
    end
    LocalPlayer:SetAttribute("TryOnFP", nil)
    LocalPlayer:SetAttribute("Showcase", nil)
    local h = s.Hooks
    local st = h.State()
    if s.Real and st then
        st.CosmeticsEquipped = s.Real.CE
        st.MeleeSkinFor = s.Real.MSF
        st.EquippedWeapon = s.Real.Weapon
        if s.Real.Mag then st.CurrentMag = s.Real.Mag end
    end
    if s.Kind == "FP" then
        if h.SelectSlot then pcall(h.SelectSlot, "Gun") end
        pcall(h.Rebuild, st and st.EquippedWeapon)
    end
    if h.RefreshTheme then pcall(h.RefreshTheme) end
    if h.Reopen and not s.NoReopen then task.delay(0.05, function() pcall(h.Reopen, s.Entry) end) end
end

-- the server synced a new state mid-preview: keep the real values, put the preview back on top
function TryOn.Reapply(newState)
    local s = active
    if not s or s.Kind ~= "FP" or type(newState) ~= "table" then return newState end
    s.Real = { CE = newState.CosmeticsEquipped, MSF = newState.MeleeSkinFor, Weapon = newState.EquippedWeapon }
    newState.CosmeticsEquipped, newState.MeleeSkinFor = s.CE, s.MSF
    if s.PreviewWeapon then newState.EquippedWeapon = s.PreviewWeapon end
    return newState
end

function TryOn.Shot(result)
    local s = active
    if not (s and result and result.Instance) then return end
    if s.Dummy then s.Dummy.Hit(result.Instance) end
    for _, d in ipairs(s.Dummies or {}) do if d.Hit(result.Instance) then break end end
end

function TryOn.Start(e, how, hooks)
    if active then TryOn.Stop(true) end -- (no store reopen: it came up over the new try-on)
    if not e then return end
    if not InHub() then if hooks.Toast then hooks.Toast("Try-ons only work in the hub") end return end
    local st = hooks.State()
    if type(st) ~= "table" then return end
    local items = Contents(e)
    local ce, msf, gun, theme, armor, glove, skinFx, guns = Override(st, items)
    local s = { Entry = e, Kind = how, Hooks = hooks, Conns = {}, Restore = {}, LocalModels = {}, Shells = {}, ShellAttr = {}, Guns = guns, GunIdx = 1 }
    active = s
    if hooks.CloseMenus then pcall(hooks.CloseMenus) end
    if how == "FP" then
        s.Real = { CE = st.CosmeticsEquipped, MSF = st.MeleeSkinFor, Weapon = st.EquippedWeapon, Mag = st.CurrentMag }
        s.CE, s.MSF = ce, msf
        if gun then
            s.PreviewWeapon = PreviewGun(gun, st.EquippedWeapon)
            st.CurrentMag = s.PreviewWeapon.MagSize or st.CurrentMag
        end
        st.CosmeticsEquipped, st.MeleeSkinFor = ce, msf
        if s.PreviewWeapon then st.EquippedWeapon = s.PreviewWeapon end
        LocalPlayer:SetAttribute("TryOnFP", true)
        pcall(hooks.Rebuild, st.EquippedWeapon)
        if theme and hooks.ApplyTheme then pcall(hooks.ApplyTheme, theme) end
        -- a melee skin: take the melee out so you see it
        local meleeOnly = (#items == 1 and items[1].Cat == "MeleeSkin")
        if meleeOnly and hooks.SelectSlot then task.delay(0.35, function() if active == s then pcall(hooks.SelectSlot, "Melee") end end) end
        local meleeSkin = nil
        for _, it in ipairs(items) do if it.Cat == "MeleeSkin" then meleeSkin = MeleeData.Skins[it.Id] end end
        s.Kill = function(pos)
            local cam = workspace.CurrentCamera
            pos = pos or (cam and (cam.CFrame.Position + cam.CFrame.LookVector * 12)) or Vector3.zero
            local skin = skinFx or meleeSkin
            local rig = hooks.Rig()
            if rig and rig.GloveBurst then rig:GloveBurst("Kill") end
            if skin and skin.FX then
                -- (colourways: the kill + banner in the colourway you wear on this set)
                local ref = ce.KillEffect and ("KillEffect:" .. ce.KillEffect) or (skin.Id and ("WeaponSkin:" .. skin.Id)) or nil
                local fx = SkinFX.KillFX(st, skin.FX, ref)
                SkinFX.KillEffect({ FX = fx }, pos)
                local okS, streak = pcall(SkinFX.Sound, "Kill")
                pcall(SkinFX.KillBanner, (okS and streak) or 1, fx)
            end
        end
        -- [N]: the next gun of the set (bundles with several gun skins)
        s.NextGun = function()
            if #s.Guns < 2 or not s.PreviewWeapon then return end
            s.GunIdx = s.GunIdx % #s.Guns + 1
            local g = s.Guns[s.GunIdx]
            local w = PreviewGun(g.Gun, s.Real and s.Real.Weapon)
            s.PreviewWeapon = w
            skinFx = g.Skin
            local st2 = hooks.State()
            if type(st2) == "table" then st2.EquippedWeapon = w; st2.CurrentMag = w.MagSize or st2.CurrentMag end
            pcall(hooks.Rebuild, w)
            task.delay(0.3, function() if active == s then local r = hooks.Rig(); if r then r:Play("Inspect") end end end)
        end
        -- (Update 6) the try range: your own lit studio with three target stands; back where you were when it ends
        if hooks.Teleport then
            local okR, sess = pcall(TryRange.Enter, hooks.Teleport, Cosmetics.RarityColor[e.Rarity])
            if okR and sess then s.Range = sess end
        end
        if s.Range then
            s.Dummies = {}
            task.delay(0.3, function()
                if active ~= s then return end
                for _, at in ipairs(s.Range.Spots) do
                    local d = Dummy(function(p) if s.Kill then s.Kill(p) end end, at)
                    if d then table.insert(s.Dummies, d) end
                end
            end)
        else
            task.delay(0.4, function() if active == s then s.Dummy = Dummy(function(p) if s.Kill then s.Kill(p) end end) end end)
        end
        -- inspect it right away
        task.delay(0.75, function() if active == s then local r = hooks.Rig(); if r then r:Play("Inspect") end end end)
    else
        -- third person: dress your character locally + the showcase orbit
        local char = LocalPlayer.Character
        if char then
            local body = {}
            for _, n in ipairs({ "Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
            "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot" }) do body[n] = char:FindFirstChild(n) end
            local look = char:FindFirstChild("AvatarLook")
            local shell = look and look:FindFirstChild("HeadShell")
            if shell then body.Head = shell end
            -- (your real armor in the slots this replaces is hidden while you look)
            local real = char:FindFirstChild("WorldArmor")
            if real and #armor > 0 then
                for _, p in ipairs(real:GetDescendants()) do
                    if p:IsA("BasePart") or p:IsA("Decal") then s.Restore[p] = { LocalTransparencyModifier = p.LocalTransparencyModifier }; p.LocalTransparencyModifier = 1 end
                end
            end
            if #armor > 0 then
                local m = Instance.new("Model"); m.Name = "TryOnArmor"
                for _, d in ipairs(armor) do ArmorFX.Build(d, body, m, true) end
                m.Parent = char
                table.insert(s.LocalModels, m)
                -- animate it (StartWorld only scans the server's models)
                local anim = {}
                for _, p in ipairs(m:GetDescendants()) do
                    local w = p:IsA("BasePart") and p:FindFirstChildOfClass("Weld")
                    local a = w and SkinFX.AnimRecord(p, w.C0, p.Size)
                    if a then table.insert(anim, { Weld = w, Rest = w.C0, Anim = a, Part = p }) end
                end
                table.insert(s.Conns, RunService.RenderStepped:Connect(function()
                    local now = os.clock()
                    local st2 = { Open = 0, Spin = 1, Flash = 1, Halo = 0 }
                    for _, x in ipairs(anim) do
                        local off, tr = SkinFX.AnimOffset(x.Anim, now, st2)
                        x.Weld.C0 = off * x.Rest
                        if tr then x.Part.Transparency = tr end
                    end
                end))
            end
            -- gloves: dress your hand shells locally
            if glove then
                local wg = char:FindFirstChild("WorldGloves")
                for _, sh in ipairs(wg and wg:GetChildren() or {}) do
                    if sh:IsA("BasePart") and sh.Name:find("HandGlove") then
                        s.Restore[sh] = { Color = sh.Color, Material = sh.Material, Reflectance = sh.Reflectance }
                        s.ShellAttr[sh] = { LookKind = sh:GetAttribute("LookKind"), LookId = sh:GetAttribute("LookId"), Side = sh:GetAttribute("Side") }
                        pcall(GloveFX.ForgetShell, sh)
                        sh:SetAttribute("LookKind", "Glove")
                        sh:SetAttribute("LookId", glove.Id)
                        sh:SetAttribute("Side", sh.Name:find("Left") and "L" or "R")
                        table.insert(s.Shells, sh)
                    end
                end
            end
            -- a gun skin: a local copy of the skinned gun on your back (yours is hidden meanwhile)
            if gun and skinFx then
                local okWG, WorldGear = pcall(require, Shared:WaitForChild("WorldGear"))
                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") -- (R6: one torso)
                if okWG and torso then
                    local model, frame = WorldGear.Gun(gun, skinFx)
                    if model and frame then
                        local real = char:FindFirstChild("WorldGun")
                        if real then
                            for _, p in ipairs(real:GetDescendants()) do
                                if p:IsA("BasePart") or p:IsA("Decal") then s.Restore[p] = { LocalTransparencyModifier = p.LocalTransparencyModifier }; p.LocalTransparencyModifier = 1 end
                            end
                        end
                        local bbCF, bbSize = model:GetBoundingBox()
                        local w = Instance.new("Weld")
                        w.Part0 = torso; w.Part1 = frame
                        w.C0 = CFrame.new(0, -0.1, torso.Size.Z / 2 + bbSize.Z / 2 + 0.05) * CFrame.Angles(0, 0, math.rad(-140)) * CFrame.Angles(math.pi, 0, 0)
                        w.C1 = CFrame.new(frame.CFrame:PointToObjectSpace(bbCF.Position))
                        w.Parent = frame
                        model.Name = "TryOnGun"
                        model.Parent = char
                        table.insert(s.LocalModels, model)
                    end
                end
            end
        end
        LocalPlayer:SetAttribute("Showcase", (#armor > 0 and armor[1].Slot == "Back" and #armor == 1) and "Back" or "Front")
    end
    s.Gui = Overlay(e, how, TryOn.Stop)
    table.insert(s.Conns, UserInputService.InputBegan:Connect(function(input, gp)
        if gp or active ~= s then return end
        if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB then
            TryOn.Stop()
        elseif input.KeyCode == Enum.KeyCode.K and s.Kill then
            s.Kill()
        elseif input.KeyCode == Enum.KeyCode.N and s.NextGun then
            s.NextGun()
        end
    end))
    -- leaving the hub (a run starting) or dying ends it
    table.insert(s.Conns, LocalPlayer:GetAttributeChangedSignal("RunId"):Connect(function() if LocalPlayer:GetAttribute("RunId") then s.NoReopen = true; TryOn.Stop() end end))
    -- (owner 2026-10-07: "you can enter any sort of play area with the preview menu open") a watchdog: the moment you
    -- leave the hub city (a dungeon / boss portal, the Training Grounds, the Bazaar, a hideout) the try-on ends
    local acc = 0
    table.insert(s.Conns, RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.2 then return end
        acc = 0
        if active == s and not InTryArea() then s.NoReopen = true; TryOn.Stop() end
    end))
    table.insert(s.Conns, LocalPlayer.CharacterAdded:Connect(function() TryOn.Stop() end))
end

return TryOn
