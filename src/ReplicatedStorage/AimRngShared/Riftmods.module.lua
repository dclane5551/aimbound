--!nocheck
-- ============================================================================================
-- RIFTMODS (UPDATE 7 B1; vault "UPDATE 7 - Depth" + Loot Economy Plan section 12, owner: "random stats only, no tuning, no
-- locked unlock-challenge"; the name is a placeholder). A Riftmod is a mod for ONE gun model with random lines; fit it on
-- a gun of that model and its lines count like the gun's own affixes (StatCalculator: gear-layer ceilings, so it can't
-- break the power curve). Drops from level UNLOCK (bosses, elites), stored in state.Riftmods (cap BAG), fitted ones live
-- on the gun (weapon.Riftmod = the mod's table; trading / stashing the gun carries it).
-- REROLL with Riftmod Dust (new lines, the same gun; costs more each time), SALVAGE for dust. DISPOSITION[gun] scales a
-- gun's lines (all 1 for now: owner to decide "whether weak guns roll stronger").
-- Server: CombatServer.RiftmodDrop / the RiftmodAction remote (Fit / Remove / Reroll / Salvage). Client: ITEMS tab view.
-- ============================================================================================
local Riftmods = {}

Riftmods.ON = true
Riftmods.UNLOCK = 45
Riftmods.BAG = 60
Riftmods.CHANCE = { Boss = 0.04, SuperBoss = 0.10, Elite = 0.004 } -- (per kill, x nothing: flat)
Riftmods.CLASS_SHARE = 0.6 -- (a drop is for a gun of your class this often, any lineup gun otherwise)
Riftmods.DISPOSITION = {} -- [baseId] = multiplier on its line values (default 1)
Riftmods.NEG_CHANCE = 0.4 -- (a penalty line, riven-style: always with 3 good lines)
Riftmods.SALVAGE = { 3, 6 }
function Riftmods.RerollCost(mod: any): number return 2 + (tonumber(mod and mod.Rolls) or 0) end

local function ID() return require(script.Parent:WaitForChild("ItemData")) end

-- fresh lines for a gun at an item level: 2 or 3 good lines (high tiers for the level), maybe a penalty with 3
function Riftmods.RollLines(gun: string, itemLevel: number): { any }
    local I = ID()
    local pre, suf = I.WeaponAffixPools()
    local base = I.BaseWeapons[gun]
    local pierces = base ~= nil and base.Pierce ~= nil
    local bag = {}
    for _, pool in ipairs({ pre, suf }) do
        for _, d in ipairs(pool) do if not d.Requires or (d.Requires == "Pierce" and pierces) then table.insert(bag, d) end end
    end
    local good = (math.random() < 0.5) and 2 or 3
    local cap = I.AffixTierCap("Infinite", itemLevel) -- (the item level's cap; rarity doesn't matter for a Riftmod)
    local k = Riftmods.DISPOSITION[gun] or 1
    local lines, used = {}, {}
    for _ = 1, good do
        if #bag == 0 then break end
        local def = table.remove(bag, math.random(1, #bag))
        local tier = math.max(1, cap - math.random(0, 2))
        local a = I.MakeAffix(def, tier)
        if k ~= 1 then a.Value = a.Value * k end
        used[a.Stat] = true
        table.insert(lines, a)
    end
    if good == 3 and math.random() < Riftmods.NEG_CHANCE then
        local neg = I.MakeNegativeAffix(used)
        if neg then table.insert(lines, neg) end
    end
    return lines
end

function Riftmods.New(gun: string, itemLevel: number): any
    local I = ID()
    local base = I.BaseWeapons[gun]
    return {
        Uid = game:GetService("HttpService"):GenerateGUID(false), Kind = "Riftmod", Gun = gun, ItemLevel = itemLevel, Rolls = 0,
        Name = ((base and (base.ShortName or base.Name)) or gun) .. " Gunwright", Lines = Riftmods.RollLines(gun, itemLevel),
    }
end

-- the gun a drop is for: one of your class's lineup guns (CLASS_SHARE) or any lineup gun
function Riftmods.PickGun(state: any): string
    local I = ID()
    local ClassData = require(script.Parent:WaitForChild("ClassData"))
    local group = ClassData.GroupOf(type(state) == "table" and state.Class or nil)
    local mine = {}
    if group then
        for _, id in ipairs(I.Lineup) do
            local b = I.BaseWeapons[id]
            if b and I.WeaponGroupOf({ BaseId = id, Class = b.Class }) == group then table.insert(mine, id) end
        end
    end
    if #mine > 0 and math.random() < Riftmods.CLASS_SHARE then return mine[math.random(1, #mine)] end
    return I.Lineup[math.random(1, #I.Lineup)]
end

-- "+12% Damage, +6% Fire Rate, -4% Reload Speed"
function Riftmods.LinesText(mod: any): string
    local I = ID()
    local t = {}
    for _, l in ipairs(type(mod) == "table" and mod.Lines or {}) do table.insert(t, I.FormatStat(l.Stat, l.Value)) end
    return table.concat(t, ",  ")
end

-- ==================== CLIENT VIEW (the inventory ITEMS tab) ====================
-- act(action, a, b) = InvokeServer RiftmodAction; equipped = your gun
function Riftmods.Render(scroll: Instance, st: any, act: (string, any, any) -> ())
    local I = ID()
    if ((type(st) == "table" and st.Level) or 1) < Riftmods.UNLOCK and #(type(st) == "table" and type(st.Riftmods) == "table" and st.Riftmods or {}) == 0 then return end
    local C1, C2 = Color3.fromRGB(120, 200, 255), Color3.fromRGB(150, 154, 166)
    local function Lbl(parent, text, size, col, w, x, bold)
        local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size; l.TextColor3 = col
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true
        l.Size = UDim2.new(w, -(x or 0), 1, 0); l.Position = UDim2.fromOffset(x or 0, 0); l.Parent = parent
        return l
    end
    local function Btn(parent, text, col, x, fn, bottom)
        local b = Instance.new("TextButton"); b.Size = UDim2.fromOffset(84, 26)
        b.Position = bottom and UDim2.new(1, -x, 1, -30) or UDim2.new(1, -x, 0.5, -13); b.BackgroundColor3 = col; b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.fromRGB(20, 20, 24); b.Text = text; b.Parent = parent
        b.MouseButton1Click:Connect(fn)
        return b
    end
    local head = Instance.new("Frame"); head.Name = "RiftmodHead"; head.LayoutOrder = 500; head.BackgroundTransparency = 1; head.Size = UDim2.new(1, -6, 0, 26); head.Parent = scroll
    local mods = type(st.Riftmods) == "table" and st.Riftmods or {}
    Lbl(head, "GUNWRIGHTS (" .. #mods .. " / " .. Riftmods.BAG .. ")  •  fit one on a gun of its model; its lines count like the gun's own", 13, C1, 1, 4, true)
    local eq = st.EquippedWeapon
    if eq and type(eq.Riftmod) == "table" then
        local r = Instance.new("Frame"); r.LayoutOrder = 501; r.Size = UDim2.new(1, -6, 0, 40); r.BackgroundColor3 = Color3.fromRGB(20, 34, 44); r.BorderSizePixel = 0; r.Parent = scroll
        Lbl(r, "FITTED on your " .. tostring(eq.Name) .. ":  " .. Riftmods.LinesText(eq.Riftmod), 12, Color3.fromRGB(210, 235, 255), 1, 10).Size = UDim2.new(1, -110, 1, 0)
        Btn(r, "REMOVE", Color3.fromRGB(200, 205, 215), 92, function() act("Remove", eq.Uid) end)
    end
    for i, m in ipairs(mods) do
        -- (two lines: the name + its lines on top, the buttons under them -- side by side the text had no room)
        local r = Instance.new("Frame"); r.Name = "Riftmod" .. i; r.LayoutOrder = 501 + i; r.Size = UDim2.new(1, -6, 0, 72); r.BackgroundColor3 = Color3.fromRGB(24, 25, 30); r.BorderSizePixel = 0; r.Parent = scroll
        local fits = eq and eq.BaseId == m.Gun
        local t = Lbl(r, tostring(m.Name) .. "  •  iLvl " .. tostring(m.ItemLevel or 1) .. "\n" .. Riftmods.LinesText(m), 12, Color3.fromRGB(225, 228, 236), 1, 10)
        t.Size = UDim2.new(1, -16, 0, 38); t.Position = UDim2.fromOffset(10, 3); t.TextYAlignment = Enum.TextYAlignment.Top
        Btn(r, "SALVAGE", Color3.fromRGB(200, 120, 110), 92, function() act("Salvage", m.Uid) end, true)
        Btn(r, "REROLL " .. Riftmods.RerollCost(m), C1, 182, function() act("Reroll", m.Uid) end, true)
        local fit = Btn(r, fits and "FIT" or "WRONG GUN", fits and Color3.fromRGB(110, 230, 170) or C2, 272, function() if fits then act("Fit", m.Uid, eq.Uid) end end, true)
        fit.AutoButtonColor = fits
    end
    if #mods == 0 then
        local r = Instance.new("Frame"); r.LayoutOrder = 501; r.BackgroundTransparency = 1; r.Size = UDim2.new(1, -6, 0, 30); r.Parent = scroll
        Lbl(r, "None yet: bosses and elites drop them from level " .. Riftmods.UNLOCK .. ".", 12, C2, 1, 10)
    end
end

return Riftmods
