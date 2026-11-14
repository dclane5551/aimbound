--!nocheck
-- ============================================================================================
-- RUN ENCOUNTERS (UPDATE 7 "DEPTH" A1; vault notes "UPDATE 7 - Depth" + "Loot Economy Plan"). Optional events that can
-- turn up on a floor, each built around ONE aim skill and paying its OWN crafting currency:
--   VAULT LOCK (L8, precision -> Shift Shard)   BOUNTY MARK (L18, tracking -> Graft)   [this module]
--   RIFT TEAR (L30, flicking -> Strip Shard)     ECHO DUEL (L45, dodge + hit -> Temper) [EncounterMark / Tear / Duel]
-- The other three are their own modules (EncounterMark, EncounterTear, EncounterDuel) using the helpers here; every kind
-- has Build(dungeon, layout, onStart) -> (model, anchorCF), Mark(model, state), Start(ctx), OnShot(result, consumesAmmo),
-- Active(), Cancel(), DevAct(what). Encounters.Kind(id) finds it; Encounters.Active / OnShot / Cancel / DevAct dispatch.
--
-- VAULT LOCK (precision): a steel vault by the entrance. PICK THE LOCK shows lime lock pins on its door ONE at a time,
-- each moving on a small path. Hit the pin -> the next one. A trigger pull that misses (every pellet / burst round of it)
-- or a pin left too long RESETS the lock to pin 1. The whole lock has WINDOW seconds, then it jams. Cracked: items with
-- better odds + gold + Shift Shards (from their unlock level), more when it was cracked clean (no resets).
--
-- Who runs what: the SERVER rolls the encounter (DungeonRuns: folder attrs Encounter / EncounterState) and pays it
-- (EncounterAction "Start" / "Finish" -> CombatServer.EncounterReward, checked: rolled, in range, plausible time, once).
-- The CLIENT builds the vault (DungeonClient) and runs the lock (this module) -- the pins are tiny and fast, so they're
-- judged locally like the Aim Trials (a known, accepted limit: aim-trial scores are client-reported too).
-- Shots reach the lock through AimRngClient's ExecuteRaycastShot (UI.LockShot -> Encounters.OnShot).
-- ============================================================================================
local Encounters = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

Encounters.ON = true -- (one switch per system, Loot Economy Plan section 7)
Encounters.CHANCE = 0.35 -- per eligible floor (floor 2+, not a boss floor, the level unlocked)
Encounters.USE_RANGE = 26 -- studs from the vault (server check, start)
Encounters.FINISH_RANGE = 60 -- studs (server check, finish)

Encounters.Defs = {
    VAULT_LOCK = {
        Name = "Tumbler", Unlock = 8, Weight = 1, Prompt = "Pick the lock", Color = Color3.fromRGB(170, 255, 60),
        Text = "Hit every moving pin on the door. A missed shot or a pin you let slip resets the lock.",
    },
    BOUNTY_MARK = {
        Name = "The Runner", Unlock = 18, Weight = 1, Prompt = "Call the mark", Color = Color3.fromRGB(255, 120, 60), Module = "EncounterMark",
        Text = "A marked target sprints and jukes round the room. Land enough hits before it escapes.",
    },
    RIFT_TEAR = {
        Name = "The Breach", Unlock = 30, Weight = 1, Prompt = "Open the tear", Color = Color3.fromRGB(190, 110, 255), Module = "EncounterTear",
        Text = "Targets spill out of the tear one after another and vanish fast. Every kill before it closes pays more.",
    },
    ECHO_DUEL = {
        Name = "Mirror Match", Unlock = 45, Weight = 1, Prompt = "Face your echo", Color = Color3.fromRGB(120, 230, 255), Module = "EncounterDuel",
        Text = "Your echo strafes and throws strikes at you. Land enough hits without being hit once.",
    },
}
Encounters.Order = { "VAULT_LOCK", "BOUNTY_MARK", "RIFT_TEAR", "ECHO_DUEL" }

-- the encounter this floor gets (server), or nil
function Encounters.Roll(level: number, floorNumber: number, isBossFloor: boolean, rng: Random?): string?
    if not Encounters.ON or floorNumber < 2 or isBossFloor then return nil end
    local r = rng or Random.new()
    if r:NextNumber() >= Encounters.CHANCE then return nil end
    local pool, total = {}, 0
    for _, id in ipairs(Encounters.Order) do
        local d = Encounters.Defs[id]
        if (level or 1) >= d.Unlock then table.insert(pool, id); total += d.Weight end
    end
    if #pool == 0 then return nil end
    local x = r:NextNumber() * total
    for _, id in ipairs(pool) do
        x -= Encounters.Defs[id].Weight
        if x <= 0 then return id end
    end
    return pool[1]
end

-- where the vault stands: inside the clear zone at the north doorway, off the walk-in line (both sides use this)
function Encounters.Position(layout: any): Vector3
    return Vector3.new((layout.CombatX or 0) + 15, 2, layout.CombatZ - layout.CombatSize / 2 + 16) -- (CombatX: LINKED ROOMS side room)
end

-- an encounter's numbers on a difficulty (rank 1..#DifficultyOrder) + bot skill (1-10, 4 = standard); the server sends them with "Start"
function Encounters.Params(id: string, difficultyRank: number?, botSkill: number?): any
    local d = math.clamp(tonumber(difficultyRank) or 1, 1, #require(script.Parent:WaitForChild("ItemData")).DifficultyOrder) -- (FUTURE-PROOF: every tier scales)
    local sk = math.clamp(tonumber(botSkill) or 4, 1, 10)
    local k = 1 + (sk - 4) * 0.05
    if id == "BOUNTY_MARK" then
        -- hits (a trigger pull that lands = 1, x the gun's shot weight) before it escapes; it runs Speed studs/s, juking
        return { Hits = 12 + math.floor(d / 2), Speed = (13 + 0.6 * d) * k, Juke = math.max(0.45, 1.1 - 0.035 * d) / k, Window = 20, Size = 1.0 }
    elseif id == "RIFT_TEAR" then
        -- one target at a time; each lives Life s; Gap s between them; kills are the score
        return { Life = math.max(0.65, (1.35 - 0.035 * d) / k), Gap = 0.15, Size = math.max(0.7, 1.15 - 0.025 * d), Window = 20 }
    elseif id == "ECHO_DUEL" then
        -- hits (pulls x shot weight) to break the echo; it strikes every Every s with a Windup s telegraph of Radius studs
        return { Hits = 14 + math.floor(d / 2), Speed = (9 + 0.4 * d) * k, Every = math.max(1.4, 2.4 - 0.05 * d) / k,
            Windup = math.max(0.75, 1.15 - 0.02 * d), Radius = 6, Window = 30, Size = 1.2 }
    end
    return Encounters.LockParams(difficultyRank, botSkill)
end

-- the lock's numbers on a difficulty (rank 1..#DifficultyOrder) + bot skill (1-10, 4 = standard)
function Encounters.LockParams(difficultyRank: number?, botSkill: number?): any
    local d = math.clamp(tonumber(difficultyRank) or 1, 1, #require(script.Parent:WaitForChild("ItemData")).DifficultyOrder) -- (FUTURE-PROOF: every tier scales)
    local sk = math.clamp(tonumber(botSkill) or 4, 1, 10)
    local k = 1 + (sk - 4) * 0.05
    return {
        Pins = 5 + math.floor(d / 4), -- 5 .. 8
        PinTime = math.max(1.4, (2.6 - 0.06 * d) / k), -- seconds before a pin slips: 2.5 .. 1.8 at standard skill
        Speed = (2.2 + 0.25 * d) * k, -- studs a second along its path
        Size = math.max(0.55, 0.95 - 0.025 * d), -- pin diameter in studs
        Window = 30,
    }
end

-- ==================== CLIENT: the vault model ====================
local function P(parent: Instance, props: any): BasePart
    local p = Instance.new(props.Class or "Part")
    props.Class = nil
    p.Anchored = true
    p.CanCollide = props.CanCollide ~= false
    props.CanCollide = nil
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end

-- ground height under a point (the dungeon's static geometry + terrain)
local function GroundY(dungeon: Instance, pos: Vector3): number
    local geo = dungeon:FindFirstChild("StaticGeometry")
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { geo or dungeon, Workspace.Terrain }
    local hit = Workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), rp)
    return hit and hit.Position.Y or pos.Y
end

Encounters.P, Encounters.GroundY = P, GroundY -- (for the other kinds' modules)

-- a sign plate with text facing the room (every kind's name plate)
function Encounters.Plate(model: Model, cf: CFrame, w: number, text: string, color: Color3): BasePart
    local plate = P(model, { Name = "Plate", Size = Vector3.new(w, 0.9, 0.12), CFrame = cf, Color = Color3.fromRGB(32, 35, 42), Material = Enum.Material.Metal })
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 60
    sg.LightInfluence = 0
    sg.Parent = plate
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Sub"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextColor3 = color
    lbl.Text = text
    lbl.Parent = sg
    return plate
end
-- the prompt every kind uses
function Encounters.Prompt(parent: Instance, action: string, object: string, onStart: () -> ())
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = action
    prompt.ObjectText = object
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Parent = parent
    prompt.Triggered:Connect(function() onStart() end)
    Encounters._DevStart = onStart -- (Studio test hook: AimRngClient DevAct "lock:start" starts whichever kind is on the floor)
    return prompt
end
-- the stand's frame: on the ground at Position, facing the room
function Encounters.Face(dungeon: Instance, layout: any): CFrame
    local base = Encounters.Position(layout)
    base = Vector3.new(base.X, GroundY(dungeon, base), base.Z)
    return CFrame.lookAt(base, Vector3.new(layout.CombatX or 0, base.Y, layout.CombatZ))
end
-- the generic done / failed look: plate text + prompt off
function Encounters.MarkPlate(model: Model?, state: string, doneText: string, failText: string)
    if not model or not model.Parent then return end
    local sub = model:FindFirstChild("Sub", true)
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if state == "OPEN" then
        if sub then sub.Text = doneText end
        if prompt then prompt.Enabled = false end
    elseif state == "JAMMED" then
        if sub then sub.Text = failText; sub.TextColor3 = Color3.fromRGB(170, 170, 180) end
        if prompt then prompt.Enabled = false end
    elseif state == "PICKING" then
        if prompt then prompt.Enabled = false end
    end
end

-- builds the vault facing the room; returns the model + its door frame (the pins live in front of it)
function Encounters.BuildVault(dungeon: Instance, layout: any, onStart: () -> ()): (Model, CFrame)
    local base = Encounters.Position(layout)
    base = Vector3.new(base.X, GroundY(dungeon, base), base.Z)
    local face = CFrame.lookAt(base, Vector3.new(layout.CombatX or 0, base.Y, layout.CombatZ)) -- (the door looks into the room)
    local model = Instance.new("Model")
    model.Name = "Encounter_VAULT_LOCK"
    model:SetAttribute("KeepNeon", true)
    local steel, dark, brass = Color3.fromRGB(70, 76, 88), Color3.fromRGB(32, 35, 42), Color3.fromRGB(196, 160, 82)
    -- plinth + body
    P(model, { Name = "Plinth", Size = Vector3.new(9, 0.8, 7), CFrame = face * CFrame.new(0, 0.4, 0), Color = dark, Material = Enum.Material.Slate })
    local body = P(model, { Name = "Body", Size = Vector3.new(7.4, 8, 5.4), CFrame = face * CFrame.new(0, 4.8, 0), Color = steel, Material = Enum.Material.DiamondPlate })
    P(model, { Name = "Top", Size = Vector3.new(7.9, 0.5, 5.9), CFrame = face * CFrame.new(0, 9.05, 0), Color = dark, Material = Enum.Material.Metal })
    for _, sx in ipairs({ -1, 1 }) do
        P(model, { Name = "Rib", Size = Vector3.new(0.5, 8.2, 5.8), CFrame = face * CFrame.new(sx * 3.75, 4.9, 0), Color = dark, Material = Enum.Material.Metal })
    end
    -- the door: a thick round disc on the front face (-Z of the face frame looks into the room; turned 90 deg about Y,
    -- the cylinder's +X axis points into the room)
    local doorCF = face * CFrame.new(0, 5, -2.75) * CFrame.Angles(0, math.rad(90), 0)
    P(model, { Name = "DoorRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6.4, 6.4), CFrame = doorCF, Color = brass, Material = Enum.Material.Metal })
    P(model, { Name = "Door", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5.8, 5.8), CFrame = doorCF * CFrame.new(0.12, 0, 0), Color = Color3.fromRGB(54, 58, 68), Material = Enum.Material.Metal })
    local ring = P(model, { Name = "LockRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 5.2, 5.2), CanCollide = false,
        CFrame = doorCF * CFrame.new(0.44, 0, 0), Color = Encounters.Defs.VAULT_LOCK.Color, Material = Enum.Material.Neon, Transparency = 0.55 })
    P(model, { Name = "RingMask", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 4.7, 4.7), CanCollide = false,
        CFrame = doorCF * CFrame.new(0.45, 0, 0), Color = Color3.fromRGB(54, 58, 68), Material = Enum.Material.Metal })
    local dial = P(model, { Name = "Dial", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.4, 1.4), CFrame = doorCF * CFrame.new(0.6, 0, 0), Color = brass, Material = Enum.Material.Metal })
    for i = 0, 3 do -- the four bolts round the door
        local a = math.rad(45 + i * 90)
        P(model, { Name = "Bolt", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = doorCF * CFrame.new(0.35, math.sin(a) * 2.55, math.cos(a) * 2.55), Color = brass, Material = Enum.Material.Metal })
    end
    -- name plate
    local plate = P(model, { Name = "Plate", Size = Vector3.new(4.6, 0.9, 0.12), CFrame = face * CFrame.new(0, 1.6, -2.75), Color = dark, Material = Enum.Material.Metal })
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front -- (Front = the plate's -Z side, which faces the room)
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 60
    sg.LightInfluence = 0
    sg.Parent = plate
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Sub"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextColor3 = Encounters.Defs.VAULT_LOCK.Color
    lbl.Text = "TUMBLER"
    lbl.Parent = sg
    -- the prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = Encounters.Defs.VAULT_LOCK.Prompt
    prompt.ObjectText = "Tumbler"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Parent = body
    prompt.Triggered:Connect(function() onStart() end)
    Encounters._DevStart = onStart -- (Studio test hook: AimRngClient DevAct "lock:start")
    model.PrimaryPart = body
    model.Parent = dungeon
    model:SetAttribute("DoorCF", doorCF)
    local _ = dial
    return model, doorCF * CFrame.new(0.9, 0, 0) -- (the pin plane, a little in front of the door: the cylinder's +X looks into the room)
end

-- mark the vault open / jammed (state from the server's EncounterState)
function Encounters.MarkVault(model: Model?, state: string)
    if not model or not model.Parent then return end
    local ring = model:FindFirstChild("LockRing")
    local sub = model:FindFirstChild("Sub", true)
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if state == "OPEN" then
        if ring then ring.Color = Color3.fromRGB(255, 210, 90); ring.Transparency = 0.2 end
        if sub then sub.Text = "CRACKED" end
        if prompt then prompt.Enabled = false end
    elseif state == "JAMMED" then
        if ring then ring.Color = Color3.fromRGB(110, 110, 120); ring.Material = Enum.Material.Metal; ring.Transparency = 0 end
        if sub then sub.Text = "JAMMED"; sub.TextColor3 = Color3.fromRGB(170, 170, 180) end
        if prompt then prompt.Enabled = false end
    elseif state == "PICKING" then
        if prompt then prompt.Enabled = false end
    end
end

-- ==================== CLIENT: the lock session ====================
-- ctx = { Model, PinCF (door frame), Params, UIStyle, SoundHelper, OnDone(result) } -> result { Ok, Resets, Time }
local session = nil

local function NewPin(s)
    local pr = s.Params
    local i = s.Index
    -- each pin: a path in the door's plane (local Y = up, Z = sideways): a circle, a sideways sweep or a figure eight,
    -- round a point inside the door; later pins move faster
    local rng = s.Rng
    local kind = ({ "Circle", "Sweep", "Eight" })[rng:NextInteger(1, 3)]
    local cy, cz = rng:NextNumber(-1.0, 1.0), rng:NextNumber(-1.0, 1.0)
    local amp = rng:NextNumber(1.1, 1.8)
    local speed = pr.Speed * (1 + 0.06 * (i - 1))
    local pin = P(Workspace, { Name = "LockPin", Shape = Enum.PartType.Ball, Size = Vector3.one * pr.Size, CanCollide = false,
        Color = Encounters.Defs.VAULT_LOCK.Color, Material = Enum.Material.Neon, CFrame = s.PinCF })
    pin.CanQuery = true
    pin:SetAttribute("KeepNeon", true)
    local halo = P(pin, { Name = "PinHalo", Shape = Enum.PartType.Ball, Size = Vector3.one * (pr.Size * 1.9), CanCollide = false,
        Color = Encounters.Defs.VAULT_LOCK.Color, Material = Enum.Material.ForceField, Transparency = 0.5, CFrame = s.PinCF })
    halo.CanQuery = false
    s.Pin = { Part = pin, Halo = halo, Kind = kind, CY = cy, CZ = cz, Amp = amp, W = speed / math.max(0.5, amp), T0 = os.clock(), Ph = rng:NextNumber(0, 6.28) }
end

local function DropPin(s, burst: boolean)
    local p = s.Pin
    s.Pin = nil
    if not p then return end
    if burst and p.Part.Parent then
        local f = P(Workspace, { Name = "PinBurst", Shape = Enum.PartType.Ball, Size = Vector3.one * (s.Params.Size * 2.6), CanCollide = false,
            Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.3, CFrame = p.Part.CFrame })
        f.CanQuery = false
        game:GetService("Debris"):AddItem(f, 0.12)
    end
    p.Part:Destroy()
end

-- (an encounter HUD is its own ScreenGui, so it would draw over windows: hidden while any window in the HUD's Menus folder
-- is open). Every kind calls this each frame.
function Encounters.HudTick(h: any)
    if not h then return end
    local now = os.clock()
    if now - (h.MenuCheck or 0) > 0.2 then
        h.MenuCheck = now
        local menus = h.Menus
        if not (menus and menus.Parent) then
            local hud = Players.LocalPlayer.PlayerGui:FindFirstChild("AimRngMasterHUD")
            menus = hud and hud:FindFirstChild("Menus")
            h.Menus = menus
        end
        local open = false
        if menus then
            for _, c in ipairs(menus:GetChildren()) do
                if c:IsA("GuiObject") and c.Visible then open = true; break end
            end
        end
        h.Gui.Enabled = not open
    end
end
local function Hud(s)
    local h = s.Hud
    if not h then return end
    Encounters.HudTick(h)
    local pins = {}
    for i = 1, s.Params.Pins do pins[i] = (i < s.Index) and "●" or "○" end
    local left = math.max(0, s.Params.Window - (os.clock() - s.Start))
    h.Pins.Text = table.concat(pins, " ")
    h.Info.Text = string.format("%d s left  •  resets %d", math.ceil(left), s.Resets)
end

local function Finish(s, ok: boolean, why: string?)
    if session ~= s then return end
    session = nil
    DropPin(s, false)
    if s.Conn then s.Conn:Disconnect() end
    if s.Hud then
        s.Hud.Pins.Text = ok and "CRACKED" or (why or "JAMMED")
        s.Hud.Info.Text = ok and ((s.Resets == 0) and "clean crack: bonus loot" or ("resets " .. s.Resets)) or ""
        local gui = s.Hud.Gui
        task.delay(2.2, function() if gui then gui:Destroy() end end)
    end
    pcall(s.OnDone, { Ok = ok, Resets = s.Resets, Time = os.clock() - s.Start })
end

local function Reset(s, why: string)
    s.Resets += 1
    s.Index = 1
    DropPin(s, false)
    if s.SoundHelper then pcall(s.SoundHelper.Play, "Empty") end
    local ring = s.Model and s.Model:FindFirstChild("LockRing")
    if ring then
        ring.Color = Color3.fromRGB(255, 70, 70)
        task.delay(0.25, function() if ring.Parent then ring.Color = Encounters.Defs.VAULT_LOCK.Color end end)
    end
    if s.Hud then
        s.Hud.Flash.Text = why
        task.delay(0.8, function() if s.Hud and s.Hud.Flash then s.Hud.Flash.Text = "" end end)
    end
    NewPin(s)
end

local function LockActive(): boolean return session ~= nil end

-- AimRngClient's ExecuteRaycastShot calls this for every ray while a lock runs. true = the ray hit the pin (the shot is
-- the lock's, nothing else happens); false = carry on as a normal shot (enemies still take hits) -- but a trigger pull
-- (consumesAmmo ~= false) whose rays all miss the pin resets the lock 0.2 s later.
local function LockOnShot(result: RaycastResult?, consumesAmmo: boolean?): boolean
    local s = session
    if not s then return false end
    local hit = s.Pin and result and result.Instance == s.Pin.Part
    if consumesAmmo ~= false then
        local pull = {}
        s.Pull = pull
        pull.Hit = hit == true
        task.delay(0.2, function()
            if session == s and s.Pull == pull and not pull.Hit then Reset(s, "MISSED") end
        end)
    elseif hit and s.Pull then
        s.Pull.Hit = true
    end
    if not hit then return false end
    if s.SoundHelper then pcall(s.SoundHelper.Play, "HitCrit") end
    DropPin(s, true)
    s.Index += 1
    if s.Index > s.Params.Pins then
        Finish(s, true)
    else
        NewPin(s)
    end
    return true
end

local function BuildHud(UIStyle, title: string?, color: Color3?): any
    local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg or not UIStyle then return nil end
    color = color or Encounters.Defs.VAULT_LOCK.Color
    local gui = Instance.new("ScreenGui")
    gui.Name = "VaultLockHUD" -- (every kind's HUD: one name, so tests / hiding find it)
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 6
    gui.Parent = pg
    -- (right side, under the run banner + its EXIT button and level with / below the objective line: away from the crosshair
    -- and the MOVE! callout)
    local box = UIStyle.New("Frame", { Name = "Box", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 100), Size = UDim2.fromOffset(300, 64),
        BackgroundColor3 = Color3.fromRGB(16, 18, 24), BackgroundTransparency = 0.08, Parent = gui })
    if UIStyle.InkEdge then UIStyle.InkEdge(2).Parent = box end
    local band = UIStyle.New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), Parent = box })
    local _ = band
    local title = UIStyle.Text({ Text = title or "TUMBLER", TextSize = 14, TextColor3 = color, Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(0, 160, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
    local _t = title
    local pins = UIStyle.Text({ Name = "Pins", Text = "", TextSize = 18, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(0.55, -12, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
    local info = UIStyle.Text({ Name = "Info", Font = UIStyle.BodyFont, Text = "", TextSize = 13, TextColor3 = Color3.fromRGB(200, 205, 220),
        Position = UDim2.new(0.55, 0, 0, 30), Size = UDim2.new(0.45, -12, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
    local flash = UIStyle.Text({ Name = "Flash", Text = "", TextSize = 13, TextColor3 = Color3.fromRGB(255, 110, 100), Position = UDim2.new(0.55, 0, 0, 6),
        Size = UDim2.new(0.45, -12, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
    return { Gui = gui, Pins = pins, Main = pins, Info = info, Flash = flash }
end
Encounters.BuildHud = BuildHud
-- the end of any kind's HUD: a result line, then gone after 2.2 s
function Encounters.HudDone(h: any, main: string, info: string?)
    if not h then return end
    h.Main.Text = main
    h.Info.Text = info or ""
    local gui = h.Gui
    task.delay(2.2, function() if gui then gui:Destroy() end end)
end

function Encounters.StartLock(ctx: any)
    if session then return end
    local s = {
        Model = ctx.Model, PinCF = ctx.PinCF, Params = ctx.Params, SoundHelper = ctx.SoundHelper, OnDone = ctx.OnDone,
        Index = 1, Resets = 0, Start = os.clock(), Rng = Random.new(), Hud = BuildHud(ctx.UIStyle),
    }
    session = s
    if s.SoundHelper then pcall(s.SoundHelper.Play, "ShieldUp") end
    NewPin(s)
    s.Conn = RunService.RenderStepped:Connect(function()
        if session ~= s then return end
        local now = os.clock()
        if now - s.Start >= s.Params.Window then Finish(s, false, "JAMMED"); return end
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 or (s.Model and s.Model.Parent == nil)
            or (root.Position - s.PinCF.Position).Magnitude > Encounters.FINISH_RANGE then
            Finish(s, false, "LEFT THE VAULT"); return
        end
        local p = s.Pin
        if p then
            if now - p.T0 >= s.Params.PinTime then Reset(s, "TOO SLOW"); return end
            local t = (now - p.T0) * p.W + p.Ph
            local y, z
            if p.Kind == "Circle" then y, z = math.sin(t) * p.Amp * 0.8, math.cos(t) * p.Amp
            elseif p.Kind == "Sweep" then y, z = math.sin(t * 0.5) * 0.4, math.sin(t) * p.Amp * 1.3
            else y, z = math.sin(2 * t) * p.Amp * 0.6, math.sin(t) * p.Amp end
            -- (kept inside the door: radius 2.4 round its middle)
            local py, pz = math.clamp(p.CY + y, -2.3, 2.3), math.clamp(p.CZ + z, -2.3, 2.3)
            local cf = s.PinCF * CFrame.new(0, py, pz)
            p.Part.CFrame = cf
            p.Halo.CFrame = cf
            -- (the halo shrinks as the pin's time runs out)
            local k = 1 - (now - p.T0) / s.Params.PinTime
            p.Halo.Size = Vector3.one * (s.Params.Size * (1.2 + 0.9 * k))
        end
        Hud(s)
    end)
    Hud(s)
end

-- Studio test hooks for the lock: "hit" / "miss" through the real OnShot path with a fake ray
local function LockDevAct(what: string)
    local s = session
    if not s then return end
    if what == "hit" and s.Pin then LockOnShot({ Instance = s.Pin.Part } :: any, true)
    elseif what == "miss" then LockOnShot(nil, true) end
end

-- ==================== THE KINDS ====================
local VAULT = {
    Build = function(dungeon, layout, onStart) return Encounters.BuildVault(dungeon, layout, onStart) end,
    Mark = function(model, state) Encounters.MarkVault(model, state) end,
    Start = function(ctx) Encounters.StartLock(ctx) end,
    OnShot = LockOnShot, Active = LockActive, DevAct = LockDevAct,
    Cancel = function() if session then Finish(session, false, "JAMMED") end end,
}
local kinds = { VAULT_LOCK = VAULT }
function Encounters.Kind(id: string): any
    if kinds[id] then return kinds[id] end
    local def = Encounters.Defs[id]
    if not def or not def.Module then return nil end
    local ok, mod = pcall(function() return require(script.Parent:WaitForChild(def.Module)) end)
    if not ok then warn("[Encounters] " .. tostring(def.Module) .. ": " .. tostring(mod)); return nil end
    kinds[id] = mod
    return mod
end
local function ActiveKind(): any
    for _, k in pairs(kinds) do if k.Active() then return k end end
    return nil
end
function Encounters.Active(): boolean return ActiveKind() ~= nil end
function Encounters.OnShot(result: RaycastResult?, consumesAmmo: boolean?): boolean
    local k = ActiveKind()
    return k ~= nil and k.OnShot(result, consumesAmmo) == true
end
-- Studio test hooks (AimRngClient DevAct "lock:start" / "lock:hit" / "lock:miss" / "lock:<anything>")
function Encounters.DevAct(what: string)
    if what == "start" and Encounters._DevStart then Encounters._DevStart() return end
    local k = ActiveKind()
    if k and k.DevAct then k.DevAct(what) end
end
-- stop a running encounter (floor change, death) without a result
function Encounters.Cancel()
    for _, k in pairs(kinds) do if k.Active() then k.Cancel() end end
end
-- a pull's weight for hit-count goals (DungeonClient sets it from the gun: slow guns count more), 1 if unknown
Encounters.ShotWeight = function() return 1 end

return Encounters
