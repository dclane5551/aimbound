--!nocheck
-- BOSS CUES (0.62, owner: "The bosses are not intuitive at all, there is almost 0 indicator as to what youre suppose to
-- even be shooting in terms of weakpoints or any other mechanic"). Client only. Every boss part you're meant to shoot gets
-- a marker that's always drawn on top:
--   WEAK POINT   a boss's breakable weak spots ("BreakPart<i>": backplates, cannons, spines, crystals, locks...) and the
--                Forgeheart's crawling brands -- a pulsing ring + label
--   TARGET       mechanic targets that live outside the boss ("ShieldOrb<i>": nodes, eggs, coins, mirrors, tracking
--                rounds) -- a brighter ring; when one is OFF-SCREEN an arrow at the screen edge points to it
-- Markers are pooled (at most MAX), checked a few times a second; nothing here touches the fight itself.
-- (0.63, owner: "very hard to tell when youre far away, they should be highlighted a completely different color and they
-- should only show the weak point circle when visible. the same would apply to the targets"): every marked part gets
-- its OWN Highlight in a cue colour no enemy outline uses (weak points + targets LIME; drawn on top -- decorations
-- often wrap the part -- but only switched on while the camera has a clear line of sight to it), and the ring + label
-- only draw while that line of sight holds. (Highlights live in a Workspace folder: parented to the part they didn't draw.)
-- At most HL_MAX cue Highlights (the client's enemy outlines keep the rest of Roblox's 31).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local BossCues = {}
BossCues.MAX = 14
BossCues.HL_MAX = 7
-- ONE signature "shoot this" colour (lime) for weak points and targets: aqua clashed with the Sentinel / Cyber kits; no boss
-- kit, elite outline or biome contrast colour is lime (the label says which kind it is)
BossCues.COLORS = { ["WEAK POINT"] = Color3.fromRGB(150, 255, 30), TARGET = Color3.fromRGB(175, 255, 40), EXPOSED = Color3.fromRGB(150, 255, 30) }
-- (0.63 EXPOSED bots, DungeonRuns rotation: the bot glows lime as a whole, ring on its head, +40% damage taken)
local LocalPlayer = Players.LocalPlayer

local gui, arrowLayer = nil, nil
local live = {} -- [BasePart] = marker
local orbs = {} -- every "ShieldOrb<i>" part that appears (event-driven: no Workspace sweeps)
local function IsBoss(m) return m and m:GetAttribute("IsBoss") == true end
local function OwnerOf(part)
    local link = part:FindFirstChild("HitModel")
    if link and link:IsA("ObjectValue") and link.Value then return link.Value end
    return part:FindFirstAncestorOfClass("Model")
end
local function KindOf(part)
    local n = part.Name
    if string.match(n, "^ShieldOrb%d$") then return "TARGET" end
    -- (0.76, owner: "only ever have one weakspot ... always hittable but relatively small"): break parts / brands are body
    -- hits now -- the HEAD alone is the weak point
    -- (0.69, owner: "Bosses should still have weakpoints, just make them more obvious and less glitchy"): every boss's own
    -- HEAD and CORE hitboxes are its weak points (the server already counts them as weak spots). They are real hitbox
    -- parts moving rigidly with the boss -- no separately animated pieces -- and get a lime GLOW orb (below)
    if n == "Head" and IsBoss(part.Parent) then return "WEAK POINT" end
    return nil
end
-- the lime glow orb on a Head / Core weak point: client-only, follows the part every frame, and is the weak point's hitbox
local glowFolder = nil
local function NewGlow(part)
    if not glowFolder or not glowFolder.Parent then
        glowFolder = Instance.new("Folder")
        glowFolder.Name = "AimBossWeakGlows"
        glowFolder.Parent = Workspace
    end
    -- (0.76: small, to reward precision -- about the head itself, 1.2 to 2 studs; it's drawn on top of the decorations and
    -- they don't take queries, so it's always hittable)
    local s = math.clamp(math.min(part.Size.X, part.Size.Y, part.Size.Z) * 1.0, 1.2, 2.0)
    local g = Instance.new("Part")
    g.Name = "WeakGlow"; g.Shape = Enum.PartType.Ball; g.Size = Vector3.one * s
    g.Material = Enum.Material.Neon; g.Color = Color3.fromRGB(150, 255, 30); g.Transparency = 0.25
    g.Anchored = true; g.CanCollide = false; g.CanQuery = true; g.CanTouch = false; g.CastShadow = false
    -- (the glow IS the weak point: a shot anywhere on it counts as that Head / Core -- what you see is what you hit. Linked
    -- like the target orbs: HitModel -> the boss, HitAs = the part; LocalDeco = a party boss's client reports the real part)
    g:SetAttribute("HitAs", part.Name)
    g:SetAttribute("LocalDeco", true)
    local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = part.Parent; link.Parent = g
    g.CFrame = part.CFrame; g.Parent = glowFolder
    return g
end

local function NewMarker(part, kind)
    local col = BossCues.COLORS[kind] or Color3.new(1, 1, 1)
    -- (drawn on the screen layer, projected every frame like the enemy bars -- BillboardGuis didn't show)
    local bb = Instance.new("Frame")
    bb.Name = "BossCue"; bb.BackgroundTransparency = 1; bb.AnchorPoint = Vector2.new(0.5, 0.4)
    bb.Size = UDim2.fromOffset(46, 58); bb.Visible = false
    local ring = Instance.new("Frame")
    ring.Name = "Ring"; ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.new(0.5, 0, 0, 23)
    ring.Size = UDim2.fromOffset(30, 30); ring.BackgroundTransparency = 1; ring.Parent = bb
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = ring
    local st = Instance.new("UIStroke"); st.Color = col; st.Thickness = (kind == "TARGET") and 3 or 2; st.Parent = ring
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5); dot.Position = UDim2.fromScale(0.5, 0.5); dot.Size = UDim2.fromOffset(6, 6)
    dot.BackgroundColor3 = col; dot.BorderSizePixel = 0; dot.Parent = ring
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
    local lbl = Instance.new("TextLabel")
    -- (0.91, owner: the lime text sat on the lime orb / glow and couldn't be read): WHITE text on a dark tag with a lime
    -- edge, under the ring -- readable over any glow, still the cue colour
    lbl.Name = "Label"; lbl.Position = UDim2.new(0.5, 0, 0, 44); lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.Size = UDim2.fromOffset(0, 16); lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.BackgroundColor3 = Color3.fromRGB(12, 14, 18); lbl.BackgroundTransparency = 0.15; lbl.BorderSizePixel = 0
    lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 12; lbl.Text = kind; lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextStrokeTransparency = 1; lbl.Parent = bb
    do
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 5); pad.PaddingRight = UDim.new(0, 5); pad.Parent = lbl
        local ls = Instance.new("UIStroke"); ls.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ls.Color = col; ls.Thickness = 1.5; ls.Parent = lbl
        local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 3); lc.Parent = lbl
    end
    bb.Parent = arrowLayer
    -- the off-screen arrow (targets only)
    local arrow = nil
    if kind == "TARGET" then
        arrow = Instance.new("TextLabel")
        arrow.Name = "CueArrow"; arrow.AnchorPoint = Vector2.new(0.5, 0.5); arrow.Size = UDim2.fromOffset(34, 34)
        arrow.BackgroundTransparency = 1; arrow.Font = Enum.Font.GothamBlack; arrow.TextSize = 30; arrow.Text = "▲"
        arrow.TextColor3 = col; arrow.TextStrokeTransparency = 0; arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
        arrow.Visible = false; arrow.Parent = arrowLayer
    end
    return { Gui = bb, Ring = ring, Stroke = st, Dot = dot, Arrow = arrow, Kind = kind, Born = os.clock(), Col = col, Seen = false, HL = nil }
end
local function Drop(part)
    local m = live[part]
    if not m then return end
    m.Gui:Destroy()
    if m.Arrow then m.Arrow:Destroy() end
    if m.HL then m.HL:Destroy() end
    if m.Glow then m.Glow:Destroy() end
    if m.Glow and part.Parent then part.CanQuery = true end -- (0.76: the head takes shots itself again)
    live[part] = nil
end

-- find what to mark (bosses on YOUR floor only)
local function Scan()
    local seen = {}
    local count = 0
    for _, boss in ipairs(CollectionService:GetTagged("AimRngEnemy")) do
        if IsBoss(boss) and boss.Parent and boss:GetAttribute("Dead") ~= true then
            local function Consider(d)
                if count >= BossCues.MAX then return end
                if d:IsA("BasePart") then
                    local kind = KindOf(d)
                    local core = d.Name == "Head" -- (hitboxes may be invisible under their decorations)
                    if kind and (core or d.Transparency < 0.95) and OwnerOf(d) == boss then
                        seen[d] = true
                        count += 1
                        if not live[d] then
                            live[d] = NewMarker(d, kind)
                            if core then
                                live[d].Glow = NewGlow(d); live[d].Model = boss -- (its own decorations never hide it)
                                d.CanQuery = false -- (0.76: the small glow is the ONLY weak spot -- a big head part no longer takes the shot)
                                -- one label per boss: the core ring stays unlabelled when the boss also has a head
                                if d.Name == "Core" and boss:FindFirstChild("Head") then live[d].Gui.Label.Text = ""; live[d].Gui.Label.Visible = false end
                                live[d].Dot.Size = UDim2.fromOffset(10, 10)
                            end
                        end
                    end
                end
            end
            for _, d in ipairs(boss:GetDescendants()) do Consider(d) end
        end
    end
    -- the EXPOSED bot (one at a time): its head / core carries the marker, the Highlight covers the whole bot
    for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do
        if count < BossCues.MAX and m:GetAttribute("Exposed") == true and m:GetAttribute("Dead") ~= true and m.Parent then
            local p = m:FindFirstChild("Head") or m:FindFirstChild("Core") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if p and p:IsA("BasePart") then
                seen[p] = true
                count += 1
                if not live[p] then live[p] = NewMarker(p, "EXPOSED"); live[p].Model = m end
            end
        end
    end
    -- targets live outside the boss model (the run / arena effects folder)
    for d in pairs(orbs) do
        if not d.Parent then
            orbs[d] = nil
        elseif count < BossCues.MAX and not seen[d] and d.Transparency < 0.95 and IsBoss(OwnerOf(d)) then
            seen[d] = true
            count += 1
            if not live[d] then live[d] = NewMarker(d, "TARGET") end
        end
    end
    for part in pairs(live) do
        if not seen[part] or not part.Parent then Drop(part) end
    end
end

-- line of sight from the camera to each marked part (12 times a second): the ring only shows when nothing is in the way
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true
local function Visible(cam, part, model)
    local from = cam.CFrame.Position
    local to = part.Position
    local filter = { cam }
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    losParams.FilterDescendantsInstances = filter
    for _ = 1, 4 do -- (see-through bits: glass, effects, other cues -- step past them)
        local r = Workspace:Raycast(from, to - from, losParams)
        if not r then return true end
        local h = r.Instance
        if h == part or h:IsDescendantOf(part) or (model and h:IsDescendantOf(model)) or h.Name == "WeakGlow" then return true end
        if h.Transparency < 0.6 and h.CanQuery then return false end
        table.insert(filter, h)
        losParams.FilterDescendantsInstances = filter
    end
    return false
end
local hlFolder = nil
local function LosPass()
    if not hlFolder or not hlFolder.Parent then
        hlFolder = Instance.new("Folder")
        hlFolder.Name = "AimBossCueHighlights"
        hlFolder.Parent = Workspace
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local list = {}
    for part, m in pairs(live) do
        if part.Parent then
            m.Seen = Visible(cam, part, m.Model)
            table.insert(list, { P = part, M = m, D = (part.Position - camPos).Magnitude })
        end
    end
    -- the cue Highlights go to the nearest visible parts (budget)
    table.sort(list, function(a, b)
        if a.M.Seen ~= b.M.Seen then return a.M.Seen end
        return a.D < b.D
    end)
    for i, e in ipairs(list) do
        local m = e.M
        if i <= BossCues.HL_MAX then
            if not m.HL or not m.HL.Parent then
                local hl = Instance.new("Highlight")
                hl.Name = "AimBossCueHL"
                hl.Adornee = m.Glow or m.Model or e.P -- (a Head / Core weak point: its glow orb, drawn through the decorations)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.FillColor = m.Col
                hl.OutlineColor = m.Col:Lerp(Color3.new(1, 1, 1), 0.35)
                hl.OutlineTransparency = 0
                hl.Parent = hlFolder
                m.HL = hl
            end
            m.HL.Enabled = m.Seen
        elseif m.HL then
            m.HL:Destroy()
            m.HL = nil
        end
    end
end

local function Step()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = os.clock()
    local vs = cam.ViewportSize
    for part, m in pairs(live) do
        if part.Parent then
            local pulse = 0.5 + 0.5 * math.sin((now - m.Born) * ((m.Kind == "TARGET") and 7 or 4))
            local s = 26 + 8 * pulse
            m.Ring.Size = UDim2.fromOffset(s, s)
            m.Stroke.Transparency = 0.1 + 0.35 * (1 - pulse)
            if m.HL then m.HL.FillTransparency = 0.05 + 0.3 * (1 - pulse) end
            if m.Glow then
                m.Glow.CFrame = part.CFrame -- (every frame: the orb never lags or jitters off the hitbox)
                m.Glow.Transparency = 0.15 + 0.3 * (1 - pulse)
            end
            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
            local off = not onScreen or sp.X < 0 or sp.Y < 0 or sp.X > vs.X or sp.Y > vs.Y
            m.Gui.Visible = (not off) and m.Seen
            if not off then
                m.Gui.Position = UDim2.fromOffset(sp.X, sp.Y)
                -- (0.78, owner: "Text should NEVER appear in front of the crosshair"): the "WEAK POINT" word sits under the
                -- ring -- right on the crosshair while you aim at the head -- so it hides near the screen centre
                local lbl = m.Gui:FindFirstChild("Label")
                if lbl then lbl.Visible = lbl.Text ~= "" and (Vector2.new(sp.X, sp.Y) - vs / 2).Magnitude > 150 end
            end
            if m.Arrow then
                m.Arrow.Visible = off
                if off then
                    -- direction from the screen centre (behind the camera: flipped)
                    local rel = cam.CFrame:PointToObjectSpace(part.Position)
                    local dir = Vector2.new(rel.X, -rel.Y)
                    if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
                    dir = dir.Unit
                    local half = vs / 2
                    local k = math.min((half.X - 40) / math.max(1e-3, math.abs(dir.X)), (half.Y - 40) / math.max(1e-3, math.abs(dir.Y)))
                    local p = half + dir * k
                    m.Arrow.Position = UDim2.fromOffset(p.X, p.Y)
                    m.Arrow.Rotation = math.deg(math.atan2(dir.X, -dir.Y))
                    m.Arrow.TextTransparency = 0.1 + 0.3 * (1 - pulse)
                end
            end
        end
    end
end

function BossCues.Init()
    if gui then return end
    gui = Instance.new("Folder")
    gui.Name = "AimBossCues"
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "AimBossCueArrows"; sg.IgnoreGuiInset = true; sg.ResetOnSpawn = false; sg.DisplayOrder = 3
    sg.Parent = LocalPlayer.PlayerGui
    arrowLayer = sg
    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") and string.sub(d.Name, 1, 9) == "ShieldOrb" then orbs[d] = true end
    end)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and string.sub(d.Name, 1, 9) == "ShieldOrb" then orbs[d] = true end
    end
    task.spawn(function()
        while true do
            local ok, err = pcall(Scan)
            if not ok then warn("[BossCues] " .. tostring(err)) end
            task.wait(0.25)
        end
    end)
    task.spawn(function()
        while true do
            local ok, err = pcall(LosPass)
            if not ok then warn("[BossCues] " .. tostring(err)) end
            task.wait(1 / 12)
        end
    end)
    RunService.RenderStepped:Connect(function() pcall(Step) end)
end

return BossCues
