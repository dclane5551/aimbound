--!nocheck
-- MOVEMENT (client). One movement for everyone (owner 2026-10-03: "remove grappling and wall running entirely ... I want
-- the movement to be simpler, right now it takes away from the aiming aspect" + "just have [this movement] in the game
-- and remove movement style from the settings"). The removed styles / grapple / wall run are archived in
-- archive/movement/ (with how to bring them back).
--   * RUN: Source-style ground (accelerate / friction at a fixed 128 ticks); above run speed your keys steer the
--     momentum while the ground takes it off fast (OverBleed) -- land without jumping and the speed is gone.
--   * BHOP [hold Space]: land with Space held and you jump again the same frame, keeping your speed. In the air a held
--     movement key (W, A, S or D) builds speed the way it points (KeyGain/s, fading out toward AirFadeTop) and swings
--     your momentum toward it; a key against your motion brakes.
--   * SLIDE [C / Ctrl]: every press is a fresh slide that puts you at TargetMult x run speed (+MinAdd when already
--     faster), then sheds Friction/s and stands you up. Jumping out of a slide = SLIDE-HOP (+HopAdd, once per
--     HopCooldown); hold crouch + Space and every landing slide-hops.
--   * DASH [Shift]: a short burst toward your keys (3 stamina bars); you leave it at least as fast as you went in.
--   * MELEE DASH-STRIKE: the melee heavy attack dashes where you look (its own cooldown).
-- The camera reacts (lean / FOV / eye height): AimRngClient reads CamRoll, FovKick, EyeOffset.
-- Off in the hub hall (third person; Shift is shift lock there), while downed / spectating, in menus and in trials --
-- the Humanoid walks normally then.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Shared = script.Parent
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Zones = require(Shared:WaitForChild("Zones"))
local slideSent, slideSentAt = false, 0

local M = {}
M.CamRoll = 0      -- radians: camera lean (dash strafe)
M.FovKick = 0      -- degrees added to the field of view
M.EyeOffset = 0    -- studs added to eye height (slide crouch, landing dip)
M.State = "None"   -- "None" | "Dash" | "Slide"

-- ==================== tuning (owner feel-tests these) ====================
-- MEASURED from the owner's reference clip (2026-10-03, its on-screen speed readout, studs/s): run 15.6 (ours 16); a slide
-- puts you at ~29 (1.85 x run) and loses ~40/s; every crouch press re-slides, so spamming holds ~25 on the ground but never
-- stacks past ~29; a slide-hop at speed added ~+12-16; landing without jumping: 33.7 -> 15.7 in 0.1 s; bhopping with a
-- key held builds ~14/s up to 35, fading in a straight line to nothing at 80 (~7/s at 55, ~3/s at 70). Owner: bhop like
-- that in EVERY direction (any movement key), and hold Space instead of clicking it.
local T = {
    -- ground: CS 1.6-like accelerate 10 / friction 6 / stopspeed 110 (units x U, CS run 250 u/s = our 16 studs/s), fixed
    -- 128 ticks/s; above run speed your keys steer the momentum (GroundGrip rad/s) while it bleeds OverBleed studs/s per s.
    -- air: a held key builds KeyGain/s along it (full below AirFadeStart, nothing at AirFadeTop), turning your momentum
    -- toward it at AirTurn rad/s; a key against your motion brakes AirBrake/s.
    Source = { U = 16 / 250, Friction = 6, StopSpeed = 110, Accelerate = 10, Tick = 1 / 128, GroundGrip = 14, OverBleed = 200,
        KeyGain = 5, AirFadeStart = 18, AirFadeTop = 26, AirTurn = 7, AirBrake = 45, AirReverse = 200 }, -- (0.60: KeyGain 14, fade 35..80)
    -- JumpBuffer: Space pressed this long before landing still hops. LandGrace: steer-only window right after landing.
    Ground = { JumpBuffer = 0.12, LandGrace = 0 },
    Dash = { Speed = 60, Time = 0.16, Exit = 20, Keep = 1.0, Fov = 4, Roll = math.rad(1.5) }, -- (Fov 9 / Roll 4: mushy; 0.60: Speed 92 / Exit 44)
    -- MELEE DASH-STRIKE (M.MeleeDash): the heavy attack with the melee out, in any direction, on its own cooldown
    MeleeDash = { Speed = 70, Time = 0.2, Exit = 22, Cooldown = 2.0 }, -- (0.60: 105 / 46)
    Stamina = { Bars = 3, GroundRate = 1 / 1.3, AirRate = 1 / 3.0 },
    -- SLIDE: TargetMult x run speed (MinAdd on top when already faster), Friction studs/s per s, MaxTime at most; a press
    -- mid-slide is a fresh slide; jumping out adds HopAdd once per HopCooldown. ChainWindow: a re-slide right after one
    -- ends picks its speed back up. Steering: TurnRate toward your keys, LookTurnRate toward the view with no key held.
    -- Cooldown (0.61, owner: "Sliding is a bit too spammable with the new movement change"): a new slide (a fresh press, a
    -- press mid-slide or a landing slide) can start at most once per Cooldown seconds; until then crouch is just crouch.
    Slide = { TargetMult = 1.4, MinAdd = 1, HopAdd = 3, HopCooldown = 1.2, Friction = 42, MaxTime = 0.6, ChainWindow = 1.0, Cooldown = 1.1,
        MinSpeed = 8, SlopeAccel = 75, Eye = -1.75, TurnRate = 14, LookTurnRate = 7,
        -- crouch held while moving faster than AutoSpeed x walk speed on the ground starts a slide by itself
        AutoSpeed = 1.15 },
    Crouch = { Speed = 0.6, Eye = -1.1, AirEye = -0.6 },
    -- SoftCap: gains shrink fast past it (SoftGain); MaxSpeed / MaxUp are only the hard safety net
    SoftCap = 22, MaxSpeed = 140, MaxUp = 60,
    -- MOMENTUM CAP (0.60, owner: "I want the player to be far slower than the bots. Because this game is aim-based, moving so
    -- fast kind of removes that aspect. Lets scale back the momentum gain and add a cap"): outside a dash your horizontal speed
    -- never passes MomentumCap (run 16, slides ~22, bhop / slide-hop gains stop there); a dash may burst past it to DashCap.
    -- DUELS (PvP): PvpCap, DashCap PvpDashCap, no bhop on landing, a jump at most every PvpJumpGap s, no melee dash.
    MomentumCap = 24, DashCap = 60, PvpCap = 18, PvpDashCap = 30, PvpJumpGap = 0.75, -- (DUELS v3: dash cap 30 -> 42, a real dodge)
    -- QUAKE DUEL MODE (0.63, owner: "make the vamp and movement feel JUST like quake live lg duels. Right now it just feels
    -- sluggish"): in a duel the movement is Quake's (scaled with the CS unit above, 1 u = 0.064 studs): run 320 u/s
    -- (Run 20.5), ground accelerate 10 / friction 6 (the Source ground above), a low quick hop (Quake: jump 270 u/s,
    -- gravity 800 u/s^2 -> Gravity 60 studs/s^2, JumpHeight 3, ~0.6 s in the air), hold Space to bunny hop with no gap,
    -- and air strafing builds speed (KeyGain, fading from FadeStart to FadeTop ~ Quake's 500-550 u/s strafe-jump pace).
    -- No dash, no slide, no knife dash (Quake has none). The game's PvpCap / PvpJumpGap above are replaced by Cap.
    -- DUELS v3 (2026-10-14, owner: "you can jump spam ... overall bland"): a jump at most every JumpGap s (PvpData.JUMP_GAP),
    -- dash + slide are back -- dash with DashBars charge(s) that refill in DashRecharge s.
    -- DUEL PACE (2026-10-15, owner: "The pvp speed is too fast / reactive ... a bit slower, focusing more on mouse control and
    -- tracking" -> pass 2 "I dont like the delay, make the overall movement slightly slower to compensate"): the snappy
    -- Source ground / air response stays (no duel overrides: SrcK falls back to T.Source); the duel is just slower:
    -- run 14 (was 20.5 x PvpData.MOVE_MULT 1.12 = 23), strafe-jump gain KeyGain 6 up to Cap 22, dash capped at
    -- PvpDashCap 30 with a 6 s recharge. (SrcK reads Accelerate / Friction / GroundGrip / AirReverse here if ever set.)
    Quake = { Run = 14, Gravity = 60, JumpHeight = 3, KeyGain = 6, FadeStart = 16, FadeTop = 22, Cap = 22, AirTurn = 8,
        JumpGap = 0.9, DashBars = 1, DashRecharge = 6 },
}
M.Tuning = T

local LocalPlayer = Players.LocalPlayer
local char, hum, root, att, lv
local stamina = T.Stamina.Bars
local dash, slide = nil, nil
local dashSentAt = nil
local lastSlideBoost = -99
local quakeOn, quakeSaved = false, nil -- (QUAKE DUEL MODE: on / the gravity + hop height to restore)
local dashEndedAt = -99 -- a slide started right as a dash ends always gets its boost (dash-slide)
local slideEndedAt = -99 -- (spam sliding: a re-slide inside T.Slide.ChainWindow chains)
local slideStartedAt = -99 -- (0.61: T.Slide.Cooldown)
-- (owner 2026-10-03: "If I dash, and then slide, and continue sliding over and over, I should be able to maintain that
-- speed. Right now you lose that speed when sliding") the speed a slide ended at: a re-slide inside ChainWindow picks it
-- back up, so the moment you spend standing between slides doesn't eat a dash's speed
local slideEndSpeed = 0
local slideHeld = false
-- COMMITTED SLIDES (owner 2026-10-02: "the sliding still doesn't really work. You can't slide cancel or slide hop, you
-- should always be able to do so with any input and maintain momentum"): a TAP of crouch slides now (letting go used to
-- end it instantly -- a tap gave +7 speed for 0.3 s). A slide runs until it slows to a walk; jump / dash end it keeping
-- the speed; crouch pressed in the air is remembered so the landing slides (slide hop);
-- a bump that lifts you off the floor resumes the slide on touch-down.
local slidePressAt = -99   -- crouch pressed while it couldn't slide yet (air / mid-dash): slide on landing
local slideResumeUntil = 0 -- slid off a lip without jumping: land back into the slide
local SLIDE_BUFFER = 0.35
-- (owner 2026-10-03: "make it so you have to actually hit the slide keybind again to repeat it, you can just hold it down and
-- infinitely slide") every PRESS arms exactly one slide; holding the key starts no more. A press in the air still slides you
-- on landing (slide hop), and it's that press's one slide.
local slideArmed = false
M.SlideAmount = 0          -- eased 0..1 while sliding (AimRngClient: viewmodel tilt, speed streaks, body pose)
M.DashAmount = 0           -- eased 0..1 while dashing (AimRngClient: DASH ANIMATION -- body lunge, gun tuck, streaks)
M.DashSide = 0             -- -1..1: how sideways the dash is to where you look (the lunge leans into it)
local jumpPressAt = -99
local lastBhopAt = -99
local landGraceUntil = 0
local BhopJump -- (defined below; Space during the landing grace calls it)
local fovImpulse, rollImpulse, landDip = 0, 0, 0
local wasGrounded, airVy, groundT = true, 0, 0
local airHV = Vector3.zero -- horizontal velocity on the last airborne frame: Roblox's landing trims speed on touch-down,
-- so slide hops / bhops take the speed you had in the air (playtest 2026-10-02: each landing lost ~6 speed)
local wasAllowed = false

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.RespectCanCollide = true

-- ==================== helpers ====================
local function Ease(cur: number, target: number, k: number, dt: number): number
    return cur + (target - cur) * (1 - math.exp(-k * dt))
end
local function Flat(v: Vector3): Vector3
    local f = Vector3.new(v.X, 0, v.Z)
    return f.Magnitude > 1e-4 and f.Unit or Vector3.zero
end
local function Vel(): Vector3
    return root.AssemblyLinearVelocity
end
local function HVel(): Vector3
    local v = Vel()
    return Vector3.new(v.X, 0, v.Z)
end
local function CamFlat(): (Vector3, Vector3)
    local cf = Workspace.CurrentCamera.CFrame
    local fwd = Flat(cf.LookVector)
    if fwd == Vector3.zero then fwd = Flat(root.CFrame.LookVector) end
    return fwd, Vector3.new(-fwd.Z, 0, fwd.X)
end
-- opposite keys held together: the one pressed LAST wins (owner 2026-10-04: "holding d and jumping, and then hold a,
-- you just kind of stop" -- Roblox reads A + D as no input at all)
local lastAD, lastWS = nil, nil
UserInputService.InputBegan:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.A or k == Enum.KeyCode.D then lastAD = k
    elseif k == Enum.KeyCode.W or k == Enum.KeyCode.S then lastWS = k end
end)
-- Studio test hook: Player attribute DevKeys = "A,Space" (comma list of W A S D Space) = those keys held
local function DevKeys(): { [string]: boolean }?
    if not game:GetService("RunService"):IsStudio() then return nil end
    local v = LocalPlayer:GetAttribute("DevKeys")
    if type(v) ~= "string" or v == "" then return nil end
    local t = {}
    for k in string.gmatch(v, "[^,]+") do t[k] = true end
    return t
end
local function Wish(): Vector3
    -- (Studio test hook, tools/autoplay.luau) Player attr DevWish = a WORLD direction (Vector3, flattened): walk that way, whatever
    -- the camera looks at (DevKeys stays camera-relative)
    local dw = game:GetService("RunService"):IsStudio() and LocalPlayer:GetAttribute("DevWish")
    if typeof(dw) == "Vector3" then
        local flat = Vector3.new(dw.X, 0, dw.Z)
        return flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
    end
    local dk = DevKeys()
    if dk then
        local fwd, right = CamFlat()
        local v = right * ((dk.D and 1 or 0) - (dk.A and 1 or 0)) + fwd * ((dk.W and 1 or 0) - (dk.S and 1 or 0))
        return v.Magnitude > 0.1 and v.Unit or Vector3.zero
    end
    local md = hum.MoveDirection
    if not GameSettings.IsTyping() then
        local a, d = UserInputService:IsKeyDown(Enum.KeyCode.A), UserInputService:IsKeyDown(Enum.KeyCode.D)
        local w, s = UserInputService:IsKeyDown(Enum.KeyCode.W), UserInputService:IsKeyDown(Enum.KeyCode.S)
        if (a and d) or (w and s) then
            local fwd, right = CamFlat()
            local x = (a and d) and ((lastAD == Enum.KeyCode.D) and 1 or -1) or ((d and 1 or 0) - (a and 1 or 0))
            local z = (w and s) and ((lastWS == Enum.KeyCode.W) and 1 or -1) or ((w and 1 or 0) - (s and 1 or 0))
            local v = right * x + fwd * z
            if v.Magnitude > 0.1 then return v.Unit end
        end
    end
    return md.Magnitude > 0.1 and Flat(md) or Vector3.zero
end
-- rotate flat unit vector `from` toward `to` by at most maxStep radians
local function Turn(from: Vector3, to: Vector3, maxStep: number): (Vector3, number)
    local a0 = math.atan2(from.X, from.Z)
    local diff = (math.atan2(to.X, to.Z) - a0 + math.pi) % (2 * math.pi) - math.pi
    local step = math.clamp(diff, -maxStep, maxStep)
    return Vector3.new(math.sin(a0 + step), 0, math.cos(a0 + step)), diff
end
local function Grounded(): boolean
    return hum.FloorMaterial ~= Enum.Material.Air
end
local launchUntil = 0 -- a jump pad launch: the speed caps stand aside until then (M.Launch)
local launchPlanar: Vector3? = nil -- the launch's horizontal velocity, held for the whole flight
local launchAt = 0
local function SlowMult(): number
    return tonumber(LocalPlayer:GetAttribute("ChillMult")) or 1
end
local function BaseSpeed(): number
    if LocalPlayer:GetAttribute("PvpDuel") ~= nil then return T.Quake.Run end -- (QUAKE DUEL MODE)
    return (tonumber(hum:GetAttribute("BaseWalkSpeed")) or 16) * SlowMult() * (tonumber(LocalPlayer:GetAttribute("ZenAdsSlow")) or 1) -- (CHASE ITEMS: Long Promise aiming x0.7)
end
local function SpaceHeld(): boolean
    local dk = DevKeys()
    if dk then return dk.Space == true end
    -- keyboard Space, a gamepad's A, or the touch jump button (it holds Humanoid.Jump while pressed)
    return UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
        or (UserInputService.TouchEnabled and hum ~= nil and hum.Jump == true)
end
local function RefreshFilter()
    local list = { char, Workspace.CurrentCamera }
    for _, e in ipairs(CollectionService:GetTagged("AimRngEnemy")) do table.insert(list, e) end
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
    params.FilterDescendantsInstances = list
end
local function Allowed(): boolean
    if not (char and hum and root and lv) or hum.Health <= 0 then return false end
    -- (the third-person hub too -- owner 2026-10-02: "allow dashing and sliding ... in the hub. It's too slow to get around")
    if LocalPlayer:GetAttribute("Downed") or LocalPlayer:GetAttribute("Spectating") then return false end
    -- a menu / free cursor is up (AimRngClient's flag -- the raw MouseBehavior flickers to Default when the window loses
    -- focus, which used to switch dashing etc. off for no visible reason)
    if LocalPlayer:GetAttribute("CursorFree") then return false end
    -- aim trials (their room floats at y 600). (Update 6: NOT the try range / tutorial hall, which also float at y 300 -- the
    -- tutorial's dash + slide steps did nothing there: "The tutorial isnt letting me dash")
    if root.Position.Y > 300 and Zones.Kind(root.Position) ~= "showcase" then return false end
    return true
end

-- the one LinearVelocity: "Plane" drives horizontal velocity only (jumps / gravity stay the Humanoid's), "Vector" all of it
local function InDuel(): boolean return LocalPlayer:GetAttribute("PvpDuel") ~= nil end
local function CapNow(): number
    if dash then return InDuel() and T.PvpDashCap or T.DashCap end
    return InDuel() and T.Quake.Cap or T.MomentumCap
end
M.CapNow = CapNow
local function Cap(v: Vector3): Vector3
    if os.clock() < launchUntil then return v end -- (a jump pad launch is allowed past the caps)
    local h = Vector3.new(v.X, 0, v.Z)
    local cap = math.min(T.MaxSpeed, CapNow())
    if h.Magnitude > cap then h = h.Unit * cap end
    return Vector3.new(h.X, math.min(v.Y, T.MaxUp), h.Z)
end
local function Drive(mode: string, v: Vector3)
    v = Cap(v)
    if mode == "Plane" then
        lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
        lv.PlaneVelocity = Vector2.new(v.X, v.Z)
    else
        lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        lv.VectorVelocity = v
    end
    lv.Enabled = true
end
local function SetVel(v: Vector3)
    v = Cap(v)
    root.AssemblyLinearVelocity = v
    if lv.Enabled and lv.VelocityConstraintMode == Enum.VelocityConstraintMode.Vector then lv.VectorVelocity = v end
    if lv.Enabled and lv.VelocityConstraintMode == Enum.VelocityConstraintMode.Plane then lv.PlaneVelocity = Vector2.new(v.X, v.Z) end
end

-- ==================== sounds ====================
local SOUNDS = { -- (v4 game sounds 2026-10-23: a real cloth / air swish, game_dash.wav; was the Roblox swoosh.wav)
    Dash = { Id = "rbxassetid://77205865921381", Vol = 0.3, Pitch = 1 },
}
local soundFolder
local function Play(name: string)
    local d = SOUNDS[name]
    if not d or d.Id == "" then return end
    if not soundFolder or not soundFolder.Parent then
        soundFolder = Instance.new("Folder"); soundFolder.Name = "MovementSounds"; soundFolder.Parent = Workspace.CurrentCamera
    end
    local s = Instance.new("Sound")
    -- (v4: the Combat & World group applies Master x Effects once -- this used to multiply them in AND the client's
    -- catch-all put it in the group too, so the dash was turned down twice)
    s.SoundId = d.Id; s.Volume = d.Vol
    local pitch = d.Pitch
    pcall(function() -- (v4 FALLBACK: the old swoosh until the new clip is confirmed loadable -- SoundHelper.Resolve)
        local SH = require(script.Parent:WaitForChild("SoundHelper", 2))
        local id, vol, p = SH.Resolve(SH.Custom.Dash)
        s.SoundId, s.Volume, pitch = "rbxassetid://" .. tostring(id), vol, p
    end)
    s.SoundGroup = game:GetService("SoundService"):FindFirstChild("AimRngMix_Effects") :: SoundGroup?
    s.PlaybackSpeed = pitch * (0.95 + math.random() * 0.1)
    s.Parent = soundFolder
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
    task.delay(3, function() if s.Parent then s:Destroy() end end)
end

-- ==================== HUD: 3 stamina bars ====================
local hud, pips, dashMeter
local function BuildHud()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MovementHUD"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 5
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    hud = Instance.new("CanvasGroup")
    hud.BackgroundTransparency = 1; hud.AnchorPoint = Vector2.new(0.5, 0); hud.Position = UDim2.new(0.5, 0, 0.5, 30)
    hud.Size = UDim2.fromOffset(120, 14); hud.GroupTransparency = 1; hud.Visible = false; hud.Parent = gui
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal; list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center; list.Padding = UDim.new(0, 4); list.Parent = hud
    pips = {}
    for i = 1, T.Stamina.Bars do
        local bg = Instance.new("Frame")
        bg.Size = UDim2.fromOffset(20, 5); bg.BackgroundColor3 = Color3.fromRGB(20, 22, 30); bg.BackgroundTransparency = 0.35; bg.BorderSizePixel = 0
        bg.LayoutOrder = i; bg.Parent = hud
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(1, 1); fill.BackgroundColor3 = Color3.fromRGB(235, 245, 255); fill.BorderSizePixel = 0; fill.Parent = bg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
        pips[i] = fill
    end
    -- MELEE DASH meter (0.58, owner: "Melee dash needs a cooldown meter (very subtle)"): a hairline under the crosshair,
    -- only while the dash recharges: it fills, glints once when it's ready, then fades away
    local line = Instance.new("Frame")
    line.Name = "MeleeDashMeter"; line.AnchorPoint = Vector2.new(0.5, 0); line.Position = UDim2.new(0.5, 0, 0.5, 48)
    line.Size = UDim2.fromOffset(44, 2); line.BackgroundColor3 = Color3.fromRGB(16, 18, 26); line.BackgroundTransparency = 1
    line.BorderSizePixel = 0; line.Visible = false; line.Parent = gui
    local lf = Instance.new("Frame")
    lf.Size = UDim2.fromScale(0, 1); lf.BackgroundColor3 = Color3.fromRGB(235, 245, 255); lf.BackgroundTransparency = 1; lf.BorderSizePixel = 0
    lf.Parent = line
    dashMeter = { Bg = line, Fill = lf, Shown = 0 }
end

-- ==================== shared ====================
local function EndAll()
    dash, slide = nil, nil
    M.State = "None"
end

-- ==================== DASH ====================
local function StartDash()
    if stamina < 1 then return end
    local fwd, right = CamFlat()
    local wish = Wish()
    local dir = wish.Magnitude > 0 and wish or fwd
    local hv = HVel()
    stamina -= 1
    EndAll()
    -- you come out of it at least as fast as you went in (the dash is a redirect + burst, never a brake)
    dash = { Dir = dir, T = 0, Air = not Grounded(), Exit = math.max(T.Dash.Exit, hv.Magnitude * T.Dash.Keep) }
    M.State = "Dash"
    fovImpulse += T.Dash.Fov
    rollImpulse += -dir:Dot(right) * T.Dash.Roll -- lean into a sideways dash
    Play("Dash")
end

local function UpdateDash(dt)
    dash.T += dt
    local spd = math.max(dash.Speed or T.Dash.Speed, dash.Exit) * SlowMult()
    if dash.Air then Drive("Vector", dash.Dir * spd) else Drive("Plane", dash.Dir * spd) end
    if dash.T >= (dash.Time or T.Dash.Time) then
        local d = dash
        dash = nil
        M.State = "None"
        local vy = d.Air and 0 or Vel().Y
        dashEndedAt = os.clock()
        SetVel(d.Dir * d.Exit * SlowMult() + Vector3.new(0, vy, 0))
        Drive("Plane", d.Dir * d.Exit * SlowMult())
    end
end

-- ==================== SLIDE ====================
-- a speed gain under the soft cap: full below T.SoftCap, then it falls off steeply ((cap / speed)^4)
local function SoftGain(speed: number, gain: number): number
    if speed <= T.SoftCap then return gain end
    return gain * (T.SoftCap / speed) ^ 4
end
M.SoftGain = SoftGain

local function StartSlide(landing: boolean?)
    slideArmed = false -- (this press is spent)
    if os.clock() - slideStartedAt < T.Slide.Cooldown then return end -- (0.61: slide cooldown)
    local hv = HVel()
    if landing and airHV.Magnitude > hv.Magnitude then hv = airHV end
    local wish = Wish()
    if hv.Magnitude < T.Slide.MinSpeed and wish.Magnitude == 0 then return end
    -- (owner 2026-10-03: "the slide should allow you to quickly change direction, right now you get kind of stuck when you
    -- 180 and slide again") a slide goes where your KEYS point, not where you were already going; turning keeps most of
    -- the speed (90 deg keeps 75%, a full 180 keeps 50%) and still gets the full boost
    local dir = (wish.Magnitude > 0 and wish) or (hv.Magnitude > 2 and Flat(hv)) or (CamFlat())
    local carried = hv.Magnitude
    -- chained slide: the speed the last slide ended at (or a dash's exit speed) comes back
    if os.clock() - slideEndedAt < T.Slide.ChainWindow then carried = math.max(carried, slideEndSpeed) end
    if wish.Magnitude > 0 and carried > 2 then carried *= 0.75 + 0.25 * Flat(hv.Magnitude > 2 and hv or wish):Dot(wish) end
    -- the slide puts you at TargetMult x run speed; already faster, it adds MinAdd
    local speed = math.max(math.max(carried, BaseSpeed()) + T.Slide.MinAdd, BaseSpeed() * T.Slide.TargetMult)
    EndAll()
    slide = { Dir = dir, Speed = speed, T = 0 }
    slideStartedAt = os.clock()
    M.State = "Slide"
    -- (no slide sound: owner found it grating.) A landing slide gets no FOV kick (owner 2026-10-03: "the screen jitters a
    -- little when bhopping while crouching" -- crouch held while bhopping slides you on every landing, and the +1 deg kick
    -- each time made the view (and the gun fitted to it) pulse every hop; measured 0.5-1.2 deg per hop).
    if not landing then fovImpulse += 1 end
end

local function EndSlide()
    if slide then slideEndedAt = os.clock(); slideEndSpeed = slide.Speed end
    slide = nil
    M.State = "None"
end

local function UpdateSlide(dt)
    slide.T += dt
    if not Grounded() then
        -- jumped: the speed carries into the air. Slid off a lip / bump (not rising): land back into the slide.
        if Vel().Y < 4 then slideResumeUntil = os.clock() + SLIDE_BUFFER end
        EndSlide()
        return
    end
    -- slope: downhill speeds you up, uphill slows you
    local hit = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
    if hit and hit.Normal.Y < 0.995 then
        local downhill = Flat(hit.Normal)
        local slopeSin = math.sqrt(math.max(0, 1 - hit.Normal.Y * hit.Normal.Y))
        slide.Speed += downhill:Dot(slide.Dir) * T.Slide.SlopeAccel * slopeSin * dt
    end
    local wish = Wish()
    -- STEERING (owner 2026-10-02: "I feel like I have no control over my direction"): the slide turns toward your keys
    -- fast (TurnRate, was 1.8 rad/s), and with no key held it follows where you look (LookTurnRate); speed is kept
    if wish.Magnitude > 0 and wish:Dot(slide.Dir) < -0.5 then EndSlide(); slideEndSpeed = 0 return end -- pull back = brake: stand up, stop crisply (no carried speed)
    if wish.Magnitude > 0 then slide.Dir = Turn(slide.Dir, wish, T.Slide.TurnRate * dt)
    else slide.Dir = Turn(slide.Dir, (CamFlat()), T.Slide.LookTurnRate * dt) end
    slide.Speed = math.max(0, slide.Speed - T.Slide.Friction * dt)
    -- a slide lasts MaxTime at most (a press re-slides) or until it slows to a run, then you stand straight up (held
    -- crouch: you stay crouched)
    local floor = slideHeld and T.Slide.MinSpeed or BaseSpeed()
    if slide.Speed < floor or slide.T > T.Slide.MaxTime then EndSlide() return end
    Drive("Plane", slide.Dir * slide.Speed)
end

-- ==================== base movement ====================
local function SrcK(key: string): number -- (DUEL PACE) the Quake override in a duel, else the Source value
    if LocalPlayer:GetAttribute("PvpDuel") ~= nil and T.Quake[key] then return T.Quake[key] end
    return T.Source[key]
end
local function Accelerate(vel: Vector3, wishdir: Vector3, wishspeed: number, accel: number, dt: number): Vector3
    local add = wishspeed - vel:Dot(wishdir)
    if add <= 0 then return vel end
    return vel + wishdir * math.min(accel * wishspeed * dt, add)
end
local function Friction(vel: Vector3, dt: number): Vector3
    local speed = vel.Magnitude
    if speed < 0.01 then return Vector3.zero end
    local control = math.max(speed, T.Source.StopSpeed * T.Source.U)
    local newSpeed = math.max(speed - control * SrcK("Friction") * dt, 0)
    return vel * (newSpeed / speed)
end

local tickAcc = 0
local airDriveVel, airDriveAt = nil, 0 -- the horizontal velocity UpdateBase drove last frame while airborne
local revSpeed, revUntil, revWish = 0, 0, Vector3.zero -- an air reversal in progress (A -> D, W -> S ...): the speed to swing back up to
local function UpdateBase(dt: number, grounded: boolean)
    local hv = HVel()
    -- (2026-10-03, measured: Roblox's velocity lags the drive a little, and reading it back each frame cut the corner of
    -- every air turn.) In the air our own velocity is the truth; it resyncs only when the real one differs a lot (you hit
    -- something / got knocked), and only straight after the last base frame (a dash / pad in between takes over again).
    if not grounded and airDriveVel and os.clock() - airDriveAt < 0.05 and (airDriveVel - hv).Magnitude < 6 then hv = airDriveVel end
    local wish = Wish() -- camera-relative WASD direction (unit), zero with no keys
    local wishspeed = wish.Magnitude > 0 and BaseSpeed() or 0
    if slideHeld and grounded then wishspeed *= T.Crouch.Speed end -- crouch-walk
    tickAcc = math.min(tickAcc + dt, 0.1)
    local tick = T.Source.Tick
    while tickAcc >= tick do
        tickAcc -= tick
        local base = BaseSpeed()
        if grounded then
            local sp = hv.Magnitude
            local along = (wish.Magnitude > 0 and sp > 0.1) and wish:Dot(hv / sp) or 0
            if os.clock() < landGraceUntil then
                -- the moment you land: no friction, but your keys still steer
                if wish.Magnitude > 0 and sp > 0.1 then hv = Turn(hv / sp, wish, SrcK("GroundGrip") * tick) * sp end
            elseif sp > base + 0.5 and wish.Magnitude > 0 and along > -0.3 then
                -- MOMENTUM: your keys steer it (it never drags you the old way), and the ground takes it off fast
                hv = Turn(hv / sp, wish, SrcK("GroundGrip") * tick) * math.max(base, sp - T.Source.OverBleed * tick)
            else
                hv = Friction(hv, tick)
                if along < -0.3 then hv = Friction(hv, tick) end -- pulling against your speed brakes twice as hard
                hv = Accelerate(hv, wish, wishspeed, SrcK("Accelerate"), tick)
            end
        elseif wish.Magnitude > 0 then
            local before = hv.Magnitude
            local now = os.clock()
            -- AIR REVERSAL (owner 2026-10-04: "holding a + space and then switching to holding d + space doesnt work, it
            -- just slows you down"): the old cap was the speed of the tick before, which shrank as you passed through
            -- zero -- so you could never build back up. Now the speed you had when you pressed the other key is kept:
            -- the momentum swings over to the new key and back up to that speed (never more).
            if before >= base * 0.85 and wish:Dot(hv / before) < -0.3 and not (now < revUntil and wish:Dot(revWish) > 0.7) then
                revSpeed, revUntil, revWish = before, now + 0.8, wish
            end
            if now < revUntil and wish:Dot(revWish) < 0.7 then revUntil = 0 end -- let go / turned elsewhere: done
            if now < revUntil then
                hv += wish * SrcK("AirReverse") * tick
                if hv.Magnitude > revSpeed then hv = hv.Unit * revSpeed end
                if hv:Dot(wish) >= revSpeed * 0.97 then revUntil = 0 end -- fully swung over
            elseif before < base * 0.85 then
                hv = Accelerate(hv, wish, wishspeed, SrcK("Accelerate") * 2, tick) -- slow: plain air control
            else
                -- KEY BHOP: speed builds along the held key and your momentum swings toward it
                local dir = hv / before
                if wish:Dot(dir) < -0.3 then
                    hv += wish * SrcK("AirReverse") * tick -- (only reached for a reversal too slow to start one above)
                    if hv.Magnitude > before then hv = hv.Unit * before end
                else
                    local q = (LocalPlayer:GetAttribute("PvpDuel") ~= nil) and T.Quake or nil -- (QUAKE DUEL MODE: strafe-jump pace)
                    local top, start = q and q.FadeTop or T.Source.AirFadeTop, q and q.FadeStart or T.Source.AirFadeStart
                    local fade = math.clamp((top - before) / (top - start), 0, 1)
                    hv = Turn(dir, wish, (q and q.AirTurn or T.Source.AirTurn) * tick) * (before + (q and q.KeyGain or T.Source.KeyGain) * fade * tick)
                end
            end
        end
    end
    airDriveVel, airDriveAt = (not grounded) and Cap(hv) * Vector3.new(1, 0, 1) or nil, os.clock()
    Drive("Plane", hv)
end

-- Jump off the ground THIS frame keeping your full horizontal speed (or the slide's): we set the jump velocity
-- ourselves -- the Humanoid ignores a jump on the landing frame and sat you on the ground, where friction ate it.
BhopJump = function(): boolean
    -- (DUELS v3: no jump before the duel's JumpGap is up -- returns false, the landing path then just lands)
    if LocalPlayer:GetAttribute("PvpDuel") ~= nil and os.clock() - (M.DuelJumpAt or -99) < T.Quake.JumpGap then return false end
    M.DuelJumpAt = os.clock()
    local hv = HVel()
    if groundT < 0.25 and airHV.Magnitude > hv.Magnitude then hv = airHV end -- (just landed: keep the air speed)
    local sp, dir = hv.Magnitude, Flat(hv)
    if slide then
        sp, dir = slide.Speed, slide.Dir
        -- SLIDE-HOP: jumping out of a slide adds HopAdd, once per HopCooldown
        if os.clock() - lastSlideBoost >= T.Slide.HopCooldown then
            sp += SoftGain(sp, T.Slide.HopAdd)
            lastSlideBoost = os.clock()
        end
    end
    local jv = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * Workspace.Gravity * hum.JumpHeight)
    slide = nil
    M.State = "None"
    SetVel(Vector3.new(dir.X * sp, jv, dir.Z * sp))
    Drive("Plane", dir * sp)
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    jumpPressAt = -99
    landGraceUntil = 0
    lastBhopAt = os.clock()
    return true
end

-- ==================== input ====================
-- crouch pressed (any device): slide now on the ground (mid-slide: a fresh slide), or remember it for the landing
local function SlidePressNow()
    if slide then
        -- (0.61: a press mid-slide only restarts it once the cooldown is up -- it used to re-boost on every tap)
        if os.clock() - slideStartedAt >= T.Slide.Cooldown then EndSlide(); StartSlide() end
        return
    end
    if Grounded() and not dash then StartSlide() else slidePressAt = os.clock() end
end
-- (the move keys reach Humanoid.MoveDirection a frame late: a crouch pressed together with a new direction key acted on
-- the OLD direction -- a 180 + crouch braked you instead of sliding back. ~2 frames' wait sees the new keys.)
local slidePressQueued = false
local function SlidePress()
    if slidePressQueued then return end
    slidePressQueued = true
    task.delay(0.03, function() slidePressQueued = false; if root and Allowed() then SlidePressNow() end end)
end

local function DoDash()
    StartDash()
end

local function KeyIs(input: InputObject, action: string, extra: Enum.KeyCode?): boolean
    -- (keys or mouse buttons: GameSettings.InputIs)
    if GameSettings.InputIs(input, action) then return true end
    return extra ~= nil and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == extra
end

-- one entry point for every input device (keyboard below, gamepad below, touch buttons via M.Action):
-- name = "Dash" | "Slide" | "Jump"; down = pressed (true) / released (false)
local function Action(name: string, down: boolean)
    if name == "Slide" then slideHeld = down; M._slideByAction = down; if down then slideArmed = true end end
    if not down or not Allowed() then return end
    if name == "Dash" then DoDash()
    elseif name == "Slide" then
        SlidePress()
    elseif name == "Jump" then
        M.OnJumpPressed()
    end
end
M.Action = Action
-- gamepad: A jump, B slide (hold), LB / L3 dash
local PAD = { [Enum.KeyCode.ButtonB] = "Slide", [Enum.KeyCode.ButtonL1] = "Dash", [Enum.KeyCode.ButtonL3] = "Dash" }

UserInputService.InputBegan:Connect(function(input, gp)
    -- (gp is not trusted on its own: Roblox's built-in bindings -- e.g. its Shift Lock on Shift -- mark our keys as
    -- "processed" in live games. Typing in a text box is what must be ignored.)
    if GameSettings.IsTyping() then return end
    if PAD[input.KeyCode] then Action(PAD[input.KeyCode], true) return end
    if gp and input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if KeyIs(input, "Slide", Enum.KeyCode.LeftControl) then slideHeld = true; M._slideByAction = false; slideArmed = true end
    if not Allowed() then return end
    if KeyIs(input, "Dash") then DoDash()
    elseif KeyIs(input, "Slide", Enum.KeyCode.LeftControl) then
        SlidePress()
    elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        M.OnJumpPressed()
    end
end)
function M.OnJumpPressed()
    if not Allowed() then return end
    do
        jumpPressAt = os.clock() -- (jump buffer: pressed just before landing still bhops)
        if Grounded() and os.clock() < landGraceUntil and not dash then
            BhopJump() -- a touch late, but inside the landing grace: full-speed hop
        elseif dash and Grounded() then
            -- DASH-JUMP: hop out of a ground dash carrying the dash's exit speed
            local d = dash
            dash = nil
            M.State = "None"
            local hv = HVel()
            local sp = math.max(d.Exit * SlowMult(), hv.Magnitude)
            SetVel(Vector3.new(d.Dir.X * sp, Vel().Y, d.Dir.Z * sp))
            BhopJump()
        elseif slide then
            -- slide -> jump = SLIDE-HOP: leave with the slide's speed (+ HopAdd when it's ready)
            slideResumeUntil = 0
            BhopJump()
        end
    end
end
UserInputService.WindowFocusReleased:Connect(function() -- (2026-10-15: tabbing out lets go of a held crouch)
    if not M._slideByAction then slideHeld = false end
end)
UserInputService.InputEnded:Connect(function(input)
    if KeyIs(input, "Slide", Enum.KeyCode.LeftControl) then slideHeld = false end
    if PAD[input.KeyCode] then Action(PAD[input.KeyCode], false) end
end)

-- MELEE DASH-STRIKE (owner 2026-10-02: "make the melee used like the scythe in Rivals, for a dash in ANY direction"):
-- the heavy attack with the melee out dashes where you're looking, steered by the movement keys (look up = dash up,
-- hold A = dash left, S = back), then the swing lands. Its own cooldown -- it doesn't use dash stamina.
local meleeDashReady = 0
function M.MeleeDash(): boolean
    if not root or not Allowed() or os.clock() < meleeDashReady then return false end
    if InDuel() then return false end -- (0.60: no knife dash in duels)
    local cam = Workspace.CurrentCamera.CFrame
    local fwd, right = CamFlat()
    local wish = Wish()
    local dir = cam.LookVector
    if wish.Magnitude > 0 then
        dir = cam.LookVector * wish:Dot(fwd) + cam.RightVector * wish:Dot(right)
        if dir.Magnitude < 0.05 then dir = cam.LookVector end
    end
    dir = dir.Unit
    if Grounded() and dir.Y < 0.05 then dir = Vector3.new(dir.X, 0.05, dir.Z).Unit end -- (never into the floor)
    meleeDashReady = os.clock() + T.MeleeDash.Cooldown
    local hv = HVel()
    EndAll()
    dash = { Dir = dir, T = 0, Air = true, Speed = T.MeleeDash.Speed, Time = T.MeleeDash.Time,
        Exit = math.max(T.MeleeDash.Exit, hv.Magnitude) }
    M.State = "Dash"
    fovImpulse += T.Dash.Fov
    rollImpulse += -dir:Dot(right) * T.Dash.Roll
    Play("Dash")
    return true
end
function M.MeleeDashCooldown(): number return math.max(0, meleeDashReady - os.clock()) end
-- (2026-10-07, owner: "when dashing, your melee shouldn't attack") is any dash running right now?
function M.Dashing(): boolean return dash ~= nil end

-- ==================== per frame ====================
local function Reset()
    dash, slide = nil, nil
    stamina = T.Stamina.Bars
    M.State = "None"
end

local filterT = 0
local touchJumpWas = false
RunService.Heartbeat:Connect(function(dt)
    if not (char and hum and root and lv) or not root.Parent then return end
    if UserInputService.TouchEnabled then
        -- the touch jump button only sets Humanoid.Jump: treat its press like Space (slide jumps, bhop buffer)
        local j = hum.Jump == true
        if j and not touchJumpWas then M.OnJumpPressed() end
        touchJumpWas = j
    end
    filterT -= dt
    if filterT <= 0 then filterT = 1; RefreshFilter() end

    local allowed = Allowed()
    local grounded = Grounded()
    if grounded then groundT += dt else groundT = 0 end
    local base = BaseSpeed()
    if math.abs(hum.WalkSpeed - base) > 0.05 then hum.WalkSpeed = base end

    if launchPlanar and os.clock() < launchUntil then
        -- JUMP PAD FLIGHT (owner 2026-10-05: "jumppads are very inconsistent"): the arc is computed to land on the
        -- platform, so nothing touches it -- no ground friction on the first frames (Roblox still reports the pad as
        -- floor right after takeoff, which ate the forward push), no air steering from held keys. Touching down (or the
        -- flight's time running out) ends it.
        Drive("Plane", launchPlanar)
        if grounded and os.clock() - launchAt > 0.3 then
            launchUntil = 0
        end
        if os.clock() >= launchUntil then
            launchPlanar = nil
            SetVel(Vector3.new(0, Vel().Y, 0))
            if not allowed then lv.Enabled = false end
        end
    elseif not allowed then
        launchPlanar = nil
        if wasAllowed then
            EndAll()
            lv.Enabled = false -- the Humanoid walks normally (hub, menus, downed, trials)
        end
    else
        launchPlanar = nil
        -- LANDING: bhop / slide hop. Space held (or pressed just before) -> jump again at once, so friction never
        -- touches you. Crouch held -> slide on touch-down; with Space too, you slide-hop straight out of it.
        if grounded and not wasGrounded and not dash and os.clock() - lastBhopAt > 0.2 then
            local jumpWanted = SpaceHeld() or os.clock() - jumpPressAt < T.Ground.JumpBuffer
            local wantSlide = slideHeld or os.clock() - slidePressAt < SLIDE_BUFFER or os.clock() < slideResumeUntil
            if wantSlide and not slide then
                slidePressAt, slideResumeUntil = -99, 0
                StartSlide(true)
            end
            if jumpWanted and BhopJump() ~= false then -- (DUELS v3: a duel hop waits for its JumpGap)
                grounded = false
            else
                landGraceUntil = os.clock() + T.Ground.LandGrace
            end
        end
        -- CHAIN INTO A SLIDE: crouch pressed and moving fast on the ground (a dash just ended, you walked off a ramp ...)
        -- -> slide, without having to press crouch again
        local slideWanted = (slideHeld and slideArmed) or os.clock() - slidePressAt < SLIDE_BUFFER or os.clock() < slideResumeUntil
        if slideWanted and grounded and not slide and not dash and os.clock() - lastBhopAt > 0.2
            and HVel().Magnitude > base * T.Slide.AutoSpeed then
            slidePressAt, slideResumeUntil = -99, 0
            StartSlide()
        end
        local handled = false
        if dash then UpdateDash(dt); handled = true
        elseif slide then UpdateSlide(dt); handled = slide ~= nil
        end
        if not handled and not dash then
            -- (counts as airborne while rising / just after a hop: Roblox still reports the floor for a few frames after
            -- takeoff, and ground friction there ate speed every hop)
            local onGround = grounded and os.clock() - lastBhopAt > 0.2 and Vel().Y < 5
            UpdateBase(dt, onGround)
        end
    end
    wasAllowed = allowed
    -- QUAKE DUEL MODE: Quake's gravity + hop height while in a duel (client-side physics: your character is yours), back
    -- to the game's own on the way out. (The old duel jump gap is gone: Quake duels bunny hop.)
    do
        local duel = InDuel()
        if duel ~= quakeOn then
            quakeOn = duel
            if duel then
                quakeSaved = { G = Workspace.Gravity, JH = hum.JumpHeight, JP = hum.JumpPower }
                Workspace.Gravity = T.Quake.Gravity
                hum.UseJumpPower = false
                hum.JumpHeight = T.Quake.JumpHeight
            elseif quakeSaved then
                Workspace.Gravity = quakeSaved.G
                hum.JumpHeight = quakeSaved.JH
                quakeSaved = nil
            end
        end
        -- (DUELS v3) the Humanoid's own jump is off until the duel's JumpGap is up (Setup's StateChanged stamps the clock)
        local canJump = (not duel) or os.clock() - (M.DuelJumpAt or -99) >= T.Quake.JumpGap
        if hum:GetStateEnabled(Enum.HumanoidStateType.Jumping) ~= canJump then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, canJump) end
    end
    if allowed and os.clock() >= launchUntil then
        local v = root.AssemblyLinearVelocity
        local h = Vector3.new(v.X, 0, v.Z)
        local hardCap = math.min(T.MaxSpeed, CapNow())
        if v.Y > T.MaxUp or h.Magnitude > hardCap + 0.5 then -- (hard safety net: collisions can't fling you past the caps)
            if h.Magnitude > hardCap then h = h.Unit * hardCap end
            root.AssemblyLinearVelocity = Vector3.new(h.X, math.min(v.Y, T.MaxUp), h.Z)
        end
    end

    -- stamina: 3 bars, faster refill on the ground
    local rate = grounded and T.Stamina.GroundRate or T.Stamina.AirRate
    local maxBars = InDuel() and T.Quake.DashBars or T.Stamina.Bars -- (DUELS v3: one dash charge, DashRecharge s)
    if InDuel() then rate = 1 / T.Quake.DashRecharge end
    stamina = math.min(maxBars, stamina + rate * dt)

    local hv = HVel().Magnitude
    -- landing dip
    if grounded and not wasGrounded and airVy < -38 then
        landDip = math.clamp((-airVy - 38) / 70, 0, 1) * -0.55
    end
    if not grounded then airVy = Vel().Y; airHV = HVel() end
    wasGrounded = grounded

    -- camera feel (eased): speed widens the view (capped -- the speed isn't)
    fovImpulse = Ease(fovImpulse, 0, 6, dt)
    rollImpulse = Ease(rollImpulse, 0, 7, dt)
    landDip = Ease(landDip, 0, 7, dt)
    local speedFov = math.clamp((hv - 30) / 80, 0, 1) * 6
    M.FovKick = Ease(M.FovKick, math.min(fovImpulse + speedFov, 20), 10, dt)
    -- (through a spam-slide chain the eye and body stay low instead of bobbing up between taps)
    local chaining = slide ~= nil or (grounded and os.clock() - slideEndedAt < 0.12)
    M.SlideAmount = Ease(M.SlideAmount, chaining and 1 or 0, chaining and 14 or 8, dt)
    -- (owner 2026-10-07: "Add dashing animations like we have with sliding, so the player knows") a dash snaps the pose in
    -- and eases it out; others see it through the server-relayed "Dashing" attribute
    M.DashAmount = Ease(M.DashAmount, dash and 1 or 0, dash and 30 or 7, dt)
    if dash and dash.Dir then
        local cam = workspace.CurrentCamera
        local lv = cam and cam.CFrame.LookVector or Vector3.zAxis
        local rv = cam and cam.CFrame.RightVector or Vector3.xAxis
        local d = Vector3.new(dash.Dir.X, 0, dash.Dir.Z)
        if d.Magnitude > 0.01 then
            d = d.Unit
            M.DashSide = math.clamp(d:Dot(Vector3.new(rv.X, 0, rv.Z).Unit), -1, 1)
            M.DashBack = d:Dot(Vector3.new(lv.X, 0, lv.Z).Unit) < -0.5
        end
        if not dashSentAt or os.clock() - dashSentAt > 0.25 then
            dashSentAt = os.clock()
            pcall(function() Remotes.GetEvent("MoveState"):FireServer("dash") end)
        end
    end
    if chaining ~= slideSent and os.clock() - slideSentAt > 0.1 then -- (others see your slide pose: the server relays it)
        slideSent, slideSentAt = chaining, os.clock()
        pcall(function() Remotes.GetEvent("MoveState"):FireServer(slideSent) end)
    end
    M.CamRoll = Ease(M.CamRoll, rollImpulse, 9, dt)
    -- STUCK CROUCH (2026-10-15, owner's screenshot: a friend squatting in the hub): a crouch key let go while the window
    -- was unfocused (Alt+Tab, chat, a menu) never sends InputEnded, so slideHeld stayed true and everyone saw you crouched.
    -- A keyboard crouch now checks the real key state every frame (touch / pad holds come through Action and end there).
    if slideHeld and not M._slideByAction then
        local bind = tostring(GameSettings.Get("Key_Slide") or "")
        if string.sub(bind, 1, 11) ~= "MouseButton" then
            local down = false
            for _, k in ipairs(UserInputService:GetKeysPressed()) do
                if KeyIs(k, "Slide", Enum.KeyCode.LeftControl) then down = true; break end
            end
            if not down then slideHeld = false end
        end
    end
    -- (2026-10-13) crouching on the ground, for your body pose on everyone's screen (CharacterPoser; the server relays it)
    M.Crouched = allowed and slideHeld and grounded and not chaining
    if M.Crouched ~= M.CrouchSent and os.clock() - (M.CrouchSentAt or 0) > 0.12 then
        M.CrouchSent, M.CrouchSentAt = M.Crouched, os.clock()
        local word = M.Crouched and "crouch" or "stand"
        pcall(function() Remotes.GetEvent("MoveState"):FireServer(word) end)
    end
    local crouchEye = (allowed and slideHeld) and (grounded and T.Crouch.Eye or T.Crouch.AirEye) or 0
    M.EyeOffset = Ease(M.EyeOffset, (chaining and T.Slide.Eye or crouchEye) + landDip, (chaining or slideHeld) and 14 or 18, dt) -- (stand up fast)

    -- HUD
    if hud then
        local barsNow = InDuel() and T.Quake.DashBars or T.Stamina.Bars
        for i, fill in ipairs(pips) do
            if fill.Parent then fill.Parent.Visible = i <= barsNow end -- (duels: one charge)
            local f = math.clamp(stamina - (i - 1), 0, 1)
            fill.Size = UDim2.fromScale(f, 1)
            fill.BackgroundColor3 = (f >= 1) and Color3.fromRGB(235, 245, 255) or Color3.fromRGB(120, 130, 150)
        end
        local full = stamina >= barsNow
        local inDungeon = LocalPlayer:GetAttribute("RunId") ~= nil or root.Position.Z > 450 or InDuel() -- (dungeons + duels: never the hub / training grounds)
        local show = allowed and inDungeon and not full
        hud.GroupTransparency = Ease(hud.GroupTransparency, show and 0 or 1, show and 14 or 6, dt)
        if hud.GroupTransparency > 0.98 then hud.GroupTransparency = 1 end
        -- (actually hide it when faded: a fully transparent CanvasGroup could still draw its contents)
        local vis = hud.GroupTransparency < 1
        if hud.Visible ~= vis then hud.Visible = vis end
        if dashMeter then
            local now = os.clock()
            local left = math.max(0, meleeDashReady - now)
            local since = now - meleeDashReady -- (> 0 once it's ready again)
            local want = (left > 0 and allowed) and 1 or ((since >= 0 and since < 0.45) and 1 - since / 0.45 or 0)
            dashMeter.Shown = Ease(dashMeter.Shown, want, 14, dt)
            local a = dashMeter.Shown
            local glint = (left <= 0 and since >= 0 and since < 0.2) and 1 or 0
            dashMeter.Fill.Size = UDim2.fromScale((left > 0) and (1 - left / T.MeleeDash.Cooldown) or 1, 1)
            dashMeter.Fill.BackgroundTransparency = 1 - a * (0.5 + 0.45 * glint)
            dashMeter.Bg.BackgroundTransparency = 1 - a * 0.45
            local mv = a > 0.02
            if dashMeter.Bg.Visible ~= mv then dashMeter.Bg.Visible = mv end
        end
    end
end)

-- jump pads (AimRngClient): a launch is faster than the speed caps allow -- they wait for `seconds`
-- (playtester 2026-10-02: "room jump boosters don't boost high enough" -- MaxUp 60 was clamping the arc)
function M.Launch(seconds: number, vel: Vector3?)
    launchUntil = os.clock() + (seconds or 1.5)
    launchAt = os.clock()
    EndAll()
    -- (the planar drive would otherwise hold the pre-launch speed for a step and eat the forward push)
    if vel and root then
        -- off the ground first: a grounded Humanoid's floor spring damped the upward kick on some frames
        if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
        launchPlanar = Vector3.new(vel.X, 0, vel.Z)
        SetVel(vel); Drive("Plane", launchPlanar)
        -- re-apply for two frames (the state change can land a frame late)
        task.spawn(function()
            for _ = 1, 2 do
                RunService.Heartbeat:Wait()
                if root and os.clock() - launchAt < 0.1 then root.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(root.AssemblyLinearVelocity.Y, vel.Y * 0.97), vel.Z) end
            end
        end)
    end
end

-- ==================== character ====================
local function Setup(c: Model)
    Reset()
    char = c
    hum = c:WaitForChild("Humanoid", 10)
    root = c:WaitForChild("HumanoidRootPart", 10)
    if not (hum and root) then char = nil return end
    att = Instance.new("Attachment"); att.Name = "MoveAtt"; att.Parent = root
    lv = Instance.new("LinearVelocity")
    lv.Name = "MoveLV"; lv.Attachment0 = att; lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.MaxForce = 120000; lv.Enabled = false -- (strong, but not infinite: infinite force into a ledge launched you)
    lv.PrimaryTangentAxis = Vector3.xAxis; lv.SecondaryTangentAxis = Vector3.zAxis
    lv.Parent = root
    wasAllowed = false
    RefreshFilter()
    -- (DUELS v3) every jump stamps the duel's jump clock -- the Jumping state lasts a frame or two, a per-frame check missed it
    hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Jumping and LocalPlayer:GetAttribute("PvpDuel") ~= nil then M.DuelJumpAt = os.clock() end
    end)
end
if LocalPlayer.Character then task.spawn(Setup, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(Setup)
task.spawn(BuildHud)

-- Studio test hook: Player attribute DevMove = "dash" | "slide" runs that move once.
if RunService:IsStudio() then
    LocalPlayer:GetAttributeChangedSignal("DevMove"):Connect(function()
        local v = LocalPlayer:GetAttribute("DevMove")
        if not v or v == "" then return end
        LocalPlayer:SetAttribute("DevMove", nil)
        if v == "dash" then DoDash()
        elseif v == "slide" then slideHeld = true; StartSlide(); task.delay(0.8, function() slideHeld = false end)
        -- "act:Dash" / "act:Slide": the REAL input path (Action = what the keys, the pad and the touch buttons call,
        -- Allowed() included), pressed now and released 0.6 s later
        elseif string.sub(v, 1, 4) == "act:" then
            local name = string.sub(v, 5)
            Action(name, true)
            task.delay(0.6, function() Action(name, false) end)
        end
    end)
end

return M
