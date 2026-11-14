--!nocheck
-- ============================================================================================
-- DUNGEON EVENTS (Diablo shrines / PoE strongboxes / Kadala gambling): a regular solo floor (floor 2+, not
-- a boss floor) has EVENT_CHANCE to hold ONE interactive event near the combat room's entrance.
--   BOON_SHRINE       pick 1 of 3 run boons (the main way to get boons -- boss floors are the other)
--   GAMBLE_ALTAR      pay gold for a random item with boosted odds; price doubles, 3 uses
--   CURSED_CHEST      wakes 3 elite guardians; kill them all for a big reward
--   TRIAL_SHRINE      20 s precision trial: 8 targets appear, weak-spot kills score, rewards by kills
--   FORTUNE_FOUNTAIN  full heal, +50% loot luck for the rest of the floor and a little gold
-- Server: DungeonRuns rolls it (folder attrs Event / EventUsed / TrialUntil) and handles the UseEvent remote.
-- Client: DungeonClient builds the shrine with DungeonEvents.Build after the map.
-- ============================================================================================
local DungeonEvents = {}

DungeonEvents.Defs = {
    BOON_SHRINE = { Name = "Boon Shrine", Prompt = "Pray", Color = Color3.fromRGB(160, 60, 255), Weight = 30,
        Text = "Choose 1 of 3 run boons." },
    GAMBLE_ALTAR = { Name = "Gambler's Altar", Prompt = "Gamble", Color = Color3.fromRGB(255, 180, 0), Weight = 20,
        Text = "Pay gold for a random item with boosted odds. The price doubles each time (3 uses)." },
    CURSED_CHEST = { Name = "Cursed Chest", Prompt = "Open", Color = Color3.fromRGB(230, 20, 50), Weight = 20,
        Text = "Awakens 3 elite guardians. Defeat them all for a big reward." },
    TRIAL_SHRINE = { Name = "Shrine of Precision", Prompt = "Begin Trial", Color = Color3.fromRGB(0, 150, 255), Weight = 15,
        Text = "20 seconds, 8 targets: only weak-spot kills count. 3 / 5 / 8 kills = better rewards." },
    FORTUNE_FOUNTAIN = { Name = "Fortune Fountain", Prompt = "Drink", Color = Color3.fromRGB(20, 210, 90), Weight = 15,
        Text = "Full heal, +50% loot luck for the rest of this floor, and a little gold." },
}
DungeonEvents.Order = { "GAMBLE_ALTAR", "CURSED_CHEST", "TRIAL_SHRINE", "FORTUNE_FOUNTAIN" } -- (UPDATE 8 Phase 5: no BOON_SHRINE -- boons are cut)
DungeonEvents.EVENT_CHANCE = 0.45
DungeonEvents.USE_RANGE = 22 -- studs (server check)
DungeonEvents.TRIAL_SECONDS = 20
DungeonEvents.TRIAL_TARGETS = 8
DungeonEvents.GAMBLE_USES = 3

function DungeonEvents.Roll(floorNumber: number, isBossFloor: boolean, rng: Random?): string?
    if floorNumber < 2 or isBossFloor then return nil end
    local r = rng or Random.new()
    if r:NextNumber() >= DungeonEvents.EVENT_CHANCE then return nil end
    local total = 0
    for _, id in ipairs(DungeonEvents.Order) do total += DungeonEvents.Defs[id].Weight end
    local roll = r:NextNumber() * total
    for _, id in ipairs(DungeonEvents.Order) do
        roll -= DungeonEvents.Defs[id].Weight
        if roll <= 0 then return id end
    end
    return DungeonEvents.Order[1]
end

-- Where the event stands: on the combat room's floor, a little in from the entrance (both sides use this).
function DungeonEvents.Position(layout: any): Vector3
    return Vector3.new(0, 2, layout.CombatZ - layout.CombatSize / 2 + 24)
end

-- Gold price of the next gamble (uses = how many times this altar was used already).
function DungeonEvents.GamblePrice(level: number, uses: number): number
    -- (linear with level like kill gold, 2026-10-05: the old curve ^0.6 asked ~1.2T gold at level 400)
    return math.round(150 * (1 + (math.max(1, level) - 1) * 0.06) * 2 ^ uses)
end

-- ===== WANDERING MERCHANT (2026-10-04, path reward FloorMods MERCHANT): a stall at the combat room's entrance,
-- left of any event, selling three things for gold. Server: DungeonRuns (folder attr "Merchant" = JSON stock,
-- MerchantBuy remote); client: DungeonClient builds it with BuildMerchant.
DungeonEvents.MERCHANT_STOCK = {
    { Kind = "Item", Name = "Armory Crate", Text = "a random item from the top four rarities", Mult = 14, Color = Color3.fromRGB(110, 180, 255) },
    { Kind = "Currency", Name = "Currency Pouch", Text = "a random crafting currency you've unlocked", Mult = 9, Color = Color3.fromRGB(190, 110, 255) }, -- (UPDATE 8: was the Boon Charm)
    { Kind = "Supplies", Name = "Field Supplies", Text = "a full heal + upgrade materials", Mult = 5, Color = Color3.fromRGB(120, 230, 150) },
}
function DungeonEvents.MerchantPosition(layout: any): Vector3
    return Vector3.new(-22, 2, layout.CombatZ - layout.CombatSize / 2 + 22)
end
function DungeonEvents.MerchantPrice(level: number, mult: number): number
    -- (linear with level like kill gold, 2026-10-05: the curve ^0.6 priced it in the hundreds of millions at level 400)
    return math.round(100 * (1 + (math.max(1, level) - 1) * 0.06) * mult / 10) * 10
end
-- stock = { { Price, Sold }, ... } (same order as MERCHANT_STOCK); onBuy(i) fires on a prompt. Returns the model and
-- a function to refresh the labels from a new stock list.
-- (fixes 2026-10-16 #7) events stand in the floor's BotObstacles folder: bots steer round them (DungeonGenerator
-- ObstacleParams); in the dungeon folder itself they walked through them
local function ObstacleFolder(parent: Instance): Instance
    local f = parent:FindFirstChild("BotObstacles")
    if not f then f = Instance.new("Folder"); f.Name = "BotObstacles"; f.Parent = parent end
    return f
end

function DungeonEvents.BuildMerchant(parent: Instance, layout: any, stock: { any }, onBuy: (number) -> ()): (Model, (any) -> ())
    local base = DungeonEvents.MerchantPosition(layout)
    local model = Instance.new("Model")
    model.Name = "WanderingMerchant"
    local function P(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, solid: boolean?): Part
        local p = Instance.new("Part")
        p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
        p.Anchored = true
        p.CanCollide = solid ~= false
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = model
        return p
    end
    local wood, cloth = Color3.fromRGB(92, 64, 44), Color3.fromRGB(150, 40, 50)
    -- the stall: a counter, four posts and a striped awning, facing the room (+Z)
    P(Vector3.new(16, 3, 3), CFrame.new(base + Vector3.new(0, 1.5, 0)), wood, Enum.Material.WoodPlanks)
    P(Vector3.new(16.6, 0.4, 3.6), CFrame.new(base + Vector3.new(0, 3.2, 0)), wood:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Wood)
    for _, x in ipairs({ -7.6, 7.6 }) do
        for _, z in ipairs({ -1.2, 1.2 }) do P(Vector3.new(0.5, 8, 0.5), CFrame.new(base + Vector3.new(x, 4, z)), wood, Enum.Material.Wood) end
    end
    for i = 0, 7 do
        local c = (i % 2 == 0) and cloth or Color3.fromRGB(235, 220, 190)
        P(Vector3.new(2.1, 0.25, 4.6), CFrame.new(base + Vector3.new(-7.35 + i * 2.1, 8.2, 0.4)) * CFrame.Angles(math.rad(-12), 0, 0), c, Enum.Material.Fabric, false)
    end
    local lamp = P(Vector3.new(0.8, 0.8, 0.8), CFrame.new(base + Vector3.new(0, 7.4, 1.6)), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, false)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 200, 140); light.Range = 16; light.Brightness = 1.4; light.Shadows = false
    light.Parent = lamp
    -- a sign over the stall
    local signBB = Instance.new("BillboardGui")
    signBB.Size = UDim2.new(0, 260, 0, 28)
    signBB.StudsOffset = Vector3.new(0, 2.2, 0)
    signBB.MaxDistance = 140
    signBB.Adornee = lamp
    signBB.Parent = model
    local sign = Instance.new("TextLabel")
    sign.Size = UDim2.fromScale(1, 1); sign.BackgroundTransparency = 1; sign.Font = Enum.Font.FredokaOne; sign.TextSize = 20
    sign.TextColor3 = Color3.fromRGB(255, 205, 130); sign.TextStrokeTransparency = 0.25; sign.Text = "WANDERING MERCHANT"
    sign.Parent = signBB
    -- three wares on the counter, each with its own prompt + price tag
    local tags = {}
    for i, def in ipairs(DungeonEvents.MERCHANT_STOCK) do
        local at = base + Vector3.new((i - 2) * 5, 4.2, 0)
        local ware = P(Vector3.new(1.4, 1.4, 1.4), CFrame.new(at) * CFrame.Angles(0, math.rad(45), math.rad(45)), def.Color, Enum.Material.Neon, false)
        ware.Name = "Ware" .. i
        local pr = Instance.new("ProximityPrompt")
        pr.Name = "PromptBuy"
        pr.ActionText = "Buy"
        pr.ObjectText = def.Name
        pr.KeyboardKeyCode = Enum.KeyCode.E
        pr.HoldDuration = 0.35
        pr.RequiresLineOfSight = false
        pr.MaxActivationDistance = 9
        pr.Parent = ware
        pr.Triggered:Connect(function() onBuy(i) end)
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 116, 0, 38)
        bb.StudsOffset = Vector3.new(0, 1.8, 0)
        bb.MaxDistance = 40
        bb.Adornee = ware
        bb.Parent = model
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 13
        t.TextColor3 = Color3.new(1, 1, 1); t.TextStrokeTransparency = 0.3; t.TextWrapped = true; t.RichText = true
        t.Parent = bb
        tags[i] = { Label = t, Ware = ware, Prompt = pr, Def = def }
    end
    local function Refresh(list: any)
        for i, tg in ipairs(tags) do
            local s = type(list) == "table" and list[i] or nil
            local sold = s and s.Sold
            tg.Prompt.Enabled = s ~= nil and not sold
            tg.Ware.Transparency = sold and 0.75 or 0
            -- (short tags: the wares sit 5 studs apart; what each one gives is on its prompt)
            tg.Label.Text = string.format('<font color="#%s">%s</font>\n%s', tg.Def.Color:ToHex(), tg.Def.Name,
                sold and "SOLD" or (s and string.format("%d gold", s.Price) or ""))
            tg.Prompt.ObjectText = s and not sold and string.format("%s: %s (%d gold)", tg.Def.Name, tg.Def.Text, s.Price) or tg.Def.Name
        end
    end
    Refresh(stock)
    task.spawn(function() -- the wares turn slowly
        local t = 0
        local bases = {}
        for i, tg in ipairs(tags) do bases[i] = tg.Ware.CFrame end
        while model.Parent do
            t += task.wait(1 / 20)
            for i, tg in ipairs(tags) do tg.Ware.CFrame = bases[i] * CFrame.new(0, math.sin(t * 2 + i) * 0.15, 0) * CFrame.Angles(0, t, 0) end
        end
    end)
    model.Parent = ObstacleFolder(parent)
    return model, Refresh
end

-- Client: builds the shrine (a pedestal, a floating glowing crystal, a name label and a prompt).
-- onUse() fires when the local player triggers the prompt. Returns the model.
function DungeonEvents.Build(parent: Instance, layout: any, eventId: string, onUse: () -> ()): Model?
    local def = DungeonEvents.Defs[eventId]
    if not def then return nil end
    local pos = DungeonEvents.Position(layout)
    local model = Instance.new("Model")
    model.Name = "DungeonEvent_" .. eventId
    local function P(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
        local p = Instance.new("Part")
        p.Size = size
        p.CFrame = cf
        p.Color = color
        p.Material = material
        if shape then p.Shape = shape end
        p.Anchored = true
        p.CanCollide = true
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = model
        return p
    end
    local stone = Color3.fromRGB(60, 62, 72)
    P(Vector3.new(7, 0.8, 7), CFrame.new(pos + Vector3.new(0, 0.4, 0)), stone, Enum.Material.Slate)
    P(Vector3.new(5, 0.8, 5), CFrame.new(pos + Vector3.new(0, 1.2, 0)), stone:Lerp(def.Color, 0.15), Enum.Material.Slate)
    P(Vector3.new(2.2, 3, 2.2), CFrame.new(pos + Vector3.new(0, 3.1, 0)), stone, Enum.Material.Marble)
    for i = 0, 3 do
        local a = math.rad(45 + i * 90)
        P(Vector3.new(0.6, 4.5, 0.6), CFrame.new(pos + Vector3.new(math.cos(a) * 3, 3.3, math.sin(a) * 3)), stone, Enum.Material.Slate)
        P(Vector3.new(0.7, 0.7, 0.7), CFrame.new(pos + Vector3.new(math.cos(a) * 3, 5.8, math.sin(a) * 3)), def.Color, Enum.Material.Neon, Enum.PartType.Ball)
    end
    local crystal = P(Vector3.new(1.6, 2.6, 1.6), CFrame.new(pos + Vector3.new(0, 6.4, 0)) * CFrame.Angles(0, math.rad(45), math.rad(45)), def.Color, Enum.Material.Neon)
    crystal.CanCollide = false
    crystal.Name = "Crystal"
    local light = Instance.new("PointLight")
    light.Color = def.Color
    light.Brightness = 1.6
    light.Range = 18
    light.Parent = crystal
    local pe = Instance.new("ParticleEmitter")
    pe.Color = ColorSequence.new(def.Color)
    pe.LightEmission = 0.8
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
    pe.Lifetime = NumberRange.new(0.8, 1.4)
    pe.Rate = 12
    pe.Speed = NumberRange.new(1, 2)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Parent = crystal

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 240, 0, 44)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.MaxDistance = 140
    bb.AlwaysOnTop = true
    bb.Adornee = crystal
    bb.Parent = model
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 20
    title.TextColor3 = def.Color:Lerp(Color3.new(1, 1, 1), 0.3)
    title.TextStrokeTransparency = 0.2
    title.Text = def.Name
    title.Parent = bb
    local sub = Instance.new("TextLabel")
    sub.Name = "Sub"
    sub.Size = UDim2.new(1, 0, 0.45, 0)
    sub.Position = UDim2.new(0, 0, 0.55, 0)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 12
    sub.TextColor3 = Color3.fromRGB(230, 230, 240)
    sub.TextStrokeTransparency = 0.3
    sub.TextWrapped = true
    sub.Text = def.Text
    sub.Parent = bb

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptEvent"
    prompt.ActionText = def.Prompt
    prompt.ObjectText = def.Name
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.4
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12
    prompt.Parent = crystal
    prompt.Triggered:Connect(function() onUse() end)

    -- slow spin + bob
    task.spawn(function()
        local t = 0
        local base = crystal.CFrame
        while model.Parent do
            t += task.wait(1 / 30)
            crystal.CFrame = base * CFrame.new(0, math.sin(t * 2) * 0.3, 0) * CFrame.Angles(0, t * 1.2, 0)
        end
    end)
    model.Parent = ObstacleFolder(parent)
    return model
end

-- Client: dims a used shrine (prompt off, crystal grey).
function DungeonEvents.MarkUsed(model: Model?, text: string?)
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then d.Enabled = false
        elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then d.Enabled = false
        elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then d.Color = Color3.fromRGB(80, 80, 90)
        elseif d:IsA("TextLabel") and d.Name == "Sub" then d.Text = text or "Used"
        end
    end
end

return DungeonEvents
