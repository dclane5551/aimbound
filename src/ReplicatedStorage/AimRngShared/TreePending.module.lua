--!nocheck
-- QOL M2 (2026-10-28; owner: "Undo-before applying in passive would be good, but not a saved tree set-up"; contract
-- docs/QOL_2026-10-28.md): the passive tree's PENDING nodes. Clicking a node (or the path to it) on the tree no longer spends
-- points on the server: the nodes go PENDING (drawn light cyan), each click one UNDO step. Nothing reaches the server until
-- APPLY, which sends the whole set to SkillTreeServer's batch remote AllocateSkillNodes (validated there as a set: class start,
-- connection to what you hold, points, cornerstone limit -- all or nothing). A pending node clicked again comes off free, along
-- with any pending node that only hung on it. UNDO = the last click, CLEAR = all of them. Closing the tree with pending nodes
-- asks APPLY / DISCARD / KEEP EDITING (TreePending.Prompt). Refunds of applied nodes are unchanged (paid, CLICK AGAIN TO PAY).
-- Client only; the state is per session (never saved -- owner: no saved tree set-ups).
local TP = {}

local Shared = script.Parent
TP.COLOR = Color3.fromRGB(120, 235, 255) -- (pending nodes + lines: the UI's neon cyan, lighter)

TP.List = {} :: { string } -- (in click order)
TP.Set = {} :: { [string]: boolean }
TP.Steps = {} :: { { string } } -- (one per click: its path)
TP.OnChange = nil :: (() -> ())?

local function Data() return require(Shared:WaitForChild("SkillTreeData")) end
local function Changed() if TP.OnChange then task.spawn(TP.OnChange) end end

function TP.Count(): number return #TP.List end
function TP.Has(id: string): boolean return TP.Set[id] == true end

-- allocated + pending (a fresh table: callers use it for paths / adjacency)
function TP.Eff(allocatedSet: { [string]: boolean }): { [string]: boolean }
    if #TP.List == 0 then return allocatedSet end
    local out = table.clone(allocatedSet)
    for _, id in ipairs(TP.List) do out[id] = true end
    return out
end

function TP.AddPath(path: { string })
    local step = {}
    for _, id in ipairs(path) do
        if not TP.Set[id] then
            TP.Set[id] = true
            table.insert(TP.List, id)
            table.insert(step, id)
        end
    end
    if #step > 0 then table.insert(TP.Steps, step) end
    Changed()
end

local function Rebuild(keep: { [string]: boolean })
    local list = {}
    for _, id in ipairs(TP.List) do if keep[id] then table.insert(list, id) end end
    TP.List = list
    TP.Set = {}
    for _, id in ipairs(list) do TP.Set[id] = true end
    local steps = {}
    for _, st in ipairs(TP.Steps) do
        local s2 = {}
        for _, id in ipairs(st) do if keep[id] then table.insert(s2, id) end end
        if #s2 > 0 then table.insert(steps, s2) end
    end
    TP.Steps = steps
end

-- which pending nodes still hang on the allocated tree (through other pending nodes; leap = gem-radius nodes that stand alone)
local function Reachable(allocatedSet: { [string]: boolean }, leapSet: { [string]: boolean }?, without: string?): { [string]: boolean }
    local SD = Data()
    local keep, frontier = {}, {}
    local pend = {}
    for _, id in ipairs(TP.List) do if id ~= without and not allocatedSet[id] then pend[id] = true end end
    for id in pairs(pend) do
        local node = SD[id]
        local anchored = leapSet ~= nil and leapSet[id] == true
        if not anchored and node then
            for _, c in ipairs(node.Connections or {}) do if allocatedSet[c] then anchored = true break end end
        end
        if anchored then keep[id] = true; table.insert(frontier, id) end
    end
    while #frontier > 0 do
        local nxt = {}
        for _, id in ipairs(frontier) do
            for _, c in ipairs((SD[id] or {}).Connections or {}) do
                if pend[c] and not keep[c] then keep[c] = true; table.insert(nxt, c) end
            end
        end
        frontier = nxt
    end
    return keep
end

-- take one pending node back (free) + whatever only hung on it
function TP.Remove(id: string, allocatedSet: { [string]: boolean }, leapSet: { [string]: boolean }?): number
    if not TP.Set[id] then return 0 end
    local before = #TP.List
    Rebuild(Reachable(allocatedSet, leapSet, id))
    Changed()
    return before - #TP.List
end

function TP.Undo(): number
    local st = table.remove(TP.Steps)
    if not st then return 0 end
    local drop = {}
    for _, id in ipairs(st) do drop[id] = true end
    local keep = {}
    for _, id in ipairs(TP.List) do if not drop[id] then keep[id] = true end end
    Rebuild(keep)
    Changed()
    return #st
end

function TP.Clear()
    if #TP.List == 0 then return end
    TP.List, TP.Set, TP.Steps = {}, {}, {}
    Changed()
end

-- after a state sync: drop pending nodes the server now holds, ones that no longer hang on the tree (a refund / respec / class
-- change), and any past the points you have. Returns true when something changed (OnChange is NOT called: Restyle calls this).
function TP.Prune(allocatedSet: { [string]: boolean }, leapSet: { [string]: boolean }?, points: number, hasClass: boolean): boolean
    if #TP.List == 0 then return false end
    local before = #TP.List
    local keep = hasClass and Reachable(allocatedSet, leapSet) or {}
    Rebuild(keep)
    while #TP.List > math.max(0, points) do
        local id = table.remove(TP.List)
        TP.Set[id] = nil
        Rebuild(TP.Set)
    end
    return #TP.List ~= before -- (no OnChange: the caller is the tree's own refresh)
end

-- APPLY: the whole set to the server in one call (validated there) -> ok, message
TP.Busy = false
function TP.Apply(): (boolean, string?)
    if TP.Busy or #TP.List == 0 then return false, nil end
    TP.Busy = true
    local Remotes = require(Shared:WaitForChild("Remotes"))
    local list = table.clone(TP.List)
    local called, ok, msg = pcall(function() return Remotes.GetFunction("AllocateSkillNodes"):InvokeServer(list) end)
    TP.Busy = false
    if not called then return false, "Couldn't reach the server: try again." end
    if ok then TP.List, TP.Set, TP.Steps = {}, {}, {}; Changed() end
    return ok == true, msg
end

-- ==================== the UI: the APPLY bar + the close prompt (built by the tree, in its look) ====================
-- bar(parent, onApply, onUndo, onClear) -> { Frame, Set(n, pointsLeft) }
function TP.Bar(parent: GuiObject, btnStyle: (GuiButton, Color3, boolean?) -> (), onApply: () -> (), onUndo: () -> (), onClear: () -> ())
    local UIStyle = require(Shared:WaitForChild("UIStyle"))
    local C = UIStyle.Colors
    local f = Instance.new("Frame")
    f.Name = "PendingBar"
    f.AnchorPoint = Vector2.new(0.5, 1)
    f.Size = UDim2.fromOffset(470, 44)
    f.BackgroundColor3 = C.Bg1
    f.BackgroundTransparency = 0.05
    f.BorderSizePixel = 0
    f.ZIndex = 6
    f.Visible = false
    f:SetAttribute("Skinned", true)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = f
    local st = Instance.new("UIStroke"); st.Color = TP.COLOR; st.Transparency = 0.45; st.Thickness = 1; st.Parent = f
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Count"
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.Size = UDim2.new(0, 150, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = TP.COLOR
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = f
    local function B(name: string, text: string, x: number, w: number, col: Color3, primary: boolean?, fn: () -> ()): TextButton
        local b = Instance.new("TextButton")
        b.Name = name
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, x, 0.5, 0)
        b.Size = UDim2.fromOffset(w, 32)
        b.ZIndex = 7
        b.Parent = f
        btnStyle(b, col, primary)
        b.MouseButton1Click:Connect(fn)
        return b
    end
    B("Clear", "CLEAR", -6, 76, C.Sub, false, onClear)
    B("Undo", "UNDO", -88, 76, C.Sub, false, onUndo)
    local apply = B("Apply", "APPLY", -170, 120, TP.COLOR, true, onApply)
    local api = { Frame = f, Apply = apply }
    function api.Set(n: number, left: number)
        f.Visible = n > 0
        lbl.Text = string.format("%d PENDING  •  %d LEFT", n, math.max(0, left))
        apply.Text = "APPLY " .. n
    end
    f.Parent = parent
    return api
end

-- prompt(parent, btnStyle, onApply, onDiscard, onKeep) -> { Frame, Show(n) }
function TP.Prompt(parent: GuiObject, btnStyle: (GuiButton, Color3, boolean?) -> (), onApply: () -> (), onDiscard: () -> (), onKeep: () -> ())
    local UIStyle = require(Shared:WaitForChild("UIStyle"))
    local C = UIStyle.Colors
    local shade = Instance.new("TextButton") -- (eats clicks on the tree behind it)
    shade.Name = "PendingPrompt"
    shade.Text = ""
    shade.AutoButtonColor = false
    shade.BackgroundColor3 = Color3.new(0, 0, 0)
    shade.BackgroundTransparency = 0.45
    shade.Size = UDim2.fromScale(1, 1)
    shade.ZIndex = 20
    shade.Visible = false
    shade:SetAttribute("Skinned", true)
    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromOffset(400, 150)
    box.BackgroundColor3 = C.Bg1
    box.BorderSizePixel = 0
    box.ZIndex = 21
    box:SetAttribute("Skinned", true)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = box
    local st = Instance.new("UIStroke"); st.Color = TP.COLOR; st.Transparency = 0.3; st.Parent = box
    box.Parent = shade
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(16, 12)
    t.Size = UDim2.new(1, -32, 0, 22)
    t.Font = Enum.Font.GothamBlack
    t.TextSize = 17
    t.TextColor3 = C.Text
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 22
    t.Parent = box
    local s = Instance.new("TextLabel")
    s.BackgroundTransparency = 1
    s.Position = UDim2.fromOffset(16, 38)
    s.Size = UDim2.new(1, -32, 0, 40)
    s.Font = Enum.Font.GothamMedium
    s.TextSize = 13
    s.TextColor3 = C.Sub
    s.TextWrapped = true
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.TextYAlignment = Enum.TextYAlignment.Top
    s.Text = "Apply them now, or drop them (nothing was spent)."
    s.ZIndex = 22
    s.Parent = box
    local function B(text: string, x: number, w: number, col: Color3, primary: boolean?, fn: () -> ())
        local b = Instance.new("TextButton")
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.Position = UDim2.new(0, x, 1, -48)
        b.Size = UDim2.fromOffset(w, 34)
        b.ZIndex = 22
        b.Parent = box
        btnStyle(b, col, primary)
        b.MouseButton1Click:Connect(fn)
    end
    B("APPLY", 16, 110, TP.COLOR, true, onApply)
    B("DISCARD", 134, 110, C.Bad, false, onDiscard)
    B("KEEP EDITING", 252, 132, C.Sub, false, onKeep)
    local api = { Frame = shade }
    function api.Show(n: number)
        t.Text = string.format("%d PENDING NODE%s NOT APPLIED", n, n == 1 and "" or "S")
        shade.Visible = true
    end
    function api.Hide() shade.Visible = false end
    shade.Parent = parent
    return api
end

return TP
