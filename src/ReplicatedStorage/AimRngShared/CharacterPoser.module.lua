--!nocheck
-- CHARACTER POSER (2026-10-13, owner: our R6 characters vs Rivals' -- "why does theirs look better"). Every R6 character
-- this client can see is animated HERE, in code, from replicated data -- no animation assets, no Roblox Animate script
-- (R6Spawner removes it: it fought these joints). One PreSimulation pass (after the Animator, before the body is solved)
-- writes Motor6D.Transform on RootJoint / Neck / both shoulders / both hips of each character, and the world gun /
-- world melee welds (local C0 only; the server's welds and every hitbox stay as they are -- visual only).
--
-- WHAT DRIVES IT (all replicated, read per character):
--   velocity      = the root's position change (works for remote players, test dummies, teleports filtered)
--   ground        = a short ray under the root every 0.1 s
--   attrs         = Sliding / Dashing (server time) / Crouching / AimPitch / HoldMelee / SwingAt + SwingKind /
--                   ReloadAt + ReloadFor / Downed -- on the Player (or on the model for a test dummy)
--   the world gun = WorldGun model in the right hand ("Hand" mode, CombatServer) with attrs Hold (Rifle / SMG / Shotgun /
--                   LMG / Sniper / Beam / Pistol) + SupFwd (studs from the grip to the support hand, from the gun's own
--                   GripPose.L); back-slung (hub) = unarmed locomotion
--   shots         = CharacterPoser.Shot(char) (AimRngClient's ShotFx relay -> OnPeerShot): recoil kick (+ shotgun pump)
-- POSE MODEL (root space, R6 sizes: torso 2x2x1, limbs 1x2x1): the torso pivots on the hips (bob, lean into the move,
-- a "bladed" yaw when holding a long gun, pitch with the aim); legs swing about their hip sockets along the move
-- direction (run, strafe, backpedal), plus air / crouch / slide / dash poses blended by eased weights; arms either swing
-- (unarmed) or REACH a target (shooting hand = the gun's grip, support hand = SupFwd up the gun) with a rigid 1x2 arm
-- that may slide 0.5 stud along its socket; the gun is then placed IN the hand, pointing along the aim. Melee: a class
-- hold (one hand / long / pole) + swings for SwingAt; a held melee moves the gun to the back on this client.
-- LOD: < 70 studs every frame, < 160 at 30 Hz, < 320 at 12 Hz, further: frozen. Hidden characters (other instances,
-- your own first-person body) are skipped. No tables are made per frame.
-- Studio test dummies: any R6 model tagged "AimPoseDummy" (attrs on the model itself; attr DevShot changing = a shot).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Poser = {}
local LocalPlayer = Players.LocalPlayer

local CF, V3, ANG = CFrame.new, Vector3.new, CFrame.Angles
local rad, sin, cos, clamp, abs, exp, min, max = math.rad, math.sin, math.cos, math.clamp, math.abs, math.exp, math.min, math.max
local DOWN, UP, XA, ZERO = Vector3.new(0, -1, 0), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.zero
local IDENT = CFrame.identity

-- body numbers (degrees / studs); Studio: workspace attr DevPoseTune = "Key=v,Key=v" changes them live
Poser.TUNE = {
    -- (pass 3, owner: the walk "looks a bit zesty" + "the leaning when you turn": grounded and tactical -- no hip sway /
    -- roll, almost no counter-twist (none with a gun), a firm heel-plant dip instead of a bounce, the gun steady, upright turns)
    Swing = 44, ArmSwing = 0.8, Lean = 7, DashLean = 18, Bob = 0.07, Twist = 2.5, Land = 1,
    -- slim third-person arms (owner: the raised R6 block arms "read as two big bricks across the chest"): every R6 arm is
    -- drawn ArmW wide on this client (its shirt / sleeve still maps onto it; the server's arm + hit checks are untouched),
    -- its shoulder socket ArmInset nearer the torso; the world glove / sleeve shells slim with it. The held melee x HeldMelee.
    -- OFF again (owner 2026-10-13: "the small arms look really silly"): normal R6 arm width. Set 1 to bring them back.
    SlimArms = 0, ArmW = 0.62, ArmInset = 0.19, HeldMelee = 1.6,
    Sway = 0.005, HipRoll = 0.3, GunBob = 0.3, AccLean = 0.6, AccSide = 0, StrafeRoll = 0.3, TurnLag = 0.02, TorsoLag = 0.008,
    StanceOut = 6, StanceStep = 9, Athletic = 0.14, AthleticLean = 6, CrouchDrop = 0.34, SlideDrop = 1.15, SlideLean = 42,
}
local TUNE = Poser.TUNE

-- per gun class: Blade = torso yaw (left shoulder forward), Hand = the grip in root space (aim level), Sup = default
-- support distance up the gun, Drop = how far below the grip the support hand sits
-- (each grip ~1.75-1.9 studs from its shoulder socket after the blade turn, every support <= 2.0: a rigid R6 arm reaches)
Poser.HOLDS = {
    Rifle   = { Blade = 30, Hand = Vector3.new(0.15, 0.32, -0.85), Sup = 1.2,  MaxSup = 1.2,  Drop = 0.14, Kick = 1 },
    SMG     = { Blade = 26, Hand = Vector3.new(0.2, 0.12, -0.9),   Sup = 0.95, MaxSup = 0.95, Drop = 0.12, Kick = 0.8 },
    Shotgun = { Blade = 30, Hand = Vector3.new(0.15, 0.14, -0.85), Sup = 1.2,  MaxSup = 1.2,  Drop = 0.14, Kick = 1.6, Pump = true },
    LMG     = { Blade = 36, Hand = Vector3.new(0.4, -0.15, -0.8),  Sup = 0.75, MaxSup = 0.75, Drop = 0.18, Kick = 0.9 },
    Sniper  = { Blade = 36, Hand = Vector3.new(0.3, 0.32, -0.85),  Sup = 1.1,  MaxSup = 1.1,  Drop = 0.14, Kick = 1.8, Cheek = true },
    Beam    = { Blade = 28, Hand = Vector3.new(0.2, 0.1, -0.85),   Sup = 1.0,  MaxSup = 1.0,  Drop = 0.14, Kick = 0.5 },
    Pistol  = { Blade = 6,  Hand = Vector3.new(0.25, 0.4, -1.4),   Pistol = true, Kick = 1.4, ToolOff = Vector3.new(-0.1, 0.16, -0.45) },
}
-- melee holds: R = right hand (root space), B = blade direction, L = left hand (nil = up the shaft by Pole studs)
Poser.MELEE = {
    One  = { R = Vector3.new(0.78, 0.02, -1.1), B = Vector3.new(-0.12, 0.55, -0.83), L = Vector3.new(-0.7, 0.55, -1.35), Blade = 10 },
    Long = { R = Vector3.new(0.82, 0.22, -0.9), B = Vector3.new(-0.22, 0.92, -0.32), L = Vector3.new(-0.62, 0.15, -1.0), Blade = 14 },
    Pole = { R = Vector3.new(0.7, -0.12, -0.7), B = Vector3.new(-0.35, 0.55, -0.76), Pole = 1.3, Blade = 26 },
}
local ARMS = { "Left Arm", "Right Arm" }
local MELEE_KIND = { Sword = "Long", Axe = "Long", Blunt = "Long", Spear = "Pole", Scythe = "Pole" }

local entries: { [Model]: any } = {}
local players: { Player } = {}
local dummies: { Model } = {}
local MV: any = nil
local started = false

-- rotation that takes (0,-1,0) onto dir (the shortest turn: a hanging limb swung straight at it)
local function HangTo(dir: Vector3): CFrame
    local axis = DOWN:Cross(dir)
    local am = axis.Magnitude
    if am < 1e-5 then return (dir.Y < 0) and IDENT or ANG(math.pi, 0, 0) end
    return CFrame.fromAxisAngle(axis / am, math.atan2(am, DOWN:Dot(dir)))
end
-- an arm (root space) from its shoulder socket s reaching the point t; returns the arm CFrame and where the hand ends up
local function Reach(s: Vector3, t: Vector3): (CFrame, Vector3)
    local d = t - s
    local m = d.Magnitude
    if m < 1e-4 then return CF(s) * CF(0, -0.5, 0), s + DOWN * 1.5 end
    local dir = d / m
    m = clamp(m, 1.55, 2.0) -- (the arm's top stays near the shoulder: closer targets push the hand out, farther fall short)
    local hand = s + dir * m
    return CF(hand - dir) * HangTo(dir), hand
end
local function RotVec(v: Vector3): CFrame
    local m = v.Magnitude
    if m < 1e-5 then return IDENT end
    return CFrame.fromAxisAngle(v / m, m)
end
local function Ease(cur: number, want: number, rate: number, dt: number): number
    return cur + (want - cur) * (1 - exp(-rate * dt))
end
local function Joint(motor: Motor6D?): any
    if not motor then return nil end
    return { M = motor, C0i = motor.C0:Inverse(), C1 = motor.C1 }
end
local function SetRel(j: any, rel: CFrame)
    j.M.Transform = j.C0i * rel * j.C1
end

local function NewEntry(char: Model, src: Instance): any
    local root = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("Torso")
    if not (root and torso and char:FindFirstChild("Head")) then return nil end
    local e = {
        Char = char, Src = src, Root = root, Torso = torso, Head = char.Head,
        RArm = char:FindFirstChild("Right Arm"), Hum = char:FindFirstChildOfClass("Humanoid"),
        JRoot = Joint(root:FindFirstChild("RootJoint")), JNeck = Joint(torso:FindFirstChild("Neck")),
        JRS = Joint(torso:FindFirstChild("Right Shoulder")), JLS = Joint(torso:FindFirstChild("Left Shoulder")),
        JRH = Joint(torso:FindFirstChild("Right Hip")), JLH = Joint(torso:FindFirstChild("Left Hip")),
        LastPos = root.Position, Vel = ZERO, Phase = 0, Acc = 0, GroundAt = 0, Grounded = true, Breath = math.random() * 6,
        KAir = 0, KSlide = 0, KDash = 0, KCrouch = 0, KHold = 0, KMelee = 0, KMove = 0, KShuf = 0, Pitch = 0, ShotAt = -99,
        Hold = "Rifle", Sup = 1.45, MeleeKind = "One", GearCheck = 0,
        LV = ZERO, AccS = ZERO, Yaw = select(2, root.CFrame:ToOrientation()), YawRate = 0, WasAir = false, FallV = 0,
        -- spring states (value, velocity): torso pos / rot, legs, head, unarmed arms, gun rot / pos
        PP = ZERO, PV = ZERO, TP = ZERO, TV = ZERO, LR = ZERO, LRv = ZERO, LL = ZERO, LLv = ZERO, HP = ZERO, HV = ZERO,
        UR = ZERO, URv = ZERO, UL = ZERO, ULv = ZERO, GR = ZERO, GRv = ZERO, GP = ZERO, GPv = ZERO,
        Ray = RaycastParams.new(),
    }
    e.Debug = RunService:IsStudio() and char:GetAttribute("PoseDebug") == true
    if not (e.JRoot and e.JNeck and e.JRS and e.JLS and e.JRH and e.JLH and e.RArm) then return nil end
    e.Ray.FilterType = Enum.RaycastFilterType.Exclude
    e.Ray.FilterDescendantsInstances = { char }
    return e
end

-- slim a part across its X / Z on this client (original size kept in attr SlimOrig; w = 1 puts it back)
local function Slim(part: BasePart, w: number)
    local orig = part:GetAttribute("SlimOrig")
    if typeof(orig) ~= "Vector3" then orig = part.Size; part:SetAttribute("SlimOrig", orig) end
    local want = Vector3.new(orig.X * w, orig.Y, orig.Z * w)
    if (part.Size - want).Magnitude > 1e-3 then part.Size = want end
end

-- the world gun / melee welds (re-found every 0.25 s: the server rebuilds them on any gear change)
local function CheckGear(e: any)
    local char = e.Char
    local w = (TUNE.SlimArms > 0) and TUNE.ArmW or 1
    for _, n in ipairs(ARMS) do
        local a = char:FindFirstChild(n)
        if a and a:IsA("BasePart") then Slim(a, w) end
    end
    local wg = char:FindFirstChild("WorldGloves")
    if wg then for _, sh in ipairs(wg:GetChildren()) do if sh:IsA("BasePart") then Slim(sh, w) end end end
    local gun = char:FindFirstChild("WorldGun")
    local gw = gun and gun:FindFirstChild("WorldGunWeld", true)
    if gw ~= e.GunWeld then
        e.GunWeld = gw
        e.GunHand = gw ~= nil and gw.Part0 == e.RArm
        e.GunC0, e.GunC1, e.GunBack = gw and gw.C0, gw and gw.C1, nil
        e.GunModel = gun
        if gun then
            e.Hold = Poser.HOLDS[gun:GetAttribute("Hold") or ""] and gun:GetAttribute("Hold") or "Rifle"
            local h = Poser.HOLDS[e.Hold]
            e.Sup = clamp(tonumber(gun:GetAttribute("SupFwd")) or h.Sup or 1.2, 0.6, h.MaxSup or 1.3)
        end
    end
    local melee = char:FindFirstChild("WorldMelee")
    local mw = melee and melee:FindFirstChild("WorldMeleeWeld", true)
    if mw ~= e.MeleeWeld then
        e.MeleeWeld = mw
        e.MeleePart0, e.MeleeC0 = mw and mw.Part0, mw and mw.C0
        e.MeleeInHand = false
        e.MeleeKind = MELEE_KIND[melee and melee:GetAttribute("MeleeClass") or ""] or "One"
        e.MeleeModel, e.MeleeScale0 = melee, melee and melee:GetScale()
    end
end

-- melee out: the gun goes on the back (this client only), the melee into the right hand -- and back again
local function SetMeleeOut(e: any, out: boolean)
    if out == (e.MeleeInHand == true) then return end
    e.MeleeInHand = out
    local gw, mw = e.GunWeld, e.MeleeWeld
    if gw and gw.Parent then
        if out then
            if not e.GunBack and e.GunModel then
                local frame = gw.Part1
                local okB, bcf, size = pcall(function() return e.GunModel:GetBoundingBox() end)
                local centre = (okB and frame) and frame.CFrame:PointToObjectSpace(bcf.Position) or ZERO
                local depth = e.Torso.Size.Z / 2 + (okB and min(size.X, size.Y, size.Z) / 2 or 0.2) + 0.05
                e.GunBack = { CF(0, 0, depth) * ANG(0, 0, rad(-140)) * ANG(math.pi, 0, 0), CF(centre) }
            end
            if e.GunBack then gw.Part0 = e.Torso; gw.C0 = e.GunBack[1]; gw.C1 = e.GunBack[2] end
        else
            gw.Part0 = e.RArm; gw.C1 = e.GunC1
        end
    end
    if mw and mw.Parent then
        -- (in the hand the melee is drawn bigger: at world scale a knife read as a dark sliver)
        local m = e.MeleeModel
        if m and m.Parent and e.MeleeScale0 then pcall(function() m:ScaleTo(e.MeleeScale0 * (out and TUNE.HeldMelee or 1)) end) end
        if out then mw.Part0 = e.RArm else mw.Part0 = e.MeleePart0; mw.C0 = e.MeleeC0 end
    end
end

local function Reset(e: any)
    for _, j in ipairs({ e.JRoot, e.JNeck, e.JRS, e.JLS, e.JRH, e.JLH }) do j.M.Transform = IDENT end
end

local function Attr(e: any, name: string): any
    return e.Src:GetAttribute(name)
end

-- SPRINGS (pass 2, owner: "its still incredibly stiff"): every pose value goes through a damped spring (w = stiffness in
-- rad/s, z = damping ratio: < 1 overshoots a touch and settles) -- never a direct set. x / v are Vector3 or numbers.
local SUB = 1 / 120
local function Spring(x: any, v: any, target: any, w: number, z: number, dt: number): (any, any)
    local n = math.max(1, math.ceil(dt / SUB))
    local h = dt / n
    local k, c = w * w, 2 * z * w
    for _ = 1, n do
        v += ((target - x) * k - v * c) * h
        x += v * h
    end
    return x, v
end
local function WrapAngle(a: number): number
    return (a + math.pi) % (2 * math.pi) - math.pi
end

-- an unarmed arm (root space) from its spring angles (x = forward swing, z = out to the side)
local function FreeArm(torsoRel: CFrame, sgn: number, ang: Vector3): CFrame
    return torsoRel * CF((1.5 - TUNE.ArmInset * TUNE.SlimArms) * sgn, 0.5, 0) * ANG(ang.X, 0, 0) * ANG(0, 0, ang.Z * sgn) * CF(0, -0.5, 0)
end

-- one pose update (dt = time since this character's last update)
local function Update(e: any, dt: number, now: number, serverNow: number)
    local root, isMe = e.Root, e.Src == LocalPlayer
    -- ===== MOTION (velocity, acceleration, turn rate) =====
    local pos = root.Position
    local raw = (pos - e.LastPos) / max(dt, 1e-3)
    e.LastPos = pos
    if raw.Magnitude > 160 then raw = e.Vel end -- (a teleport)
    e.Vel = e.Vel:Lerp(raw, 1 - exp(-dt * 15))
    local rcf = root.CFrame
    local lv = rcf:VectorToObjectSpace(e.Vel)
    local hv = V3(lv.X, 0, lv.Z)
    local speed = hv.Magnitude
    local mdir = speed > 0.3 and hv / speed or ZERO
    local acc = (hv - e.LV) / max(dt, 1e-3)
    e.LV = hv
    if acc.Magnitude > 400 then acc = ZERO end
    e.AccS = e.AccS:Lerp(acc, 1 - exp(-dt * 10))
    local _, yaw = rcf:ToOrientation()
    local yr = WrapAngle(yaw - e.Yaw) / max(dt, 1e-3)
    e.Yaw = yaw
    if abs(yr) > 40 then yr = 0 end
    e.YawRate += (yr - e.YawRate) * (1 - exp(-dt * 12))
    local yawRate = clamp(e.YawRate, -8, 8)
    if now - e.GroundAt > 0.1 then
        e.GroundAt = now
        if Attr(e, "Air") ~= nil then e.Grounded = not Attr(e, "Air")
        else e.Grounded = Workspace:Raycast(pos, V3(0, -3.6, 0), e.Ray) ~= nil end
    end
    -- ===== STATES =====
    local slide, dash, crouch
    if isMe and MV then
        slide, dash, crouch = (MV.SlideAmount or 0) > 0.5, (MV.DashAmount or 0) > 0.3, MV.Crouched == true
    else
        slide = Attr(e, "Sliding") == true
        dash = serverNow - (tonumber(Attr(e, "Dashing")) or -99) < 0.3
        crouch = Attr(e, "Crouching") == true
    end
    local air = not e.Grounded and not slide
    -- landing: a squash on touchdown, harder the faster you fell
    if air then e.FallV = lv.Y
    elseif e.WasAir then
        local fall = clamp(-(e.FallV or 0), 0, 60)
        e.PV += V3(0, -clamp(1.5 + fall * 0.12, 1.5, 6) * TUNE.Land, 0)
        e.TV += V3(-clamp(fall * 0.06, 0, 3) * TUNE.Land, 0, 0)
        e.KLand = clamp(0.35 + fall * 0.03, 0.35, 1) * TUNE.Land -- (legs bend into a short crouch, then spring back)
    end
    e.WasAir = air
    if now - e.GearCheck > 0.25 then e.GearCheck = now; CheckGear(e) end
    local armed = e.GunHand and e.GunWeld ~= nil and e.GunWeld.Parent ~= nil
    local meleeOut = armed and Attr(e, "HoldMelee") == true and e.MeleeWeld ~= nil and e.MeleeWeld.Parent ~= nil
    SetMeleeOut(e, meleeOut)
    e.KAir = Ease(e.KAir, air and 1 or 0, air and 10 or 16, dt)
    e.KSlide = Ease(e.KSlide, slide and 1 or 0, slide and 14 or 9, dt)
    e.KDash = Ease(e.KDash, dash and 1 or 0, dash and 26 or 7, dt)
    e.KCrouch = Ease(e.KCrouch, (crouch and not slide) and 1 or 0, 12, dt)
    e.KLand = (e.KLand or 0) * exp(-dt * 7)
    e.KHold = Ease(e.KHold, armed and 1 or 0, 10, dt)
    e.KMelee = Ease(e.KMelee, meleeOut and 1 or 0, 12, dt)
    e.KMove = Ease(e.KMove, clamp(speed / 16, 0, 1.4), speed > e.KMove * 16 and 7 or 5, dt) -- (eases in / out of the run)
    local wantPitch = isMe and 0 or clamp(tonumber(Attr(e, "AimPitch")) or 0, -1.2, 1.2)
    e.Pitch = Ease(e.Pitch, wantPitch, 16, dt)
    e.Breath += dt
    local kM, kA, kS, kD, kC, kH = e.KMove, e.KAir, e.KSlide, e.KDash, max(e.KCrouch, e.KLand), e.KHold
    local kMv = math.min(kM, 1)
    local ground = (1 - kA) * (1 - kS)
    -- ===== GAIT: cadence rises with speed, a step-in-place shuffle when turning on the spot =====
    local shuffle = (speed < 1.5 and not air) and clamp((abs(yawRate) - 1.2) / 2.5, 0, 1) or 0
    e.KShuf = Ease(e.KShuf, shuffle, 10, dt)
    local cadence = (kM > 0.03) and clamp(1.0 + speed * 0.055, 1.05, 2.5) or 0
    cadence = max(cadence, 1.7 * e.KShuf)
    e.Phase = (e.Phase + dt * cadence * math.pi * 2) % (math.pi * 2)
    local ph = e.Phase
    local s1, c1 = sin(ph), cos(ph)
    local legDeg = clamp(16 + speed * TUNE.Swing / 22, 16, TUNE.Swing * 1.3) -- (wider strides at speed)
    local swing = rad(legDeg) * kMv * ground * (1 - kD * 0.6)
    -- ===== LEAN: into velocity AND acceleration (a stop pitches back, a start dips forward) =====
    local accLean = V3(clamp(e.AccS.X * 0.012 * TUNE.AccSide, -0.3, 0.3), 0, clamp(e.AccS.Z * 0.014 * TUNE.AccLean, -0.35, 0.35)) * ground
    local leanVec = mdir * (rad(TUNE.Lean) * kMv + rad(TUNE.DashLean) * kD) + accLean
    -- ===== THE HOLD =====
    local hold = Poser.HOLDS[e.Hold] or Poser.HOLDS.Rifle
    local mk = Poser.MELEE[e.MeleeKind] or Poser.MELEE.One
    local bladeDeg = (hold.Blade * (1 - e.KMelee) + mk.Blade * e.KMelee) * kH * (1 - kS * 0.5)
    local swingT = -1
    local sAt = tonumber(Attr(e, "SwingAt"))
    if sAt then
        local kind = Attr(e, "SwingKind")
        local dur = (kind == "Heavy" and 0.55) or (kind == "Quick" and 0.32) or 0.4
        local t = (serverNow - sAt) / dur
        if t >= 0 and t < 1 then swingT = t end
    end
    local twist = 0
    if swingT >= 0 and e.KMelee > 0.5 then
        twist = (swingT < 0.3) and rad(22) * (swingT / 0.3) or rad(22) - rad(55) * clamp((swingT - 0.3) / 0.3, 0, 1) * (1 - clamp((swingT - 0.7) / 0.3, 0, 1))
    end
    -- ===== TORSO targets: position (bob dips on each foot plant, hip sway) + rotation =====
    local breathS = sin(e.Breath * 1.7)
    local idle = (1 - kMv) * ground
    local plant = abs(s1) -- 1 = feet furthest apart = the foot plant
    local tPos = V3(
        s1 * TUNE.Sway * kMv * ground + sin(e.Breath * 0.8) * 0.015 * idle,
        -TUNE.Bob * plant * plant * plant * kMv * ground + breathS * 0.02 * idle -- (a firm dip at each heel plant, no bounce)
            - (TUNE.CrouchDrop * kC + TUNE.SlideDrop * kS + 0.22 * kD) - TUNE.Athletic * kH * ground * (1 - kC),
        0)
    local tRot = V3(
        leanVec.Z * (1 - kS) + rad(TUNE.SlideLean) * kS - rad(8) * kC - rad(TUNE.AthleticLean) * kH * ground + breathS * rad(1.2) * idle
            + e.Pitch * 0.22 * kH,
        -rad(bladeDeg) + twist - s1 * rad(TUNE.Twist) * kMv * ground * (1 - kH * 0.9) - yawRate * TUNE.TorsoLag + sin(e.Breath * 0.6) * rad(0.8) * idle,
        -leanVec.X * TUNE.StrafeRoll * (1 - kS) + s1 * rad(TUNE.HipRoll) * kMv * ground + sin(e.Breath * 0.8) * rad(0.6) * idle)
    if e.Debug then e.Char:SetAttribute("DbgMdir", mdir); e.Char:SetAttribute("DbgLean", leanVec); e.Char:SetAttribute("DbgAcc", e.AccS); e.Char:SetAttribute("DbgRot", tRot) end
    e.PP, e.PV = Spring(e.PP, e.PV, tPos, 16, 0.55, dt)
    e.TP, e.TV = Spring(e.TP, e.TV, tRot, 11, 0.55, dt)
    local tp = e.TP
    local torsoRel = CF(e.PP) * CF(0, -1, 0) * ANG(0, tp.Y, 0) * ANG(tp.X, 0, tp.Z) * CF(0, 1, 0)
    local torsoInv = torsoRel:Inverse()
    SetRel(e.JRoot, torsoRel)
    -- ===== LEGS: rotation vectors through springs =====
    local axis = (speed > 0.3) and DOWN:Cross(mdir) or XA
    local am = axis.Magnitude
    if am > 1e-4 then axis /= am else axis = XA end
    local strafe = abs(mdir.X)
    local legAmp = swing * (1 - 0.3 * strafe)
    local airUp = clamp(lv.Y / 18, -1, 1)
    local still = (1 - kMv) * (1 - kA)
    for side = 1, 2 do
        local sgn = (side == 1) and 1 or -1 -- right = +1
        local a = legAmp * s1 * sgn
        -- (standing: an athletic stance, feet apart, the left foot a step forward when armed)
        local rv = axis * a + (V3(0, 0, rad(TUNE.StanceOut) * sgn) + XA * (rad(TUNE.StanceStep) * -sgn * kH)) * still
        rv += XA * (rad(14) * s1 * sgn * e.KShuf) + V3(0, 0, rad(4) * max(0, c1 * sgn) * e.KShuf) -- (turning on the spot)
        local rvAir = XA * ((side == 1) and rad(30 + 10 * airUp) or rad(-18 + 8 * airUp))
        local rvCrouch = XA * ((side == 1) and rad(30) or rad(-34)) + axis * a * 0.45
        local rvSlide = XA * ((side == 1) and rad(80) or rad(62)) + V3(0, 0, rad(6) * sgn)
        local rvDash = XA * ((side == 1) and rad(42) or rad(-38))
        rv = rv:Lerp(rvCrouch, kC * (1 - kA))
        rv = rv:Lerp(rvDash, kD * (1 - kS))
        rv = rv:Lerp(rvAir, kA)
        rv = rv:Lerp(rvSlide, kS)
        if side == 1 then e.LR, e.LRv = Spring(e.LR, e.LRv, rv, 20, 0.7, dt); rv = e.LR
        else e.LL, e.LLv = Spring(e.LL, e.LLv, rv, 20, 0.7, dt); rv = e.LL end
        local socket = torsoRel * V3(0.5 * sgn, -1, 0)
        local legRoot = CF(socket) * RotVec(rv) * CF(0, -1, 0)
        SetRel((side == 1) and e.JRH or e.JLH, torsoInv * legRoot)
    end
    -- ===== HEAD: steadier than the torso (root space), looks into turns, cheek on the stock =====
    local cheek = hold.Cheek and kH * (1 - e.KMelee) or 0
    local tHead = V3(e.Pitch * 0.85 * max(kH, 0.35) - rad(6) * cheek, clamp(yawRate * 0.015, -0.12, 0.12), rad(9) * cheek)
    e.HP, e.HV = Spring(e.HP, e.HV, tHead, 14, 0.8, dt)
    local headRoot = CF(torsoRel * V3(0, 1, 0)) * ANG(0, e.HP.Y, 0) * ANG(e.HP.X, 0, 0) * ANG(0, 0, e.HP.Z) * CF(0, 0.5, 0)
    SetRel(e.JNeck, torsoInv * headRoot)
    -- ===== ARMS =====
    -- unarmed: counter-swing to the legs, out in the air, back in a slide, forward in a dash -- floppier springs
    local armA = legAmp * TUNE.ArmSwing
    for side = 1, 2 do
        local sgn = (side == 1) and 1 or -1
        local x = -armA * s1 * sgn + rad(10) * kC - rad(6) * kMv
        local z = rad(4 + 2 * breathS * idle)
        x = x + (rad(-25) - x) * kA; z = z + (rad(42) - z) * kA
        x = x + (rad(40) - x) * kS; z = z + (rad(26) - z) * kS
        local kd = kD * (1 - kS)
        x = x + (rad(50) - x) * kd; z = z + (rad(16) - z) * kd
        local t = V3(x, 0, z)
        if side == 1 then e.UR, e.URv = Spring(e.UR, e.URv, t, 12, 0.5, dt) else e.UL, e.ULv = Spring(e.UL, e.ULv, t, 12, 0.5, dt) end
    end
    local rArm, lArm = FreeArm(torsoRel, 1, e.UR), FreeArm(torsoRel, -1, e.UL)
    if kH > 0.01 then
        local chest = torsoRel * V3(0, 0.5, 0)
        local aimRot = ANG(e.Pitch, 0, 0)
        local aim = aimRot.LookVector
        local sx = 1.5 - TUNE.ArmInset * TUNE.SlimArms
        local sR, sL = torsoRel * V3(sx, 0.5, 0), torsoRel * V3(-sx, 0.5, 0)
        local rT, lT, toolRot, toolOff
        local kMel = e.KMelee
        -- reload + quick-melee bash (the gun's springs carry them)
        local rl, rlT = 0, -1
        local rAt, rFor = tonumber(Attr(e, "ReloadAt")), tonumber(Attr(e, "ReloadFor"))
        if rAt and rFor and rFor > 0 then
            local t = (serverNow - rAt) / rFor
            if t >= 0 and t < 1 then rlT = t; rl = clamp(min(t, 1 - t) * 5, 0, 1) end
        end
        local bash = (swingT >= 0 and kMel < 0.5) and sin(swingT * math.pi) or 0
        -- the gun lags behind turns, bobs with the steps, sways a little at rest
        local gRotT = V3(-rad(14) * rl - rad(16) * bash + sin(ph * 2) * rad(2.5) * TUNE.GunBob * kMv * ground + sin(e.Breath * 1.1) * rad(0.6) * idle,
            clamp(-yawRate * TUNE.TurnLag, -0.12, 0.12) + sin(e.Breath * 0.7) * rad(0.6) * idle, -rad(28) * rl)
        local gPosT = V3(-0.12 * rl, -0.18 * rl + sin(ph * 2 + 0.6) * 0.05 * TUNE.GunBob * kMv * ground, 0.25 * rl - 0.6 * bash)
        e.GR, e.GRv = Spring(e.GR, e.GRv, gRotT, 20, 0.42, dt)
        e.GP, e.GPv = Spring(e.GP, e.GPv, gPosT, 18, 0.5, dt)
        if kMel < 0.99 then
            local h = hold.Hand
            local gunRot = aimRot * ANG(0, e.GR.Y, 0) * ANG(e.GR.X, 0, 0) * ANG(0, 0, e.GR.Z)
            local grip = chest + aimRot * (V3(h.X, h.Y - 0.5, h.Z) + e.GP)
            local gAim, gUp = gunRot.LookVector, gunRot.UpVector
            rT = grip
            if hold.Pistol then
                lT = grip + gunRot * V3(-0.28, -0.12, 0.05)
            else
                local supD = e.Sup
                if hold.Pump then
                    local since = now - e.ShotAt
                    if since > 0.1 and since < 0.5 then supD -= 0.45 * sin((since - 0.1) / 0.4 * math.pi) end
                end
                lT = grip + gAim * supD - gUp * hold.Drop
                if rlT >= 0 then -- reload: the support hand drops to the magazine, dips for a new one, back up
                    local mag = grip + gAim * 0.35 - gUp * 0.45
                    local dip = (rlT > 0.3 and rlT < 0.6) and sin((rlT - 0.3) / 0.3 * math.pi) or 0
                    lT = lT:Lerp(mag - gUp * 0.7 * dip, rl)
                end
            end
            toolRot = gunRot
            toolOff = hold.ToolOff or ZERO -- (a pistol sits out in front of the fists, between them)
        end
        local mrT, mlT, mRot
        if kMel > 0.01 then
            local hr, bd = mk.R, mk.B
            if swingT >= 0 then
                local k1 = (swingT < 0.3) and swingT / 0.3 or 1
                local k2 = clamp((swingT - 0.3) / 0.28, 0, 1)
                local k3 = clamp((swingT - 0.7) / 0.3, 0, 1)
                local wind, windB = V3(1.05, 1.15, -0.25), V3(0.25, 0.85, 0.45)
                local cut, cutB = V3(-0.45, -0.25, -1.3), V3(-0.85, -0.15, -0.5)
                hr = hr:Lerp(wind, k1):Lerp(cut, k2):Lerp(hr, k3)
                bd = bd:Lerp(windB, k1):Lerp(cutB, k2):Lerp(bd, k3)
            end
            mrT = chest + aimRot * (V3(hr.X, hr.Y - 0.5, hr.Z) + e.GP * 0.5)
            local b = (aimRot * bd).Unit
            local x = b:Cross(aim)
            if x.Magnitude < 1e-3 then x = XA else x = x.Unit end
            mRot = CFrame.fromMatrix(ZERO, x, b)
            mlT = mk.Pole and (mrT + b * mk.Pole) or (chest + aimRot * V3(mk.L.X, mk.L.Y - 0.5, mk.L.Z))
        end
        if kMel >= 0.99 then rT, lT, toolRot, toolOff = mrT, mlT, mRot, ZERO
        elseif kMel > 0.01 then rT, lT = rT:Lerp(mrT, kMel), lT:Lerp(mlT, kMel); toolRot = toolRot:Lerp(mRot, kMel); toolOff = toolOff * (1 - kMel) end
        local rArmA = Reach(sR, rT)
        local lArmA = Reach(sL, lT)
        rArm, lArm = rArm:Lerp(rArmA, kH), lArm:Lerp(lArmA, kH)
        -- the gun / melee in the hand that is really there (the reach can fall short of the grip)
        local hand = rArm * V3(0, -1, 0)
        local tool = CF(hand) * toolRot * CF(toolOff)
        local inv = rArm:Inverse()
        if kMel > 0.5 then
            local mw = e.MeleeWeld
            if mw and mw.Parent and e.MeleeInHand then mw.C0 = inv * tool end
        else
            local gw = e.GunWeld
            if gw and gw.Parent and gw.Part0 == e.RArm then gw.C0 = inv * tool end
        end
    elseif e.GunWeld and e.GunWeld.Parent and e.GunHand and e.GunC0 and e.GunWeld.C0 ~= e.GunC0 and e.GunWeld.Part0 == e.RArm then
        e.GunWeld.C0 = e.GunC0
    end
    SetRel(e.JRS, torsoInv * rArm)
    SetRel(e.JLS, torsoInv * lArm)
end

function Poser.Shot(char: Model?)
    local e = char and entries[char]
    if not e then return end
    local hold = Poser.HOLDS[e.Hold] or Poser.HOLDS.Rifle
    local kick = hold.Kick or 1
    -- recoil = an impulse into the gun's springs (muzzle up, a little sideways, back into the shoulder) + the torso
    e.GRv += V3(2.6 * kick, (math.random() - 0.5) * 1.2 * kick, (math.random() - 0.5) * 0.6 * kick)
    e.GPv += V3(0, 0.35 * kick, 2.4 * kick)
    e.TV += V3(0.35 * kick, 0, 0)
    e.ShotAt = os.clock()
end

-- (2026-10-13 fix, owner: "now there is no animation, we are just fully still"): a character whose parts / joints had not
-- all replicated yet when it was first seen used to be marked "not R6" FOREVER -- with no Animate script it never moved
-- again. A failed look is retried every 0.5 s (an R15 fallback body just keeps failing quietly).
local retryAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local warnedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function Track(char: Model?, src: Instance)
    if not char or entries[char] then return end
    local now = os.clock()
    if (retryAt[char] or 0) > now then return end
    local e = NewEntry(char, src)
    if e then entries[char] = e; retryAt[char] = nil else retryAt[char] = now + 0.5 end
end
-- a cached joint replaced (a duel's ApplyDescription, a limb rebuilt) = look again
local function JointsAlive(e: any): boolean
    return e.JRoot.M.Parent ~= nil and e.JNeck.M.Parent ~= nil and e.JRS.M.Parent ~= nil and e.JLS.M.Parent ~= nil
        and e.JRH.M.Parent ~= nil and e.JLH.M.Parent ~= nil and e.RArm.Parent ~= nil
end

function Poser.Start(opts: any?)
    if started then return end
    started = true
    MV = opts and opts.MV
    local TAG = (opts and opts.Tag) or "AimPoseDummy" -- (opts.Tag / DummiesOnly: a Studio test copy can pose its own dummies)
    local function AddPlayer(p: Player)
        if opts and opts.DummiesOnly then return end
        if not table.find(players, p) then table.insert(players, p) end
    end
    for _, p in ipairs(Players:GetPlayers()) do AddPlayer(p) end
    Players.PlayerAdded:Connect(AddPlayer)
    Players.PlayerRemoving:Connect(function(p)
        local i = table.find(players, p)
        if i then table.remove(players, i) end
    end)
    local function AddDummy(m: Instance)
        if m:IsA("Model") and not table.find(dummies, m) then
            table.insert(dummies, m)
            m:GetAttributeChangedSignal("DevShot"):Connect(function() Poser.Shot(m) end)
        end
    end
    for _, m in ipairs(CollectionService:GetTagged(TAG)) do AddDummy(m) end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(AddDummy)
    CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
        local i = table.find(dummies, m)
        if i then table.remove(dummies, i) end
        entries[m] = nil
    end)
    if RunService:IsStudio() then
        -- Studio tuning: DevPoseTune "Key=v,..." (TUNE) and DevPose "Rifle:blade,x,y,z[,maxSup,drop]" (a hold)
        Workspace:GetAttributeChangedSignal("DevPoseTune"):Connect(function()
            for k, v in string.gmatch(tostring(Workspace:GetAttribute("DevPoseTune") or ""), "(%w+)=([%-%d%.]+)") do TUNE[k] = tonumber(v) end
        end)
        Workspace:GetAttributeChangedSignal("DevPose"):Connect(function()
            local cls, rest = string.match(tostring(Workspace:GetAttribute("DevPose") or ""), "^(%w+):(.+)$")
            local h = cls and Poser.HOLDS[cls]
            if not h then return end
            local n = {}
            for v in string.gmatch(rest, "[%-%d%.]+") do table.insert(n, tonumber(v)) end
            h.Blade = n[1] or h.Blade
            if n[4] then h.Hand = V3(n[2], n[3], n[4]) end
            h.MaxSup, h.Drop = n[5] or h.MaxSup, n[6] or h.Drop
            for _, e in pairs(entries) do if e then e.GunWeld = nil end end -- (re-read the support distance)
        end)
    end
    local sweepAt = 0
    local function Step(e: any, dt: number, now: number, serverNow: number, camPos: Vector3)
        if not e or not e.Root.Parent then return end
        if not JointsAlive(e) then entries[e.Char] = nil; return end
        local src = e.Src
        if src:GetAttribute("Downed") or (e.Hum and e.Hum.Health <= 0) then
            if not e.Rest then e.Rest = true; Reset(e); SetMeleeOut(e, false) end
            e.Acc = 0
            return
        end
        e.Rest = nil
        e.Acc += dt
        -- (hidden: another instance, or your own first-person body -- read on the TORSO: a head left at modifier 1 by a camera
        -- change must never freeze a body that is on screen)
        if e.Torso.LocalTransparencyModifier > 0.99 then return end
        local d = (e.Root.Position - camPos).Magnitude
        local every = (d < 70 and 0) or (d < 160 and 1 / 30) or (d < 320 and 1 / 12) or nil
        if not every or e.Acc < every then return end
        local used = min(e.Acc, 0.25)
        e.Acc = 0
        local ok, err = pcall(Update, e, used, now, serverNow)
        if not ok then
            -- (a body whose update fails can't move at all -- no Animate script -- so say so every 10 s, with whose)
            if now - (warnedAt[e.Char] or -99) > 10 then warnedAt[e.Char] = now; warn("[CharacterPoser] " .. e.Char.Name .. ": " .. tostring(err)) end
            entries[e.Char] = nil -- (rebuilt next frame: a bad cached state can't stick)
        end
    end
    local studio = RunService:IsStudio()
    RunService.PreSimulation:Connect(function(dt)
        if studio then dt *= (Workspace:GetAttribute("DevPoseTimeScale") or 1) end -- (Studio: slow motion to film the springs)
        local now = os.clock()
        local serverNow = Workspace:GetServerTimeNow()
        local cam = Workspace.CurrentCamera
        local camPos = cam and cam.CFrame.Position or ZERO
        for i = 1, #players do
            local p = players[i]
            local c = p.Character
            if c then
                if entries[c] == nil then Track(c, p) end
                Step(entries[c], dt, now, serverNow, camPos)
            end
        end
        for i = 1, #dummies do
            local m = dummies[i]
            if entries[m] == nil then Track(m, m) end
            Step(entries[m], dt, now, serverNow, camPos)
        end
        if now - sweepAt > 2 then
            sweepAt = now
            for c in pairs(entries) do if not c.Parent then entries[c] = nil end end
        end
    end)
end

return Poser
