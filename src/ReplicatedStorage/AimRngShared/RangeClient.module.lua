--!nocheck
-- ============================================================================================
-- TRAINING GROUNDS (client, Rivals-style range). The hub's south wing has a firing line with 13 bays
-- (HubGenerator BuildTrainingGrounds): standing on a bay's pad starts it, walking off stops it.
--   * Bot bays: real dungeon bots (DungeonGenerator.CreateBot in range mode: they stay in the bay and never
--     shoot) built on this client only, so every player gets their own. Speed = the dungeon BOT SKILL scale
--     (1-10, same names), [Z] slower / [X] faster, [N] bot count 1-5. Hits are scored here (damage is an
--     estimate from your stats); the panel shows kills, accuracy and average time-to-kill.
--   * DPS bay: a server dummy that never dies; the server reports every hit and damage tick (DpsTick), so
--     procs, DoTs, crits and keystones all count. The meter shows DPS, peak 1 s, total and crit rate, and
--     resets after 4 s without damage.
--   RangeClient.Init(hooks)  hooks: { GetState, GetStats, DamageText(dmg, weak, crit, pos), PlaySound(name), Parent }
--   RangeClient.CountShot(consumesAmmo)  -- every ray fired while a bot bay is active
--   RangeClient.HandleHit(part, pos) -> true if the part was one of our range bots
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = script.Parent
local DG = require(Shared:WaitForChild("DungeonGenerator"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local LocalPlayer = Players.LocalPlayer
local RangeClient = {}

local hooks: any = {}
local zones: { BasePart } = {}
local active: BasePart? = nil
local folder: Folder? = nil
local bots: { [Model]: { FirstHit: number? } } = {}
local skill = DG.DEFAULT_BOT_SKILL or 4
local count = 3
local s = { Shots = 0, Hits = 0, Kills = 0, TTK = 0 }
local dps = { Start = 0, Last = 0, Total = 0, Hits = 0, Crits = 0, Peak = 0, Window = {} }
local panel, pTitle, pSub, pLines, pKeys

local function Fmt(n) return ItemData.FormatNumber(n) end

-- ---------------------------------------------------------------- panel
local function BuildPanel(parent: Instance)
    -- (right side, under the daily contracts: the left dock covered it -- owner 2026-10-02)
    panel = UIStyle.New("Frame", { Name = "RangePanel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.55, 0), Size = UDim2.fromOffset(300, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = parent }, { UIStyle.Corner(12) })
    panel:SetAttribute("UIStyled", true)
    UIStyle.Gradient(UIStyle.Colors.Card, UIStyle.Colors.CardDark).Parent = panel
    local stroke = UIStyle.Stroke(UIStyle.Colors.Border, 3); stroke.Name = "Edge"; stroke.Parent = panel
    UIStyle.New("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = panel })
    UIStyle.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
    pTitle = UIStyle.Text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), TextSize = 24, Stroke = 2, Parent = panel })
    pSub = UIStyle.Text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UIStyle.BodyFont, TextSize = 13,
        TextColor3 = UIStyle.Colors.Sub, RichText = true, Parent = panel })
    pLines = UIStyle.Text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = UIStyle.BodyFont, TextSize = 16, RichText = true,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = panel })
    pKeys = UIStyle.Text({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Font = UIStyle.BodyFont, TextSize = 13,
        TextColor3 = UIStyle.Colors.Gold, RichText = true, Parent = panel })
end

local function SkillName(lvl: number): string
    local d = DG.BotSkillLevels and DG.BotSkillLevels[lvl]
    return d and d.Name or tostring(lvl)
end

local function Refresh()
    if not panel or not active then return end
    local kind = active:GetAttribute("Kind")
    local col = active:GetAttribute("Color") or UIStyle.Colors.Blue
    panel.Edge.Color = col
    pTitle.TextColor3 = col
    if kind == "DPS" then
        pTitle.Text = "DPS TEST"
        pSub.Text = "Shoot the dummy. Everything counts: crits, weak spots, procs, burns and bleeds. The meter resets 4 s after you stop."
        local now = os.clock()
        local live = (dps.Total > 0) and (now - dps.Last < 4)
        local elapsed = math.max(1, dps.Last - dps.Start)
        local recent = 0
        for _, e in ipairs(dps.Window) do if now - e[1] <= 1 then recent += e[2] end end
        pLines.Text = string.format(
            '<font size="30" color="#FFD25A"><b>%s</b></font>  <font color="#AAB6D2">DPS</font>\nLast second: <b>%s</b>   Peak: <b>%s</b>\nTotal: <b>%s</b> in %.1f s\nHits: <b>%d</b>   Crits: <b>%d%%</b>%s',
            Fmt(dps.Total / elapsed), Fmt(recent), Fmt(dps.Peak), Fmt(dps.Total), (dps.Total > 0) and (dps.Last - dps.Start) or 0, dps.Hits,
            (dps.Hits > 0) and math.round(dps.Crits / dps.Hits * 100) or 0, live and "" or '\n<font color="#8C96B4">(waiting for your first shot)</font>')
        pKeys.Text = ""
    else
        pTitle.Text = string.upper(kind) .. " RANGE"
        local lore = DG.BotLore and DG.BotLore[kind]
        pSub.Text = lore and (lore.Tip or lore.Text or "") or ""
        local acc = (s.Shots > 0) and math.round(s.Hits / s.Shots * 100) or 0
        pLines.Text = string.format('Speed: <b>%d</b> <font color="#FFD25A">%s</font>   Bots: <b>%d</b>\nKills: <b>%d</b>   Accuracy: <b>%d%%</b>\nAvg time to kill: <b>%s</b>',
            skill, SkillName(skill), count, s.Kills, acc, (s.Kills > 0) and string.format("%.2f s", s.TTK / s.Kills) or "--")
        pKeys.Text = "[Z] slower   [X] faster   [N] bot count\nWalk off the pad to stop."
    end
end

-- ---------------------------------------------------------------- bots
local function BotConfig(z: BasePart): any
    local st = hooks.GetState and hooks.GetState() or {}
    return {
        Biome = "Cyber", Difficulty = "Easy", FloorNumber = 1, PlayerLevel = st.Level or 1, BotSkill = skill, FxFolder = folder,
        Range = { MinX = z:GetAttribute("MinX"), MaxX = z:GetAttribute("MaxX"), MinZ = z:GetAttribute("MinZ"), MaxZ = z:GetAttribute("MaxZ"), MinY = 5, MaxY = 22 },
    }
end

local function SpawnBot(z: BasePart)
    if active ~= z or not folder then return end
    local kind = z:GetAttribute("Kind")
    local cfg = BotConfig(z)
    local R = cfg.Range
    local pos = Vector3.new(math.random(math.floor(R.MinX), math.floor(R.MaxX)), math.random(8, 14), math.random(math.floor(R.MinZ + 20), math.floor(R.MaxZ - 10)))
    local ok, model = pcall(DG.CreateBot, kind, pos, cfg, folder, nil, nil)
    if ok and model then
        model:SetAttribute("RangeBot", true)
        bots[model] = {}
    else
        warn("[Range] couldn't spawn", kind, model)
    end
end

local function ClearBots()
    for m in pairs(bots) do if m.Parent then m:Destroy() end end
    bots = {}
    if folder then folder:ClearAllChildren() end
end

local function FillBots(z: BasePart)
    local n = 0
    for m in pairs(bots) do if m.Parent then n += 1 else bots[m] = nil end end
    for m in pairs(bots) do
        if n > count and m.Parent then m:Destroy(); bots[m] = nil; n -= 1 end
    end
    for _ = n + 1, count do SpawnBot(z) end
end

-- ---------------------------------------------------------------- zones
local function Activate(z: BasePart)
    active = z
    s = { Shots = 0, Hits = 0, Kills = 0, TTK = 0 }
    dps = { Start = 0, Last = 0, Total = 0, Hits = 0, Crits = 0, Peak = 0, Window = {} }
    folder = folder or Instance.new("Folder")
    folder.Name = "RangeBots"
    folder.Parent = Workspace
    if z:GetAttribute("Kind") ~= "DPS" then FillBots(z) end
    if hooks.PlaySound then hooks.PlaySound("Click") end
    panel.Visible = true
    Refresh()
end

local function Deactivate()
    active = nil
    ClearBots()
    if panel then panel.Visible = false end
end

local function ZoneAt(pos: Vector3): BasePart?
    for _, z in ipairs(zones) do
        local rel = z.CFrame:PointToObjectSpace(pos)
        if math.abs(rel.X) <= z.Size.X / 2 and math.abs(rel.Z) <= z.Size.Z / 2 and rel.Y > -2 and rel.Y < 8 then return z end
    end
    return nil
end

function RangeClient.IsActive(): boolean return active ~= nil end

function RangeClient.CountShot(consumesAmmo: boolean?)
    if active and active:GetAttribute("Kind") ~= "DPS" then s.Shots += 1 end
end

-- dmgOverride (melee): use this damage instead of the gun's (weak spots / crits are rolled by the caller)
function RangeClient.HandleHit(part: Instance, pos: Vector3, dmgOverride: number?): boolean
    if not active then return false end
    local model = part:FindFirstAncestorOfClass("Model")
    while model and not bots[model] and model.Parent ~= folder do model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") end
    if not model or not bots[model] then return false end
    local info = bots[model]
    local st = hooks.GetStats and hooks.GetStats()
    local pn = part:GetAttribute("HitAs") or part.Name -- (a decoration counts as the part it sits on)
    local weak = pn == "Head" -- (0.76: one weak spot)
    local dmg = st and st.Damage or 10
    local crit = false
    if dmgOverride then
        dmg = dmgOverride
    else
        if part.Name == "Shield" then dmg *= 0.1 end
        if weak then dmg *= (st and st.WeakSpotMultiplier or 2) else dmg *= (st and st.BodyShotMult or 1) end
        if st and math.random() < (st.CritChance or 0) then crit = true; dmg *= (st.CritMultiplier or 1.5) end
    end
    dmg = math.max(0.1, math.round(dmg * 10) / 10)
    s.Hits += 1
    info.FirstHit = info.FirstHit or os.clock()
    local hp = math.max(0, (model:GetAttribute("Health") or 0) - dmg)
    model:SetAttribute("Health", hp)
    local maxHp = model:GetAttribute("MaxHealth") or 1
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "Fill" and d:IsA("Frame") then d.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0) end
    end
    if hooks.DamageText then hooks.DamageText(dmg, weak, crit, pos, "Hit", false) end
    if hp <= 0 then
        s.Kills += 1
        s.TTK += os.clock() - (info.FirstHit or os.clock())
        bots[model] = nil
        if hooks.PlaySound then hooks.PlaySound("Kill") end
        model:Destroy()
        local z = active
        task.delay(0.7, function() if active == z then FillBots(z) end end)
    end
    Refresh()
    return true
end

-- Melee swing in a bot bay: every range bot within reach and in front of you (same rule as the server's melee:
-- flat facing dot > arc) takes the hit. Returns how many were hit.
function RangeClient.MeleeSweep(origin: CFrame, reach: number, arc: number, dmg: number): number
    if not active then return 0 end
    local n = 0
    local look = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
    look = look.Magnitude > 0.01 and look.Unit or Vector3.zAxis
    for model in pairs(bots) do
        local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if root and model.Parent then
            local to = root.Position - origin.Position
            local flat = Vector3.new(to.X, 0, to.Z)
            local facing = flat.Magnitude > 0.01 and look:Dot(flat.Unit) or 1
            if to.Magnitude <= reach + 2 and facing > arc then
                if RangeClient.HandleHit(root, root.Position, dmg) then n += 1 end
            end
        end
    end
    return n
end

function RangeClient.Init(h: any)
    hooks = h or {}
    BuildPanel(hooks.Parent)
    Remotes.GetEvent("DpsTick").OnClientEvent:Connect(function(dmg, kind, isCrit)
        if not active or active:GetAttribute("Kind") ~= "DPS" or type(dmg) ~= "number" then return end
        local now = os.clock()
        if now - dps.Last > 4 then dps = { Start = now, Last = now, Total = 0, Hits = 0, Crits = 0, Peak = 0, Window = {} } end
        dps.Last = now
        dps.Total += dmg
        if kind == "Hit" then
            dps.Hits += 1
            if isCrit then dps.Crits += 1 end
        end
        table.insert(dps.Window, { now, dmg })
        local recent = 0
        for i = #dps.Window, 1, -1 do
            if now - dps.Window[i][1] > 1 then table.remove(dps.Window, i) else recent += dps.Window[i][2] end
        end
        if now - dps.Start >= 1 then dps.Peak = math.max(dps.Peak, recent) end
    end)
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not active or active:GetAttribute("Kind") == "DPS" then return end
        if require(script.Parent:WaitForChild("GameSettings")).IsTyping() then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.Z or k == Enum.KeyCode.X then -- (C is slide)
            skill = math.clamp(skill + ((k == Enum.KeyCode.X) and 1 or -1), 1, 10)
            ClearBots(); FillBots(active)
            s = { Shots = 0, Hits = 0, Kills = 0, TTK = 0 }
            if hooks.PlaySound then hooks.PlaySound("Click") end
            Refresh()
        elseif k == Enum.KeyCode.N then
            count = (count % 5) + 1
            FillBots(active)
            if hooks.PlaySound then hooks.PlaySound("Click") end
            Refresh()
        end
    end)
    task.spawn(function()
        local hub = Workspace:WaitForChild("HubWorld", 60)
        local tg = hub and hub:WaitForChild("TrainingGrounds", 30)
        if not tg then return end
        -- (0.60f, owner: "dps test doesn't work in range": the pads were listed ONCE, the moment the TrainingGrounds
        -- folder replicated -- on a live server its pads can arrive after that, which left the list empty for the whole
        -- session: no meter, no damage counted. The list now follows the folder.)
        local function Add(c) if c.Name == "RangeZone" and not table.find(zones, c) then table.insert(zones, c) end end
        for _, c in ipairs(tg:GetChildren()) do Add(c) end
        tg.ChildAdded:Connect(Add)
        tg.ChildRemoved:Connect(function(c) local i = table.find(zones, c) if i then table.remove(zones, i) end end)
        local acc = 0
        RunService.Heartbeat:Connect(function(dt)
            acc += dt
            if acc < 0.2 then return end
            acc = 0
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local z = root and ZoneAt(root.Position) or nil
            if z ~= active then
                if active then Deactivate() end
                if z then Activate(z) end
            elseif active then
                Refresh()
            end
        end)
    end)
end

return RangeClient
