--!nocheck
-- ============================================================================================
-- SPECTATE, client (0.62; server: AimRngServer/SpectateService). From the city: the SPECTATE window lists players in
-- runs; WATCH looks through their eyes (AimRngClient's spectate camera: their facing + shared AimPitch) holding THEIR
-- gun in THEIR skin (a ViewmodelRig built from the look the server sends), firing when they fire (ShotFx relay).
-- A SOLO target's floor only exists on their client, so this client builds the same floor from its config (seed,
-- biome, layout ...) and moves its enemies as PUPPETS to the positions the server streams (they target nobody here:
-- DungeonGenerator.TargetPlayers returns {} while WatchUid is set). A PARTY target's floor is server-built:
-- DungeonClient just shows it. Your own body waits in the city (anchored); nobody sees it while you watch.
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local LocalPlayer = Players.LocalPlayer

local SpectateClient = {}

local function SplitMods(s: any): { string }?
    if type(s) ~= "string" or s == "" then return nil end
    return string.split(s, ",")
end

-- hooks: menuFolder, OpenFrame(f), CloseAll(), Toast(msg), Click(), SetTarget(player?), SetMouseLocked(on), Hud (ScreenGui)
function SpectateClient.Init(hooks: any)
    local C = UIStyle.Colors
    local ACC = Color3.fromRGB(120, 200, 255)
    local api = {}
    local target: Player? = nil
    local floor: Instance? = nil -- the puppet floor (solo targets)
    local floorCfg: any = nil
    local puppets: { [string]: Model } = {}
    local goal: { [string]: any } = {}
    local at: { [string]: Vector3 } = {} -- (where each puppet is drawn: its own AI moves the model too, so not read back)
    local rig, rigHolder = nil, nil
    local duelInfo: any = nil -- (0.79: watching a duel -- the score / health / arena from SpectateFeed "Duel")
    local lookKey = nil
    local conns = {}

    local function Act(...)
        local ok, a, b = pcall(function(...) return Remotes.GetFunction("SpectateAction"):InvokeServer(...) end, ...)
        if not ok then hooks.Toast("Couldn't reach the server."); return false end
        if a == false and b then hooks.Toast(b) end
        return a, b
    end

    -- ===== LIVE VIEW (0.83, owner: "The spectating is also incredibly desynced ... Its very choppy and inaccurate. I want it
    -- to be as accurate as possible to properly showcase the players aim") =====
    -- The watched client streams its REAL camera (CFrame + FOV, ~30/s) and, on a solo floor, the enemies it sees (~15/s),
    -- all stamped with the shared server clock. Here everything plays back at (now - delay) with interpolation, so view,
    -- enemies, shots and hits stay in step and move smoothly. delay = the measured one-way latency + a jitter margin.
    local camBuf: { any } = {} -- { { stamp, CFrame, fov } } in stamp order
    local worldBuf: { [string]: { any } } = {} -- enemy id -> { { stamp, Vector3 } }
    local latEMA = 0.12
    local currentLook: any = nil
    local function Delay(): number return math.clamp(latEMA + 0.07, 0.1, 0.45) end
    api.Delay = Delay
    local function PushSample(buf: { any }, item: any)
        table.insert(buf, item)
        local i = #buf
        while i > 1 and buf[i - 1][1] > buf[i][1] do buf[i - 1], buf[i] = buf[i], buf[i - 1]; i -= 1 end -- (unreliable: may arrive out of order)
        local cut = item[1] - 1.5
        while #buf > 2 and buf[1][1] < cut do table.remove(buf, 1) end
    end
    local function Sample(buf: { any }, t: number): (any, any, number)
        local n = #buf
        if t <= buf[1][1] then return buf[1], buf[1], 0 end
        if t >= buf[n][1] then return buf[n], buf[n], 0 end
        for i = n - 1, 1, -1 do
            local a = buf[i]
            if a[1] <= t then
                local b = buf[i + 1]
                local span = b[1] - a[1]
                return a, b, (span > 0) and (t - a[1]) / span or 0
            end
        end
        return buf[1], buf[1], 0
    end
    local function ClearStream()
        table.clear(camBuf)
        table.clear(worldBuf)
    end
    Remotes.GetEvent("SpecCam").OnClientEvent:Connect(function(uid: any, stamp: any, cf: any, fov: any)
        if not target or target.UserId ~= uid or type(stamp) ~= "number" or typeof(cf) ~= "CFrame" then return end
        latEMA += (math.clamp(Workspace:GetServerTimeNow() - stamp, 0, 1) - latEMA) * 0.08
        PushSample(camBuf, { stamp, cf, tonumber(fov) or 70 })
    end)
    Remotes.GetEvent("SpecWorld").OnClientEvent:Connect(function(uid: any, stamp: any, ids: any, poss: any)
        if not target or target.UserId ~= uid or type(stamp) ~= "number" or type(ids) ~= "table" or type(poss) ~= "table" then return end
        for i, id in ipairs(ids) do
            local p = poss[i]
            if typeof(p) == "Vector3" then
                local key = tostring(id)
                worldBuf[key] = worldBuf[key] or {}
                PushSample(worldBuf[key], { stamp, p })
            end
        end
    end)
    -- the watched camera right now (nil = no live stream: the old facing + pitch view is used)
    function api.CameraNow(): (CFrame?, number?)
        if not target or #camBuf == 0 then return nil end
        if Workspace:GetServerTimeNow() - camBuf[#camBuf][1] > 1.5 then return nil end
        local a, b, k = Sample(camBuf, Workspace:GetServerTimeNow() - Delay())
        return a[2]:Lerp(b[2], k), a[3] + (b[3] - a[3]) * k
    end
    local function WorldAt(id: string, t: number): Vector3?
        local buf = worldBuf[id]
        if not buf or #buf == 0 or Workspace:GetServerTimeNow() - buf[#buf][1] > 1 then return nil end
        local a, b, k = Sample(buf, t)
        return a[2]:Lerp(b[2], k)
    end
    -- run fn when the playback reaches the watched player's moment `stamp` (shots, hits: in step with the view)
    function api.AtStamp(stamp: any, fn: () -> ())
        if type(stamp) ~= "number" then fn(); return end
        local wait = stamp + Delay() - Workspace:GetServerTimeNow()
        if wait <= 0.005 then fn() else task.delay(math.min(wait, 1), fn) end
    end

    -- ===== the window =====
    local panel = UIStyle.Panel(hooks.menuFolder, { Name = "SpectateMenu", Size = UDim2.fromOffset(600, 500), Accent = ACC })
    UIStyle.TitleBar(panel, "SPECTATE", ACC, "watch a run through the player's eyes, with their gun and skin", function() hooks.CloseAll() end)
    local list = Instance.new("ScrollingFrame")
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Position = UDim2.fromOffset(16, 80)
    list.Size = UDim2.new(1, -32, 1, -130)
    list.CanvasSize = UDim2.new()
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ScrollBarThickness = 6
    list.Parent = panel
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = list
    local function Txt(parent, props)
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Font = UIStyle.HeaderFont or Enum.Font.GothamBold
        t.TextColor3 = C.Text or Color3.new(1, 1, 1)
        t.TextXAlignment = Enum.TextXAlignment.Left
        for k, v in pairs(props) do t[k] = v end
        t.Parent = parent
        return t
    end
    local refresh = UIStyle.Button(panel, "REFRESH", C.Steel, UDim2.fromOffset(140, 36), UDim2.new(1, -156, 1, -46))

    local function Render()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local ok, rows = Act("List")
        if not ok then return end
        if #rows == 0 then
            Txt(list, { Text = "Nobody is in a run or a duel right now. Players who turned Allow Spectators off (Settings > Social) aren't listed.",
                TextSize = 14, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 44) })
        end
        for i, r in ipairs(rows) do
            local row = Instance.new("Frame")
            row.BackgroundColor3 = C.Card
            row.Size = UDim2.new(1, -8, 0, 62)
            row.LayoutOrder = i
            row.Parent = list
            Txt(row, { Text = string.upper(tostring(r.Name)) .. (r.Level and ("  •  LV " .. tostring(r.Level)) or ""), TextSize = 17, TextColor3 = ACC,
                Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 22) })
            local bits = {}
            if r.Kind == "Duel" and type(r.Duel) == "table" then
                table.insert(bits, "DUEL vs " .. string.upper(tostring(r.Duel.Opp)))
                table.insert(bits, tostring(r.Duel.MyFrags) .. " - " .. tostring(r.Duel.OppFrags))
                table.insert(bits, string.upper(tostring(r.Duel.Arena)))
            else
                table.insert(bits, r.Kind == "Party" and "PARTY RUN" or (r.Rift and "MAP" or "SOLO RUN"))
            end
            if r.Difficulty then table.insert(bits, string.upper(tostring(r.Difficulty))) end
            if r.Floor then table.insert(bits, "FLOOR " .. tostring(r.Floor)) end
            if r.Biome then table.insert(bits, string.upper(tostring(r.Biome))) end
            if (r.Watchers or 0) > 0 then table.insert(bits, tostring(r.Watchers) .. " watching") end
            Txt(row, { Text = table.concat(bits, "  •  "), TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub,
                Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 20) })
            local b = UIStyle.Button(row, "WATCH", ACC, UDim2.fromOffset(120, 40), UDim2.new(1, -130, 0, 11))
            b.Button.MouseButton1Click:Connect(function()
                hooks.Click()
                local okW = Act("Watch", r.UserId)
                if okW then hooks.CloseAll() end
            end)
        end
    end
    refresh.Button.MouseButton1Click:Connect(function() hooks.Click(); Render() end)
    function api.Watch(uid: number) -- (0.79: from the Duel window)
        local okW = Act("Watch", uid)
        if okW then hooks.CloseAll() end
        return okW
    end
    function api.Open()
        if LocalPlayer:GetAttribute("WatchUid") then Act("Stop") return end
        hooks.OpenFrame(panel)
        task.spawn(Render)
    end

    -- ===== the watching bar =====
    local bar = Instance.new("Frame")
    bar.Name = "SpectateWatchBar"
    bar.AnchorPoint = Vector2.new(0.5, 1)
    bar.Position = UDim2.new(0.5, 0, 1, -24)
    bar.Size = UDim2.fromOffset(720, 54) -- (0.79: 560 -> 720, a duel line is longer)
    bar.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
    bar.BackgroundTransparency = 0.1
    bar.Visible = false
    bar.Parent = hooks.Hud
    local stroke = UIStyle.InkEdge and UIStyle.InkEdge(2)
    if stroke then stroke.Parent = bar end
    local barLbl = Txt(bar, { Text = "", TextSize = 16, TextColor3 = ACC, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -150, 0, 22) })
    local barSub = Txt(bar, { Text = "", TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -150, 0, 18) })
    local stopB = UIStyle.Button(bar, "STOP", Color3.fromRGB(220, 70, 70), UDim2.fromOffset(110, 36), UDim2.new(1, -120, 0, 9))
    stopB.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Stop") end)

    -- ===== the puppet floor =====
    local function ClearPuppets()
        for id, m in pairs(puppets) do if m.Parent then m:Destroy() end; puppets[id] = nil end
        table.clear(goal)
        table.clear(at)
    end
    local function ClearFloor()
        ClearPuppets()
        if floor then floor:Destroy(); floor = nil end
        floorCfg = nil
    end
    local function ClearRig()
        if rig then pcall(function() rig:StopBeam() end); pcall(function() rig:Destroy() end); rig = nil end
        if rigHolder then rigHolder:Destroy(); rigHolder = nil end
        lookKey = nil
    end
    local function BuildRig(look: any)
        if type(look) ~= "table" or not look.BaseId then return end
        local SkinFX = require(Shared:WaitForChild("SkinFX"))
        local key = tostring(look.BaseId) .. "|" .. tostring(look.Cos and look.Cos[SkinFX.EquipKey(look.BaseId)]) .. "|" .. tostring(look.Weapon and look.Weapon.Uid)
            .. "|" .. tostring((SkinFX.GunSkinFor({ CosmeticsEquipped = look.Cos or {}, Colorways = look.Colorways }, look.BaseId) or {}).FX) -- (0.93 colourways)
        if key == lookKey and rig then return end
        ClearRig()
        lookKey = key
        local ViewmodelRig = require(Shared:WaitForChild("ViewmodelRig"))
        if not ViewmodelRig.HasRig(look.BaseId) then return end
        local cosState = { CosmeticsEquipped = look.Cos or {}, Colorways = look.Colorways }
        local skin = SkinFX.GunSkinFor(cosState, look.BaseId) or ItemData.WeaponSkins.Factory
        rigHolder = Instance.new("Model")
        rigHolder.Name = "SpectateViewmodel"
        rigHolder.Parent = Workspace.CurrentCamera
        local ok, err = pcall(function()
            rig = ViewmodelRig.new(rigHolder)
            rig:SetWeapon(look.BaseId, look.Weapon, skin)
            local GloveFX = require(Shared:WaitForChild("GloveFX"))
            rig:ApplyCosmetics({ Glove = ItemData.Gloves.Tactical, Sleeve = ItemData.ArmSkins.Standard, Skin = skin,
                HandFX = { Glove = GloveFX.GloveFor(cosState), Sleeve = GloveFX.SleeveFor(cosState) } })
            rig:SetVisible(true)
            rig:Play("Equip")
        end)
        if not ok then warn("[Spectate] rig: " .. tostring(err)); ClearRig() end
    end

    local pendingRoster: { any }? = nil -- (0.93: a roster that came before its floor was built)
    local OnRoster: (rows: { any }) -> ()
    local function OnFloor(cfg: any, look: any, who: Player?)
        pendingRoster = nil -- (before the gun loads: a roster that lands during that wait is kept for this floor)
        target = who
        hooks.SetTarget(who)
        BuildRig(look)
        ClearStream()
        currentLook = look
        if hooks.ApplyLook then pcall(hooks.ApplyLook, look) end -- (0.83: their settings, theme, bar style)
        duelInfo = nil
        if cfg.Duel then -- (0.79: the arena is server-built -- nothing to build, just the duel's light)
            ClearFloor()
            SpectateClient.Light = "Pvp"
            return
        end
        if cfg.Party then
            ClearFloor()
            SpectateClient.Light = nil
            local DC = require(Shared:WaitForChild("DungeonClient"))
            if DC.RefreshRunVisibility then DC.RefreshRunVisibility() end
            return
        end
        ClearFloor()
        local DungeonGenerator = require(Shared:WaitForChild("DungeonGenerator"))
        floorCfg = {
            Biome = cfg.Biome, Difficulty = cfg.Difficulty, Endless = cfg.Endless == true, FloorNumber = cfg.FloorNumber,
            PlayerLevel = cfg.PlayerLevel, Seed = cfg.Seed, BotSkill = cfg.BotSkill, Mods = cfg.Mods, BossArena = cfg.BossArena, Layout = cfg.Layout,
        }
        local ok, f = pcall(DungeonGenerator.BuildThemedDungeon, floorCfg)
        if ok and f then
            floor = f
            f:SetAttribute("SpectateFloor", true)
            SpectateClient.Light = tostring(cfg.Biome or "Fire") .. (cfg.BossArena and ":Boss" or "")
            if pendingRoster then local rows = pendingRoster; pendingRoster = nil; OnRoster(rows) end -- (0.93: the early roster)
        else
            warn("[Spectate] floor: " .. tostring(f))
        end
    end

    OnRoster = function(rows: { any })
        -- (0.93, owner: "The spectating just shows like an empty biome and the players gun, you cant see any enemies"):
        -- the server sends Floor then Roster in the same tick, but OnFloor yields while it loads the gun model (BuildRig)
        -- and builds the floor -- the Roster arrived with no floor yet and was DROPPED, and the server only re-sent it when
        -- the enemy set changed. Now it waits here and OnFloor applies it once the floor exists.
        if not floor or not floorCfg then pendingRoster = rows; return end
        local DungeonGenerator = require(Shared:WaitForChild("DungeonGenerator"))
        local keep = {}
        for _, a in ipairs(rows) do
            local id = tostring(a.EnemyId)
            keep[id] = true
            if not puppets[id] then
                local pos = a.SpawnPos or Vector3.new(0, 10, 600)
                local spec = { EnemyId = a.EnemyId, Element = a.Element, MaxHealth = a.MaxHealth, AttackDamage = a.AttackDamage }
                local ok, m = pcall(DungeonGenerator.CreateOfKind, a.Kind, a.Archetype, SplitMods(a.EliteMods), pos, floorCfg, floor, spec)
                if ok and m then
                    m:SetAttribute("LocalSim", true)
                    m:SetAttribute("Puppet", true)
                    for _, k in ipairs({ "Health", "MaxHealth", "IsElite", "EliteTier", "BossTitle", "BossColor", "BossPhases", "BossInfo", "DamageTakenMult" }) do
                        if a[k] ~= nil then m:SetAttribute(k, a[k]) end
                    end
                    puppets[id] = m
                end
            end
        end
        for id, m in pairs(puppets) do
            if not keep[id] then
                puppets[id] = nil
                goal[id] = nil
                at[id] = nil
                if m.Parent then
                    m:SetAttribute("Dead", true)
                    pcall(function() require(Shared:WaitForChild("EnemyAnim")).Death(m) end)
                    task.delay(0.15, function() if m.Parent then m:Destroy() end end)
                end
            end
        end
    end

    local function Stop(why: string?)
        target = nil
        duelInfo = nil
        ClearStream()
        currentLook = nil
        if hooks.ApplyLook then pcall(hooks.ApplyLook, nil) end
        hooks.SetTarget(nil)
        ClearRig()
        ClearFloor()
        SpectateClient.Light = nil
        bar.Visible = false
        local DC = require(Shared:WaitForChild("DungeonClient"))
        if DC.RefreshRunVisibility then DC.RefreshRunVisibility() end
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then (root :: BasePart).Anchored = false end
        if why then hooks.Toast(why) end
    end

    Remotes.GetEvent("SpectateFeed").OnClientEvent:Connect(function(kind, a, b, c)
        if kind == "Floor" then OnFloor(a, b, c)
        elseif kind == "Roster" then OnRoster(a)
        elseif kind == "Look" then
            BuildRig(a)
            currentLook = a
            if hooks.ApplyLook then pcall(hooks.ApplyLook, a) end
        elseif kind == "Hit" then -- (0.83: their hit, as they saw it -- at their moment in the playback)
            local d = a
            if type(d) == "table" then
                api.AtStamp(d.Stamp, function() if target and hooks.WatchHit then pcall(hooks.WatchHit, d, currentLook) end end)
            end
        elseif kind == "Duel" then duelInfo = a
        elseif kind == "Stop" then Stop(a) end
    end)
    Remotes.GetEvent("SpectatePos").OnClientEvent:Connect(function(pos: any)
        if type(pos) ~= "table" then return end
        for id, v in pairs(pos) do
            goal[id] = v[1]
            local m = puppets[id]
            if m and v[2] then m:SetAttribute("Health", v[2]) end
            if m and v[3] then m:SetAttribute("MaxHealth", v[3]) end
        end
    end)

    -- their shots: fire the first-person gun (+ a tracer / beam from its muzzle)
    function api.Shot(shooter: Player, hitPos: Vector3, baseId: string, skinKind: string?): boolean
        if not target or shooter ~= target then return false end
        if rig then
            pcall(function()
                local def = rig.Def
                if def and def.Beam then rig:Beam(hitPos) end
                rig:Fire(false)
                local m = rig.Points and rig.Points.Muzzle
                if m and not (def and def.Beam) then
                    local from = m.WorldPosition
                    local SkinFX = require(Shared:WaitForChild("SkinFX"))
                    if type(skinKind) == "string" and SkinFX.Sets[skinKind] then
                        SkinFX.ShotFx(skinKind, from, hitPos, nil, true)
                    elseif (hitPos - from).Magnitude > 1.5 then
                        local tr = Instance.new("Part")
                        tr.Anchored = true; tr.CanCollide = false; tr.CanQuery = false; tr.CanTouch = false; tr.CastShadow = false
                        tr.Material = Enum.Material.Neon; tr.Color = Color3.fromRGB(255, 226, 170); tr.Transparency = 0.25
                        local d = (hitPos - from).Magnitude
                        tr.Size = Vector3.new(0.05, 0.05, d); tr.CFrame = CFrame.lookAt((from + hitPos) / 2, hitPos)
                        tr.Parent = Workspace
                        TweenService:Create(tr, TweenInfo.new(0.08), { Transparency = 1 }):Play()
                        game:GetService("Debris"):AddItem(tr, 0.1)
                    end
                end
            end)
        end
        return true
    end

    -- every frame: puppets glide to their streamed spots, the rig follows the camera (after it moved)
    RunService:BindToRenderStep("AimRngSpectate", Enum.RenderPriority.Last.Value, function(dt)
        local testing = LocalPlayer:GetAttribute("SpecTest") == true -- (Studio: DevCmd spectest feeds a fake floor, no target)
        local watching = LocalPlayer:GetAttribute("WatchUid") ~= nil and target ~= nil
        if not watching and not testing then return end
        local troot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        local k = 1 - math.exp(-12 * dt)
        local playT = Workspace:GetServerTimeNow() - Delay()
        local camNow = api.CameraNow()
        for id, m in pairs(puppets) do
            local g = goal[id]
            local live = m.Parent and WorldAt(id, playT) -- (0.83: where THEY saw it, at the playback moment)
            if live then
                at[id] = live
                local eyeAt = camNow and camNow.Position or (troot and troot.Position)
                local face = eyeAt and Vector3.new(eyeAt.X, live.Y, eyeAt.Z) or (live + m:GetPivot().LookVector)
                if (face - live).Magnitude > 0.1 then m:PivotTo(CFrame.lookAt(live, face)) else m:PivotTo(CFrame.new(live) * m:GetPivot().Rotation) end
            elseif g and m.Parent then
                local cur = m:GetPivot()
                local p = (at[id] or g):Lerp(g, k)
                at[id] = p
                local face = troot and Vector3.new(troot.Position.X, p.Y, troot.Position.Z) or (p + cur.LookVector)
                if (face - p).Magnitude > 0.1 then m:PivotTo(CFrame.lookAt(p, face)) else m:PivotTo(CFrame.new(p) * cur.Rotation) end
            end
        end
        if rig then
            local cam = Workspace.CurrentCamera
            local eyes = testing or (troot and not target:GetAttribute("Downed"))
            rig:SetVisible(eyes == true)
            if eyes then pcall(function() rig:Update(dt, cam.CFrame, CFrame.new(), nil) end) end
        end
        if not watching then return end
        -- keep your own body parked in the city
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and not (root :: BasePart).Anchored then (root :: BasePart).Anchored = true end
        bar.Visible = true
        local fl = floorCfg and floorCfg.FloorNumber
        barLbl.Text = "WATCHING  " .. string.upper(target.DisplayName)
        if duelInfo then
            local d = duelInfo
            local left = d.EndsAt and math.max(0, d.EndsAt - Workspace:GetServerTimeNow()) or nil
            barSub.Text = string.format("DUEL vs %s  •  %d - %d (first to %d)%s  •  HP %d / %d  •  %s  •  %s", string.upper(tostring(d.Opp)),
                d.MyFrags or 0, d.OppFrags or 0, d.ToWin or 5, d.Sudden and "  SUDDEN DEATH" or (left and string.format("  %d:%02d", left // 60, left % 60) or ""),
                d.MyHP or 0, d.OppHP or 0, string.upper(tostring(d.Arena)), tostring(d.Gun))
        else
        barSub.Text = (floorCfg and (string.upper(tostring(floorCfg.Difficulty)) .. "  •  FLOOR " .. tostring(fl) .. "  •  " .. string.upper(tostring(floorCfg.Biome))) or "party run")
            .. ((target:GetAttribute("Downed") and "  •  DOWN") or "")
        end
    end)
    -- ===== THE STREAM (0.83): while someone watches YOU, send your real camera (+ the enemies you see on a solo floor) =====
    do
        local specCam = Remotes.GetEvent("SpecCam")
        local specWorld = Remotes.GetEvent("SpecWorld")
        local CollectionService = game:GetService("CollectionService")
        local camAcc, worldAcc = 0, 0
        RunService:BindToRenderStep("AimRngSpecSend", Enum.RenderPriority.Camera.Value + 2, function(dt)
            if not LocalPlayer:GetAttribute("Spectators") then return end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            camAcc += dt
            worldAcc += dt
            local now = Workspace:GetServerTimeNow()
            if camAcc >= 1 / 30 then
                camAcc = 0
                ;(specCam :: any):FireServer(now, cam.CFrame, cam.FieldOfView)
            end
            if worldAcc >= 1 / 15 then
                worldAcc = 0
                -- (party runs and duels are server-built: their enemies / opponent replicate on their own)
                if LocalPlayer:GetAttribute("RunId") or LocalPlayer:GetAttribute("PvpDuel") then return end
                local cp = cam.CFrame.Position
                local list = {}
                for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do
                    local id = m:GetAttribute("EnemyId")
                    if id and not m:GetAttribute("Dead") and not m:GetAttribute("Puppet") and m:IsDescendantOf(Workspace) then
                        local p = m:GetPivot().Position
                        local d = (p - cp).Magnitude
                        if d < 240 then table.insert(list, { d, id, p }) end
                    end
                end
                if #list == 0 then return end
                table.sort(list, function(a, b) return a[1] < b[1] end)
                local ids, poss = {}, {}
                for i = 1, math.min(14, #list) do ids[i] = list[i][2]; poss[i] = list[i][3] end -- (an unreliable event is < 900 bytes)
                ;(specWorld :: any):FireServer(now, ids, poss)
            end
        end)
    end

    -- ===== THE EYE (0.83, owner: "add an eyeball somewhere on the screen to show that someone is spectating them") =====
    do
        local eye = Instance.new("Frame")
        eye.Name = "SpectatedEye"; eye.AnchorPoint = Vector2.new(1, 0.5); eye.Position = UDim2.new(1, -14, 0.42, 0)
        eye.Size = UDim2.fromOffset(78, 36); eye.BackgroundColor3 = Color3.fromRGB(14, 18, 26); eye.BackgroundTransparency = 0.15
        eye.Visible = false; eye.Parent = hooks.Hud
        local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0, 4); ec.Parent = eye
        local ink = UIStyle.InkEdge and UIStyle.InkEdge(2)
        if ink then ink.Parent = eye end
        local white = Instance.new("Frame") -- (the eyeball: an almond of white, an iris that looks around, a pupil)
        white.AnchorPoint = Vector2.new(0, 0.5); white.Position = UDim2.new(0, 9, 0.5, 0); white.Size = UDim2.fromOffset(34, 20)
        white.BackgroundColor3 = Color3.fromRGB(240, 244, 250); white.ClipsDescendants = true; white.Parent = eye
        local wc = Instance.new("UICorner"); wc.CornerRadius = UDim.new(1, 0); wc.Parent = white
        local ws = Instance.new("UIStroke"); ws.Color = Color3.fromRGB(10, 10, 14); ws.Thickness = 2; ws.Parent = white
        local iris = Instance.new("Frame")
        iris.AnchorPoint = Vector2.new(0.5, 0.5); iris.Position = UDim2.fromScale(0.5, 0.5); iris.Size = UDim2.fromOffset(14, 14)
        iris.BackgroundColor3 = ACC; iris.Parent = white
        local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(1, 0); ic.Parent = iris
        local pupil = Instance.new("Frame")
        pupil.AnchorPoint = Vector2.new(0.5, 0.5); pupil.Position = UDim2.fromScale(0.5, 0.5); pupil.Size = UDim2.fromOffset(6, 6)
        pupil.BackgroundColor3 = Color3.fromRGB(8, 8, 12); pupil.Parent = iris
        local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(1, 0); pc.Parent = pupil
        local count = Txt(eye, { Text = "", TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -50, 1, 0) })
        local function Refresh()
            local n = LocalPlayer:GetAttribute("Spectators")
            eye.Visible = type(n) == "number" and n > 0
            count.Text = tostring(n or "")
        end
        LocalPlayer:GetAttributeChangedSignal("Spectators"):Connect(Refresh)
        Refresh()
        task.spawn(function() -- (the iris glances around now and then)
            while true do
                task.wait(1.6 + math.random() * 1.8)
                if eye.Visible then
                    TweenService:Create(iris, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.36, 0.5 + (math.random() - 0.5) * 0.2) }):Play()
                end
            end
        end)
    end

    -- a party target moving floors changes its RunId: refresh which floor shows
    table.insert(conns, LocalPlayer:GetAttributeChangedSignal("WatchUid"):Connect(function()
        if not LocalPlayer:GetAttribute("WatchUid") and target then Stop(nil) end
    end))
    return api
end

return SpectateClient
