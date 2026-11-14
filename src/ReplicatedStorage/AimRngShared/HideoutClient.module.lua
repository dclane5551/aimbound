--!nocheck
-- HideoutClient (0.55): the client side of hideouts (server: Hideouts; data + builders: HideoutData).
--   * DRAWS the hideout you're standing in (attribute HideoutOf -> that owner's HideoutLayout JSON): the apartment shell
--     once, the furniture again whenever the layout changes; station prompts open the city stations' windows; the door
--     takes you back to the city. Nothing is drawn while you're elsewhere (all of it is local: no replication).
--   * the HIDEOUT window ([U] / dock tile): HOME (your hideout, visit / ask to visit players, your visitors + KICK) and
--     FURNITURE (the catalog: what you own, a 3D preview, BUY for gold / Robux, how to earn the rest).
--   * BUILD MODE (your own hideout): a bar of your furniture; the piece follows the mouse on the grid (R turns it), click
--     places; with nothing picked, click a placed piece to move it, DELETE / X takes it back.
--   * the visit-request popup (owner side).
-- HideoutClient.Init(menuFolder, hudGui, hooks) -> api { Toggle, OpenShop, OnState }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Zones = require(Shared:WaitForChild("Zones"))
local HD = require(Shared:WaitForChild("HideoutData"))
local Rifts = require(Shared:WaitForChild("Rifts"))

local HideoutClient = {}
local LocalPlayer = Players.LocalPlayer
local C = UIStyle.Colors
local New = UIStyle.New
local ACCENT = Color3.fromRGB(255, 150, 90)
-- (UI CLEAN R-B2) every button on the role styles: a confirm / buy (green, gold, the window accent) = the off-white primary,
-- any other hue (blue / purple / red / a material colour) = the quiet outlined secondary; neutral slates keep their own role
local function RoleCol(col: Color3?): Color3?
    local CC = UIStyle.Colors
    if not col then return col end
    if col == CC.Green or col == CC.Gold or col == ACCENT then return CC.Accent end
    local _, sat = col:ToHSV()
    if sat < 0.25 then return col end
    return CC.Steel
end
local function RoleBtn(parent, text, col, ...) return UIStyle.Button(parent, text, RoleCol(col), ...) end
local SOURCE_LABEL = { Gold = "GOLD SHOP", Drop = "BOSS DROP", Achievement = "ACHIEVEMENT", Robux = "PREMIUM" }

function HideoutClient.Init(menuFolder: Instance, hudGui: Instance, hooks: any)
    local api = {}
    local busy = false
    local function Act(...)
        if busy then return false end
        busy = true
        local ok, a, b = pcall(function(...) return Remotes.GetFunction("HideoutAction"):InvokeServer(...) end, ...)
        busy = false
        if not ok then hooks.Toast("Couldn't reach the server."); return false end
        if a == false and b then hooks.Toast(b) elseif a and b then hooks.Toast(b) end
        return a, b
    end
    -- (2026-10-20 owner: a popup with the BOUND points needed before ANY buy) BoundShop.Confirm, then the action
    local function BuyBP(name: string, price: number, desc: string?, ...)
        local args = table.pack(...)
        require(Shared:WaitForChild("BoundShop")).Confirm({ Name = name, Price = price, Desc = desc, OnBuy = function()
            local ok, a, b = pcall(function() return Remotes.GetFunction("HideoutAction"):InvokeServer(table.unpack(args, 1, args.n)) end)
            if not ok then return false, "Couldn't reach the server." end
            if a then
                if b then hooks.Toast(b) end
                task.delay(0.4, function() if HideoutClient._render then HideoutClient._render() end end)
            end
            return a, b
        end })
    end
    local function Root(): BasePart?
        local ch = LocalPlayer.Character
        return ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
    end
    local function InHideout(): boolean
        local r = Root()
        return r ~= nil and Zones.InHideout(r.Position)
    end
    local function OwnerId(): number? return LocalPlayer:GetAttribute("HideoutOf") end
    local function InOwn(): boolean return InHideout() and OwnerId() == LocalPlayer.UserId end
    -- (UPDATE 6) the showcase pieces (title wall, stats board, trophy shelf, weapon rack, jukebox, arcade): HideoutShowcase
    local Show = require(Shared:WaitForChild("HideoutShowcase")).Init(menuFolder, hooks, Act)
    if game:GetService("RunService"):IsStudio() then -- (Studio: Player attr DevShowcase = Titles | Stats | Trophies | Rack | Jukebox | Arcade opens that window)
        local lp0 = game:GetService("Players").LocalPlayer
        lp0:GetAttributeChangedSignal("DevShowcase"):Connect(function()
            local k = lp0:GetAttribute("DevShowcase")
            if type(k) == "string" and k ~= "" then pcall(Show.Open, k, nil, true) end
        end)
    end

    -- ===================== drawing the hideout =====================
    local world = Instance.new("Folder")
    world.Name = "HideoutLocal"
    local shell, furn = nil, nil
    local drawnFor, drawnJson = nil, nil
    local anim = {} -- parts the idle loop animates
    local shellAnim = {} -- the theme's outside life (kelp, fish, fireflies)
    local shellScroll = {} -- (UPDATE 4) scrolling textures: caustic light rippling over sand / floors (HideoutKit.Caustics)
    local KitOk, Kit = pcall(function() return require(script.Parent:WaitForChild("HideoutKit", 5)) end)
    if not KitOk then Kit = nil end
    local function ThemeFor(owner: Player?): string
        local t = owner and owner:GetAttribute("HideoutTheme")
        return (type(t) == "string" and HD.THEMES[t]) and t or "Apartment"
    end
    local layout = {} -- the layout being drawn
    local function LayoutOf(owner: Player?): { any }
        local json = owner and owner:GetAttribute("HideoutLayout")
        if type(json) ~= "string" then return {}, nil end
        local ok, t = pcall(HttpService.JSONDecode, HttpService, json)
        return (ok and type(t) == "table") and t or {}, json
    end
    local function Prompt(part: BasePart, action: string, object: string, onTrigger: () -> ())
        local pp = Instance.new("ProximityPrompt")
        pp.ActionText = action; pp.ObjectText = object; pp.MaxActivationDistance = 9; pp.RequiresLineOfSight = false; pp.HoldDuration = 0
        pp.Parent = part
        pp.Triggered:Connect(onTrigger)
    end
    -- the owner's published choices that change the shell (0.58): the map room, the stash + portal skins
    local function OptsFor(owner: Player?, theme: string): (any, string)
        local o = {
            MapRoom = owner ~= nil and owner:GetAttribute("HideoutMapRoom") == true,
            StashSkin = owner and owner:GetAttribute("HideoutStashSkin") or nil,
            PortalSkin = owner and owner:GetAttribute("HideoutPortalSkin") or nil,
            Low = Kit ~= nil and Kit.Low() or false, -- (UPDATE 4: the low-quality setting rebuilds the shell lighter)
        }
        return o, table.concat({ theme, tostring(o.MapRoom), tostring(o.StashSkin), tostring(o.PortalSkin), tostring(o.Low) }, "|")
    end
    local portalOpen = false
    local OpenMapDevice -- (the sigil picker, below)
    local function MakeShell(theme: string, opts: any?, key: string?)
        if shell then shell:Destroy() end
        world.Parent = workspace
        portalOpen = false
        shell = HD.BuildShell(world, theme, opts)
        shell:SetAttribute("Key", key or theme)
        table.clear(shellAnim)
        table.clear(shellScroll)
        for _, d in ipairs(shell:GetDescendants()) do
            if d:IsA("Texture") and d:GetAttribute("ScrollU") then
                table.insert(shellScroll, { Tex = d, U = d:GetAttribute("ScrollU"), V = d:GetAttribute("ScrollV") or 0 })
            end
        end
        -- the theme's moving decoration (HD.BuildShell tags it: Anim + its numbers; child parts ride along, a Hinge child
        -- flaps on its joint)
        for _, d in ipairs(shell:GetDescendants()) do
            if d:IsA("BasePart") and d:GetAttribute("Anim") then
                local kids = {}
                for _, c in ipairs(d:GetChildren()) do
                    if c:IsA("BasePart") then
                        table.insert(kids, { Part = c, Off = d.CFrame:ToObjectSpace(c.CFrame), Hinge = c:GetAttribute("Hinge"), Axis = c:GetAttribute("HingeAxis"),
                            Amp = c:GetAttribute("HingeAmp") or 0, Rate = c:GetAttribute("HingeRate") or 6 })
                    end
                end
                local at = d:GetAttributes()
                at.Kind = d:GetAttribute("Anim")
                at.Part, at.Rest, at.Kids, at.BaseT = d, d.CFrame, kids, d.Transparency
                at.Phase = at.Phase or ((#shellAnim * 1.3) % 6.28)
                if at.PortalOpenOnly then at.BaseT = at.OpenT or at.BaseT end
                table.insert(shellAnim, at)
            end
        end
        LocalPlayer:SetAttribute("HideoutView", theme) -- (the client's light profile follows the theme: AimRngClient)
        -- (0.58) the MAP DEVICE (owner: pick a sigil) and the portal (owner: walk in while it's open)
        local device = shell:FindFirstChild("MapDevice")
        if device then
            Prompt(device, "Open a map", "Map device", function()
                if not InOwn() then hooks.Toast("Only the owner can use this map device.") return end
                if OpenMapDevice then OpenMapDevice() end
            end)
        end
        local portal = shell:FindFirstChild("MapPortal")
        if portal then
            Prompt(portal, "Enter", "Map portal", function()
                if not portalOpen then return end
                if not InOwn() then hooks.Toast("Only the owner can take this portal for now.") return end
                Act("EnterPortal")
            end)
            local pp = portal:FindFirstChildOfClass("ProximityPrompt")
            if pp then pp.Enabled = false; pp.MaxActivationDistance = 14 end
            for _, d in ipairs(shell:GetDescendants()) do
                if d:IsA("BasePart") and d:GetAttribute("PortalOpenOnly") then d.Transparency = 1 end
            end
        end
        local door = shell:FindFirstChild("HideoutDoor")
        if door then Prompt(door, "Leave", "Back to the city", function() Act("Leave") end) end
        -- the STASH CHEST (0.56): your hideout stash, in the inventory window's STASH tab
        local chest = shell:FindFirstChild("HideoutStash")
        if chest then
            Prompt(chest, "Open stash", "Stash", function()
                if not InOwn() then hooks.Toast("Only the owner can open this stash.") return end
                hooks.OpenMenu("Inventory")
                task.defer(function() if hooks.ShowStashTab then hooks.ShowStashTab("Stash") end end)
            end)
        end
    end
    local function DrawFurniture()
        if furn then furn:Destroy() end
        furn = Instance.new("Folder")
        furn.Name = "Furniture"
        table.clear(anim)
        for i, e in ipairs(layout) do
            local m = HD.BuildPiece(furn, e, i)
            if m then
                local def = HD.Items[e.I]
                if def.Station then
                    Prompt(m.PrimaryPart, def.Prompt or "Use", def.Name, function() hooks.OpenMenu(def.Station) end)
                end
                if def.Show then -- (UPDATE 6: dressed with the OWNER's data; the prompt opens its window / the arcade)
                    Show.Dress(m, def, Show.Data(drawnFor))
                    Prompt(m.PrimaryPart, def.Prompt or "Use", def.Name, function() Show.Open(def.Show, nil, InOwn()) end)
                end
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("BasePart") and (d.Name == "Koi" or d.Name == "Fish" or d.Name == "Holo" or d.Name == "HoloOrb" or d.Name == "ShrineOrb"
                        or d.Name == "AscOrb" or d.Name == "PortalMembrane" or d.Name == "TVScreen" or d.Name == "OrbitNode" or d.Name == "SpinRing"
                        or d.Name == "JukeGlow") then
                        table.insert(anim, { Part = d, Rest = d.CFrame, Phase = (#anim * 1.7) % 6.28, Center = m.PrimaryPart.Position })
                    end
                end
            end
        end
        furn.Parent = world
    end
    -- the server's practice dummy + safety floor float over the city: only people in a hideout see the dummy
    local function ShowHideoutWorld(on: boolean)
        local hw = workspace:FindFirstChild("HideoutWorld")
        if not hw or api._hwShown == on then return end
        api._hwShown = on
        for _, d in ipairs(hw:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 0 or 1
            elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ProximityPrompt") then d.Enabled = on end
        end
    end
    local function Redraw(force: boolean?)
        local here = InHideout()
        ShowHideoutWorld(here)
        if not here then
            Show.StopMusic()
            LocalPlayer:SetAttribute("HideoutView", nil)
            if shell then shell:Destroy(); shell = nil end
            if furn then furn:Destroy(); furn = nil end
            drawnFor, drawnJson = nil, nil
            world.Parent = nil
            return
        end
        world.Parent = workspace
        local owner = Players:GetPlayerByUserId(OwnerId() or LocalPlayer.UserId)
        local theme = ThemeFor(owner)
        local opts, key = OptsFor(owner, theme)
        if not shell or shell:GetAttribute("Key") ~= key then MakeShell(theme, opts, key) end
        local lay, json = LayoutOf(owner)
        if force or drawnFor ~= owner or json ~= drawnJson then
            drawnFor, drawnJson = owner, json
            layout = lay
            DrawFurniture()
            if api.OnLayout then api.OnLayout() end
        end
        Show.Music(Show.Data(owner), world) -- (UPDATE 6: the owner's jukebox track; only restarts when it changes)
    end
    Show.OnMuteChanged = function() pcall(Redraw) end
    -- watch: where you are, whose hideout, its layout attribute
    local watched = nil
    local function Watch()
        local owner = Players:GetPlayerByUserId(OwnerId() or LocalPlayer.UserId)
        if watched ~= owner then
            if api._conn then api._conn:Disconnect() end
            watched = owner
            if api._conn2 then api._conn2:Disconnect() end
            if owner then
                api._conn = owner:GetAttributeChangedSignal("HideoutLayout"):Connect(function() Redraw() end)
                api._conn2 = owner.AttributeChanged:Connect(function(n) -- (theme, map room, stash / portal skins)
                    if n == "HideoutTheme" or n == "HideoutMapRoom" or n == "HideoutStashSkin" or n == "HideoutPortalSkin" then pcall(Redraw) end
                    if n == "HideoutShowcase" then pcall(Redraw, true) end -- (UPDATE 6: the showcase pieces show the new data)
                end)
            end
        end
    end
    task.spawn(function()
        while true do
            Watch()
            pcall(Redraw)
            task.wait(0.5)
        end
    end)
    LocalPlayer:GetAttributeChangedSignal("HideoutOf"):Connect(function() Watch(); pcall(Redraw) end)
    -- THE THEME'S LIFE (every frame, one BulkMoveTo): fish, kelp, jellies, bubbles, birds, butterflies, leaves, fireflies
    local bulkParts, bulkCFs = {}, {}
    local function PathPos(a: any, t: number): Vector3
        local ph = a.Phase
        if a.Kind == "Orbit" then
            local rx, rz = a.RX or 30, a.RZ or 30
            local w = (a.Dir or 1) * (a.Speed or 5) / ((rx + rz) / 2)
            local c = a.Center or a.Rest.Position
            return c + Vector3.new(math.cos(w * t + ph) * rx, math.sin(t * 0.8 + ph) * (a.Bob or 0), math.sin(w * t + ph) * rz)
        end
        local amp = a.Amp or 20 -- (Line)
        local s = math.sin((a.Speed or 5) / amp * t + ph) * amp
        local off = (a.Axis == "Z") and Vector3.new(0, 0, s) or Vector3.new(s, 0, 0)
        return a.Rest.Position + off + Vector3.new(0, math.sin(t * 1.3 + ph) * 0.4, 0)
    end
    local function AnimateShell()
        local t = os.clock()
        table.clear(bulkParts); table.clear(bulkCFs)
        for _, a in ipairs(shellAnim) do
            local p = a.Part
            if not p.Parent then continue end
            if a.PortalOpenOnly and not portalOpen then continue end
            local k, ph = a.Kind, a.Phase
            local cf
            if k == "Line" or k == "Orbit" then
                local pos = PathPos(a, t)
                local ahead = PathPos(a, t + 0.08)
                cf = (ahead - pos).Magnitude > 1e-4 and CFrame.lookAt(pos, ahead) or CFrame.new(pos)
                cf *= CFrame.Angles(0, math.sin(t * 5 + ph) * 0.06, 0)
            elseif k == "Sway" then
                local h = p.Size.Y / 2
                local pivot = a.Hang and CFrame.new(0, h, 0) or CFrame.new(0, -h, 0)
                local amp = a.Amp or 0.1
                cf = a.Rest * pivot * CFrame.Angles(math.sin(t * 0.8 + ph) * amp, 0, math.sin(t * 0.6 + ph * 1.3) * amp) * pivot:Inverse()
            elseif k == "Spin" then
                local ang = t * (a.Rate or 1) + ph
                cf = a.Rest * ((a.Axis == "X") and CFrame.Angles(ang, 0, 0) or (a.Axis == "Z") and CFrame.Angles(0, 0, ang) or CFrame.Angles(0, ang, 0))
            elseif k == "Bob" then
                cf = CFrame.new(a.Rest.Position + Vector3.new(0, math.sin(t * (a.Rate or 0.6) + ph) * (a.Amp or 1), 0)) * a.Rest.Rotation * CFrame.Angles(0, a.NoTurn and 0 or (t * 0.15 + ph), 0)
            elseif k == "Rise" then
                local hgt = a.Height or 30
                local y = (t * (a.Speed or 3) + ph * 7) % hgt
                cf = a.Rest + Vector3.new(math.sin(t * 2 + ph) * 0.3, y, math.cos(t * 1.7 + ph) * 0.3)
                p.Transparency = a.BaseT + (1 - a.BaseT) * (y / hgt) ^ 3
            elseif k == "Fall" then
                local hgt = a.Height or 20
                local y = (t * (a.Speed or 1.6) + ph * 5) % hgt
                cf = a.Rest * CFrame.new(math.sin(t * 1.1 + ph) * 1.5, -y, math.cos(t * 0.9 + ph) * 1.2) * CFrame.Angles(t * 1.5 + ph, t * 0.7, math.sin(t * 2 + ph) * 0.8)
            elseif k == "Firefly" then
                local sp = a.Speed or 0.8
                cf = a.Rest * CFrame.new(math.sin(t * sp + ph) * 2.2, math.sin(t * sp * 1.7 + ph) * 1.2, math.cos(t * sp * 0.8 + ph) * 1.6)
                if a.Steady then
                    cf *= CFrame.Angles(0, math.cos(t * sp + ph) > 0 and 0 or math.pi, 0)
                else
                    p.Transparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(t * 2.2 + ph * 3))
                end
            elseif k == "Pulse" then
                p.Transparency = math.clamp(a.BaseT + (a.Amp or 0.2) * (0.5 + 0.5 * math.sin(t * (a.Rate or 1) + ph)), 0, 1)
            end
            if cf then
                table.insert(bulkParts, p); table.insert(bulkCFs, cf)
                for _, kd in ipairs(a.Kids) do
                    local kcf
                    if kd.Hinge then
                        local ang = math.sin(t * kd.Rate + ph) * kd.Amp
                        local rot = (kd.Axis == "Y") and CFrame.Angles(0, ang, 0) or (kd.Axis == "X") and CFrame.Angles(ang, 0, 0) or CFrame.Angles(0, 0, ang)
                        kcf = cf * CFrame.new(kd.Hinge) * rot * CFrame.new(-kd.Hinge) * kd.Off
                    else
                        kcf = cf * kd.Off
                    end
                    table.insert(bulkParts, kd.Part); table.insert(bulkCFs, kcf)
                end
            end
        end
        if #bulkParts > 0 then workspace:BulkMoveTo(bulkParts, bulkCFs, Enum.BulkMoveMode.FireCFrameChanged) end
    end
    -- the idle animations (20 Hz, only while drawn)
    local acc, fallAcc = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        -- out of the apartment (fell or slipped past a wall): straight back to the spawn
        fallAcc += dt
        if fallAcc > 0.25 and shell then
            fallAcc = 0
            local r = Root()
            if r and Zones.InHideout(r.Position) then
                local lp = r.Position - HD.Origin
                if lp.Y < -10 or lp.Y > 40 or lp.X < -36 or lp.X > HD.BX + 3 or lp.Z < -42 or lp.Z > HD.BALZ + 2 then
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.CFrame = HD.SPAWN
                end
            end
        end
        -- the map room's portal: open while the owner's HideoutPortalUntil is in the future (server time)
        if shell and shell:GetAttribute("MapRoom") then
            local owner = Players:GetPlayerByUserId(OwnerId() or LocalPlayer.UserId)
            local open = owner ~= nil and (owner:GetAttribute("HideoutPortalUntil") or 0) > workspace:GetServerTimeNow()
            if open ~= portalOpen then
                portalOpen = open
                for _, d in ipairs(shell:GetDescendants()) do
                    if d:IsA("BasePart") and d:GetAttribute("PortalOpenOnly") then
                        d.Transparency = open and (d:GetAttribute("OpenT") or 0) or 1
                    elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Fire") then
                        -- (0.59 portal skins v2: Open = on while open, Burst = once as it opens)
                        local mode = d:GetAttribute("FxMode")
                        if mode == "Open" then
                            (d :: any).Enabled = open
                        elseif mode == "Burst" and open and d:IsA("ParticleEmitter") then
                            d:Emit(d:GetAttribute("BurstN") or 40)
                        end
                    elseif d:IsA("Sound") then
                        local mode = d:GetAttribute("SndMode")
                        if mode == "Open" and open then d.TimePosition = 0; d:Play()
                        elseif mode == "Hum" then if open then d:Play() else d:Stop() end end
                    end
                end
                local mp = shell:FindFirstChild("MapPortal")
                local pp = mp and mp:FindFirstChildOfClass("ProximityPrompt")
                if pp then pp.Enabled = open end
            end
        end
        if shell and #shellAnim > 0 then AnimateShell() end
        if shell and #shellScroll > 0 then
            local ts = os.clock()
            for _, sc in ipairs(shellScroll) do
                local tx = sc.Tex
                tx.OffsetStudsU = (ts * sc.U) % tx.StudsPerTileU
                tx.OffsetStudsV = (ts * sc.V) % tx.StudsPerTileV
            end
        end
        acc += dt
        if acc < 0.05 or not shell then return end
        local t = os.clock()
        acc = 0
        if #anim == 0 or not furn then return end
        for _, a in ipairs(anim) do
            local p, n = a.Part, a.Part.Name
            if not p.Parent then continue end
            if n == "Koi" then
                local c = a.Center
                local ang = t * 0.6 + a.Phase
                p.CFrame = CFrame.new(c.X + math.cos(ang) * 1.7, a.Rest.Y, c.Z + math.sin(ang) * 1.7) * CFrame.Angles(0, -ang, 0)
            elseif n == "Fish" then
                p.CFrame = a.Rest * CFrame.new(math.sin(t * 0.8 + a.Phase) * 1.6, math.sin(t * 1.3 + a.Phase) * 0.2, 0)
            elseif n == "Holo" or n == "HoloOrb" then
                p.CFrame = a.Rest * CFrame.Angles(0, t * 1.2, 0)
            elseif n == "ShrineOrb" or n == "AscOrb" then
                p.CFrame = a.Rest * CFrame.new(0, math.sin(t * 1.6 + a.Phase) * 0.25, 0)
            elseif n == "OrbitNode" then -- (0.76 Observatory: class stars circling the centre)
                local c = a.Center
                local off = a.Rest.Position - c
                local rad = math.sqrt(off.X * off.X + off.Z * off.Z)
                local ang = math.atan2(off.Z, off.X) + t * 0.35
                p.CFrame = CFrame.new(c.X + math.cos(ang) * rad, a.Rest.Y + math.sin(t * 1.1 + a.Phase) * 0.3, c.Z + math.sin(ang) * rad)
            elseif n == "SpinRing" then
                p.CFrame = a.Rest * CFrame.Angles(0, t * ((p.Parent and p.Parent:GetAttribute("Playing")) and 3.5 or 0.8), 0)
            elseif n == "JukeGlow" then -- (UPDATE 6: the jukebox's neon tubes run through the colours while it plays)
                if p.Parent and p.Parent:GetAttribute("Playing") then p.Color = Color3.fromHSV((t * 0.12 + a.Phase * 0.05) % 1, 0.65, 1) end
            elseif n == "PortalMembrane" then
                p.Transparency = 0.35 + 0.15 * math.sin(t * 2.5)
            elseif n == "TVScreen" then
                local k = 0.5 + 0.5 * math.sin(t * 7 + math.sin(t * 2.3) * 3)
                p.Color = Color3.fromRGB(70, 150, 220):Lerp(Color3.fromRGB(150, 210, 255), k)
            end
        end
    end)

    -- ===================== the HIDEOUT window =====================
    local panel = UIStyle.Panel(menuFolder, { Name = "HideoutMenu", Size = UDim2.fromOffset(960, 640), Accent = ACCENT })
    UIStyle.TitleBar(panel, "HIDEOUT", ACCENT, "your own walled-city loft: decorate it, use it, show it off", function() hooks.CloseAll() end)
    local tabsRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 40), Parent = panel })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 26), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = tabsRow })
    local body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 120), Size = UDim2.new(1, -32, 1, -136), Parent = panel })
    -- (2026-10-13 phones: as tall as the screen -- lists scroll, the HOME column and the piece detail scroll inside)
    panel:SetAttribute("PhoneMinH", 300)
    local tab = "Home"
    local filter = "All"
    local selected = nil
    local function Clear(f) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
    local function Text(parent, props) props.Parent = parent return UIStyle.Text(props) end
    local function Scroll(parent, pos, size)
        local sf = New("ScrollingFrame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = pos, Size = size, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent }, { UIStyle.Corner(2) })
        New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
        New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), Parent = sf })
        return sf
    end
    local Render
    local function TabButton(id, label)
        -- (UI CLEAN audit: word tabs, not slabs)
        local b = UIStyle.WordTab(tabsRow, label, tab == id, function() hooks.Click(); tab = id; Render() end, 17)
        b.Size = UDim2.new(0, 0, 1, 0)
    end

    -- THE MAP DEVICE window (0.58): your Rift Sigils; OPEN puts one in and opens the portal at the end of the map room
    local mapPanel = UIStyle.Panel(menuFolder, { Name = "MapDeviceMenu", Size = UDim2.fromOffset(660, 640), Accent = C.Purple })
    UIStyle.TitleBar(mapPanel, "MAP DEVICE", C.Purple, "level 100+: put a map in, the portal opens for 90 seconds. Rarer maps: harder floors, more loot", function() hooks.CloseAll() end)
    local mapList = Scroll(mapPanel, UDim2.fromOffset(16, 200), UDim2.new(1, -32, 1, -216))
    mapPanel:SetAttribute("PhoneMinH", 300) -- (2026-10-13 phones: as tall as the screen, the map list scrolls)
    -- (MAP TREE) the map passives window, built the first time it opens
    local atlasMenu
    local treeBtn = RoleBtn(mapPanel, "MAP TREE", C.Purple, UDim2.fromOffset(180, 36), UDim2.fromOffset(16, 76))
    local treePts = Text(mapPanel, { Text = "", TextSize = 14, Font = UIStyle.BodyFont, TextColor3 = C.Gold, Position = UDim2.fromOffset(372, 84), Size = UDim2.new(1, -388, 0, 20) })
    do -- (MAPS V2 L2) COMPLETION: every map type beaten in time on every band (AimRngShared/MapCompletionMenu)
        local cb = RoleBtn(mapPanel, "COMPLETION", C.Purple, UDim2.fromOffset(150, 36), UDim2.fromOffset(206, 76))
        local view
        local function OpenView()
            view = view or require(Shared:WaitForChild("MapCompletionMenu")).Init(menuFolder, hooks)
            hooks.CloseAll()
            view.Open()
        end
        cb.Button.MouseButton1Click:Connect(function() hooks.Click(); OpenView() end)
        if game:GetService("RunService"):IsStudio() then -- (Studio test hook: Player attr DevMapCompletion = any new value opens the view)
            local lp2 = game:GetService("Players").LocalPlayer
            lp2:GetAttributeChangedSignal("DevMapCompletion"):Connect(function()
                if lp2:GetAttribute("DevMapCompletion") then OpenView() end
            end)
        end
    end
    treeBtn.Button.MouseButton1Click:Connect(function()
        hooks.Click()
        atlasMenu = atlasMenu or require(Shared:WaitForChild("AtlasMenu")).Init(menuFolder, hooks)
        hooks.CloseAll()
        atlasMenu.Open()
    end)
    -- BOT SKILL PICK (owner: "maps should also have difficulty selections ... bot difficulty selection"): STANDARD = every map's
    -- bot skill (Rifts.SkillOf: BOT MOVEMENT POE 2026-10-30, it was a 6-10 roll), or 1-10 like the Dungeons window -- the OPT-IN:
    -- faster bots (still inside the readable limit, BotMove.CAP_DEG) pay Rifts.MapReward. Sent with OPEN; the server keeps it on
    -- the open portal (HideoutPortalSkill). Hunter's Pact (map tree) still forces 10.
    local mapSkill = nil -- nil = Standard
    local skillBtns = {}
    local skillInfo = Text(mapPanel, { Text = "", TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub, RichText = true,
        Position = UDim2.fromOffset(16, 176), Size = UDim2.new(1, -32, 0, 18) })
    do -- (PLAYTEST 2026-10-31: on a phone the STANDARD line ran ~100 px past the window's edge -- one line, stepped down to fit)
        local function Refit() -- (from 13 down, only once it has a real size: a 0-size label never fits)
            if skillInfo.AbsoluteSize.X < 2 then return end
            skillInfo.TextSize = 13
            while not skillInfo.TextFits and skillInfo.TextSize > 9 do skillInfo.TextSize -= 1 end
        end
        skillInfo:GetPropertyChangedSignal("Text"):Connect(Refit)
        skillInfo:GetPropertyChangedSignal("AbsoluteSize"):Connect(Refit)
        skillInfo:GetPropertyChangedSignal("FontFace"):Connect(Refit)
    end
    -- (UPDATE 7 C1) THE APEX HUNT row: your Coordinates + TRACK THE APEX / UBER APEX (ApexAction)
    local AH = require(Shared:WaitForChild("ApexHunt"))
    local apexInfo = Text(mapPanel, { Text = "", TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = AH.COLOR, RichText = true,
        Position = UDim2.fromOffset(16, 118), Size = UDim2.new(1, -300, 0, 24) })
    local apexBtn = RoleBtn(mapPanel, "CLIMB THE SUMMIT", AH.COLOR, UDim2.fromOffset(138, 26), UDim2.new(1, -284, 0, 117))
    local uberBtn = RoleBtn(mapPanel, "SUMMIT UNBOUND", C.Red, UDim2.fromOffset(122, 26), UDim2.new(1, -138, 0, 117))
    apexBtn.Label.TextSize, uberBtn.Label.TextSize = 13, 13
    local function StartApex(uber)
        hooks.Click()
        task.spawn(function()
            local ok, okRes, msg = pcall(function() return Remotes.GetFunction("ApexAction"):InvokeServer("Start", uber) end)
            if not ok then hooks.Toast("Couldn't reach the server."); return end
            if msg then hooks.Toast(msg) end
            if okRes then hooks.CloseAll() end
        end)
    end
    apexBtn.Button.MouseButton1Click:Connect(function() if apexBtn.Button.Active then StartApex(false) end end)
    uberBtn.Button.MouseButton1Click:Connect(function() if uberBtn.Button.Active then StartApex(true) end end)
    do
        Text(mapPanel, { Text = "BOT SKILL", TextSize = 14, TextColor3 = C.Purple, Position = UDim2.fromOffset(16, 150), Size = UDim2.fromOffset(84, 22) })
        local function Pick(v) hooks.Click(); mapSkill = v; OpenMapDevice() end
        local rb = RoleBtn(mapPanel, "STANDARD", C.Steel, UDim2.fromOffset(104, 24), UDim2.fromOffset(100, 148))
        rb.Button.MouseButton1Click:Connect(function() Pick(nil) end)
        skillBtns[0] = rb
        for i = 1, 10 do
            local b = RoleBtn(mapPanel, tostring(i), C.Steel, UDim2.fromOffset(40, 24), UDim2.fromOffset(210 + (i - 1) * 43, 148))
            b.Button.MouseButton1Click:Connect(function() Pick(i) end)
            skillBtns[i] = b
        end
    end
    -- (MAPS V2 M3) the RUPTURE confirm: the shown odds, then the server rolls (Hideouts CraftMap)
    local function RuptureConfirm(cost: number, go: () -> ())
        require(Shared:WaitForChild("PopupUI")).Confirm(string.format("Rupture? (%d Chart Shards)", cost),
            Rifts.RuptureOddsText() .. "\nThen the map is locked for good (marks still go on).", "RUPTURE", C.Red, go)
    end
    OpenMapDevice = function()
        for _, c in ipairs(mapList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local st = hooks.GetState() or {}
        local sigils = table.clone(st.Sigils or {})
        do
            local AD = require(Shared:WaitForChild("AtlasData"))
            local free = AD.Free(st)
            treePts.Text = free > 0 and string.format("%d map point%s to spend", free, free == 1 and "" or "s") or string.format("%d map points spent", AD.Spent(st))
        end
        table.sort(sigils, function(x, y2) return (x.Tier or 0) > (y2.Tier or 0) end)
        do -- (UPDATE 7 C1) the Apex row
            local mats = st.Materials or {}
            local lvl = st.Level or 1
            if lvl < AH.UNLOCK then
                apexInfo.Text = "THE SUMMIT: from level " .. AH.UNLOCK .. " map guardians drop Bearings."
            else
                local t = {}
                for _, k in ipairs(AH.COORDS) do
                    local n = mats[k] or 0
                    table.insert(t, string.format("<font color=\"#%s\">%s %d</font>", (n > 0) and "ff78a0" or "8a8f99", string.upper(string.sub(k, 6)), n))
                end
                apexInfo.Text = "BEARINGS  " .. table.concat(t, "  •  ")
            end
            apexBtn.SetEnabled((AH.CanStart(st, false)))
            uberBtn.Button.Visible = lvl >= AH.UBER_LEVEL
            uberBtn.SetEnabled((AH.CanStart(st, true)))
        end
        -- (0.61 MAPS v2: level 100+, tiers climb Ruin -> Singularity three at a time, the guardian pays Rifts.Reward)
        local open = (st.Level or 1) >= Rifts.MIN_LEVEL
        if not open then
            Text(mapList, { Text = "Maps open at level " .. Rifts.MIN_LEVEL .. ". Your sigils wait here until then.", TextSize = 14, Font = UIStyle.BodyFont,
                TextColor3 = C.Gold, TextWrapped = true, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 0 })
        end
        if #sigils == 0 then
            Text(mapList, { Text = "No sigils yet. From level 100 bosses drop them; after that maps drop inside maps (the guardian, elites and the map caches).", TextSize = 14, Font = UIStyle.BodyFont,
                TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1 })
        end
        -- (0.62 MAPS v3) a row per map: rarity-coloured name, every modifier spelled out, item quantity, the guardian's
        -- cache, OPEN + the crafts (Imbue / Empower / Reroll, paid in Prism)
        local FloorMods = require(Shared:WaitForChild("FloorMods"))
        local prism = (st.Materials or {})[Rifts.CRAFT_MATERIAL] or 0
        local shards = (st.Materials or {}).ChartShard or 0 -- (0.66 map-only currency)
        local BossTrials = require(Shared:WaitForChild("BossTrials"))
        -- the bot skill row (the pick above)
        local LEVELS = require(Shared:WaitForChild("DungeonGenerator")).BotSkillLevels
        local hunter = require(Shared:WaitForChild("AtlasData")).Stats(st).K_HUNTER
        for i, b in pairs(skillBtns) do
            local t = (math.max(1, i) - 1) / 9
            local col = C.Green:Lerp(C.Gold, math.min(1, t * 2)):Lerp(C.Red, math.max(0, t * 2 - 1))
            b.SetColor(((mapSkill or 0) == i) and (i == 0 and C.Purple or col) or C.Steel)
        end
        local function SkillFor(sg) return hunter and 10 or mapSkill or Rifts.SkillOf(sg) end
        if hunter then
            skillInfo.Text = string.format("Hunter's Pact (map tree): every map is bot skill 10  •  kill rewards <b>%.2fx</b>", Rifts.MapReward(10))
        elseif mapSkill then
            local sk = LEVELS[mapSkill]
            skillInfo.Text = string.format("Every map you open: bot skill <b>%d %s</b>  •  bot speed %d%%  •  kill rewards <b>%.2fx</b> (XP, gold and loot)",
                mapSkill, string.upper(sk.Name), math.round(sk.Speed / LEVELS[Rifts.MAP_SKILL].Speed * 100), Rifts.MapReward(mapSkill))
        else
            skillInfo.Text = string.format("Maps play at Standard bot skill  •  kill rewards <b>%.2fx</b>. Higher steps: faster bots, more loot. Map titles need step 7 (8 from Annihilation).", Rifts.MapReward(Rifts.MAP_SKILL))
        end
        local order = Rifts.RARITY_ORDER
        table.sort(sigils, function(x, y2)
            local rx, ry = table.find(order, Rifts.RarityOf(x)) or 1, table.find(order, Rifts.RarityOf(y2)) or 1
            if (x.Tier or 0) ~= (y2.Tier or 0) then return (x.Tier or 0) > (y2.Tier or 0) end
            return rx > ry
        end)
        for i, sg in ipairs(sigils) do
            local tier = tonumber(sg.Tier) or 1
            local diff = Rifts.DifficultyFor(tier)
            local ml = ItemData.MONSTER_LEVEL[diff]
            local rar = Rifts.RarityOf(sg)
            local rcol = Rifts.RARITIES[rar].Color
            local rw = Rifts.Reward(tier, true, sg)
            local top = ItemData.MaxRarityRank(diff)
            local u = sg.Unique and Rifts.UNIQUES[sg.Unique]
            local modLines, modH = {}, 0
            local MI = require(Shared:WaitForChild("MapInks"))
            local inkLines = {}
            for _, k in ipairs(MI.Of(sg)) do table.insert(inkLines, "MARKS  " .. MI.Defs[k].Name .. ": " .. MI.Defs[k].Text) end
            local MapCard = require(Shared:WaitForChild("MapCard")) -- (MAPS V2: the mods at this tier's real values)
            for _, line in ipairs(MapCard.ModLines(sg)) do
                table.insert(modLines, line)
                modH += 15 * math.max(1, math.ceil(#line / 74)) -- (a long line wraps: give it its rows)
            end
            for _, line in ipairs(inkLines) do table.insert(modLines, line); modH += 15 * math.max(1, math.ceil(#line / 74)) end
            -- (UPDATE 7 MAP INKS) the inks you could draw onto this map
            local inkable = {}
            if (st.Level or 1) >= MI.UNLOCK then
                for _, k in ipairs(MI.Order) do
                    if ((st.Materials or {})[k] or 0) > 0 and MI.CanInk(sg, k, require(Shared:WaitForChild("AtlasData")).Stats(st)) then table.insert(inkable, k) end -- (MAPS V2: Wide Margins = 3)
                end
            end
            modH = math.max(15, modH)
            local nCraft = 0
            for _, act in ipairs(Rifts.CRAFT_ORDER) do if Rifts.CanCraft(sg, act) then nCraft += 1 end end
            local tag = MapCard.TagLine(sg) -- (MAPS V2: corrupted / ruptured state)
            local h = math.max(96 + 18 + modH + (u and 18 or 0) + (tag and 16 or 0), 52 + 30 * (nCraft + #inkable)) -- (0.66: up to five craft buttons; + inks; MAPS V2 + the stat line)
            local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, h), LayoutOrder = i + 1, Parent = mapList }, { UIStyle.Corner(2) })
            New("Frame", { BackgroundColor3 = rcol, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = row })
            Text(row, { Text = string.upper(Rifts.DisplayName(sg)) .. "  •  TIER " .. tier, TextSize = 17, TextColor3 = rcol,
                Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -150, 0, 22) })
            local off = Rifts.LevelOffset(sg)
            Text(row, { Text = string.format("%s  •  %s  •  map level %d (you +%d)  •  bot skill %d  •  %s", string.upper(diff), string.upper(tostring(sg.Biome or "Mixed")),
                Rifts.MapLevel(sg, st.Level or 1), off, SkillFor(sg), (string.split(Rifts.LAYOUTS[Rifts.LayoutOf(sg)], ":"))[1]),
                TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -150, 0, 16) })
            local y = 44
            -- (MAPS V2 M2) ITEM QUANTITY / ITEM RARITY / PACK SIZE / QUALITY: the same numbers the server pays with (MapCard)
            Text(row, { Text = MapCard.StatLine(sg), TextSize = 13, TextColor3 = C.Gold, TextWrapped = true, Name = "MapStats",
                Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -150, 0, 16) })
            y += 18
            if tag then
                Text(row, { Text = tag, TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Red, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -150, 0, 14) })
                y += 16
            end
            if u then
                Text(row, { Text = u.Text, TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = rcol, TextWrapped = true, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -150, 0, 16) })
                y += 18
            end
            Text(row, { Text = (#modLines > 0) and table.concat(modLines, "\n") or (sg.Corrupted and "No modifiers. Corrupted: it can't be crafted any more." or "No modifiers (Plain map). Imbue it to add some: harder, but more loot."),
                TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = Color3.fromRGB(150, 180, 255), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                LineHeight = 1, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -150, 0, modH) })
            y += modH + 4
            local gdef = BossTrials.ById[Rifts.GuardianOf(tier, sg).Boss] -- (0.92: each map its own guardian)
            Text(row, { Text = string.format("GUARDIAN: %s  •  in time: %d items with boosted odds, %d gem%s",
                gdef and gdef.Name or "?", rw.Items, rw.Gems, rw.Gems == 1 and "" or "s"), -- (0.91 loot v3: no floors; MAPS V2: quantity is on the stat line)
                TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Gold, TextWrapped = true, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -150, 0, 30) })
            local ob = RoleBtn(row, "OPEN", C.Purple, UDim2.fromOffset(120, 34), UDim2.new(1, -128, 0, 8))
            ob.SetEnabled(open)
            ob.Button.MouseButton1Click:Connect(function()
                hooks.Click()
                local ok = Act("OpenMap", sg.Uid, mapSkill)
                if ok then hooks.CloseAll() end
            end)
            local by = 46
            for _, act in ipairs(Rifts.CRAFT_ORDER) do
                local c = Rifts.CRAFT[act]
                if Rifts.CanCraft(sg, act) then
                    local cost = c.Fixed and c.Cost or require(Shared:WaitForChild("AtlasData")).CraftCost(st, c.Cost) -- (MAP TREE: Artisan; MAPS V2: HONE / RUPTURE full price)
                    local shard = Rifts.CraftMaterial(act) == "ChartShard"
                    local cb = RoleBtn(row, string.format("%s  %d", c.Name, cost), shard and ItemData.MaterialDefs.ChartShard.Color or rcol, UDim2.fromOffset(120, 26), UDim2.new(1, -128, 0, by))
                    cb.Button.Name = "Craft_" .. act
                    cb.SetEnabled((shard and shards or prism) >= cost)
                    local function Go()
                        if Act("CraftMap", sg.Uid, act) then task.delay(0.3, OpenMapDevice) end
                    end
                    cb.Button.MouseButton1Click:Connect(function()
                        hooks.Click()
                        if act == "Rupture" then -- (MAPS V2 M3: the second corruption -- shown odds + a confirm, rolled on the server)
                            RuptureConfirm(cost, Go)
                        else
                            Go()
                        end
                    end)
                    by += 30
                end
            end
            for _, k in ipairs(inkable) do
                local d = MI.Defs[k]
                local ib = RoleBtn(row, string.format("MARK: %s  (%d)", string.upper(d.Short), (st.Materials or {})[k] or 0), d.Color, UDim2.fromOffset(120, 26), UDim2.new(1, -128, 0, by))
                ib.Label.TextSize = 12
                ib.Button.MouseButton1Click:Connect(function()
                    hooks.Click()
                    if Act("InkMap", sg.Uid, k) then task.delay(0.3, OpenMapDevice) end
                end)
                by += 30
            end
        end
        if #sigils > 0 then
            Text(mapList, { Text = string.format("CRAFTING with Prism (you have %d): IMBUE a Plain map into Charged (1-2 mods), EMPOWER a Charged into Rare (4-6 mods, more on higher tiers), REROLL a Charged / Rare map's mods. Mods get stronger on higher tiers and every mod adds item quantity and item rarity.\nWith CHART SHARDS (blue buttons, only found in maps; you have %d): CHART = a new biome and layout, HONE = +5%% quality (up to 20%%, +1%% item quantity each), CORRUPT = a gamble (40%% +1 tier and +1 mod, 30%% +1 mod, 30%% nothing; +20%% item quantity, no more crafting), RUPTURE = corrupt a Corrupted map once more (25%% each: nothing, +1 tier, new corrupted mods, +30%% quantity and +20%% rarity), ENGRAVE = a Rare map into a Storied one. Map guardians can also drop map-only relics.\nSIGIL MARKS (from guardians): draw up to %d different ones onto a map before you open it (the map tree's Wide Margins adds a third). From level 125 guardians also drop BEARINGS: one of each leads you to the Summit.",
                prism, shards, require(Shared:WaitForChild("MapInks")).MaxFor(require(Shared:WaitForChild("AtlasData")).Stats(st))),
                TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 120), LayoutOrder = 999 })
        end
        if not mapPanel.Visible then hooks.OpenFrame(mapPanel) end -- (OpenFrame toggles: a refresh from a skill pick / craft must not close it)
    end
    if game:GetService("RunService"):IsStudio() then -- (MAPS V2 Studio hook: Player attr DevMapDevice = "open" | "rupture" (the RUPTURE
        -- confirm with its odds, as the button shows it; nothing is rolled) -- set "" first to repeat a value)
        local lp1 = game:GetService("Players").LocalPlayer
        lp1:GetAttributeChangedSignal("DevMapDevice"):Connect(function()
            local k = tostring(lp1:GetAttribute("DevMapDevice") or "")
            if k == "open" then OpenMapDevice()
            elseif k == "rupture" then RuptureConfirm(Rifts.CRAFT.Rupture.Cost, function() end) end
        end)
    end

    local function RenderHome()
        local st = hooks.GetState() or {}
        local left = New("Frame", { BackgroundColor3 = C.CardDark, Size = UDim2.new(0.42, -8, 1, 0), Parent = body }, { UIStyle.Corner(2) })
        Text(left, { Text = "YOUR HIDEOUT", TextSize = 18, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 26) })
        local placed = 0
        local h = type(st.Hideout) == "table" and st.Hideout or {}
        placed = type(h.Layout) == "table" and #h.Layout or 0
        local exp = HD.ExpLevel(st)
        local cap = HD.Cap(exp)
        Text(left, { Text = string.format("%d / %d pieces placed. Stations you place open the same windows as the city's (stash, forge, upgrades, passive tree, dungeons, cosmetics, Index, challenges, season, shop, trade). The practice alcove has a damage dummy.", placed, cap),
            TextSize = 14, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 72) })
        local y = 120
        -- EXPANSIONS: the next one to buy
        local nxt = HD.EXPANSIONS[exp + 1]
        local card = New("Frame", { BackgroundColor3 = C.Card, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 92), Parent = left }, { UIStyle.Corner(2), UIStyle.Stroke(ACCENT, 1) })
        Text(card, { Text = string.format("EXPANSIONS  %d / %d", exp, #HD.EXPANSIONS), TextSize = 14, TextColor3 = ACCENT, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18) })
        if nxt then
            local lvlOk = (st.Level or 1) >= nxt.Level
            Text(card, { Text = nxt.Name .. ": " .. nxt.Desc, TextSize = 13, Font = UIStyle.BodyFont, TextWrapped = true,
                TextColor3 = C.Text, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 32) })
            -- (2026-10-20 owner: "Stashes and such should cost boundpoints": each expansion adds stash room -> BOUND points
            -- only, no level needed; the popup shows how many more you need)
            local bp = HD.BPPrice(nxt.Robux)
            local rb = RoleBtn(card, "BUY  " .. bp .. " BOUND", C.Green, UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 60))
            rb.Button.MouseButton1Click:Connect(function() hooks.Click(); BuyBP(nxt.Name, bp, nxt.Desc, "ExpandRobux") end)
        else
            Text(card, { Text = "Fully expanded: the balcony is yours and there's room for " .. cap .. " pieces.", TextSize = 13, Font = UIStyle.BodyFont, TextWrapped = true,
                TextColor3 = C.Good, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 50) })
        end
        y += 100
        -- (0.58) THE MAP ROOM: its own purchase
        if not HD.HasMapRoom(st) then
            local mr = HD.MAP_ROOM
            -- (PLAYTEST 2026-10-31: its 3-line text (4 under level 100) was cut at 2 lines -- the card is 20 px taller)
            local mc = New("Frame", { BackgroundColor3 = C.Card, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 112), Parent = left }, { UIStyle.Corner(2), UIStyle.Stroke(C.Purple, 1) })
            local lvlOk = (st.Level or 1) >= mr.Level
            Text(mc, { Text = "MAP ROOM", TextSize = 14, TextColor3 = C.Purple, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18) })
            Text(mc, { Text = mr.Desc .. (lvlOk and "" or ("  Needs level " .. mr.Level .. ".")), TextSize = 13, Font = UIStyle.BodyFont, TextWrapped = true,
                TextColor3 = lvlOk and C.Text or C.Sub, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 52) })
            local gb = RoleBtn(mc, ItemData.FormatNumber(mr.Price) .. " GOLD", C.Gold, UDim2.new(0.6, -14, 0, 26), UDim2.fromOffset(10, 80))
            gb.SetEnabled(lvlOk and (st.Gold or 0) >= mr.Price)
            gb.Button.MouseButton1Click:Connect(function() hooks.Click(); local ok = Act("BuyMapRoom"); if ok then task.delay(0.3, Render) end end)
            local bp = HD.BPPrice(mr.Robux) -- (0.97 BOUND SHOP)
            local rb = RoleBtn(mc, bp .. " BOUND", C.Green, UDim2.new(0.4, -10, 0, 26), UDim2.new(0.6, 0, 0, 80))
            rb.Button.MouseButton1Click:Connect(function() hooks.Click(); BuyBP("Map Room", bp, mr.Desc, "MapRoomRobux") end)
            y += 120
        end
        local function Big(label, col, fn)
            local b = RoleBtn(left, label, col, UDim2.new(1, -28, 0, 46), UDim2.fromOffset(14, y))
            b.Button.MouseButton1Click:Connect(function() hooks.Click(); fn() end)
            y += 54
        end
        if not InOwn() then Big("GO TO MY HIDEOUT", ACCENT, function() hooks.CloseAll(); Act("Enter") end) end
        if InOwn() then Big("BUILD MODE", C.Green, function() hooks.CloseAll(); api.StartBuild() end) end
        if InHideout() then Big("BACK TO THE CITY", C.Steel, function() hooks.CloseAll(); Act("Leave") end) end
        Big("FURNITURE", C.Blue, function() tab = "Furniture"; Render() end)
        -- visitors (owner, in their hideout)
        if InOwn() then
            Text(left, { Text = "VISITORS", TextSize = 16, TextColor3 = C.Gold, Position = UDim2.fromOffset(14, y + 6), Size = UDim2.new(1, -28, 0, 22) })
            y += 32
            local n = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p:GetAttribute("HideoutOf") == LocalPlayer.UserId then
                    n += 1
                    local row = New("Frame", { BackgroundColor3 = C.Card, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 36), Parent = left }, { UIStyle.Corner(2) })
                    Text(row, { Text = p.DisplayName, TextSize = 15, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -110, 1, 0) })
                    local k = RoleBtn(row, "KICK", C.Red, UDim2.fromOffset(90, 30), UDim2.new(1, -94, 0, 3))
                    k.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Kick", p.UserId); task.delay(0.4, Render) end)
                    y += 40
                end
            end
            if n == 0 then Text(left, { Text = "Nobody's visiting.", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 20) }) end
        end
        UIStyle.PhoneScrollCard(left, 0)
        -- other players: VISIT (friends / party) or ASK (anyone in their hideout)
        local right = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.42, 8, 0, 0), Size = UDim2.new(0.58, -8, 1, 0), Parent = body })
        Text(right, { Text = "VISIT A HIDEOUT", TextSize = 18, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 26) })
        Text(right, { Text = "Friends and party members can walk straight in. Anyone else: ASK while they're in their hideout.", TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 34) })
        local list = Scroll(right, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 1, -66))
        local any = false
        for i, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                any = true
                local home = p:GetAttribute("HideoutOf") == p.UserId
                local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, Parent = list }, { UIStyle.Corner(2) })
                Text(row, { Text = p.DisplayName, TextSize = 16, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -250, 0, 22) })
                Text(row, { Text = home and "in their hideout" or (p:GetAttribute("RunId") and "in a run" or "in the city"), TextSize = 12, Font = UIStyle.BodyFont,
                    TextColor3 = home and C.Good or C.Sub, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -250, 0, 18) })
                local v = RoleBtn(row, "VISIT", ACCENT, UDim2.fromOffset(110, 38), UDim2.new(1, -234, 0, 6))
                v.Button.MouseButton1Click:Connect(function() hooks.Click(); local ok = Act("Visit", p.UserId); if ok then hooks.CloseAll() end end)
                local a = RoleBtn(row, "ASK", C.Blue, UDim2.fromOffset(110, 38), UDim2.new(1, -118, 0, 6))
                a.SetEnabled(home)
                a.Button.MouseButton1Click:Connect(function() if home then hooks.Click(); Act("RequestVisit", p.UserId) end end)
            end
        end
        if not any then Text(list, { Text = "Nobody else is in this server.", TextSize = 14, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 30) }) end
    end

    -- the 3D preview of one piece
    local function Preview(parent, id)
        local vp = New("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(26, 24, 30), Size = UDim2.new(1, 0, 0, 260), Ambient = Color3.fromRGB(170, 160, 160),
            LightColor = Color3.fromRGB(255, 236, 220), LightDirection = Vector3.new(-1, -1.2, -0.8), Parent = parent }, { UIStyle.Corner(2) })
        local m = HD.BuildPiece(vp, { I = id, X = 1, Z = 1, R = 0 })
        if m then
            local cf, size = m:GetBoundingBox()
            local r = math.max(size.X, size.Y, size.Z)
            local cam = Instance.new("Camera")
            cam.FieldOfView = 40
            cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(r * 0.9, r * 0.75, r * 1.3), cf.Position) -- (pieces face +Z: from the front)
            cam.Parent = vp
            vp.CurrentCamera = cam
        end
        return vp
    end
    local function RenderFurniture()
        local st = hooks.GetState() or {}
        local filters = { "All", "Gold", "Stations", "Drop", "Achievement", "Robux" }
        local fr = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.58, -8, 0, 32), Parent = body })
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = fr })
        for _, f in ipairs(filters) do
            local lbl = ({ All = "ALL", Gold = "SHOP", Stations = "STATIONS", Drop = "TROPHIES", Achievement = "EARNED", Robux = "PREMIUM" })[f]
            UIStyle.WordTab(fr, lbl, filter == f, function() hooks.Click(); filter = f; Render() end, 14) -- (UI CLEAN audit: word filters)
        end
        local list = Scroll(body, UDim2.fromOffset(0, 40), UDim2.new(0.58, -8, 1, -40))
        local n = 0
        for _, id in ipairs(HD.Order) do
            local def = HD.Items[id]
            local show = filter == "All" or (filter == "Stations" and def.Station ~= nil) or (filter == "Gold" and def.Source == "Gold" and not def.Station) or (def.Source == filter and filter ~= "Gold")
            if show then
                n += 1
                local own = HD.OwnedCount(st, id)
                local col = ItemData.RarityColors[def.Rarity] or C.Text
                local row = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = (selected == id) and UIStyle.Lighten(C.Card, 0.1) or C.Card,
                    Size = UDim2.new(1, 0, 0, 46), LayoutOrder = n, Parent = list }, { UIStyle.Corner(2) })
                New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 5, 1, -8), Position = UDim2.fromOffset(4, 4), Parent = row })
                Text(row, { Text = def.Name, TextSize = 15, TextColor3 = col, Position = UDim2.fromOffset(16, 3), Size = UDim2.new(1, -140, 0, 20) })
                Text(row, { Text = SOURCE_LABEL[def.Source] .. "  •  " .. def.W .. "x" .. def.D .. ((def.Layer == "Rug") and " rug" or ""), TextSize = 11, Font = UIStyle.BodyFont, TextColor3 = C.Sub,
                    Position = UDim2.fromOffset(16, 24), Size = UDim2.new(1, -140, 0, 16) })
                Text(row, { Text = (own > 0) and ("OWNED " .. own) or ((def.Source == "Gold") and (ItemData.FormatNumber(def.Price) .. " gold") or ((def.Source == "Robux") and (HD.BPPrice(def.Price) .. " BP") or "locked")),
                    TextSize = 14, TextColor3 = (own > 0) and C.Good or C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -130, 0, 0), Size = UDim2.new(0, 122, 1, 0) })
                row.MouseButton1Click:Connect(function() hooks.Click(); selected = id; Render() end)
            end
        end
        -- detail
        local det = New("Frame", { BackgroundColor3 = C.CardDark, Position = UDim2.new(0.58, 8, 0, 0), Size = UDim2.new(0.42, -8, 1, 0), Parent = body }, { UIStyle.Corner(2) })
        New("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = det })
        local id = selected or HD.Order[1]
        local def = HD.Items[id]
        Preview(det, id)
        local col = ItemData.RarityColors[def.Rarity] or C.Text
        Text(det, { Text = def.Name, TextSize = 22, TextColor3 = col, Position = UDim2.fromOffset(0, 268), Size = UDim2.new(1, 0, 0, 28) })
        Text(det, { Text = def.Rarity .. "  •  " .. SOURCE_LABEL[def.Source] .. "  •  " .. def.W .. "x" .. def.D .. " cells", TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, 296), Size = UDim2.new(1, 0, 0, 18) })
        local how = def.Desc .. (def.Station and ("\nUse it to open: " .. def.Station .. ".") or "") .. ((def.How and def.Source ~= "Gold") and ("\nHow to get: " .. def.How .. ".") or "")
        if def.Drop then how ..= "\nDrops more often on harder difficulties." end
        Text(det, { Text = how, TextSize = 14, Font = UIStyle.BodyFont, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 320), Size = UDim2.new(1, 0, 0, 90) })
        local own = HD.OwnedCount(st, id)
        Text(det, { Text = string.format("Owned %d / %d", own, def.Max), TextSize = 15, TextColor3 = (own > 0) and C.Good or C.Sub, Position = UDim2.fromOffset(0, 412), Size = UDim2.new(1, 0, 0, 20) })
        if (def.Source == "Gold" or def.Source == "Robux") and own < def.Max then
            local label = (def.Source == "Gold") and ("BUY  " .. ItemData.FormatNumber(def.Price) .. " GOLD") or ("BUY  " .. HD.BPPrice(def.Price) .. " BOUND POINTS")
            local b = RoleBtn(det, label, (def.Source == "Gold") and C.Gold or C.Green, UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 440))
            b.Button.MouseButton1Click:Connect(function()
                hooks.Click()
                if def.Source == "Robux" then BuyBP(def.Name, HD.BPPrice(def.Price), def.Desc, "Buy", id) return end
                local ok = Act("Buy", id); if ok then task.delay(0.3, Render) end
            end)
        end
        UIStyle.PhoneScrollCard(det, 0)
    end

    -- THEMES: prebuilt hideouts that replace the loft's look (the floor plan and your furniture stay)
    local function RenderThemes()
        local st = hooks.GetState() or {}
        local h = type(st.Hideout) == "table" and st.Hideout or {}
        local owned = type(h.Themes) == "table" and h.Themes or {}
        local current = HD.ThemeOf(st)
        Text(body, { Text = "Prebuilt hideouts change the whole look of your place. Your furniture stays where you put it, and you can keep building.", TextSize = 14,
            Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36) })
        local list = Scroll(body, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44))
        for i, id in ipairs(HD.THEME_ORDER) do
            local t = HD.THEMES[id]
            local have = t.Free or owned[id] == true
            local col = t.Rarity and (ItemData.RarityColors[t.Rarity] or C.Text) or C.Text
            local row = New("Frame", { BackgroundColor3 = (current == id) and UIStyle.Lighten(C.Card, 0.08) or C.Card, Size = UDim2.new(1, 0, 0, 96), LayoutOrder = i, Parent = list },
                { UIStyle.Corner(2), UIStyle.Stroke((current == id) and ACCENT or C.Border, (current == id) and 2 or 1) })
            Text(row, { Text = t.Name .. ((current == id) and "   (SHOWN)" or ""), TextSize = 19, TextColor3 = col, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -260, 0, 24) })
            Text(row, { Text = t.Desc, TextSize = 13, Font = UIStyle.BodyFont, TextWrapped = true, TextColor3 = C.Sub, TextYAlignment = Enum.TextYAlignment.Top,
                Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -260, 0, 54) })
            local label, colB, fn
            if current == id then
                label, colB = "SHOWN", C.Off
            elseif have then
                label, colB, fn = "USE THIS", ACCENT, function() Act("SetTheme", id) end
            else
                label = "BUY  " .. HD.THEME_BP .. " BOUND POINTS" -- (0.97 BOUND SHOP)
                colB, fn = C.Green, function() BuyBP(t.Name, HD.THEME_BP, t.Desc, "BuyTheme", id) end
            end
            local b = RoleBtn(row, label, colB, UDim2.fromOffset(220, 46), UDim2.new(1, -234, 0, 25))
            if fn then b.Button.MouseButton1Click:Connect(function() hooks.Click(); fn(); task.delay(0.4, Render) end) else b.SetEnabled(false) end
        end
    end

    Render = function()
        HideoutClient._render = Render
        if not panel.Visible then return end
        Clear(tabsRow); New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = tabsRow })
        TabButton("Home", "HOME")
        TabButton("Furniture", "FURNITURE")
        TabButton("Themes", "THEMES")
        Clear(body)
        if tab == "Home" then RenderHome() elseif tab == "Themes" then RenderThemes() else RenderFurniture() end
    end
    panel:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Visible then Render() end end)
    -- a teleport is about to land in a hideout: draw it first (the floor must be there when you arrive)
    api.Prepare = function(cf: CFrame)
        if Zones.InHideout(cf.Position) then
            local theme = ThemeFor(Players:GetPlayerByUserId(OwnerId() or LocalPlayer.UserId))
            if not shell or shell:GetAttribute("Theme") ~= theme then MakeShell(theme) end
        end
    end
    api.Toggle = function()
        if panel.Visible then hooks.CloseAll() return end
        if LocalPlayer:GetAttribute("RunId") then hooks.Toast("Not during a run.") return end
        tab = "Home"
        hooks.OpenFrame(panel)
    end
    api.OpenShop = function()
        tab, filter = "Furniture", "Gold"
        if not panel.Visible then hooks.OpenFrame(panel) else Render() end
    end
    api.OnState = function() if panel.Visible then Render() end if api.RefreshBar then api.RefreshBar() end end
    api.Panel = panel

    -- ===================== the visit-request popup =====================
    local pop = New("Frame", { Name = "VisitRequestPopup", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Size = UDim2.fromOffset(440, 92),
        BackgroundColor3 = C.Card, Visible = false, ZIndex = 50, Parent = hudGui }, { UIStyle.Corner(2), UIStyle.Stroke(ACCENT, 2) })
    local popText = UIStyle.Text({ Text = "", TextSize = 17, ZIndex = 51, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Parent = pop })
    local yes = RoleBtn(pop, "LET THEM IN", C.Green, UDim2.fromOffset(190, 38), UDim2.fromOffset(14, 44))
    local no = RoleBtn(pop, "NO THANKS", C.Red, UDim2.fromOffset(190, 38), UDim2.fromOffset(234, 44))
    for _, b in ipairs({ yes, no }) do b.Button.ZIndex = 51 for _, d in ipairs(b.Button:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 52 end end end
    local popFrom = nil
    yes.Button.MouseButton1Click:Connect(function() pop.Visible = false; if popFrom then hooks.Click(); Act("RespondVisit", popFrom, true) end end)
    no.Button.MouseButton1Click:Connect(function() pop.Visible = false; if popFrom then hooks.Click(); Act("RespondVisit", popFrom, false) end end)
    Remotes.GetEvent("HideoutUpdate").OnClientEvent:Connect(function(kind: string, data: any)
        if kind == "VisitRequest" then
            popFrom = data.FromId
            popText.Text = data.From .. " wants to visit your hideout"
            pop.Visible = true
            hooks.Click()
            task.delay(25, function() if popFrom == data.FromId then pop.Visible = false end end)
        elseif kind == "Toast" then
            hooks.Toast(tostring(data))
        elseif kind == "Got" then
            if panel.Visible then Render() end
        end
    end)

    -- ===================== BUILD MODE =====================
    local building = false
    local pick = nil -- { Id, Rot, MoveIndex? }
    local ghost = nil
    local ghostOk = false
    local ghostCell = nil
    local bar = New("Frame", { Name = "HideoutBuildBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0, 900, 0, 150),
        BackgroundColor3 = C.CardDark, Visible = false, ZIndex = 40, Parent = hudGui }, { UIStyle.Corner(2), UIStyle.Stroke(ACCENT, 2) })
    local hint = UIStyle.Text({ Text = "", TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Text, ZIndex = 41, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 18), Parent = bar })
    local strip = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -150, 1, -36), ScrollBarThickness = 6,
        ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ZIndex = 41, Parent = bar })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = strip })
    local done = RoleBtn(bar, "DONE", C.Green, UDim2.fromOffset(120, 50), UDim2.new(1, -130, 0, 30))
    local shopB = RoleBtn(bar, "SHOP", C.Gold, UDim2.fromOffset(120, 44), UDim2.new(1, -130, 0, 90))
    -- (touch screens: the keys R / Q / DELETE as buttons over the bar's top-right; shown by api.TouchRow)
    local turnB = RoleBtn(bar, "TURN", C.Steel, UDim2.fromOffset(110, 44), UDim2.new(1, -370, 0, -52))
    local cancelB = RoleBtn(bar, "CANCEL", C.Steel, UDim2.fromOffset(110, 44), UDim2.new(1, -250, 0, -52))
    local takeB = RoleBtn(bar, "TAKE BACK", C.Red, UDim2.fromOffset(120, 44), UDim2.new(1, -130, 0, -52))
    for _, b in ipairs({ done, shopB, turnB, cancelB, takeB }) do b.Button.ZIndex = 41 for _, d in ipairs(b.Button:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 42 end end end
    function api.TouchRow()
        local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        turnB.Button.Visible = touch and pick ~= nil
        cancelB.Button.Visible = touch and pick ~= nil
        takeB.Button.Visible = touch and pick ~= nil and pick.MoveIndex ~= nil
    end
    -- (phones: the bar is a HUD piece at the HUD's short-screen scale -- 900 px wide -> ~500 pt with ~7 pt text; it gets
    -- the phone window scale, fitted to the width)
    local barScale = New("UIScale", { Parent = bar })
    local function FitBar()
        if not UIStyle.IsPhone() then barScale.Scale = 1 return end
        local gui = bar:FindFirstAncestorWhichIsA("LayerCollector")
        local hs = gui and gui:FindFirstChildOfClass("UIScale")
        local kk = (hs and hs.Scale or 1) / UIStyle.SimK()
        local vs = UIStyle.Screen()
        barScale.Scale = math.min(UIStyle.PhoneScale(), (vs.X - 16) / 900) / kk
    end
    bar:GetPropertyChangedSignal("Visible"):Connect(function() if bar.Visible then FitBar() end end)
    local function ClearGhost()
        if ghost then ghost:Destroy(); ghost = nil end
        -- a piece being moved shows again
        if furn then for _, m in ipairs(furn:GetChildren()) do for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") and d.Name ~= "Hitbox" then d.LocalTransparencyModifier = 0 end end end end
    end
    local function Remaining(id: string): number
        local st = hooks.GetState() or {}
        return HD.OwnedCount(st, id) - HD.PlacedCount(layout, id)
    end
    function api.RefreshBar()
        if not building then return end
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            hint.Text = pick and "Tap the floor to place  •  TURN / CANCEL above  •  drag turns the view, pinch zooms" or "Pick a piece  •  tap a placed piece to move it or TAKE BACK  •  drag turns the view"
        else
            hint.Text = pick and "Click to place  •  R turn  •  Q cancel  •  right-drag turns the view, wheel zooms" or "Pick a piece  •  click a placed piece to move it  •  DELETE / X over a piece takes it back  •  right-drag turns the view"
        end
        if api.TouchRow then api.TouchRow() end
        for _, c in ipairs(strip:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local st = hooks.GetState() or {}
        local n = 0
        for _, id in ipairs(HD.Order) do
            local left = Remaining(id)
            if left > 0 then
                n += 1
                local def = HD.Items[id]
                local col = ItemData.RarityColors[def.Rarity] or C.Text
                local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = (pick and pick.Id == id and not pick.MoveIndex) and UIStyle.Lighten(C.Card, 0.15) or C.Card,
                    Size = UDim2.fromOffset(120, 104), LayoutOrder = n, ZIndex = 42, Parent = strip }, { UIStyle.Corner(2), UIStyle.Stroke(col, 1.5) })
                UIStyle.Text({ Text = def.Name, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = col, ZIndex = 43, Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 0, 52), Parent = b })
                UIStyle.Text({ Text = def.W .. "x" .. def.D .. "  •  x" .. left, TextSize = 12, Font = UIStyle.BodyFont, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Sub, ZIndex = 43, Position = UDim2.fromOffset(4, 70), Size = UDim2.new(1, -8, 0, 20), Parent = b })
                b.MouseButton1Click:Connect(function()
                    hooks.Click()
                    ClearGhost()
                    pick = { Id = id, Rot = 0 }
                    api.RefreshBar()
                end)
            end
        end
        if n == 0 then UIStyle.Text({ Text = "Nothing left to place. Buy furniture in the SHOP (or the Bazaar's furniture stall).", TextSize = 14, TextColor3 = C.Sub, ZIndex = 43, Size = UDim2.fromOffset(600, 60), Parent = strip }) end
    end
    -- (2026-10-13 phones: build mode only listened to the mouse -- a tap placed nothing. `pointer` = the last TAP in
    -- viewport pixels (touch positions are GUI space: + the top-bar inset), nil = follow the mouse)
    local pointer: Vector2? = nil
    local function PointerPos(): Vector2
        return pointer or UserInputService:GetMouseLocation()
    end
    local function MouseCell(id: string, rot: number): (number?, number?)
        local cam = workspace.CurrentCamera
        local m = PointerPos()
        local ray = cam:ViewportPointToRay(m.X, m.Y)
        local y0 = HD.Origin.Y
        if math.abs(ray.Direction.Y) < 1e-3 then return nil end
        local t = (y0 - ray.Origin.Y) / ray.Direction.Y
        if t < 0 then return nil end
        local hit = ray.Origin + ray.Direction * t - HD.Origin
        local w, d = HD.Footprint(id, rot)
        local G, Rm = HD.GRID, HD.ROOM
        local gx = math.floor((hit.X - Rm.X0) / G - w / 2 + 0.5) + 1
        local gz = math.floor((hit.Z - Rm.Z0) / G - d / 2 + 0.5) + 1
        return gx, gz
    end
    local function PieceUnderMouse(): (Model?, number?)
        if not furn then return nil end
        local cam = workspace.CurrentCamera
        local m = PointerPos()
        local ray = cam:ViewportPointToRay(m.X, m.Y)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Include
        local hbs = {}
        for _, mm in ipairs(furn:GetChildren()) do local hb = mm:FindFirstChild("Hitbox") if hb then table.insert(hbs, hb) end end
        rp.FilterDescendantsInstances = hbs
        local r = workspace:Raycast(ray.Origin, ray.Direction * 300, rp)
        if not r then return nil end
        local model = r.Instance.Parent
        return model, model:GetAttribute("Index")
    end
    local stepConn
    local function UpdateGhost()
        if not (building and pick) then if ghost then ClearGhost() end return end
        local gx, gz = MouseCell(pick.Id, pick.Rot)
        if not gx then return end
        local key = gx .. "," .. gz .. "," .. pick.Rot
        if ghost and ghostCell == key then return end
        ghostCell = key
        if ghost then ghost:Destroy() end
        local e = { I = pick.Id, X = gx, Z = gz, R = pick.Rot }
        ghostOk = HD.CanPlace(layout, pick.Id, gx, gz, pick.Rot, pick.MoveIndex, HD.ExpLevel(hooks.GetState() or {}))
        ghost = HD.BuildPiece(world, e)
        if ghost then
            ghost.Name = "BuildGhost"
            for _, d in ipairs(ghost:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.CanCollide = false; d.CanQuery = false
                    if d.Name == "Hitbox" then
                        d.Transparency = 0.6; d.Material = Enum.Material.Neon
                        d.Color = ghostOk and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(255, 70, 70)
                        d.Size = Vector3.new(d.Size.X, 0.2, d.Size.Z)
                    else
                        d.Transparency = math.max(d.Transparency, 0.35)
                    end
                end
            end
            local hb = ghost:FindFirstChild("Hitbox")
            if hb then hb.CFrame = CFrame.new(HD.Origin + HD.CellCenter(pick.Id, gx, gz, pick.Rot) + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, -pick.Rot * math.pi / 2, 0) end
        end
    end
    -- the BUILD CAMERA: an overview of the whole room (the hub's shoulder camera clips the walls in a small room);
    -- right-drag turns it round the room, the wheel zooms, the cursor stays free for placing
    local camYaw, camPitch, camDist = math.rad(35), math.rad(-52), 82
    local lastMouse = nil
    local function BuildCam()
        local cam = workspace.CurrentCamera
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            -- (2026-10-07, owner: "your hideout currently doesnt allow you to look around": the hub camera locks the mouse
            -- in place while right mouse is held, so the cursor never moved and this never turned. Read the mouse DELTA,
            -- and the cursor's own movement as a fallback.)
            local m = UserInputService:GetMouseLocation()
            local d = UserInputService:GetMouseDelta()
            if d.Magnitude < 1e-3 and lastMouse then d = m - lastMouse end
            if lastMouse or d.Magnitude > 0 then
                camYaw -= d.X * 0.008
                camPitch = math.clamp(camPitch - d.Y * 0.006, math.rad(-80), math.rad(-25))
            end
            lastMouse = m
        else
            lastMouse = nil
        end
        local center = HD.Origin + Vector3.new(12, 2, 6) -- (0.58: the bigger room's middle)
        local rot = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)
        cam.CFrame = CFrame.new(center) * rot * CFrame.new(0, 0, camDist)
    end
    UserInputService.InputChanged:Connect(function(input, gp)
        if building and input.UserInputType == Enum.UserInputType.MouseWheel and not gp then
            camDist = math.clamp(camDist - input.Position.Z * 4, 30, 125)
        end
    end)
    function api.StartBuild()
        if not InOwn() then hooks.Toast("Build mode works in your own hideout.") return end
        RunService:BindToRenderStep("HideoutBuildCam", Enum.RenderPriority.Last.Value + 2, BuildCam)
        if shell then for _, p in ipairs(shell:GetDescendants()) do if p:IsA("BasePart") and p:GetAttribute("Roof") then p.LocalTransparencyModifier = 1 end end end
        building = true
        pick = nil
        bar.Visible = true
        api.RefreshBar()
        if stepConn then stepConn:Disconnect() end
        stepConn = RunService.RenderStepped:Connect(function()
            if not building then return end
            if not InOwn() then api.StopBuild() return end
            UpdateGhost()
        end)
    end
    function api.StopBuild()
        pcall(function() RunService:UnbindFromRenderStep("HideoutBuildCam") end)
        if shell then for _, p in ipairs(shell:GetDescendants()) do if p:IsA("BasePart") and p:GetAttribute("Roof") then p.LocalTransparencyModifier = 0 end end end
        building = false
        pick = nil
        bar.Visible = false
        ClearGhost()
        if stepConn then stepConn:Disconnect(); stepConn = nil end
    end
    done.Button.MouseButton1Click:Connect(function() hooks.Click(); api.StopBuild() end)
    turnB.Button.MouseButton1Click:Connect(function() if pick then hooks.Click(); pick.Rot = (pick.Rot + 1) % 4; ghostCell = nil end end)
    cancelB.Button.MouseButton1Click:Connect(function() hooks.Click(); pick = nil; ghostCell = nil; ClearGhost(); api.RefreshBar() end)
    takeB.Button.MouseButton1Click:Connect(function()
        if pick and pick.MoveIndex and Act("Remove", pick.MoveIndex) then hooks.Click(); pick = nil; ClearGhost(); api.RefreshBar() end
    end)
    shopB.Button.MouseButton1Click:Connect(function() hooks.Click(); api.OpenShop() end)
    api.OnLayout = function() if building then ghostCell = nil; ClearGhost(); api.RefreshBar() end end
    -- a click (mouse) or a tap (touch) at the pointer: place the picked piece, or pick a placed one up to move it
    local function Tap()
            if pick then
                local gx, gz = MouseCell(pick.Id, pick.Rot)
                if gx then
                    local ok
                    if pick.MoveIndex then ok = Act("Move", pick.MoveIndex, gx, gz, pick.Rot) else ok = Act("Place", pick.Id, gx, gz, pick.Rot) end
                    if ok then
                        hooks.Sound("Equip")
                        local keep = (not pick.MoveIndex) and Remaining(pick.Id) > 1
                        pick = keep and { Id = pick.Id, Rot = pick.Rot } or nil
                        ghostCell = nil
                        ClearGhost()
                        api.RefreshBar()
                    end
                end
            else
                local model, idx = PieceUnderMouse()
                if model and idx and layout[idx] then
                    pick = { Id = layout[idx].I, Rot = layout[idx].R or 0, MoveIndex = idx }
                    for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.LocalTransparencyModifier = 0.8 end end
                    api.RefreshBar()
                end
            end
    end
    -- touch: a short tap = Tap() at that spot, a one-finger drag turns the build camera, a pinch zooms
    local touchDown = nil -- { input, start, t, moved }
    local pinch0 = nil
    UserInputService.TouchPinch:Connect(function(_, scale, _, state, gp)
        if not building or gp then return end
        if state == Enum.UserInputState.Begin then pinch0 = camDist
        elseif state == Enum.UserInputState.Change and pinch0 then camDist = math.clamp(pinch0 / math.max(scale, 0.2), 30, 125) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then pointer = nil end -- (the mouse again: follow it)
        if not (building and touchDown and input == touchDown.input) then return end
        local d = input.Delta
        if (input.Position - touchDown.start).Magnitude > 12 then
            touchDown.moved = true
            camYaw -= d.X * 0.008
            camPitch = math.clamp(camPitch - d.Y * 0.006, math.rad(-80), math.rad(-25))
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not (touchDown and input == touchDown.input) then return end
        local td = touchDown
        touchDown = nil
        if building and not td.moved and os.clock() - td.t < 0.6 then
            local ins = game:GetService("GuiService"):GetGuiInset()
            pointer = Vector2.new(input.Position.X + ins.X, input.Position.Y + ins.Y)
            ghostCell = nil
            UpdateGhost()
            Tap()
        end
    end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if not building or hooks.IsTyping() then return end
        if input.UserInputType == Enum.UserInputType.Touch then
            if gp then return end -- (a tap on the bar / a window)
            touchDown = { input = input, start = input.Position, t = os.clock(), moved = false }
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if gp then return end -- (a click on the bar / a window)
            pointer = nil
            Tap()
        elseif input.KeyCode == Enum.KeyCode.R and pick then
            pick.Rot = (pick.Rot + 1) % 4
            ghostCell = nil
        elseif input.KeyCode == Enum.KeyCode.Q and pick then -- (right mouse stays the camera orbit)
            pick = nil; ghostCell = nil; ClearGhost(); api.RefreshBar()
        elseif input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Backspace then
            local _, idx = PieceUnderMouse()
            if idx then
                if Act("Remove", idx) then hooks.Sound("Click"); pick = nil; ClearGhost() end
            end
        end
    end)
    return api
end

return HideoutClient
