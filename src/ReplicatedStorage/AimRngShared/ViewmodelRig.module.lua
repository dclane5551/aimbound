--!nocheck
-- ViewmodelRig: the real-mesh first-person viewmodel -- shared rigged arms holding a multi-part gun.
--
--   local rig = ViewmodelRig.new(camera)
--   rig:SetWeapon("Glock17", weapon)      -- builds from WeaponAssets + WeaponRigs (false if no rig exists)
--   rig:ApplyCosmetics({ Glove = ..., Sleeve = ..., Skin = ... })
--   rig:Play("Equip" | "Reload" | "ReloadEmpty" | "Inspect")    rig:Fire(isLastRound)
--   rig:Update(dt, cameraCFrame, swayCFrame, cameraFOV)          -- every render frame
--
-- The arms are IK-driven: each frame the wrists are solved onto the gun's GripR / GripL points (or the
-- left hand's free animation target), and the fingers take named hand shapes. Animations therefore only
-- move the gun, its parts and the left hand -- which is why one arm rig works for every gun and knife.
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = script.Parent
local WeaponRigs = require(Shared:WaitForChild("WeaponRigs"))
local MeleeData = require(Shared:WaitForChild("MeleeData")) -- melee weapons use the same rig (MeleeData.Rigs)
local SkinFX = require(Shared:WaitForChild("SkinFX")) -- premium model skins (surfaces, wings, halo, kill effects)
local GloveFX = require(Shared:WaitForChild("GloveFX")) -- glove + sleeve cosmetics on the block arms
local Inspects = require(Shared:WaitForChild("Inspects")) -- (Update 5) inspect / equip data: class + gun + skin overrides

local ViewmodelRig = {}
ViewmodelRig.__index = ViewmodelRig
local IS_STUDIO = game:GetService("RunService"):IsStudio()
local BEAM_COLOR = Color3.fromRGB(70, 215, 255) -- beam guns (def.Beam): beam, flash and light colour

local ArmsData = WeaponRigs.Arms
local FORWARD_ROT = CFrame.Angles(0, math.rad(90), 0) -- gun space +X (muzzle) -> camera -Z
local R = math.rad

-- ==================== helpers ====================
local function RotBetween(a: Vector3, b: Vector3): CFrame
    local dot = math.clamp(a:Dot(b), -1, 1)
    local axis = a:Cross(b)
    if axis.Magnitude < 1e-6 then
        if dot > 0 then return CFrame.identity end
        local perp = (math.abs(a.X) < 0.9) and a:Cross(Vector3.xAxis) or a:Cross(Vector3.yAxis)
        return CFrame.fromAxisAngle(perp.Unit, math.pi)
    end
    return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- Fixed viewmodel FOV: the viewmodel is laid out as seen at the reference FOV, then -- as ONE rigid piece --
-- uniformly scaled by s = tan(fov/2) / tan(ref/2) about the point on the camera's axis at the grip's depth
-- (VM_PIVOT_Z: the grip, so the hands and arms -- closest to the camera -- never swing past it at wide FOVs;
-- the far end of the gun drifts a little toward the centre instead). Something at that depth then appears exactly where (and as big as) it did at the reference
-- FOV, and because the gun, the arms and the hands all scale together, every hand pose stays exactly as tuned.
-- (The old method squashed the gun along the view depth but could only shrink the bone-rigged arms evenly, so
-- at any FOV other than the reference the hands drifted off the gun and the forearms stretched.)
local VM_PIVOT_Z = -1
-- Block arms (no bone rig to keep rigid): EXACT fixed-FOV look instead -- only the sideways / up offsets grow
-- with tan(fov/2) and depth stays put, so every point lands on exactly the same spot of the screen at any FOV
-- (nothing stretches toward / away from the camera). Parts are resized per axis to match (see DepthMap).
local EXACT_FOV = ArmsData.Style == "Block"
-- VIEWMODEL DEPTH (0.97 UPDATE 3, owner: "The uzi still looks streched length wise"): at a 90 deg camera the parts of a gun
-- near the camera are blown up and everything reads elongated (wide-angle distortion) -- shooters draw the viewmodel with
-- a narrower FOV of its own. Same idea here: the whole viewmodel (gun + arms) is compressed along the view depth about
-- the grip's depth (VM_PIVOT_Z) by VM_DEPTH, so the grip / hands stay exactly where they are and the gun reads at its true
-- proportions. (Guns are held square to the camera, so per-axis part resizing in DepthMap is exact enough.)
local VM_DEPTH = 1.0 -- (0.72 made the guns chunky in the corner and changed the approved AK; kept as a knob)
local function DepthScale(p: Vector3, s: number): Vector3
    if EXACT_FOV then return Vector3.new(p.X * s, p.Y * s, VM_PIVOT_Z + (p.Z - VM_PIVOT_Z) * VM_DEPTH) end
    return Vector3.new(p.X * s, p.Y * s, VM_PIVOT_Z + (p.Z - VM_PIVOT_Z) * s)
end
-- Map a world CFrame laid out at the reference FOV into the real camera. Also returns how much each of its
-- local axes got scaled (multiply a part's Size by it) -- uniform now.
local function DepthMap(cf: CFrame, camCF: CFrame, s: number): (CFrame, Vector3)
    if math.abs(s - 1) < 1e-4 and (not EXACT_FOV or math.abs(VM_DEPTH - 1) < 1e-4) then return cf, Vector3.one end
    local rel = camCF:ToObjectSpace(cf)
    if EXACT_FOV then
        -- each local axis grows by how much it points sideways / up; along the view it takes VM_DEPTH
        local function F(v: Vector3): number return Vector3.new(v.X * s, v.Y * s, v.Z * VM_DEPTH).Magnitude end
        return camCF * (CFrame.new(DepthScale(rel.Position, s)) * rel.Rotation), Vector3.new(F(rel.RightVector), F(rel.UpVector), F(rel.LookVector))
    end
    return camCF * (CFrame.new(DepthScale(rel.Position, s)) * rel.Rotation), Vector3.new(s, s, s)
end
-- Resize a part to rest size * f (only when it changed, Size writes aren't free)
local function Squash(entry: any, f: Vector3)
    if entry.F and (entry.F - f).Magnitude < 1e-4 then return end
    entry.F = f
    entry.Part.Size = entry.Size * f
end

-- Note: Bone.WorldCFrame leaves out the bone's own Transform; TransformedWorldCFrame is the posed one.
local function ParentWorld(bone: Bone): CFrame
    local p = bone.Parent
    if p:IsA("Bone") then return p.TransformedWorldCFrame end
    return (p :: BasePart).CFrame
end

-- Rotate `bone` so the direction to its child (childLocal, in the bone's own space) points along worldDir.
local function AimBone(bone: Bone, childLocal: Vector3, worldDir: Vector3)
    local restWorld = ParentWorld(bone) * bone.CFrame
    local restDir = restWorld:VectorToWorldSpace(childLocal.Unit)
    local desired = CFrame.new(restWorld.Position) * RotBetween(restDir, worldDir.Unit) * restWorld.Rotation
    bone.Transform = restWorld:ToObjectSpace(desired)
end

-- A hand frame from three joints: X = pinky -> index knuckle line, Y = from the wrist toward the knuckles.
local function PoseFrame(wrist: Vector3, index1: Vector3, pinky1: Vector3): CFrame
    local x = (index1 - pinky1).Unit
    local y = (index1 + pinky1) / 2 - wrist
    y = (y - x * y:Dot(x)).Unit
    return CFrame.fromMatrix(wrist, x, y, x:Cross(y))
end

local EASE = {
    Linear = function(a) return a end,
    In = function(a) return a * a end,
    Out = function(a) return 1 - (1 - a) * (1 - a) end,
    InOut = function(a) return a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2 end,
}

local function LerpValue(a, b, k)
    local ta = typeof(a)
    if ta == "number" then return a + (b - a) * k end
    if ta == "CFrame" then return a:Lerp(b, k) end
    if ta == "Vector3" then return a:Lerp(b, k) end
    return (k < 1) and a or b -- strings / anything else step
end

-- (2026-10-07, owner: "Melee inspect animations need a lot of work ... Everything needs to be smoother") every segment
-- used to ease IN and OUT on its own, so a melee came to a dead stop at every keyframe (stop-start, robotic). For melee
-- rigs a segment that names no ease now runs on a Catmull-Rom spline through its neighbours (Barry-Goldman form, built
-- from Lerps so CFrames turn smoothly): the motion flows THROUGH the keys. Keys marked "Out" / "In" / "Linear" / "Step"
-- keep their snap (the swings' impacts).
local function SmoothSample(keys: { any }, i: number, t: number): any
    local k1, k2 = keys[i - 1], keys[i]
    local t1, t2 = k1[1], k2[1]
    local k0, k3 = keys[i - 2], keys[i + 1]
    local p0, t0 = k0 and k0[2] or k1[2], k0 and k0[1] or (t1 - (t2 - t1))
    local p3, t3 = k3 and k3[2] or k2[2], k3 and k3[1] or (t2 + (t2 - t1))
    local p1, p2 = k1[2], k2[2]
    if typeof(p0) ~= typeof(p1) or typeof(p3) ~= typeof(p2) then return nil end
    local function L(a, b, ta, tb) local d = tb - ta; return (d > 1e-6) and LerpValue(a, b, (t - ta) / d) or b end
    local a1, a2, a3 = L(p0, p1, t0, t1), L(p1, p2, t1, t2), L(p2, p3, t2, t3)
    local b1, b2 = L(a1, a2, t0, t2), L(a2, a3, t1, t3)
    return L(b1, b2, t1, t2)
end
-- Sample a keyframe track at time t. Each key's ease shapes the segment arriving at that key.
local function SampleTrack(keys: { any }, t: number, smooth: boolean?): any
    local n = #keys
    if n == 0 then return nil end
    if t <= keys[1][1] then return keys[1][2] end
    for i = 2, n do
        local k1 = keys[i]
        if t < k1[1] then
            local k0 = keys[i - 1]
            if typeof(k0[2]) == "string" or k1[3] == "Step" then return k0[2] end
            local span = k1[1] - k0[1]
            local a = span > 0 and (t - k0[1]) / span or 1
            if smooth and k1[3] == nil and (typeof(k0[2]) == "CFrame" or typeof(k0[2]) == "number") then
                local v = SmoothSample(keys, i, t)
                if v ~= nil then return v end
            end
            return LerpValue(k0[2], k1[2], (EASE[k1[3] or "InOut"] or EASE.InOut)(a))
        end
    end
    return keys[n][2]
end

local function MakeSound(parent: Instance, def: any): Sound?
    if not def then return nil end
    local s = Instance.new("Sound")
    s.SoundId = def.Id
    s.Volume = def.Volume or 0.6
    s.PlaybackSpeed = def.Pitch or 1
    s.SoundGroup = game:GetService("SoundService"):FindFirstChild("AimRngMix_Weapons") -- Settings > Audio > Weapons
    s.Parent = parent
    return s
end

-- ==================== construction ====================
function ViewmodelRig.new(parent: Instance)
    local self = setmetatable({}, ViewmodelRig)
    self.Model = Instance.new("Model")
    self.Model.Name = "RealViewmodel"
    self.Model.Parent = parent
    self.SoundFolder = Instance.new("Folder")
    self.SoundFolder.Name = "ViewmodelSounds"
    -- (Edit-mode previews / benches: keep it with the rig, or every test saved a folder into the place -- 179 were found)
    self.SoundFolder.Parent = game:GetService("RunService"):IsRunning() and game:GetService("SoundService") or parent
    self.Visible = true
    self.Anim = nil
    self.AnimTime = 0
    self.SlideLocked = false
    self.HandPose = { R = "PistolGrip", L = "Support" }
    self.Curl = { R = {}, L = {} }
    self.Knife = nil
    self:BuildArms()
    return self
end

local function RigDef(id: string?): any
    if not id then return nil end
    return WeaponRigs.Guns[id] or MeleeData.Rigs[id]
end

function ViewmodelRig.HasRig(gunId: string?): boolean
    return RigDef(gunId) ~= nil
end

function ViewmodelRig:BuildArms()
    local assets = Shared:WaitForChild("WeaponAssets")
    local arms = assets:WaitForChild(ArmsData.Asset):Clone()
    arms.Name = "Arms"
    arms.Parent = self.Model
    self.Arms = arms
    self.ArmsRoot = arms:FindFirstChild("RootPart") :: BasePart
    self.ArmsRoot.Transparency = 1
    self.ArmsBaseScale = arms:GetScale()
    self.ArmScale = 1
    self.ArmParts = {}
    for _, d in ipairs(arms:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
            if d ~= self.ArmsRoot then
                local off = self.ArmsRoot.CFrame:ToObjectSpace(d.CFrame)
                table.insert(self.ArmParts, { Part = d, Offset = off, ScaledOffset = off })
            end
        end
    end
    self.Layers = {}
    for layer, name in pairs(ArmsData.Layers) do
        local p = arms:FindFirstChild(name)
        if p then
            self.Layers[layer] = { Part = p, Original = p:FindFirstChildOfClass("SurfaceAppearance") }
        end
    end

    local function Bone(name: string): Bone
        local b = self.ArmsRoot:FindFirstChild(name, true)
        assert(b, "ViewmodelRig: missing bone " .. name)
        return b :: Bone
    end
    self.Sides = {}
    for side, def in pairs(ArmsData.Sides) do
        local s = {
            Shoulder = Bone(def.Shoulder), Elbow = Bone(def.Elbow), Wrist = Bone(def.Wrist),
            Pole = def.Pole, Fingers = {},
        }
        s.ElbowLocal = s.Elbow.Position
        s.WristLocal = s.Wrist.Position
        s.L1 = s.ElbowLocal.Magnitude
        s.L2 = s.WristLocal.Magnitude
        for finger, chain in pairs(def.Fingers) do
            local bones = {}
            for i, n in ipairs(chain) do bones[i] = Bone(n) end
            s.Fingers[finger] = bones
        end
        self.Sides[side] = s
    end
    self:MeasureHands()
    if ArmsData.Style == "Block" then self:BuildBlockArms() end
end

-- ===== block arms (WeaponRigs.Arms.Style = "Block") =====
-- The rigged arms keep solving (their hand points drive everything) but are hidden; each side shows a block arm
-- from a fixed off-screen shoulder to a block hand on that side's grip point.
function ViewmodelRig:BuildBlockArms()
    for _, d in ipairs(self.Arms:GetDescendants()) do
        if d:IsA("BasePart") then d.Transparency = 1 end
    end
    local cfg = ArmsData.Block
    local skin = cfg.HandColor
    local function Make(name, color)
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.Material = Enum.Material.SmoothPlastic
        p.Color = color
        p.Size = Vector3.new(0.3, 0.3, 0.3)
        p.Parent = self.Model
        return p
    end
    local cuff = ViewmodelRig.CUFF_COLOR
    self.Block = {
        R = { Arm = Make("BlockArmR", cfg.ArmColor), Hand = Make("BlockHandR", skin), Cuff = Make("BlockCuffR", cuff) },
        L = { Arm = Make("BlockArmL", cfg.ArmColor), Hand = Make("BlockHandL", skin), Cuff = Make("BlockCuffL", cuff) },
        Skin = skin,
    }
end
-- ARMS v2 (0.97 UPDATE 3, owner: "Arms still look horrific"): the arm was one thick tube ending in a stump of the same
-- width. Now a slimmer forearm (FOREARM_W of the fist's width, never as fat as a pistol's 1.5x fist), a hand that is
-- longer than it was and wider than the wrist, and a cuff band between them. Only the LOOK changed: the hand point (the
-- arm's end), the fist size every hold is measured with (ArmWidth x ArmFit) and the clearance rays are unchanged.
-- melees: shoulders out to the sides so both forearms come in diagonally and the sleeves show (owner: "The melees have
-- the same issue of not being able to really see the sleeves")
ViewmodelRig.MELEE_SH_R = Vector3.new(1.3, -1.7, 0.2)
ViewmodelRig.MELEE_SH_L = Vector3.new(-1.35, -1.7, 0.2)
ViewmodelRig.FOREARM_W = 0.92 -- (0.82 read "so skinny in comparison to the gloves")
ViewmodelRig.FOREARM_FIT_MAX = 1.5
ViewmodelRig.HAND_LEN_K = 1.35
ViewmodelRig.CUFF_COLOR = Color3.fromRGB(28, 30, 37)
-- place the cuff band at the wrist end of the arm block (look = the arm's frame, armLen = its length, aw = its width)
local function PlaceCuff(b: any, look: CFrame, armLen: number, aw: number)
    local c = b.Cuff
    if not c then return end
    local cl = math.min(aw * 0.32, armLen * 0.5)
    c.Size = Vector3.new(aw * 1.14, aw * 1.14, cl)
    c.CFrame = look * CFrame.new(0, 0, -(armLen - cl / 2))
end

-- handCF (optional): the hand block is fixed to the gun (on its grip, turning with it) instead of following
-- the arm direction -- so it never cuts through the gun while the gun turns (inspects, reloads)
-- follow (optional, Update 5 INSPECTS): { R = the gun's world rotation away from its rest hold, W = weight, Rest = where this
-- fist is in the rest hold } -- ArmFollowR / L turn the forearm (and its roll) with the gun during an inspect: at W = 1 the
-- arm keeps its REST offset from the fist, turned with the gun = rigid with it, so the gun can't swing through it; at 0 it
-- comes from the fixed shoulder as usual
function ViewmodelRig:PlaceBlockArm(side: string, hand: Vector3, camCF: CFrame, k: number, handCF: CFrame?, follow: CFrame?)
    local b = self.Block and self.Block[side]
    if not b then return end
    if handCF then hand = handCF.Position end
    local cfg = ArmsData.Block
    local d0 = self.Def or {}
    -- (same FOV mapping as the gun -- scaling the shoulder alone stretched the arm at other FOVs)
    local shR = d0.BlockShoulderR or (d0.IsMelee and ViewmodelRig.MELEE_SH_R) or cfg.ShoulderR
    local shL = d0.BlockShoulderL or (d0.IsMelee and ViewmodelRig.MELEE_SH_L) or cfg.ShoulderL
    if IS_STUDIO and game:GetService("Players").LocalPlayer then -- live tuning: Player attributes DevShoulder / DevShoulderL = "x,y,z" (camera space; no LocalPlayer = an Edit-context tool rig)
        local lp = game:GetService("Players").LocalPlayer
        local function V(attr)
            local t = {}
            for v in string.gmatch(tostring(lp:GetAttribute(attr) or ""), "[^,]+") do table.insert(t, tonumber(v) or 0) end
            return (#t == 3) and Vector3.new(t[1], t[2], t[3]) or nil
        end
        shR = V("DevShoulder") or shR
        shL = V("DevShoulderL") or shL
    end
    -- (Update 6, SUPPORT_STEEP: the rest hold's steeper support arm; it fades out while an animation takes the hand away --
    -- a steep forearm swung the fist block up into the gun on reloads)
    if side == "L" and not d0.IsMelee and self.ShoulderLShift then shL += self.ShoulderLShift * math.clamp(1 - 3 * (self.LInNow or 0), 0, 1) end
    local sh0 = (side == "R") and shR or shL
    local sh = camCF:PointToWorldSpace(EXACT_FOV and Vector3.new(sh0.X * k, sh0.Y * k, sh0.Z) or DepthScale(sh0, k)) -- (shoulders stay behind the camera: no VM_DEPTH)
    local upV = camCF.UpVector
    if follow then
        local v1 = follow.R:VectorToWorldSpace(sh - follow.Rest)
        sh = hand + (sh - hand):Lerp(v1, follow.W)
        upV = upV:Lerp(follow.R:VectorToWorldSpace(upV), follow.W).Unit -- (a following arm keeps its roll on the gun too)
    end
    if cfg.Rivals then
        -- Rivals arms: one thick sleeve block from the shoulder, ending in a short glove cuff of the same
        -- thickness (a hair wider so the faces never fight). The END of the arm is the hand: the gun rests on it.
        local d = hand - sh
        if d.Magnitude < 0.05 then return end
        -- (0.93, owner: melees "out infront of your hands", "the animations go through your hand"): a melee is HELD -- the
        -- fist (glove cuff) sits centred on the handle and turns with it every frame, the handle running ACROSS the fist
        -- (thumb side -> pinky side) and the forearm meeting it from the side, like CS / Valorant. The weapon can then never
        -- swing or inspect through the hand. handCF = the grip point (its Y = the handle). Guns rest on the arm's end.
        if (side == "R" or d0.Dual) and d0.IsMelee and handCF then
            local grip = handCF.Position
            -- (owner: "the hand is like twisted, it looks super messed up"): the fist is a straight continuation of the
            -- forearm, centred on the handle -- never turned to the weapon
            local u = Vector3.yAxis
            local f = d.Unit
            -- (calm: the fist never twists more than ~40 deg off the forearm, and eases there over a few frames -- a fast
            -- swing used to snap it round and poke the cuff through the glove)

            local w = cfg.ArmWidth * k
            local aw = w * ViewmodelRig.FOREARM_W
            local hl = cfg.HandLen * k * 1.5
            local wristP = grip - f * (hl / 2)
            local da = wristP - sh
            local armLen = math.max(0.05, da.Magnitude)
            local lookA = CFrame.lookAt(sh, wristP, camCF.UpVector) -- (camera up: with world up the block rolled as you looked up / down)
            b.Arm.Size = Vector3.new(aw, aw, armLen)
            b.Arm.CFrame = lookA * CFrame.new(0, 0, -armLen / 2)
            PlaceCuff(b, lookA, armLen, aw)
            b.Hand.Size = Vector3.new(w * 1.04, w * 1.04, hl)
            b.Hand.CFrame = lookA.Rotation + grip -- (same roll as the arm block: no visible twist at the wrist)
            self:PlaceHandFX(side, b)
            return
        end
        local look = CFrame.lookAt(sh, hand, upV) -- (camera up, owner: "The arm also like wiggles / rotates when looking around or up or down")
        local fit = self.ArmFit or 1
        local w = cfg.ArmWidth * k * fit
        local aw = cfg.ArmWidth * k * math.min(fit, ViewmodelRig.FOREARM_FIT_MAX) * ViewmodelRig.FOREARM_W
        local hl = math.min(cfg.HandLen * k * fit * ViewmodelRig.HAND_LEN_K, d.Magnitude * 0.5)
        local armLen = math.max(0.05, d.Magnitude - hl)
        b.Arm.Size = Vector3.new(aw, aw, armLen)
        b.Arm.CFrame = look * CFrame.new(0, 0, -armLen / 2)
        PlaceCuff(b, look, armLen, aw)
        b.Hand.Size = Vector3.new(w * 1.04, w * 1.04, hl)
        b.Hand.CFrame = look * CFrame.new(0, 0, -(armLen + hl / 2))
        local dress = side == "L" and not d0.IsMelee and self.ArmDress and self.ArmDress.L
        if dress then -- (Update 6: the sleeve covers the forearm that is on screen, see SLEEVE_LEN_MAX)
            local cam = Workspace.CurrentCamera
            local tv = math.tan(math.rad(cam and cam.FieldOfView or 70) / 2)
            local vs = cam and cam.ViewportSize or Vector2.new(16, 9)
            local th = tv * vs.X / math.max(1, vs.Y)
            local wrist = look * CFrame.new(0, 0, -armLen)
            local enter = 1
            for i = 0, 15 do
                local q = camCF:PointToObjectSpace(sh:Lerp(wrist.Position, i / 15))
                if q.Z < -0.05 and math.abs(q.X / -q.Z) < th and math.abs(q.Y / -q.Z) < tv then enter = i / 15 break end
            end
            local want = math.clamp(armLen * (1 - enter) + 0.1, ViewmodelRig.SLEEVE_LEN, ViewmodelRig.SLEEVE_LEN_MAX)
            local now = os.clock()
            local dt = math.clamp(now - (self.SleeveFitT or now), 0, 0.1)
            self.SleeveFitT = now
            local snap = self.SleeveFitDress ~= dress or self.SleeveFitDef ~= d0 -- (a new sleeve / gun: fit at once)
            self.SleeveFitDress, self.SleeveFitDef = dress, d0
            dress.LenRef = snap and want or ((dress.LenRef or ViewmodelRig.SLEEVE_LEN) + (want - (dress.LenRef or ViewmodelRig.SLEEVE_LEN)) * math.min(1, dt * 3))
        end
        self:PlaceHandFX(side, b)
        return
    end
    local d = hand - sh
    if d.Magnitude < 0.05 then return end
    hand -= d.Unit * (cfg.HandBack or 0) * k
    if handCF then hand += d.Unit * (cfg.HandBack or 0) * k end -- (undo: a gun-fixed hand stays on the grip)
    d = hand - sh
    local len = d.Magnitude
    local look = CFrame.lookAt(sh, hand, camCF.UpVector)
    local bs = self.BlockScale or 1
    local w = cfg.ArmWidth * k * bs
    local hs = cfg.HandSize * k * bs
    local armLen = math.max(0.05, len - hs / 2) -- the arm stops where the hand block begins (no overlapping faces)
    b.Arm.Size = Vector3.new(w, w, armLen)
    b.Arm.CFrame = look * CFrame.new(0, 0, -armLen / 2)
    local hsize = (cfg.HandBox or Vector3.new(cfg.HandSize, cfg.HandSize, cfg.HandSize)) * k * bs -- the same hand on every gun
    if IS_STUDIO and handCF then -- live tuning: Player attribute DevBlockSize = "x,y,z"
        local t = {}
        for v in string.gmatch(tostring((game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:GetAttribute("DevBlockSize")) or ""), "[^,]+") do table.insert(t, tonumber(v) or 0) end
        if #t == 3 then hsize = Vector3.new(t[1], t[2], t[3]) * k end
    end
    b.Hand.Size = hsize
    b.Hand.CFrame = handCF or (CFrame.new(hand) * look.Rotation)
    self:PlaceHandFX(side, b)
end

-- ===== glove + sleeve cosmetics (GloveFX) on the block arms =====
function ViewmodelRig:PlaceHandFX(side: string, b: any)
    local now = os.clock()
    if self.HandDress and self.HandDress[side] then GloveFX.Place(self.HandDress[side], b.Hand.CFrame, b.Hand.Size, now) end
    if self.ArmDress and self.ArmDress[side] then GloveFX.Place(self.ArmDress[side], b.Arm.CFrame, b.Arm.Size, now) end
    -- (0.58, owner: "Some gloves go through the sides of new guns"): the block hand sits centred IN the handguard and the
    -- glove's plates / spikes are placed off the palm, so on the slim new guns they came out the gun's FAR side (away
    -- from the camera) -- spikes sticking out past the barrel. In first person (a gun, not a melee), glove pieces near
    -- the hand that sit past the gun's middle on the far side are hidden: the gun body covers that half of the glove
    -- anyway, so only the poke-through disappears. ~20 Hz per hand.
    local hd = self.HandDress and self.HandDress[side]
    if hd and self.Visible ~= false then
        self.GloveCullT = self.GloveCullT or {}
        if now - (self.GloveCullT[side] or 0) >= 0.05 then
            self.GloveCullT[side] = now
            local fr = not (self.Def and self.Def.IsMelee) and self.GunParts and self.GunParts.Frame and self.GunParts.Frame.Part
            local fcf, fs, camZ, hq
            if fr then
                fcf, fs = fr.CFrame, fr.Size / 2
                camZ = fcf:PointToObjectSpace(Workspace.CurrentCamera.CFrame.Position).Z
                hq = fcf:PointToObjectSpace(b.Hand.Position)
            end
            for _, e in ipairs(hd.Parts) do
                local p = e.Part
                if p then
                    local far = false
                    if fr then
                        local q = fcf:PointToObjectSpace(p.Position)
                        far = q.Z * camZ < 0 and math.abs(q.Z) > 0.02 and math.abs(q.X - hq.X) < 0.6 and math.abs(q.Y) < fs.Y + 0.2
                    end
                    p.LocalTransparencyModifier = far and 1 or 0
                end
            end
        end
    end
end
ViewmodelRig.GLOVE_FIT = 0.8 -- (0.93: first-person glove size, see GloveFX.Place "GLOVE FIT")
ViewmodelRig.GLOVE_WRIST = 0.06 -- (studs past the hand block toward the elbow a glove piece may sit)
ViewmodelRig.SLEEVE_LEN = 1.4 -- (studs: the forearm length sleeve pieces are laid out on, from the wrist)
ViewmodelRig.SLEEVE_WRAP = 0.4 -- (share of a sleeve band's width past 1.08x that it keeps in first person)
-- (Update 6) the support arm's sleeve covers the forearm you can SEE: on the few guns whose support fist still sits far out
-- after the reach cap (drum / ammo-box guns, long pumps) more than SLEEVE_LEN of forearm showed past the sleeve's pieces.
-- The left sleeve's layout length follows the on-screen forearm (eased), between SLEEVE_LEN and SLEEVE_LEN_MAX.
ViewmodelRig.SLEEVE_LEN_MAX = 2.3
function ViewmodelRig:ApplyHandFX(glove: any?, sleeve: any?)
    if not self.Block then return end
    for _, sd in ipairs({ "R", "L" }) do
        if self.HandDress then GloveFX.Clear(self.HandDress[sd]) end
        if self.ArmDress then GloveFX.Clear(self.ArmDress[sd]) end
    end
    self.HandDress, self.ArmDress = {}, {}
    local w = (ArmsData.Block.ArmWidth or 0.3) * 1.5 -- (particle scale: a bit bigger than the block so they read on screen)
    local bw = (ArmsData.Block.ArmWidth or 0.3) * 1.04 -- (texture tiling: the block's width)
    for _, sd in ipairs({ "R", "L" }) do
        local b = self.Block[sd]
        local handTex = GloveFX.ApplyBase(glove, b.Hand, self.Block.Skin, bw)
        local armTex = GloveFX.ApplyBase(sleeve, b.Arm, ArmsData.Block.ArmColor, bw)
        self.HandDress[sd] = GloveFX.Dress(glove, b.Hand, self.Model, w)
        self.ArmDress[sd] = GloveFX.Dress(sleeve, b.Arm, self.Model, w)
        -- (ARMS v2, owner: cuffs "too big"): sleeve pieces are laid out on a forearm of ONE length from the wrist (the
        -- support arm is ~2.7x longer than the shooting arm, so its cuff / plates came out 2.7x as long) and their wrap
        -- bands keep only SLEEVE_WRAP of their extra width (the 1.36x bell cuffs read as huge in first person)
        self.ArmDress[sd].LenRef = ViewmodelRig.SLEEVE_LEN
        self.ArmDress[sd].WrapK = ViewmodelRig.SLEEVE_WRAP
        if b.Cuff then b.Cuff.Transparency = sleeve and 1 or 0 end
        -- (0.93, owner: "Sometimes the gloves dont align with the sleeves, and the gloves in general are too big"): the
        -- glove is fitted closer (GloveFX Fit), and with a sleeve on, the glove's forearm pieces (cuffs / vambraces that
        -- ran ~1 stud up the arm OVER the sleeve, from a different block, drifting apart as the wrist turns) are left off:
        -- the glove ends at the wrist, the sleeve owns the forearm
        local hd = self.HandDress[sd]
        hd.Fit = ViewmodelRig.GLOVE_FIT
        if glove then -- (ARMS v2: always -- the glove ends at the wrist, the sleeve / the plain forearm owns the arm)
            local keep = {}
            local hsz = b.Hand.Size
            local hw = math.max(hsz.X, hsz.Y)
            for _, e in ipairs(hd.Parts) do
                local pd = e.Def or {}
                local z = ((pd.Off and pd.Off.Z or 0) * hsz.Z) + ((pd.OffW and pd.OffW.Z or 0) * hw)
                if pd.Root and typeof(pd.Size) == "Vector3" and not pd.Uniform then z += pd.Root * pd.Size.Z * hsz.Z / 2 end -- (rooted pieces reach up the arm)
                if e.Part and not e.EmitAtt and not e.RaysAtt and z > hsz.Z * 0.5 + ViewmodelRig.GLOVE_WRIST then
                    e.Part:Destroy()
                else
                    table.insert(keep, e)
                end
            end
            hd.Parts = keep
        end
        self.HandDress[sd].BaseTex, self.ArmDress[sd].BaseTex = handTex, armTex
        self.HandDress[sd].Local = true -- (holo displays show your ammo)
        for _, d in ipairs({ self.HandDress[sd], self.ArmDress[sd] }) do
            for _, pe in ipairs(d.Emitters) do table.insert(self.SkinEmitters or {}, pe) end
            for _, list in pairs(d.Bursts) do for _, bb in ipairs(list) do table.insert(self.SkinEmitters or {}, bb.Emitter) end end
        end
    end
    GloveFX.Link(self.HandDress.R, self.HandDress.L) -- (gloves with an Arc: lightning between the hands)
    -- (the new parts must follow the rig's current visibility)
    for _, d in ipairs({ self.HandDress.R, self.HandDress.L, self.ArmDress.R, self.ArmDress.L }) do
        for _, e in ipairs(d.Parts) do if e.Part then e.Part.LocalTransparencyModifier = self.Visible and 0 or 1 end end
        GloveFX.SetShown(d, self.Visible ~= false)
    end
end
function ViewmodelRig:GloveBurst(kind: string)
    for _, sd in ipairs({ "R", "L" }) do
        if self.HandDress then GloveFX.Event(self.HandDress[sd], kind) end
        if self.ArmDress then GloveFX.Event(self.ArmDress[sd], kind) end
    end
end

-- Work out, from the bind pose, each hand's "grip frame" in wrist space: origin = where a grip's centre
-- line sits in the closed hand, X = palm normal (palm -> grip), Y = the knuckle line (pinky -> index).
-- Also each finger joint's curl axis and direction, so hand shapes are just angles.
function ViewmodelRig:MeasureHands()
    for side, s in pairs(self.Sides) do
        for _, b in ipairs(self.Arms:GetDescendants()) do if b:IsA("Bone") then b.Transform = CFrame.identity end end
        local W = s.Wrist.TransformedWorldCFrame
        local function P(bone: Bone): Vector3 return W:PointToObjectSpace(bone.TransformedWorldCFrame.Position) end
        local index1, pinky1 = P(s.Fingers.Index[1]), P(s.Fingers.Pinky[1])
        local middle1, middle3 = P(s.Fingers.Middle[1]), P(s.Fingers.Middle[3])
        local up = (index1 - pinky1).Unit
        local fingerDir = (middle3 - Vector3.zero)
        fingerDir = (fingerDir - up * fingerDir:Dot(up)).Unit
        -- right palm faces up x fingers; left palm the opposite way
        local palm = (side == "R") and up:Cross(fingerDir) or fingerDir:Cross(up)
        palm = palm.Unit
        local knuckleMid = (index1 + pinky1) / 2
        local palmCentre = knuckleMid:Lerp(Vector3.zero, 0.45)
        local origin = palmCentre + palm * ArmsData.PalmToGrip
        s.HandFrame = CFrame.fromMatrix(origin, palm, up, palm:Cross(up))
        s.PalmWorldDir = W:VectorToWorldSpace(palm)
        -- for hand-posed grips (WeaponRigs GripPose): the wrist frame built from wrist/index/pinky knuckles,
        -- and each finger bone's "towards the next joint" direction in its own space
        s.PoseRest = PoseFrame(Vector3.zero, index1, pinky1)
        s.ChildLocal = {}
        for finger, bones in pairs(s.Fingers) do
            local list = {}
            for i, bone in ipairs(bones) do
                local here = bone.TransformedWorldCFrame
                local nextPos = bones[i + 1] and bones[i + 1].TransformedWorldCFrame.Position
                    or (here.Position + (here.Position - bones[i - 1].TransformedWorldCFrame.Position))
                list[i] = here:VectorToObjectSpace(nextPos - here.Position)
            end
            s.ChildLocal[finger] = list
        end

        -- curl axis per joint = the joint's own X axis; sign chosen so a positive curl closes toward the palm
        s.Curl = {}
        local palmWorld = W:VectorToWorldSpace(palm)
        for finger, bones in pairs(s.Fingers) do
            local entry = {}
            for i, bone in ipairs(bones) do
                -- where this joint's segment ends: the next joint, or a point along the last bone
                local function Tip(): Vector3
                    local nextBone = bones[i + 1]
                    if nextBone then return nextBone.TransformedWorldCFrame.Position end
                    return bone.TransformedWorldCFrame:PointToWorldSpace(Vector3.new(0, 0, -0.1))
                end
                local before = Tip()
                bone.Transform = CFrame.fromAxisAngle(Vector3.xAxis, R(20))
                local after = Tip()
                bone.Transform = CFrame.identity
                entry[i] = { Bone = bone, Axis = Vector3.xAxis, Sign = ((after - before):Dot(palmWorld) >= 0) and 1 or -1 }
            end
            s.Curl[finger] = entry
        end
    end
end

-- ==================== weapon ====================
function ViewmodelRig:ClearGun()
    self:StopBeam()
    if self.Gun then self.Gun:Destroy() end
    if self.GunL then self.GunL:Destroy() end
    self.Gun, self.GunL, self.GunPartsL = nil, nil, nil
    self.GunParts = nil
    self.Def = nil
    -- (SKIN UI 2026-10-29) the skin this rig showed is no longer in your hands: a rig cleared or destroyed without a new SetWeapon
    -- finishing (a gun without a first-person rig, the spectate rig torn down) left its kind behind for HitNumbers / the sounds
    if self.SkinFxKind and SkinFX.CurrentKind == self.SkinFxKind then SkinFX.CurrentKind = nil end
    self.SkinFxKind = nil
end

-- The model a weapon is drawn with -- the ONE lookup shared by this rig and WorldGear (what other players see):
-- a full skin can replace the whole model (skin.Model = a model in WeaponAssets, built on the same Frame / part-zone
-- layout and grip points as the default), otherwise the weapon's own asset, otherwise its placeholder Build().
-- A SkinFX skin (skin.Surface / skin.Deco) is dressed onto the clone here; forView = the first-person rig.
-- exotic = the weapon's ItemData exotic id (or true): the gun also wears the EXOTIC MARK (SkinFX.ExoticMark) in the
-- skin's own signature colour.
function ViewmodelRig.ExoticColor(skin: any?): Color3
    return (skin and (skin.ExoticColor or skin.Color or skin.Accent)) or Color3.fromRGB(255, 150, 40)
end
function ViewmodelRig.ModelFor(def: any, skin: any?, forView: boolean?, exotic: any?): Model?
    if not def then return nil end
    local assets = Shared:FindFirstChild("WeaponAssets")
    -- (SKINS V3) a resculpted skin model lives in WeaponAssets.SkinModels (SkinFX.ModelSource; older full-model skins
    -- were direct children of WeaponAssets)
    local skinSrc = skin and skin.Model and SkinFX.ModelSource("SkinModels", skin.Model) or nil
    local name = skinSrc and skin.Model or def.Asset
    -- (GUN MODELS v2, 2026-10-10): a palette skin (skin.Surface) was painted for the v1 model's UV layout; while its set
    -- isn't rebuilt for the new model, it keeps drawing on WeaponAssets.<GUN>_v1 (skin.V2 = true once rebuilt)
    -- (0.97: a skin with v2 surfaces for this gun -- WeaponAssets.SkinSurfacesV2 -- draws on the v2 model)
    if skin and skin.Surface and not skin.Model and not skin.V2 and assets and def.Asset and assets:FindFirstChild(def.Asset .. "_v1")
        and not SkinFX.V2Surface(skin.Surface, def.Asset, "Frame") then
        name = def.Asset .. "_v1"
    end
    local src = skinSrc or (name and assets and assets:FindFirstChild(name))
    local model = (src and src:Clone()) or (def.Build and def.Build()) or nil
    if model and skin and (skin.Surface or skin.Deco or skin.V3) then SkinFX.Dress(model, skin, forView) end
    if model and skin and skin.FX then model:SetAttribute("SkinFxKind", skin.FX) end -- (SkinFX.StartWorld: the set animates it for others)
    if model and exotic and not def.IsMelee then
        pcall(SkinFX.ExoticMark, model, ViewmodelRig.ExoticColor(skin))
        model:SetAttribute("Exotic", true)
    end
    return model
end

function ViewmodelRig:SetWeapon(gunId: string, weapon: any?, skin: any?): boolean
    local def = RigDef(gunId)
    if not def then return false end
    self:ClearGun()
    Shared:WaitForChild("WeaponAssets")
    local gun = ViewmodelRig.ModelFor(def, skin, true, weapon and weapon.Exotic)
    if not gun then return false end
    if (self.CalTier or 0) > 0 and not def.IsMelee then pcall(SkinFX.CalibrationMark, gun, self.CalTier) end -- (UPDATE 7 B2: set by the client)
    self.Skin = skin
    gun.Name = "Gun"
    gun.Parent = self.Model
    self.Gun = gun
    self.Def = def
    self.GunId = gunId
    self.Weapon = weapon
    -- Optional per-gun Scale (WeaponRigs): the whole gun is drawn bigger/smaller; every gun-space point,
    -- offset and travel below is multiplied by it so hands, VFX and animations still line up.
    self.GunScale = def.Scale or 1
    -- def.Length (owner: "The uzi still looks streched length wise"): the gun is drawn this much shorter along its length
    -- (gun-space X, about the Frame) -- parts, points and hand spots alike. GV = per-axis gun-space scale.
    self.LenK = def.Length or 1
    self.GV = Vector3.new(self.GunScale * self.LenK, self.GunScale, self.GunScale)
    self.MeasuredGripR = nil
    -- (0.97 UPDATE 3, owner: the hand is "inside of the ak" -- "This seems to happen with most of the guns"): the block
    -- arms were sized for the old, bigger guns; with every gun at true size (WeaponRigs.GUN_VIEW_SCALE) the fists swallowed
    -- the grips and the forearms crossed the magazines. Arm / fist blocks (+ the drop under the grip, the support-hand
    -- clearance, the two-hand pistol offset) now scale with the gun from ARM_REF_SCALE, the size they were tuned at.
    -- (one fist size on every long gun; pistols get bigger hands -- owner: "you can barely see the hands" -- a pistol grip
    -- was 2.5 fists tall, so the gun read huge next to a tiny fist hanging off its butt; a hand should cover the grip)
    self.ArmFit = def.IsMelee and 1 or ((def.RivalsClass == "PISTOL") and ViewmodelRig.PISTOL_ARM_FIT or ViewmodelRig.ARM_FIT)
    self.MagInHand = nil
    if self.GunScale ~= 1 then gun:ScaleTo(gun:GetScale() * self.GunScale) end
    local frame = gun:FindFirstChild("Frame") :: BasePart
    -- Optional def.Widen: the imported mesh came out too thin side-to-side (gun space Z = width) -- every part is
    -- stretched sideways about the Frame by this factor
    if def.Widen and def.Widen ~= 1 and frame then
        local w = def.Widen
        for _, p in ipairs(gun:GetChildren()) do
            if p:IsA("BasePart") then
                local rel = frame.CFrame:ToObjectSpace(p.CFrame)
                local rx, ry, rz = rel:ToOrientation()
                p.Size = Vector3.new(p.Size.X, p.Size.Y, p.Size.Z * w)
                if p ~= frame then p.CFrame = frame.CFrame * CFrame.new(rel.X, rel.Y, rel.Z * w) * CFrame.fromOrientation(rx, ry, rz) end
            end
        end
    end
    if self.LenK ~= 1 and frame then
        local lk = self.LenK
        for _, p in ipairs(gun:GetChildren()) do
            if p:IsA("BasePart") then
                local rel = frame.CFrame:ToObjectSpace(p.CFrame)
                local rx, ry, rz = rel:ToOrientation()
                p.Size = Vector3.new(p.Size.X * lk, p.Size.Y, p.Size.Z)
                if p ~= frame then p.CFrame = frame.CFrame * CFrame.new(rel.X * lk, rel.Y, rel.Z) * CFrame.fromOrientation(rx, ry, rz) end
            end
        end
    end
    self.GunParts = {}
    for i, p in ipairs(gun:GetChildren()) do
        if p:IsA("BasePart") then
            p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
            local key = self.GunParts[p.Name] and (p.Name .. "#" .. i) or p.Name -- (skin decorations repeat names)
            self.GunParts[key] = { Part = p, Size = p.Size, Rest = frame.CFrame:ToObjectSpace(p.CFrame), Zone = def.Parts[p.Name] and def.Parts[p.Name].Zone or "Frame", Original = p:FindFirstChildOfClass("SurfaceAppearance"),
                Factory = { Color = p.Color, Material = p.Material, Reflectance = p.Reflectance, Transparency = p.Transparency } }
        end
    end
    -- skin decorations (SkinFX animation attributes): wings breathe + unfold on inspect, rotors spin, seams pulse,
    -- the muzzle star flashes per shot, a light blade sweeps on equip / inspect; emitters + beams follow visibility
    self.HasHinges, self.HaloParts, self.SkinEmitters, self.HasSkinAnim = false, {}, {}, false
    for _, gp in pairs(self.GunParts) do
        local p = gp.Part
        gp.Anim = p:GetAttribute("SkinDeco") and SkinFX.AnimRecord(p, gp.Rest, gp.Size) or nil
        gp.Follow = p:GetAttribute("Follow") -- ("Slide": a skin decoration that rides the pistol slide)
        if gp.Follow == "Magazine" then -- (its stickers hide with it on a reload: a Decal keeps its own transparency modifier)
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("Decal") then gp.Decals = gp.Decals or {}; table.insert(gp.Decals, c) end
            end
        end
        if gp.Anim then
            self.HasSkinAnim = true
            if gp.Anim.Hinge then self.HasHinges = true end
        end
        if p:GetAttribute("Halo") then table.insert(self.HaloParts, p) end
    end
    for _, d in ipairs(gun:GetDescendants()) do
        if (d:IsA("ParticleEmitter") or d:IsA("Beam")) and d:GetAttribute("SkinFx") then table.insert(self.SkinEmitters, d) end
    end
    self.WingOpen = 0
    -- the set's moments (skin.FX): materialise + light sweep on equip
    self.SkinFxKind = skin and skin.FX or nil
    SkinFX.CurrentKind = self.SkinFxKind -- (picks the sound set: Infernal has its own pack)
    self.EquipT0, self.SweepT0, self.LastShotT, self.IgniteT0, self.SkinHeat = nil, nil, nil, nil, 0
    self.SkinSet = self.SkinFxKind and SkinFX.Sets[self.SkinFxKind] or nil
    self.SkinVars = {} -- (a set's own per-gun state: charge, frost, tank level ...)
    -- (Update 5 INSPECTS) the skin's own inspect / equip (skin.InspectAnim / EquipAnim, its set's GunInspect / GunEquip,
    -- extra timed InspectEvents on the class inspect) -- see Inspects.SkinAnims + docs/INSPECTS.md
    local okA, sa = pcall(Inspects.SkinAnims, def, gunId, skin, SkinFX.Sets)
    self.SkinAnims = okA and sa or nil
    if self.SkinSet then
        -- a SkinSets skin runs its own equip moment (its Drive reads st.SinceEquip)
        self.IgniteT0 = os.clock()
        if self.SkinSet.OnEquip then pcall(self.SkinSet.OnEquip, self, SkinFX.H) end
        self.HasSkinAnim = true
        pcall(SkinFX.Sound, "Equip")
    elseif self.SkinFxKind == "Infernal" then
        self.IgniteT0 = os.clock() -- (drawn charred; its cracks catch fire one by one -- no fade, no light sweep)
        pcall(SkinFX.Sound, "Equip")
    elseif self.SkinFxKind then
        self.EquipT0 = os.clock()
        self.SweepT0 = os.clock() + 0.05
        pcall(SkinFX.Sound, "Equip")
    end
    -- Named points become Attachments on the Frame so VFX / accessories can parent to them directly.
    self.Points = {}
    self.PointRest = {}
    self.PointF = nil
    for name, cf in pairs(def.Points) do
        local att = Instance.new("Attachment")
        att.Name = name
        att.CFrame = CFrame.new(cf.Position * self.GV) * cf.Rotation
        att.Parent = frame
        self.Points[name] = att
        self.PointRest[name] = att.CFrame
    end
    -- (Update 5, DUAL melee class): a second copy of the weapon rides the LEFT fist (mirrored hold, its own GunL /
    -- BladeRollL channels); skin animations stay on the right-hand one
    if def.Dual then
        local gl = gun:Clone()
        gl.Name = "GunL"
        for _, d in ipairs(gl:GetDescendants()) do if d:IsA("Attachment") and self.Points[d.Name] then d:Destroy() end end
        gl.Parent = self.Model
        self.GunL = gl
        self.GunPartsL = {}
        local fl = gl:FindFirstChild("Frame")
        for _, p in ipairs(gl:GetChildren()) do
            if p:IsA("BasePart") and fl then table.insert(self.GunPartsL, { Part = p, Size = p.Size, Rest = fl.CFrame:ToObjectSpace(p.CFrame) }) end
        end
    end
    self:ResolvePlacement()
    if self.Block then self:MeasureBlockHands() end
    self:BuildEffects()
    self:BuildSounds()
    self.SlideLocked = false
    self.Anim = nil
    self:Play("Equip")
    -- (2026-11-09) a weapon swapped in while the rig is hidden (the melee drawn in the third-person hub) stays hidden too
    if self.Visible == false then self:SetVisible(false, true) end
    return true
end

-- Work out this gun's grip points, hold and shoulder placement.
--  * GripR / GripL: from Points, or (hand-posed guns) derived from the GripPose so the animation fallback
--    puts each hand exactly where the pose has it.
--  * Hold: def.Hold.Position, or (def.Eye = where the camera sits in gun space) derived from it.
--  * Arms root: ArmsData.RootOffset, or (def.ArmsRoot = where the arm rig's root sat when the gun was
--    posed, in gun space) placed so the arms reach the gun exactly as posed.
-- Turn the hand(s) around a melee's handle (handle = the grip's local Y axis). A round handle looks the same
-- from every side, but the spin decides how the wrist bends -- each melee sets its own (def.GripSpin, degrees).
function ViewmodelRig:SpinGrip(deg: number)
    local base = self.BaseGrips or { R = self.Pt.GripR, L = self.Pt.GripL }
    self.BaseGrips = base
    local rot = CFrame.Angles(0, R(deg), 0)
    self.Pt.GripR = base.R * rot
    if base.L then self.Pt.GripL = base.L * rot end
end

function ViewmodelRig:ResolvePlacement()
    local def, gs = self.Def, self.GunScale or 1
    self.BaseGrips = nil
    local pts = table.clone(def.Points)
    for _, side in ipairs({ "R", "L" }) do
        local key = "Grip" .. side
        if not pts[key] then
            local wrist = self:GripPoseWrist(side, CFrame.identity, gs)
            if wrist then
                local grip = wrist * self.Sides[side].HandFrame
                pts[key] = CFrame.new(grip.Position / gs) * grip.Rotation
            end
        end
    end
    if self.MeasuredGripR then pts.GripR = self.MeasuredGripR end -- (MeasureBlockHands: the real grip)
    self.Pt = pts
    local hold = def.Hold or {}
    local ang = hold.Angles or Vector3.new(0, -5, 0)
    self.HoldRot = CFrame.Angles(R(ang.X), R(ang.Y), R(ang.Z))
    local q = self.HoldRot * FORWARD_ROT
    local gripPos = pts.GripR.Position * gs
    if def.Eye then
        self.HoldPos = q:VectorToWorldSpace(gripPos - def.Eye * gs)
    else
        self.HoldPos = hold.Position
    end

    if def.ArmsRoot then
        self.RootOff = CFrame.new(self.HoldPos + q:VectorToWorldSpace(def.ArmsRoot * gs - gripPos))
    else
        self.RootOff = ArmsData.RootOffset
    end
    -- ArmsShift (camera space): moves the shoulders, e.g. back and down so they stay off-screen; the arms
    -- still solve onto the posed hands
    if def.ArmsShift then self.RootOff = CFrame.new(def.ArmsShift) * self.RootOff end
    if def.GripSpin then self:SpinGrip(def.GripSpin) end
    -- block arms: per-gun lift of the whole hold (camera space), e.g. pistols sat too low to see the inspect
    if ArmsData.Style == "Block" and def.BlockLift then self.HoldPos += def.BlockLift end
    -- Rivals-style framing (WeaponRigs "RIVALS HOLDS"): the right grip point sits at a fixed camera-space spot
    -- per weapon class, and the gun can be turned (BlockTurn, degrees: pitch, yaw = muzzle toward the centre, roll)
    -- Rivals: melee weapons sit further out (same spot on screen, the thick arms no longer swamp them)
    if ArmsData.Style == "Block" and ArmsData.Block.Rivals and def.IsMelee then
        -- the fist sits low-right on screen (like Rivals' knife), the weapon rising from it
        -- (Update 5, owner: "Melee is awkwardly in the middle of the screen, everything right a little bit"): a class's
        -- ViewPos puts the fist low in the bottom-right corner (MeleeData.CLASSES)
        self.HoldPos = def.ViewPos or def.BlockHold or Vector3.new(0.42, -0.58, -1.2)
        -- per-weapon extra turn / shift (degrees pitch, yaw, roll; camera space), e.g. the Seraphim Spear
        if def.HoldNudge then self.HoldPos += def.HoldNudge end
        if def.HoldTurn then
            local t = def.HoldTurn
            self.HoldRot = CFrame.Angles(0, R(t.Y), 0) * CFrame.Angles(R(t.X), 0, R(t.Z)) * self.HoldRot
        end
        -- (0.58, owner: "many are rotated oddly so it doesn't properly showcase the weapon"): measured, every melee stood
        -- bolt upright like a torch (its top straight up the screen, some leaning out to the right). The weapon's own up
        -- axis (gun-space +Y, the handle -> tip) is now AIMED at one showcase direction (camera space: up, leaning in toward
        -- the crosshair, tipped forward) by the smallest turn, so every melee presents the same way whatever its base
        -- hold. FaceSpin (degrees) first turns a weapon about its own handle so its broad face meets the camera (the hand
        -- is spun back so the wrist doesn't twist). Rigs posed by hand (the spear, the scythe) set NoPresent.
        if def.FaceSpin then
            self.HoldRot = self.HoldRot * FORWARD_ROT * CFrame.Angles(0, R(def.FaceSpin), 0) * FORWARD_ROT:Inverse()
            self:SpinGrip((def.GripSpin or 0) - def.FaceSpin)
        end
        if not def.NoPresent then
            local present = def.PresentDir
            local faceFlip = def.FaceFlip
            local faceRoll = def.FaceRoll or 0
            if IS_STUDIO and game:GetService("Players").LocalPlayer then -- live tuning: Player attributes DevPresent = "x,y,z" (camera-space tip direction), DevFaceFlip, DevFaceRoll (deg)
                local lp = game:GetService("Players").LocalPlayer
                local t = {}
                for v in string.gmatch(tostring(lp:GetAttribute("DevPresent") or ""), "[^,]+") do table.insert(t, tonumber(v) or 0) end
                if #t == 3 then present = Vector3.new(t[1], t[2], t[3]) end
                if lp:GetAttribute("DevFaceFlip") ~= nil then faceFlip = lp:GetAttribute("DevFaceFlip") end
                if lp:GetAttribute("DevFaceRoll") ~= nil then faceRoll = tonumber(lp:GetAttribute("DevFaceRoll")) or 0 end
            end
            local up = (self.HoldRot * FORWARD_ROT):VectorToWorldSpace(Vector3.yAxis)
            local want = (present or ViewmodelRig.MELEE_PRESENT_DIR).Unit
            local ax = up:Cross(want)
            if ax.Magnitude > 1e-4 then
                self.HoldRot = CFrame.fromAxisAngle(ax.Unit, math.atan2(ax.Magnitude, up:Dot(want))) * self.HoldRot
            end
            -- (0.93, owner: melees "twisted slightly funny"): aiming the tip leaves the spin about the handle to chance, so
            -- blades showed a skewed face. FaceCamera turns the weapon about its own handle until its flat side (gun-space
            -- FaceAxis, default Z: H.Blade builds blades flat in X / Y) faces the camera; FaceFlip shows the other side (the
            -- edge / hook on the other side of the handle); FaceRoll (degrees) turns it on from there.
            if def.FaceCamera then
                local q = self.HoldRot * FORWARD_ROT
                local u = q:VectorToWorldSpace(Vector3.yAxis)
                local n = q:VectorToWorldSpace(def.FaceAxis or Vector3.zAxis)
                local tw = Vector3.zAxis - u * u.Z
                local np = n - u * n:Dot(u)
                if tw.Magnitude > 1e-3 and np.Magnitude > 1e-3 then
                    tw, np = tw.Unit, np.Unit
                    local ang = math.atan2(np:Cross(tw):Dot(u), np:Dot(tw)) + math.rad(faceRoll)
                    if faceFlip then ang += math.pi end
                    self.HoldRot = CFrame.fromAxisAngle(u, ang) * self.HoldRot
                end
            end
        end
    end
    if ArmsData.Style == "Block" and def.BlockHold then
        self.HoldPos = def.BlockHold
        -- playtester 2026-10-02: "lower the first person weapon -- more towards the corner of the screen than inches away
        -- from the crosshair": every gun sits this much further right / lower (before aiming, so it still converges)
        if not def.IsMelee then self.HoldPos += ViewmodelRig.GUN_SCREEN_SHIFT end
        local t = def.BlockTurn
        -- upright (no cant) and aimed at the crosshair a little way out, like Rivals; Turn adds on top
        -- (the posed holds were canted ~20 deg, which is what made the pistols look awkward)
        local aim = Vector3.new(0, self.HoldPos.Y * 0.6, -(def.BlockConverge or 1000)) - self.HoldPos -- (0.97: straight ahead -- owner: guns "pointed inwards"; was 40 studs out)
        local fwd = aim.Unit
        local right = fwd:Cross(Vector3.yAxis).Unit
        local up = right:Cross(fwd)
        -- gun space: +X muzzle, +Y up -> frame rotation = fromMatrix(fwd, up); holdRot * FORWARD_ROT = that
        local target = CFrame.fromMatrix(Vector3.zero, fwd, up)
        t = t or Vector3.zero
        self.HoldRot = CFrame.Angles(0, R(t.Y), 0) * CFrame.Angles(R(t.X), 0, R(t.Z)) * target * FORWARD_ROT:Inverse()
        -- (0.97 VALORANT HOLDS for guns, owner: the "dead-centre straight-down-the-barrel hold" looks bad -- "Reference
        -- valorant skins"): the gun is turned so its right side faces you (yaw, about the grip), canted a little and sat a
        -- touch lower-right; the side is where a skin lives. Tuned live on the AK with DevGunLift "0.1,-0.03,0.05,2,24,-8".
        if not def.IsMelee then
            local vh = ViewmodelRig.VALORANT_HOLD[def.RivalsClass or ""] or ViewmodelRig.VALORANT_HOLD.Default
            self.HoldPos += vh.Lift
            if def.ViewLiftY then self.HoldPos += Vector3.new(0, def.ViewLiftY, 0) end -- (WeaponRigs.VIEW_FIT: muzzle height)
            if def.ViewShiftX then self.HoldPos += Vector3.new(def.ViewShiftX, 0, 0) end -- (VIEW_FIT: off the centre like its class)
            -- PISTOLS sit by their MUZZLE (owner: the Rhino "way too high up still" while the Glock was right): grips differ
            -- a lot in length / rake, so anchoring the fist put long-gripped guns' barrels high. Every pistol's muzzle
            -- ends at PISTOL_MUZZLE_Y (camera space); the hands go wherever that grip puts them.
            if (def.RivalsClass == "PISTOL") and self.MeasuredGripR and def.Points.Muzzle then
                local gv = self.GV or Vector3.one * gs
                local root = CFrame.new(self.HoldPos) * self.HoldRot * FORWARD_ROT * CFrame.new(-(self.MeasuredGripR.Position * gv))
                local my = (root * (def.Points.Muzzle.Position * gv)).Y
                self.HoldPos += Vector3.new(0, ViewmodelRig.PISTOL_MUZZLE_Y - my, 0)
            end
            if def.ViewLiftAfter then self.HoldPos += Vector3.new(0, def.ViewLiftAfter, 0) end -- (WeaponRigs.VIEW_TWEAK Lift)
            self.HoldRot = CFrame.Angles(0, R(vh.Yaw), 0) * CFrame.Angles(R(vh.Pitch), 0, R(vh.Roll)) * self.HoldRot
        end
        -- a skin can slide its whole gun in camera space (after aiming, so the muzzle moves too) -- ViewNudge, e.g.
        -- the Seraphim M4A1's wings sat over the crosshair
        if self.Skin and self.Skin.ViewNudge then self.HoldPos += self.Skin.ViewNudge end
    end
    -- block arms: guns sit at different distances from the camera, so the same block would look bigger on a
    -- close gun (pistols) and smaller on a far one (rifles). Size the blocks by the grip's distance instead, so
    -- the hand (and the sleeve with it) looks the same size on screen on every gun.
    if def.IsMelee and def.ViewLift then self.HoldPos += def.ViewLift end -- (0.97 VALORANT HOLDS: closer + bigger)
    -- (Update 5, DUAL): the left weapon's hold = the right one mirrored across the screen's middle (ViewPosL overrides the spot)
    if def.Dual then
        local q = self.HoldRot * FORWARD_ROT
        local function M(v: Vector3): Vector3 return Vector3.new(-v.X, v.Y, v.Z) end
        local x, y, z = q.XVector, q.YVector, q.ZVector
        self.HoldRotQL = CFrame.fromMatrix(Vector3.zero, -M(x), M(y), M(z)) -- (= M q M: still a proper rotation)
        self.HoldPosL = def.ViewPosL or Vector3.new(-self.HoldPos.X, self.HoldPos.Y, self.HoldPos.Z)
    end
    self.BlockScale = 1 -- (depth-based sizing made rifle hands huge; kept off for now)
end

ViewmodelRig.GUN_SCREEN_SHIFT = Vector3.new(0.12, -0.09, 0) -- camera space: + right, - down
-- (0.97 VALORANT HOLDS, guns): per Rivals class (WeaponRigs RIVALS_CLASS -> def.RivalsClass); Lift = camera space,
-- Yaw = degrees the muzzle turns in toward the centre (shows the gun's right side), Roll = cant, Pitch = nose up
-- (owner after the first pass: "its pointing the wrong way!" -- a 24 deg yaw aimed every muzzle ~25 deg LEFT of the
-- crosshair, crossing the screen. The muzzle now stays almost straight ahead (a few degrees in, like Valorant) and the
-- side shows because the gun sits further right; the cant stays)
ViewmodelRig.PISTOL_FIST = Vector3.new(-0.11, 0, 0)
ViewmodelRig.PISTOL_ARM_FIT = 1.5
ViewmodelRig.PISTOL_MUZZLE_Y = -0.62 -- (camera space: where every pistol's muzzle sits -- the Glock's spot the owner accepted) -- (gun space, x scale: the sidearm fist's extra offset down / back the grip)
ViewmodelRig.ARM_FIT = 1.0 -- (the original fist blocks: 0.3 wide; guns all at WeaponRigs.GUN_VIEW_SCALE)
ViewmodelRig.SUPPORT_FRAC = 0.36 -- support hand: this far from the grip toward the muzzle (ahead of any front magazine)
ViewmodelRig.SUPPORT_FRAC_LMG = 0.52 -- (LMGs: out on the handguard, clear of the ammo box / drum)
-- SUPPORT REACH (Update 6, owner: "Some of the guns cause the left arm to be super long and it looks a little silly and
-- ruins some of the arm skins"; pass 2: "A lot of weapons tend to have the super long arm issue still: some ars, all the
-- lmgs, a lot of the snipers, and some of the shotguns"). MeasureBlockHands: the support fist sits at most SUPPORT_AHEAD
-- studs past the trigger (the rear of the handguard; a front magazine pushes it just ahead of the magazine, like the
-- approved AK), then the rest pose's forearm ON SCREEN is capped at SUPPORT_VIS_MAX (studs of forearm inside the view at
-- SUPPORT_VIS_FOV, the game's default FOV; = the approved AK's own value): the fist walks back toward the receiver and /
-- or the support arm comes up more steeply (the left shoulder moves by up to SUPPORT_STEEP, camera space: in toward the
-- middle, down, forward) until it fits with a clean forearm. tools/arm_reach_probe.luau measures every gun.
ViewmodelRig.SUPPORT_AHEAD = 1.2
ViewmodelRig.SUPPORT_VIS_FOV = 90
ViewmodelRig.SUPPORT_DEPTH_MAX = 2.85 -- (Update 6 pass 3: the fist no deeper in the scene than the AK's, 2.75: the MP40 read
-- "way longer" at 3.04 while its on-screen forearm measured shorter; the AK's fist END measures 2.84)
ViewmodelRig.SUPPORT_SCREEN = Vector2.new(0.262, -0.264) -- (pass 3: the fist's spot on screen, tan units at SUPPORT_VIS_FOV: X >= / Y <= the AK's)
ViewmodelRig.SUPPORT_VIS_MAX = 1.73 -- (the AK measures 1.72 by this estimate; 1.74 drawn)
-- guns whose support fist may cradle the magazine itself (the PPSh's drum sits right where the handguard starts: holding
-- ahead of it put the fist 4.3 studs out)
ViewmodelRig.SUPPORT_ON_MAG = { PPSH = true, PKM = true, M60 = true, HK21 = true, M249 = true }
-- (Update 6 pass 2) guns whose support fist cradles an AMMO BOX from below (ahead of the PKM's box every forearm ran through
-- it): held rigid to the gun on inspects (no handguard roll -- the "handguard" there is the box)
ViewmodelRig.SUPPORT_BOX_CRADLE = { PKM = true, M60 = true, HK21 = true, M249 = true } -- (the on-screen cap below seats it under the middle of the box)
ViewmodelRig.SUPPORT_STEEP = Vector3.new(0.5, -1.2, -0.6)
-- (Update 6 pass 3) guns whose support fist holds the magwell from BEHIND the magazine (a magazine far out along the gun);
-- SUPPORT_BEHIND_MIN = the closest it comes to the trigger (studs: clear of the trigger guard)
ViewmodelRig.SUPPORT_BEHIND_MAG = { MP40 = true }
ViewmodelRig.SUPPORT_BEHIND_MIN = 0.55
ViewmodelRig.VALORANT_HOLD = { -- (owner: "the guns seem to all have a very slight tilt to the right" -> no cant)
    Default = { Lift = Vector3.new(0.12, -0.02, 0), Pitch = 1, Yaw = 0, Roll = 0 },
    PISTOL = { Lift = Vector3.new(0.05, -0.01, 0), Pitch = 1, Yaw = 0, Roll = 0 }, -- (9 nose-up: owner "pointed way too far up")
    HEAVY = { Lift = Vector3.new(0.04, 0, 0), Pitch = 1, Yaw = 0, Roll = 0 },
}
ViewmodelRig.MELEE_PRESENT_DIR = Vector3.new(-0.38, 0.86, -0.34) -- (camera space: a melee's top leans in + forward)

-- (Update 5 INSPECTS) the support ring's surface distance at angle a (radians, gun YZ plane: 0 = up, pi = down)
function ViewmodelRig.RingRadius(ring: any, a: number): number
    local n = #ring.Prof + 1
    local f = (a % (2 * math.pi)) / (2 * math.pi) * n
    local i0 = math.floor(f) % n
    local k = f - math.floor(f)
    return ring.Prof[i0] + (ring.Prof[(i0 + 1) % n] - ring.Prof[i0]) * k
end

-- Block arms: measure where each block hand should sit on this gun (gun space, once per gun). The grip points
-- sit on the gun's centre line, so a block centred there is half inside the gun -- the support hand is moved
-- down until its top just touches the underside of the gun (handguard / pump) above it. Per-gun nudges
-- (BlockNudgeL / BlockNudgeR, gun space: +X = toward the muzzle, +Y = up) are added on top.
function ViewmodelRig:MeasureBlockHands()
    local def, gs = self.Def, self.GunScale or 1
    self.BlockOff = { R = def.BlockNudgeR or Vector3.zero, L = def.BlockNudgeL or Vector3.zero }
    self.ShoulderLShift = nil
    if def.IsMelee then return end
    local frame = self.Gun:FindFirstChild("Frame") :: BasePart
    local parts, saved = {}, {}
    for _, gp in pairs(self.GunParts) do
        table.insert(parts, gp.Part)
        saved[gp.Part] = gp.Part.CanQuery
        gp.Part.CanQuery = true
    end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = parts
    -- SHOOTING FIST ON THE REAL GRIP (0.97 UPDATE 3, owner: "Check through everything and ensure hand placement is
    -- correct"): the grip point comes from hand poses made for the old models -- on the new AK it sat ~0.4 studs behind the
    -- trigger, back toward the stock. The fist now goes where the gun's own pistol grip is: its front just behind the
    -- trigger (TriggerPivot), its top just under the trigger guard (measured by a ray up at the trigger), wrapping the grip.
    -- (The gun keeps its place on screen; only the fist moves.)
    if ArmsData.Block.Rivals and def.Points.TriggerPivot then
        local fcf0 = frame.CFrame
        local fit0 = self.ArmFit or 1
        local w0 = ArmsData.Block.ArmWidth * fit0
        local tp = def.Points.TriggerPivot.Position * self.GV
        local guardY = tp.Y - 0.08 * gs
        local hg = Workspace:Raycast(fcf0:PointToWorldSpace(Vector3.new(tp.X, tp.Y - 3, tp.Z)), fcf0.UpVector * 3, rp)
        -- (a vertical foregrip / a full-hand bullpup guard under the trigger is not the trigger guard: never more than
        -- 0.2 x scale below the trigger)
        if hg then guardY = math.clamp(fcf0:PointToObjectSpace(hg.Position).Y, tp.Y - 0.2 * gs, tp.Y) end
        local target = Vector3.new(tp.X - 0.06 * gs, guardY - w0 * 0.5 + 0.04, tp.Z) -- (tp.Z: the gun's centreline -- the M60's isn't at 0)
        -- sidearms: the fist wraps the MIDDLE of the raked grip (owner: "The hands on the pistols are still super messed up"
        -- -- the fist only capped the top of the grip and the grip stood in front of the arm)
        local side = def.RivalsClass == "PISTOL" or def.RivalsClass == "HEAVY"
        if side and self.HoldPos and self.HoldRot then
            -- the fist block ENDS at the target (the arm's end): centre it on the middle of the raked grip by pushing the
            -- end half a fist further along the forearm (direction shoulder -> hand, in gun space)
            -- the grip's own length: a ray up from below at the grip finds its butt (a Rhino's grip is far longer than a
            -- Glock's -- one fixed drop left that fist hanging under the grip)
            local xb = tp.X - 0.15 * gs
            local butt = guardY - 0.4 * gs
            local hb = Workspace:Raycast(fcf0:PointToWorldSpace(Vector3.new(xb, tp.Y - 3, tp.Z)), fcf0.UpVector * 3, rp)
            if hb then butt = math.clamp(fcf0:PointToObjectSpace(hb.Position).Y, guardY - 0.7 * gs, guardY - 0.15 * gs) end
            local gripMid = Vector3.new(xb, (guardY + butt) * 0.5, tp.Z) + ViewmodelRig.PISTOL_FIST * gs
            -- a magazine that sits in the grip (behind the trigger, below it) IS the middle of the grip
            local mg = self.GunParts.Magazine
            if mg then
                local mp = mg.Rest.Position
                if mp.X < tp.X and mp.Y < tp.Y then gripMid = Vector3.new(mp.X, mp.Y, tp.Z) end
            end
            -- never INSIDE the gun (owner: "deagle is kind of inside of your hands"): the fist stays below the trigger
            -- guard and behind the trigger -- its top just under the guard, its front just behind the trigger
            local half = ArmsData.Block.ArmWidth * fit0 * 0.5
            gripMid = Vector3.new(math.min(gripMid.X, tp.X - 0.04 * gs - half), math.min(gripMid.Y, guardY - half + 0.02), gripMid.Z)
            local sh = def.BlockShoulderR or ArmsData.Block.ShoulderR
            local dirG = (self.HoldRot * FORWARD_ROT):VectorToObjectSpace((self.HoldPos - sh).Unit)
            target = gripMid + dirG * (ArmsData.Block.HandLen * fit0 * 0.5)
        end
        if def.FistOff then target += def.FistOff * gs end -- (WeaponRigs.VIEW_TWEAK Fist: a per-gun fist nudge, gun space)
        if IS_STUDIO then
            local t = {}
            for v in string.gmatch(tostring((game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:GetAttribute("DevFistOff")) or ""), "[^,]+") do table.insert(t, tonumber(v) or 0) end
            if #t == 3 then target += Vector3.new(t[1], t[2], t[3]) * gs end
        end
        local drop0 = (def.BlockGripDrop or ArmsData.Block.GripDrop) * fit0
        -- ANCHOR THE GUN BY ITS REAL GRIP (owner: "holding weapons should feel consistent ... all the guns vary a lot with
        -- the different arm lengths, heights etc"): the grip point the hold puts at the class's camera-space spot is moved
        -- onto the real grip, so the shooting fist lands on the SAME spot of the screen with every gun (only the gun's own
        -- length / height differ)
        self.MeasuredGripR = CFrame.new((target + Vector3.new(0, drop0, 0)) / self.GV) * self.Pt.GripR.Rotation
        self.Pt.GripR = self.MeasuredGripR
        self.BlockOff.R = def.BlockNudgeR or Vector3.zero
        self:ResolvePlacement() -- (re-place on the real grip: the pistol muzzle-height anchor needs it)
    end
    if def.OneHanded or def.BlockOneHand or def.BlockLeftOnRight then
        for p, v in pairs(saved) do p.CanQuery = v end
        return
    end
    local box = ArmsData.Block.HandBox
    local hs = (box and box.Y or ArmsData.Block.HandSize) * (self.BlockScale or 1)
    if ArmsData.Block.Rivals then hs = ArmsData.Block.ArmWidth * (self.ArmFit or 1) end
    local gl = self.Pt.GripL.Position * self.GV
    local fcf = frame.CFrame
    local origin = fcf:PointToWorldSpace(gl - Vector3.new(0, 3, 0))
    local hit = Workspace:Raycast(origin, fcf.UpVector * 3, rp)
    if hit then
        local ly = fcf:PointToObjectSpace(hit.Position).Y
        self.BlockOff.L += Vector3.new(0, (ly - hs * 0.5 + 0.02) - gl.Y, 0)
        self.BlockMeasured = true
    end
    -- SUPPORT HAND ON THE HANDGUARD (0.97 UPDATE 3, owner: "almost all of the lmgs hold the handguard wrong"): the posed
    -- support grips came from other guns' hand poses and sat under feed trays / receivers on the new models. Now: a set
    -- fraction of the way from the grip to the muzzle (SUPPORT_FRAC), never on a magazine that hangs in front of the grip,
    -- seated on the gun's underside right there (the fist's top just touching). Pump guns: the middle of the pump
    -- (owner: "ksg ... the hand goes through it" -- the posed grip sat behind the KSG's pump, half inside the gun).
    local muz = def.Points.Muzzle
    local supLo = nil -- (Update 6 pass 2: set below, used by the on-screen forearm cap)
    local supHi = math.huge -- (Update 6 pass 3: the furthest out the fist may go -- behind a magazine it holds from behind)
    local supBox = nil -- (Update 6 pass 3: SUPPORT_BOX_CRADLE guns: the ammo box's centre, gun space)
    if ArmsData.Block.Rivals and not def.BlockLeftOnRight and muz then
        local fit = self.ArmFit or 1
        local gx = (def.Points.TriggerPivot or self.Pt.GripR).Position.X * self.GV.X -- (the real grip, not the old pose point)
        local cz = (def.Points.TriggerPivot or self.Pt.GripR).Position.Z * gs -- (centreline)
        local mx = muz.Position.X * self.GV.X
        local lx = gx + (def.RivalsClass == "LMG" and ViewmodelRig.SUPPORT_FRAC_LMG or ViewmodelRig.SUPPORT_FRAC) * (mx - gx)
        local magFront, magBack = -math.huge, math.huge
        for _, gp in pairs(self.GunParts) do
            local pt = gp.Part
            if string.sub(pt.Name, 1, 8) == "Magazine" and gp.Rest.Position.X > gx then
                if ViewmodelRig.SUPPORT_ON_MAG[self.GunId or ""] then
                    supBox = supBox or gp.Rest.Position -- (Update 6 pass 3: the box a cradling fist sits under)
                else
                    local r, sz = gp.Rest, gp.Size / 2
                    for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, -1),
                        Vector3.new(-1, 1, 1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, -1) }) do
                        magFront = math.max(magFront, (r * (sz * c)).X)
                        magBack = math.min(magBack, (r * (sz * c)).X)
                    end
                end
            end
        end
        local lxFloor = magFront + ArmsData.Block.HandLen * fit * 0.5 + 0.04 * gs
        -- (Update 6 pass 3, owner: "mp40 arm is still way longer") SUPPORT_BEHIND_MAG: a magazine far out along the gun (the
        -- MP40's sits 1.3 studs past the trigger) put "just ahead of it" deep in the scene -- the fist holds the magwell from
        -- BEHIND instead, between the trigger guard and the magazine, and never moves forward into it (supHi)
        local behind = ViewmodelRig.SUPPORT_BEHIND_MAG[self.GunId or ""] and magBack < math.huge
            and magBack - ArmsData.Block.HandLen * fit * 0.5 - 0.03 * gs >= gx + ViewmodelRig.SUPPORT_BEHIND_MIN
        if behind then
            supHi = magBack - ArmsData.Block.HandLen * fit * 0.5 - 0.03 * gs
            lx, lxFloor = supHi, gx + ViewmodelRig.SUPPORT_BEHIND_MIN
        end
        lx = math.max(lx, lxFloor)
        -- (Update 6 pass 2) RECEIVER HOLD: never further out than SUPPORT_AHEAD studs past the trigger (the rear of the
        -- handguard) unless a front magazine needs the room -- then just ahead of it, like the approved AK
        if ViewmodelRig.SUPPORT_AHEAD then lx = math.min(lx, math.max(lxFloor, gx + ViewmodelRig.SUPPORT_AHEAD)) end
        lx = math.min(lx, mx - 0.3 * gs)
        local pump = self.GunParts.Pump
        if pump then lx = pump.Rest.Position.X end
        -- (the furthest back the on-screen forearm cap below may walk the fist: never onto the trigger guard / a front
        -- magazine, never off a pump)
        supLo = math.max(lxFloor, gx + 0.2 * (mx - gx))
        if supBox and ViewmodelRig.SUPPORT_BOX_CRADLE[self.GunId or ""] then supLo = math.min(supLo, supBox.X) end
        if pump then
            local pr, ps = pump.Rest, pump.Size / 2
            local back = math.huge
            for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, -1) }) do
                back = math.min(back, (pr * (ps * c)).X)
            end
            supLo = math.max(supLo, back + ArmsData.Block.HandLen * fit * 0.5)
        end
        -- the underside of the gun at lx (slide forward a little if there's nothing above, e.g. a gap)
        local seatY
        for k2 = 0, 6 do
            local x = lx + k2 * 0.05 * gs
            local h = Workspace:Raycast(fcf:PointToWorldSpace(Vector3.new(x, -3, cz)), fcf.UpVector * 6, rp) -- (from under the whole gun)
            if h then lx = x; seatY = fcf:PointToObjectSpace(h.Position).Y; break end
        end
        self.Model:SetAttribute("SupportSeat", seatY and string.format("%.2f@%.2f", seatY, lx) or ("none@" .. string.format("%.2f", lx)))
        if seatY then
            local nudge = def.BlockNudgeL or Vector3.zero
            self.BlockOff.L = Vector3.new(lx - gl.X, (seatY - hs * 0.5 + 0.02) - gl.Y, cz) + Vector3.new(0, nudge.Y, 0)
        end
    end
    -- SUPPORT-ARM CLEARANCE (0.97 UPDATE 3, owner: "the ak and m4 still have the hand clip through the magazine"): the
    -- forearm runs from the left shoulder up to the support grip and on many guns passed through the magazine / receiver.
    -- The rest pose is traced here in gun space (as UpdateRig places it): five rays along the forearm (centre + its four
    -- edges, stopping short of the fist) against every gun part. If they hit, the support fist moves to the camera side of
    -- the handguard (gun -Z) and, if that isn't enough, a little forward -- the cheapest clear spot wins.
    if ArmsData.Block.Rivals and not def.BlockLeftOnRight and self.HoldPos and self.HoldRot then
        local root = CFrame.new(self.HoldPos) * self.HoldRot * FORWARD_ROT * CFrame.new(-(self.Pt.GripR.Position * self.GV))
        local shG = root:PointToObjectSpace((def.BlockShoulderL or ArmsData.Block.ShoulderL) + (self.ShoulderLShift or Vector3.zero))
        local fit = self.ArmFit or 1
        local half = ArmsData.Block.ArmWidth * fit * 0.55 -- (the full arm + a margin: at 0.42 the edges still grazed LMG boxes)
        local fistLen = ArmsData.Block.HandLen * fit + 0.04
        local base = self.BlockOff.L
        local function rayHits(handG: Vector3, shG: Vector3, trim: number?): number
            local d = handG - shG
            local len = d.Magnitude - fistLen - (trim or 0)
            if len <= 0.05 then return 0 end
            local dir = d.Unit
            local side = dir:Cross(Vector3.yAxis)
            side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
            local up2 = side:Cross(dir).Unit
            local n = 0
            for _, o in ipairs({ Vector3.zero, side * half, -side * half, up2 * half, -up2 * half,
                (side + up2) * half, (side - up2) * half, (-side + up2) * half, (-side - up2) * half }) do
                if Workspace:Raycast(fcf:PointToWorldSpace(shG + o), fcf:VectorToWorldSpace(dir * len), rp) then n += 1 end
            end
            return n
        end
        local function hits(off: Vector3): number
            return rayHits(Vector3.new(gl.X, gl.Y, 0) + off - Vector3.new(0, 0.02, 0), shG)
        end
        local best, bestCost, bestHits = base, math.huge, hits(base)
        if bestHits > 0 then
            local fewest = bestHits
            for fi = 0, 12 do
                for zi = 0, 4 do -- (sideways <= 0.12: owner "hk21 hand is completely off the gun" at 0.34)
                    local off = base + Vector3.new(fi * 0.05 * gs, 0, -zi * 0.03 * gs)
                    local h = (gl.X + off.X <= supHi + 1e-4) and hits(off) or 99 -- (never forward into a magazine held from behind)
                    local cost = fi * 0.05 + zi * 0.03 * 2.5
                    if h == 0 and cost < bestCost then best, bestCost = off, cost end
                    if bestCost == math.huge and h < fewest then fewest = h; best = off end
                end
            end
            bestHits = hits(best)
        end
        self.BlockOff.L = best
        self.Model:SetAttribute("SupportShift", string.format("%.2f,%.2f", best.X - base.X, best.Z - base.Z))
        self.Model:SetAttribute("SupportClips", bestHits)
        -- (Update 6 pass 2) ON-SCREEN FOREARM CAP: the rest pose's forearm on screen (studs of the shoulder -> wrist block
        -- PlaceBlockArm draws that fall inside the view at SUPPORT_VIS_FOV, 16:9) must stay <= SUPPORT_VIS_MAX (the
        -- approved AK). Over it: the fist walks back toward the receiver (to supLo: never onto a front magazine / ammo box,
        -- never off a pump) and / or the support arm comes up more steeply (the left shoulder moves by up to SUPPORT_STEEP);
        -- the first spot under the cap whose forearm clears the gun (these 9 rays, the fist up to 0.12 x scale toward the
        -- camera side) and visibly reaches the fist wins -- receiver end first, the shallowest arm first. Nothing clean under the cap -> the clean spot with the least forearm.
        -- Guns already under the cap keep their pose exactly.
        if ViewmodelRig.SUPPORT_VIS_MAX and supLo then
            local shC = def.BlockShoulderL or ArmsData.Block.ShoulderL
            local hl = ArmsData.Block.HandLen * fit * ViewmodelRig.HAND_LEN_K
            local tv = math.tan(math.rad(ViewmodelRig.SUPPORT_VIS_FOV) / 2)
            local th = tv * 16 / 9
            local function visOf(hC: Vector3, sh: Vector3): number -- camera space: the arm's end (the fist) + the shoulder
                local d = hC - sh
                if d.Magnitude < 0.1 then return 0 end
                local wr = hC - d.Unit * math.min(hl, d.Magnitude * 0.5)
                local n, N = 0, 40
                for i = 0, N - 1 do
                    local q = sh:Lerp(wr, (i + 0.5) / N)
                    if q.Z < -0.05 and math.abs(q.X / -q.Z) < th and math.abs(q.Y / -q.Z) < tv then n += 1 end
                end
                return (wr - sh).Magnitude * n / N
            end
            -- the forearm must visibly REACH the fist: a point just behind the wrist is in plain sight of the camera (an ammo
            -- box / a magazine between them read as the hand inside it -- the M60 at first)
            local camG = root:PointToObjectSpace(Vector3.zero)
            local function seen(hG: Vector3, shG2: Vector3): boolean
                local d = hG - shG2
                if d.Magnitude < 0.3 then return true end
                local p = hG - d.Unit * (math.min(hl, d.Magnitude * 0.5) + 0.12)
                return Workspace:Raycast(fcf:PointToWorldSpace(camG), fcf:VectorToWorldSpace((p - camG) * 0.98), rp) == nil
            end
            local cur = Vector3.new(gl.X, gl.Y, 0) + best - Vector3.new(0, 0.02, 0)
            local v0 = visOf(root:PointToWorldSpace(cur), shC + (self.ShoulderLShift or Vector3.zero))
            local d0 = -root:PointToWorldSpace(cur).Z -- (Update 6 pass 3: how deep in the scene the fist sits)
            local v1, w1, pulled = v0, 0, 0
            local function fits(v: number, p: Vector3): boolean
                local q = root:PointToWorldSpace(p)
                -- (pass 3: where the fist lands ON SCREEN -- higher up / further left than the AK's reads as a long reach
                -- toward the crosshair even when the forearm itself is short: the MP40, HK21, M60)
                local sx, sy = q.X / -q.Z / tv, q.Y / -q.Z / tv
                return v <= ViewmodelRig.SUPPORT_VIS_MAX and -q.Z <= ViewmodelRig.SUPPORT_DEPTH_MAX
                    and sy <= ViewmodelRig.SUPPORT_SCREEN.Y and sx >= ViewmodelRig.SUPPORT_SCREEN.X
            end
            local function scrOf(p: Vector3): string
                local q = root:PointToWorldSpace(p)
                return string.format("%.3f,%.3f", q.X / -q.Z / tv, q.Y / -q.Z / tv)
            end
            local s0 = scrOf(cur)
            if not fits(v0, cur) or (supBox and ViewmodelRig.SUPPORT_BOX_CRADLE[self.GunId or ""]) then -- (a box cradle always looks)
                local ny = (def.BlockNudgeL or Vector3.zero).Y
                local czb = base.Z -- (the centreline, before the sideways shift above)
                local cradle = supBox and ViewmodelRig.SUPPORT_BOX_CRADLE[self.GunId or ""]
                local x0 = cur.X
                local pick, top, alt = nil, nil, nil
                -- the fist's spots from the receiver end forward (the owner: "back toward the receiver"), the support arm
                -- only as steep as it has to be: every spot at the current steepness before a steeper arm
                local spots = {}
                local x = math.min(supLo, x0)
                while x <= math.min(x0, supHi) + 1e-4 and #spots < 80 do
                    -- (a cradled ammo box: the fist under the box's own middle, which may sit off the centreline -- the M60's)
                    local zc = (cradle and x <= supBox.X + 0.3 * gs) and supBox.Z or czb
                    local h = Workspace:Raycast(fcf:PointToWorldSpace(Vector3.new(x, -3, zc)), fcf.UpVector * 6, rp)
                    if h then table.insert(spots, Vector3.new(x, fcf:PointToObjectSpace(h.Position).Y - hs * 0.5 + ny, zc)) end
                    x += 0.04 * gs
                end
                for wi = 0, 8 do
                    local sh = shC + ViewmodelRig.SUPPORT_STEEP * (wi / 8)
                    local shG2 = root:PointToObjectSpace(sh)
                    for _, p in ipairs(spots) do
                        local v = visOf(root:PointToWorldSpace(p), sh)
                        if fits(v, p) or not top or v < top.V then
                            for zi = 0, 4 do
                                local z = p.Z - zi * 0.03 * gs
                                if rayHits(Vector3.new(p.X, p.Y, z), shG2) == 0 then
                                    local c = { X = p.X, Y = p.Y, Z = z, W = wi / 8, V = v, F = fits(v, p) }
                                    if not seen(Vector3.new(p.X, p.Y, z), shG2) then
                                        -- (hidden behind the gun from the camera: only if nothing in sight fits -- the M60's
                                        -- ammo box hides every spot under the cap, as it hid the old one)
                                        -- (the furthest-out such spot at the shallowest arm: the arm still reaches past the box)
                                        if fits(v, p) and (not alt or alt.W == c.W) then alt = c end
                                    else
                                        if fits(v, p) then pick = c elseif not top or v < top.V then top = c end
                                        break
                                    end
                                end
                            end
                        end
                        if pick then break end
                    end
                    if pick then break end
                end
                pick = pick or alt or top
                if pick and (pick.F or pick.V < v0) then
                    self.BlockOff.L = Vector3.new(pick.X - gl.X, pick.Y + 0.02 - gl.Y, pick.Z)
                    self.ShoulderLShift = pick.W > 0 and ViewmodelRig.SUPPORT_STEEP * pick.W or nil
                    v1, w1, pulled = pick.V, pick.W, x0 - pick.X
                    self.Model:SetAttribute("SupportClips", 0)
                end
            end
            local bo = self.BlockOff.L
            self.Model:SetAttribute("SupportReach", string.format("vis %.2f -> %.2f depth %.2f scr %s -> %s (pulled %.2f, steep %.2f)", v0, v1, d0, s0,
                scrOf(Vector3.new(gl.X, gl.Y, 0) + bo - Vector3.new(0, 0.02, 0)), pulled, w1))
        end
        -- the SHOOTING forearm (bullpups: the magazine sits behind the grip, so it ran straight through it): the fist slides
        -- to the gun's far side (gun +Z, the side a right palm is on) and / or a little down until the forearm clears.
        -- BlockOff.R is in the grip point's frame (UpdateRig: gunRoot * gripR * CFrame.new(offR - drop)).
        local gripR = CFrame.new(self.Pt.GripR.Position * self.GV) * self.Pt.GripR.Rotation
        local drop = (def.BlockGripDrop or ArmsData.Block.GripDrop) * fit
        local shRG = root:PointToObjectSpace(def.BlockShoulderR or ArmsData.Block.ShoulderR)
        local baseR = self.BlockOff.R
        local function hitsR(dG: Vector3): number
            local off = baseR + gripR:VectorToObjectSpace(dG)
            -- (the pistol grip runs down past the fist into the heel of the hand: the last stretch before the fist is
            -- skipped, or every gun's own grip counted as the forearm clipping and the fist was shoved off it)
            return rayHits((gripR * CFrame.new(off - Vector3.new(0, drop, 0))).Position, shRG, 0.2 * gs)
        end
        local bestR, costR, hR = Vector3.zero, math.huge, hitsR(Vector3.zero)
        if hR >= 2 then
            local fewest = hR
            for zi = 0, 6 do
                for yi = 0, 0 do -- (sideways only: a lower fist on some guns broke the one-hold-for-all look)
                    local dG = Vector3.new(0, -yi * 0.04 * gs, zi * 0.03 * gs)
                    local h = hitsR(dG)
                    local cost = zi * 0.03 * 1.6 + yi * 0.04 * 2
                    if h == 0 and cost < costR then bestR, costR = dG, cost end
                    if costR == math.huge and h < fewest then fewest = h; bestR = dG end
                end
            end
            hR = hitsR(bestR)
        end
        self.BlockOff.R = baseR + gripR:VectorToObjectSpace(bestR)
        self.Model:SetAttribute("GripShift", string.format("%.2f,%.2f", bestR.Y, bestR.Z))
        self.Model:SetAttribute("GripClips", hR)
    end
    -- (Update 5 INSPECTS) the handguard's cross-section where the support fist sits (gun space, scaled): LCradle rolls the
    -- fist round it. Measured as a radial PROFILE: 16 rays from outside toward a point just inside the handguard's underside,
    -- in the gun's YZ plane (angle 0 = up, pi = down), so a U-shaped / rectangular / tapered handguard is followed exactly.
    -- C = that centre, Prof[i] = the surface distance at angle i x 22.5 deg, Gap = how far the fist's centre sits off it.
    self.SupportRing = nil
    if ArmsData.Block.Rivals and not def.BlockLeftOnRight and self.BlockOff and self.BlockOff.L and not ViewmodelRig.SUPPORT_BOX_CRADLE[self.GunId or ""] then
        local gp = self.Pt.GripL.Position * self.GV
        local seat = Vector3.new(gp.X, gp.Y, 0) + self.BlockOff.L - Vector3.new(0, 0.02, 0)
        local x = seat.X
        local cz0 = (def.Points.TriggerPivot or self.Pt.GripR).Position.Z * gs
        local hU = Workspace:Raycast(fcf:PointToWorldSpace(Vector3.new(x, -3, cz0)), fcf.UpVector * 6, rp)
        if hU then
            local yB = fcf:PointToObjectSpace(hU.Position).Y
            local c = Vector3.new(x, yB + 0.06 * gs, cz0)
            local prof = {}
            for i = 0, 15 do
                local a = i / 16 * 2 * math.pi
                local dir = Vector3.new(0, math.cos(a), math.sin(a))
                local h = Workspace:Raycast(fcf:PointToWorldSpace(c + dir * 1.5), fcf:VectorToWorldSpace(-dir * 1.5), rp)
                local r = 0.04 * gs
                if h then
                    local l = fcf:PointToObjectSpace(h.Position) - c
                    r = math.max(0.02, Vector3.new(0, l.Y, l.Z).Magnitude)
                end
                prof[i] = r
            end
            local d0 = Vector3.new(0, seat.Y - c.Y, seat.Z - c.Z)
            local ring = { C = c, Prof = prof, Gap = 0.1 }
            if d0.Magnitude > 1e-3 then
                ring.Gap = math.max(0.05, d0.Magnitude - ViewmodelRig.RingRadius(ring, math.atan2(d0.Z, d0.Y)))
            end
            self.SupportRing = ring
            self.Model:SetAttribute("SupportRing", string.format("down %.2f side %.2f gap %.2f", prof[8], prof[4], ring.Gap))
        end
    end
    for p, v in pairs(saved) do p.CanQuery = v end
end

function ViewmodelRig:BuildSounds()
    self.SoundFolder:ClearAllChildren()
    self.Sounds = {}
    local set = WeaponRigs.Sounds[self.Def.Sounds or ""] or {}
    for name, def in pairs(set) do self.Sounds[name] = MakeSound(self.SoundFolder, def) end
end

function ViewmodelRig:PlaySound(name: string)
    local s = self.Sounds and self.Sounds[name]
    if s then
        if name == "Fire" then
            -- (a recording Roblox hasn't approved yet, or one that failed to load, never loads in a live server: the
            -- caller falls back to the class shot instead of a silent gun -- owner 2026-10-05 "deagle has no sound")
            if not s.IsLoaded then return false end
            local c = s:Clone(); c.Parent = self.SoundFolder
            c.PlaybackSpeed = (s.PlaybackSpeed) * (0.96 + math.random() * 0.08)
            if self.SkinFxKind then c.Volume = s.Volume * 0.8 end -- a skin's own shot layer carries its voice
            c:Play(); Debris:AddItem(c, 2)
        else
            s:Play()
        end
        return true
    end
    return false
end

-- ==================== effects ====================
function ViewmodelRig:BuildEffects()
    local muzzle = self.Points.Muzzle
    if not muzzle then return end
    local flash = Instance.new("ParticleEmitter")
    flash.Name = "Flash"
    flash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    flash.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 140, 40))
    flash.LightEmission = 1
    flash.LightInfluence = 0
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.05) })
    flash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    flash.Lifetime = NumberRange.new(0.04, 0.06)
    flash.Speed = NumberRange.new(2, 5)
    flash.SpreadAngle = Vector2.new(12, 12)
    flash.EmissionDirection = Enum.NormalId.Right -- attachment +X = out of the barrel
    flash.Rate = 0
    flash.LockedToPart = true
    flash.Parent = muzzle
    if self.Def and self.Def.Energy then
        -- (BEAM GUNS v5: an Arcwright gun's flash is a short tight discharge in its beam colour, not a powder burst --
        -- SetProcFx colours it, MuzzleFlash skips the smoke)
        flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
        flash.Lifetime = NumberRange.new(0.03, 0.05)
        flash.Speed = NumberRange.new(1, 3)
        flash.SpreadAngle = Vector2.new(6, 6)
    end
    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "Smoke"
    smoke.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190))
    smoke.LightInfluence = 0.6
    smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.35) })
    smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
    smoke.Lifetime = NumberRange.new(0.35, 0.6)
    smoke.Speed = NumberRange.new(0.5, 1.5)
    smoke.Acceleration = Vector3.new(0, 1.5, 0)
    smoke.SpreadAngle = Vector2.new(25, 25)
    smoke.EmissionDirection = Enum.NormalId.Right
    smoke.Rate = 0
    smoke.Parent = muzzle
    local light = Instance.new("PointLight")
    light.Name = "FlashLight"
    light.Color = Color3.fromRGB(255, 190, 110)
    -- (0.62: was range 9 / brightness 3 every shot -- a strobe that lit the walls in front of you white)
    light.Range = 6
    light.Brightness = 1.1
    light.Enabled = false
    light.Parent = muzzle
    self.Fx = { Flash = flash, Smoke = smoke, Light = light }
    self:SetProcFx(self.Weapon and self.Weapon.Proc)
    local set = self.Skin and SkinFX.Sets[self.Skin.FX or ""]
    if set and set.Muzzle then
        -- a SkinSets skin dresses its own muzzle (flash colours, light, extra emitters -> self.Fx.Motes / any keys)
        local ok, err = pcall(set.Muzzle, self, flash, light, muzzle, SkinFX.H)
        if not ok then warn("[ViewmodelRig] skin muzzle: " .. tostring(err)) end
    elseif self.Skin and self.Skin.FX == "Infernal" then
        -- hellfire: a crimson flash with a violet heart, embers spat from the muzzle
        flash.Color = ColorSequence.new(Color3.fromRGB(255, 170, 170), SkinFX.Colors.Crimson)
        light.Color = SkinFX.Colors.Crimson
        local motes = Instance.new("ParticleEmitter")
        motes.Name = "SkinMotes"
        motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        motes.Color = ColorSequence.new(SkinFX.Colors.Ember, SkinFX.Colors.Violet)
        motes.LightEmission = 1; motes.LightInfluence = 0
        motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 0) })
        motes.Transparency = NumberSequence.new(0, 1)
        motes.Lifetime = NumberRange.new(0.25, 0.45)
        motes.Speed = NumberRange.new(1, 3)
        motes.SpreadAngle = Vector2.new(40, 40)
        motes.EmissionDirection = Enum.NormalId.Right
        motes.Rate = 0
        motes.Parent = muzzle
        self.Fx.Motes = motes
    elseif self.Skin and self.Skin.FX == "Seraphim" then
        -- heavenly: a white-gold flash with drifting gold motes, gold tracers (Tracer uses the light colour)
        flash.Color = ColorSequence.new(Color3.new(1, 1, 1), SkinFX.Colors.Gold)
        light.Color = SkinFX.Colors.PaleGold
        local motes = Instance.new("ParticleEmitter")
        motes.Name = "SkinMotes"
        motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        motes.Color = ColorSequence.new(SkinFX.Colors.PaleGold, SkinFX.Colors.Gold)
        motes.LightEmission = 1; motes.LightInfluence = 0
        motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 0) })
        motes.Transparency = NumberSequence.new(0, 1)
        motes.Lifetime = NumberRange.new(0.25, 0.45)
        motes.Speed = NumberRange.new(1, 3)
        motes.SpreadAngle = Vector2.new(40, 40)
        motes.EmissionDirection = Enum.NormalId.Right
        motes.Rate = 0
        motes.Parent = muzzle
        self.Fx.Motes = motes
    end
end

-- Weapon prefix (Burning, Freezing, ...) tints the muzzle flash and adds a faint aura at the muzzle.
function ViewmodelRig:SetProcFx(proc: any?)
    if not self.Fx then return end
    local ItemData = require(Shared:WaitForChild("ItemData"))
    local def = proc and ItemData.WeaponProcs[proc.Id]
    local old = self.Points.Muzzle:FindFirstChild("ProcAura")
    if old then old:Destroy() end
    if def then
        self.Fx.Flash.Color = ColorSequence.new(Color3.fromRGB(255, 230, 180), def.Color)
        self.Fx.Light.Color = def.Color
        local aura = Instance.new("ParticleEmitter")
        aura.Name = "ProcAura"
        aura.Color = ColorSequence.new(def.Color)
        aura.LightEmission = 0.8
        aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0) })
        aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
        aura.Lifetime = NumberRange.new(0.25, 0.45)
        aura.Speed = NumberRange.new(0.2, 0.6)
        aura.SpreadAngle = Vector2.new(180, 180)
        aura.Rate = 12
        aura.Parent = self.Points.Muzzle
    elseif self.Def and (self.Def.Beam or self.Def.Energy) then
        local col = (self.Skin and self.Skin.BeamColor) or self.Def.BeamColor or BEAM_COLOR -- (the tracer reads the light colour)
        self.Fx.Flash.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.6), col)
        self.Fx.Light.Color = col
    else
        self.Fx.Flash.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 140, 40))
        self.Fx.Light.Color = Color3.fromRGB(255, 190, 110)
    end
end

function ViewmodelRig:MuzzleFlash()
    if not self.Fx then return end
    self.Fx.Flash:Emit(3)
    if not (self.Def and (self.Def.Beam or self.Def.Energy)) then self.Fx.Smoke:Emit(2) end
    if self.Fx.Motes then self.Fx.Motes:Emit(4) end
    -- (0.62: at most one light flash every 0.12 s -- a fast gun used to strobe the room)
    if os.clock() - (self.lastFlashLight or 0) >= 0.12 then
        self.lastFlashLight = os.clock()
        self.Fx.Light.Enabled = true
        task.delay(0.05, function() if self.Fx then self.Fx.Light.Enabled = false end end)
    end
end

-- HELD ROUNDS (2026-10-10, owner: "Some guns dont have actual reload animations either, just your hand moves"): tube
-- shotguns, stripper clips, the double barrel and the revolver reloaded with an empty hand. The hand now carries a
-- shotshell / stripper clip / speed-loader (hand space: +Y points from the palm toward the loading port), shown while
-- the reload's ShellHold channel is on (WeaponRigs ShellLoads / BreakAnims / RevolverAnims).
function ViewmodelRig.BuildHeldRound(def: any, gs: number)
    local model = Instance.new("Model")
    model.Name = "HeldRound"
    local parts = {}
    local function P(size: Vector3, color: Color3, mat: Enum.Material, at: CFrame, cyl: boolean?)
        local p = Instance.new("Part")
        p.Name = "HeldRoundPart"
        if cyl then p.Shape = Enum.PartType.Cylinder end
        p.Size = size * gs
        p.Color, p.Material = color, mat
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.LocalTransparencyModifier = 1
        p.Parent = model
        table.insert(parts, { p, CFrame.new(at.Position * gs) * at.Rotation })
    end
    local UP = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis (X) turned to +Y
    local brass, steel = Color3.fromRGB(196, 150, 72), Color3.fromRGB(46, 46, 52)
    local kind = def.Fx and def.Fx.Shell
    if def.Revolver then
        P(Vector3.new(0.05, 0.19, 0.19), steel, Enum.Material.Metal, CFrame.new(0, 0.07, 0) * UP, true) -- loader body
        for i = 0, 5 do
            local a = i * math.pi / 3
            P(Vector3.new(0.11, 0.045, 0.045), brass, Enum.Material.Metal, CFrame.new(math.cos(a) * 0.058, 0.15, math.sin(a) * 0.058) * UP, true)
        end
    elseif def.TopLoad then
        P(Vector3.new(0.012, 0.03, 0.26), steel, Enum.Material.Metal, CFrame.new(0, 0.04, 0)) -- the stripper clip
        for i = 0, 4 do
            P(Vector3.new(0.13, 0.04, 0.04), brass, Enum.Material.Metal, CFrame.new(0, 0.115, -0.1 + i * 0.05) * UP, true)
        end
    elseif kind == "12ga" then
        P(Vector3.new(0.04, 0.078, 0.078), brass, Enum.Material.Metal, CFrame.new(0, 0.05, 0) * UP, true) -- brass head
        P(Vector3.new(0.17, 0.074, 0.074), Color3.fromRGB(170, 30, 32), Enum.Material.SmoothPlastic, CFrame.new(0, 0.155, 0) * UP, true)
    else
        P(Vector3.new(0.12, 0.04, 0.04), brass, Enum.Material.Metal, CFrame.new(0, 0.1, 0) * UP, true)
    end
    return { Model = model, Parts = parts, On = false }
end

function ViewmodelRig:EjectShell()
    local eject = self.Points and self.Points.Eject
    if not eject or (self.Def and self.Def.Beam) then return end
    local wcf = eject.WorldCFrame
    local shell = Instance.new("Part")
    shell.Name = "Shell"
    local kind = self.Def and self.Def.Fx and self.Def.Fx.Shell
    local rifle, shotshell = kind == "Rifle", kind == "12ga"
    shell.Size = shotshell and Vector3.new(0.075, 0.075, 0.2) or rifle and Vector3.new(0.045, 0.045, 0.12) or Vector3.new(0.04, 0.04, 0.075)
    shell.Material = shotshell and Enum.Material.SmoothPlastic or Enum.Material.Metal
    shell.Color = (self.Skin and self.Skin.ShellColor) or (shotshell and Color3.fromRGB(165, 28, 28)) or Color3.fromRGB(205, 160, 70) -- (SKINS V3: skin.ShellColor)
    shell.CanCollide = true
    shell.CanQuery = false
    shell.CanTouch = false
    shell.CastShadow = false
    shell.CFrame = wcf * CFrame.Angles(0, math.random() * 6, 0)
    shell.Parent = Workspace
    local out = wcf.XVector -- eject point X = out of the port (gun's right)
    shell.AssemblyLinearVelocity = out * (7 + math.random() * 3) + wcf.YVector * (6 + math.random() * 2) - wcf.ZVector * 0
    shell.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
    Debris:AddItem(shell, 1.5)
end

-- A quick bright streak from the muzzle to where the shot landed.
-- BEAM GUNS (def.Beam, 0.48): one continuous beam from the emitter to whatever you hit while the trigger is held,
-- instead of a tracer per shot. 3 parts (core, glow sleeve, impact flare) re-aimed every frame; it lingers 0.09 s after
-- the last shot, so a steady fire rate reads as an unbroken beam.
-- (Update 4, owner: "The lasers should directly follow your crosshair, right now they kinda are laggy and delayed": the end
-- was the LAST SHOT's hit -- it only moved on fire ticks -- and a plain RenderStepped connection could read the muzzle
-- before the viewmodel moved this frame. Now it is bound AFTER AimRngViewmodel (Camera + 1) and both ends are rebuilt
-- every frame: start = the muzzle of this frame's pose, end = a visual camera ray (same filter as the shot ray, separate
-- from the damage raycast, which keeps its fire-rate cadence))
function ViewmodelRig:StopBeam()
    if self.BeamConn then
        if self.BeamConn == true then game:GetService("RunService"):UnbindFromRenderStep(self.BeamBind) else self.BeamConn:Disconnect() end
        self.BeamConn = nil
    end
    if self.BeamParts then for _, p in ipairs(self.BeamParts) do p:Destroy() end; self.BeamParts = nil end
end
function ViewmodelRig:Beam(hitPos: Vector3, hitNormal: Vector3?)
    self.BeamHit, self.BeamNormal, self.BeamAt = hitPos, hitNormal, os.clock()
    if self.BeamConn then return end
    local col = (self.Skin and self.Skin.BeamColor) or (self.Def and self.Def.BeamColor) or BEAM_COLOR -- (a skin may tint the beam: skin.BeamColor)
    local function P(name, size, tr)
        local p = Instance.new("Part")
        p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        p.Material = Enum.Material.Neon; p.Color = col; p.Transparency = tr; p.Size = size
        p.Parent = Workspace
        return p
    end
    local core = P("BeamCore", Vector3.new(0.05, 0.05, 1), 0.05)
    core.Color = col:Lerp(Color3.new(1, 1, 1), 0.55)
    local sleeve = P("BeamGlow", Vector3.new(0.16, 0.16, 1), 0.7)
    local flare = P("BeamFlare", Vector3.new(0.6, 0.6, 0.6), 0.35)
    flare.Shape = Enum.PartType.Ball
    self.BeamParts = { core, sleeve, flare }
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    self.BeamBind = "AimRngBeam_" .. tostring(self):gsub("%W", "")
    self.BeamConn = true
    game:GetService("RunService"):BindToRenderStep(self.BeamBind, Enum.RenderPriority.Camera.Value + 2, function()
        local muzzle = self.Points and self.Points.Muzzle
        local since = os.clock() - (self.BeamAt or 0)
        if not muzzle or since > 0.09 or not self.Visible then self:StopBeam(); return end
        local cam = Workspace.CurrentCamera
        local to = self.BeamHit
        if cam then
            local lpc = game:GetService("Players").LocalPlayer
            local char = lpc and lpc.Character
            rp.FilterDescendantsInstances = char and { cam, char } or { cam }
            local o, dir = cam.CFrame.Position, cam.CFrame.LookVector * 1000
            local r = Workspace:Raycast(o, dir, rp)
            to = r and r.Position or (o + dir)
            self.BeamNormal = r and r.Normal or nil
        end
        local from = muzzle.WorldPosition
        local d = to - from
        local len = d.Magnitude
        if len < 0.5 then return end
        local mid = CFrame.lookAt(from + d / 2, to)
        local t = os.clock()
        local w = 1 + 0.18 * math.sin(t * 55) -- a little crackle in the width
        core.Size = Vector3.new(0.05 * w, 0.05 * w, len); core.CFrame = mid
        sleeve.Size = Vector3.new(0.17 * w, 0.17 * w, len); sleeve.CFrame = mid
        local fs = 0.5 + 0.25 * math.sin(t * 40)
        flare.Size = Vector3.new(fs, fs, fs); flare.CFrame = CFrame.new(to + (self.BeamNormal or -d.Unit) * 0.1)
        -- (0.62: a neon flare on a wall right in front of you bloomed the screen white -- it fades when it's close)
        local camD = cam and (to - cam.CFrame.Position).Magnitude or 99
        flare.Transparency = (camD < 14) and (0.35 + 0.6 * (1 - camD / 14)) or 0.35
    end)
end

function ViewmodelRig:Tracer(hitPos: Vector3, hitNormal: Vector3?)
    local muzzle = self.Points and self.Points.Muzzle
    if not muzzle then return end
    if self.Def and self.Def.Beam and not self.SkinSet then self:Beam(hitPos, hitNormal); return end
    local from = muzzle.WorldPosition
    if self.SkinSet then
        SkinFX.ShotFx(self.SkinFxKind, from, hitPos, hitNormal)
        return
    elseif self.SkinFxKind == "Seraphim" or self.SkinFxKind == "Infernal" then
        -- golden tracer + a starburst / hellfire tracer + claw marks where it lands (0.62: lights tamed, see SkinFX.Tame)
        local inf = self.SkinFxKind == "Infernal"
        SkinFX.Tame(false, inf and SkinFX.InfernalTracer or SkinFX.Tracer, from, hitPos)
        if hitNormal and os.clock() - (self.lastImpactFx or 0) >= SkinFX.IMPACT_GAP then
            self.lastImpactFx = os.clock()
            local cam = workspace.CurrentCamera
            SkinFX.Tame(cam ~= nil and (hitPos - cam.CFrame.Position).Magnitude < 14, inf and SkinFX.InfernalImpact or SkinFX.Impact, hitPos, hitNormal)
        end
        return
    end
    local dist = (hitPos - from).Magnitude
    if dist < 2 then return end
    local p = Instance.new("Part")
    p.Name = "Tracer"
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = (self.Fx and self.Fx.Light.Color) or Color3.fromRGB(255, 210, 140)
    p.Transparency = 0.35
    -- (2026-10-22 HITSCAN LOOK, owner: "There should be no projectiles at all"): was an 18-stud streak flying from the muzzle
    -- to the hit over 0.08 s, which read as a bullet in flight. Now the whole line, muzzle -> hit, is there on the shot frame
    -- and fades in place (the same as the line other players see, AimRngClient "PeerTracer"). Skin tracers: SkinFX.H.TRAVEL.
    p.Size = Vector3.new(0.03, 0.03, dist)
    p.CFrame = CFrame.lookAt((from + hitPos) / 2, hitPos)
    p.Parent = Workspace
    game:GetService("TweenService"):Create(p, TweenInfo.new(0.08), { Transparency = 1 }):Play()
    game:GetService("Debris"):AddItem(p, 0.1)
end

-- ==================== cosmetics ====================
-- A "look" is: { KeepTexture = bool, Tint = Color3, Material = Enum.Material?, Reflectance = number?,
--               Animated = "Rainbow"? }. KeepTexture keeps the realistic texture (tinted by Tint);
-- otherwise the part becomes a solid Material/Color (Neon, Glass, Foil, Metal...).
-- Weapon skins may also give per-zone looks: skin.Zones = { Slide = look, Frame = look, ... }.
local function ApplyLook(part: BasePart, original: SurfaceAppearance?, look: any)
    local sa = part:FindFirstChildOfClass("SurfaceAppearance")
    if look.KeepTexture ~= false then
        if not sa and original then
            sa = original:Clone(); sa.Parent = part
        end
        if sa then sa.Color = look.Tint or Color3.new(1, 1, 1) end
        part.Material = Enum.Material.SmoothPlastic
        part.Reflectance = 0
    else
        if sa then sa:Destroy() end
        part.Material = look.Material or Enum.Material.SmoothPlastic
        part.Color = look.Tint or Color3.new(1, 1, 1)
        part.Reflectance = look.Reflectance or 0
    end
end
ViewmodelRig.ApplyLook = ApplyLook

-- Dress gun / melee parts in a skin -- the ONE place skins are applied, shared by this first-person rig and the
-- third-person models other players see (WorldGear). parts = { { Part, Zone, Original = SurfaceAppearance?,
-- Factory = { Color, Material, Reflectance, Transparency } } }; skin = ItemData.WeaponSkins / MeleeData.Skins entry.
-- Returns the parts a "Rainbow" skin animates.
function ViewmodelRig.SkinParts(parts: { any }, def: any, skin: any?): { BasePart }
    local animated = {}
    if def and def.IsMelee then
        -- melee skins (MeleeData.Skins): a look per zone; zones the skin doesn't set keep the factory look
        for _, gp in pairs(parts) do
            if gp.Part:GetAttribute("SkinDeco") then continue end -- (SkinFX decorations keep their own look)
            local z = skin and skin.Zones and skin.Zones[gp.Zone]
            local f = gp.Factory
            gp.Part.Color = z and z.Color or f.Color
            gp.Part.Material = z and z.Material or f.Material
            gp.Part.Reflectance = z and z.Reflectance or f.Reflectance
            gp.Part.Transparency = z and z.Transparency or f.Transparency
            if z and z.Animated == "Rainbow" then table.insert(animated, gp.Part) end
        end
    else
        for _, gp in pairs(parts) do
            if gp.Part:GetAttribute("SkinDeco") then continue end
            local look
            if skin and skin.Zones and skin.Zones[gp.Zone] then
                look = skin.Zones[gp.Zone]
            elseif not skin or skin.Id == "Factory" then
                look = { KeepTexture = true, Tint = def and def.FactoryTint } -- (flat-colour models need darkening)
            else
                look = { KeepTexture = skin.KeepTexture ~= false, Tint = skin.Tint, Material = skin.Material, Reflectance = skin.Reflectance }
            end
            if gp.Zone ~= "Interior" then ApplyLook(gp.Part, gp.Original, look) end
            if (look.Animated or (skin and skin.Animated)) == "Rainbow" then table.insert(animated, gp.Part) end
        end
    end
    return animated
end

-- cosmetics = { Glove = GloveCosmetic, Sleeve = ArmSkin, Skin = WeaponSkin } (ItemData catalog entries)
function ViewmodelRig:ApplyCosmetics(cos: any)
    self.Animated = {}
    local glove, sleeve, skin = cos and cos.Glove, cos and cos.Sleeve, cos and cos.Skin
    local function GloveLook(g)
        if not g or g.Id == "Tactical" then return { KeepTexture = true } end
        local mat = g.Material
        if mat == Enum.Material.Neon or mat == Enum.Material.Glass or mat == Enum.Material.ForceField or mat == Enum.Material.Foil then
            return { KeepTexture = false, Material = mat, Tint = g.PrimaryColor }
        end
        return { KeepTexture = true, Tint = g.PrimaryColor }
    end
    local function SleeveLook(s)
        if not s or s.Id == "Standard" then return { KeepTexture = true } end
        local mat = s.Material
        if mat == Enum.Material.Neon or mat == Enum.Material.Glass or mat == Enum.Material.ForceField or mat == Enum.Material.Foil then
            return { KeepTexture = false, Material = mat, Tint = s.SleeveColor }
        end
        return { KeepTexture = true, Tint = s.SleeveColor }
    end
    if self.Block then
        -- block arms: a glove colours the hand blocks, a sleeve the arm blocks
        local handCol = (glove and glove.Id ~= "Tactical" and glove.PrimaryColor) or self.Block.Skin
        local armCol = (sleeve and sleeve.Id ~= "Standard" and sleeve.SleeveColor) or ArmsData.Block.ArmColor
        for _, sd in ipairs({ "R", "L" }) do
            self.Block[sd].Hand.Color = handCol
            self.Block[sd].Arm.Color = armCol
        end
    end
    if self.Layers.Glove then ApplyLook(self.Layers.Glove.Part, self.Layers.Glove.Original, GloveLook(glove)) end
    if self.Layers.Sleeve then ApplyLook(self.Layers.Sleeve.Part, self.Layers.Sleeve.Original, SleeveLook(sleeve)) end
    if self.GunParts then
        self.Animated = ViewmodelRig.SkinParts(self.GunParts, self.Def, skin)
    end
    if cos and cos.HandFX then self:ApplyHandFX(cos.HandFX.Glove, cos.HandFX.Sleeve) end
end

-- ==================== animation ====================
-- end the running animation, easing back to the rest pose (a cancelled reload)
function ViewmodelRig:Stop()
    self.BlendFrom = self.LastGunCh
    self.BlendT = 0
    self.Anim = nil
    self.AnimName = nil
    self.Model:SetAttribute("Anim", "")
end
function ViewmodelRig:Play(name: string, speed: number?)
    local anims = self.Def and self.Def.Anims
    local a = (self.SkinAnims and self.SkinAnims[name]) or (anims and anims[name])
    if not a then return false end
    -- start from wherever the weapon is right now (re-pressing inspect / chaining swings never snaps)
    self.BlendFrom = (name ~= "Fire") and self.LastGunCh or nil -- (a gun's fire kick stays crisp)
    self.BlendT = 0
    self.Anim = a
    self.AnimName = name
    self.AnimTime = 0
    self.AnimSpeed = speed or 1
    self.EventIndex = 1
    self.Model:SetAttribute("Anim", name) -- visible to play-test tooling
    if self.SkinSet and self.SkinSet.OnAnim then pcall(self.SkinSet.OnAnim, self, name, SkinFX.H) end -- (equip / inspect / reload / swings)
    if name == "Inspect" then
        self:GloveBurst("Inspect")
        if self.SkinSet then
            self.InspectT0 = os.clock()
        elseif self.SkinFxKind and self.SkinFxKind ~= "Infernal" then -- (Infernal inspect = its eye opens: SkinFX st.Eye)
            self.SweepT0 = os.clock() + 0.35 -- (silent: owner 2026-10-02 "the inspect sound sounds silly")
        end
    end
    -- melee skin swings: the blade's trail lights up for the swing
    if self.SkinFxKind and self.Def and self.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then
        pcall(SkinFX.Sound, "Swing")
        -- (2026-10-07, owner: "The melee swings having the trail needs to be toned down, it kind of lingers in your face for
        -- a second"): the trail used to stay on for 80% of the whole animation, return arc included. Now it draws only
        -- around the strike (the anim's "Swing" event: 0.08 s before to 0.12 s after), shorter-lived and fainter here in
        -- first person (other players' views keep the set's own look)
        local strikeAt = 0.1
        for _, e in ipairs(a.Events or {}) do if e[2] == "Swing" then strikeAt = e[1] break end end
        local sp = speed or 1
        -- (0.58, owner: "The melee swinging trails need to be toned down even more"): a thin streak off the blade's outer third
        -- (it was the whole blade's width, facing the camera = a sheet across your view), 0.06 s long, faint, 0.04 s before
        -- the strike to 0.08 s after
        local on, off = math.max(0, strikeAt - 0.04) / sp, (strikeAt + 0.08) / sp
        for _, d in ipairs(self.Gun and self.Gun:GetDescendants() or {}) do
            if d:IsA("Trail") and d:GetAttribute("SwingTrail") then
                if not d:GetAttribute("FPTamed") then
                    d:SetAttribute("FPTamed", true)
                    d.Lifetime = math.min(d.Lifetime, 0.06)
                    d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
                    d.LightEmission = math.min(d.LightEmission, 0.5)
                    local a0, a1 = d.Attachment0, d.Attachment1
                    if a0 and a1 and a0.Parent == a1.Parent then a0.Position = a0.Position:Lerp(a1.Position, 0.7) end
                end
                d.Enabled = false
                local token = (d:GetAttribute("SwingTok") or 0) + 1
                d:SetAttribute("SwingTok", token)
                task.delay(on, function() if d.Parent and d:GetAttribute("SwingTok") == token then d.Enabled = true end end)
                task.delay(off, function() if d.Parent and d:GetAttribute("SwingTok") == token then d.Enabled = false end end)
            end
        end
    end
    if name == "Inspect" and self.SkinEmitters and not self.SkinSet then
        for _, pe in ipairs(self.SkinEmitters) do task.delay(0.35, function() if pe.Parent then pe:Emit(6) end end) end
    end
    self.Model:SetAttribute("AnimSpeed", self.AnimSpeed)
    return true
end

-- (Studio test hook, Update 5): play an animation frozen at time t (DevAct "pose:<Anim>@<t>"): clip checks sample poses
function ViewmodelRig:PoseAt(name: string, t: number): boolean
    if not self:Play(name, 0) then return false end
    self.AnimTime = math.max(0, t)
    self.BlendFrom = nil
    return true
end

function ViewmodelRig:AnimLength(name: string): number
    local a = (self.SkinAnims and self.SkinAnims[name]) or (self.Def and self.Def.Anims and self.Def.Anims[name])
    return a and a.Length or 0
end

function ViewmodelRig:IsPlaying(name: string?): boolean
    if not self.Anim then return false end
    return name == nil or self.AnimName == name
end

-- RECOIL SPRING (0.48, owner: "guns need more satisfying animation"): every shot (and every handling moment: a mag
-- seating, a bolt slamming home, a pump racking) is an IMPULSE into a damped spring per channel, so the gun snaps back,
-- overshoots forward a touch and settles -- heavy guns on a slower, heavier spring, SMGs on a quick tight one.
-- Channels: back (studs), up (studs), pitch / roll / yaw (degrees). Peak ~= the gun's RecoilKick numbers at strength 1.
local SPRING_ZETA = 0.42 -- damping ratio: < 1 = the forward overshoot that makes it feel mechanical
function ViewmodelRig:Jolt(strength: number, isShot: boolean?)
    local def = self.Def
    if not def then return end
    local rk = def.RecoilKick or {}
    local w = def.KickHz and (def.KickHz * 2 * math.pi) or self.KickOmega
    if not w then
        -- heavier kick = heavier spring: pistols / SMGs ~3.6 Hz, rifles ~3 Hz, snipers / shotguns ~2.4 Hz
        local pitch = rk.Pitch or 6
        w = 2 * math.pi * math.clamp(3.7 - pitch * 0.13, 2.2, 3.7)
        self.KickOmega = w
    end
    local s = self.Spring or { back = { 0, 0 }, up = { 0, 0 }, pitch = { 0, 0 }, roll = { 0, 0 }, yaw = { 0, 0 } }
    self.Spring = s
    local v = w / 0.62 * strength -- impulse that peaks at about the target amount
    local jitter = isShot and (0.85 + math.random() * 0.3) or 1
    s.back[2] += (rk.Back or 0.08) * v * jitter
    s.up[2] += (rk.Up or 0.03) * v * (isShot and 1 or -0.6)
    s.pitch[2] += (rk.Pitch or 6) * v * (isShot and jitter or 0.35)
    s.roll[2] += (rk.Roll or 2) * v * (self.RollSign or 1) * (isShot and 1 or 0.5)
    if isShot then s.yaw[2] += (rk.Roll or 2) * 0.6 * v * (math.random() * 2 - 1) end
end

-- a landed melee hit (owner 2026-10-07: melee "hits"): hit-stop + a knock back through the arms
function ViewmodelRig:MeleeHit(strength: number?)
    local k = strength or 1
    self.HitStopUntil = os.clock() + 0.055 * k
    self:Jolt(0.45 * k, false)
end

function ViewmodelRig:StepSpring(dt: number): CFrame
    local s = self.Spring
    if not s then return CFrame.identity end
    local w = self.KickOmega or 18
    local K, C = w * w, 2 * SPRING_ZETA * w
    local steps = math.clamp(math.ceil(dt / (1 / 240)), 1, 8)
    local h = dt / steps
    local live = false
    for _, c in pairs(s) do
        for _ = 1, steps do
            c[2] += (-K * c[1] - C * c[2]) * h
            c[1] += c[2] * h
        end
        if math.abs(c[1]) > 1e-4 or math.abs(c[2]) > 1e-3 then live = true else c[1], c[2] = 0, 0 end
    end
    if not live then return CFrame.identity end
    return CFrame.new(0, s.up[1], s.back[1]) * CFrame.Angles(R(s.pitch[1]), R(s.yaw[1]), R(s.roll[1]))
end

-- A shot: slide cycles (locks back on the last round), trigger, flash, shell.
function ViewmodelRig:Fire(isLastRound: boolean?)
    if not self.Def then return end
    -- reloading / equipping: no visual shot (an inspect is simply cancelled by shooting)
    if self.Anim and self.AnimName ~= "Fire" and self.AnimName ~= "Inspect" then return end
    self:Play("Fire")
    if self.Def.Revolver then self.CylTarget = (self.CylTarget or 0) + math.rad(60) end
    self.PendingLock = isLastRound == true and not self.Def.NoBoltLock
    -- each shot kicks the recoil spring (Update): a hard snap back, a little overshoot forward, settle
    self.RollSign = (math.random() < 0.5) and -1 or 1
    self:Jolt(1, true)
    self:MuzzleFlash()
    self:GloveBurst("Fire")
    local skinShot = self.SkinFxKind and SkinFX.GunFire(self.GunId) -- (a skinned gun's own full shot replaces the base)
    if not skinShot and not self:PlaySound("Fire") then
        pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayWeaponFire(self.Weapon and self.Weapon.Class, self.GunId) end)
    end
    if self.SkinFxKind then
        self.LastShotT = os.clock()
        self.FlashRoll = math.random() * math.pi * 2
        if self.SkinFxKind == "Infernal" then
            self.FlashRoll = (math.random() - 0.5) * 0.6 -- (the tongue licks out roughly level)
            self.SkinHeat = math.min(1, (self.SkinHeat or 0) + 0.075) -- sustained fire heats the gun
        end
        if self.SkinSet and self.SkinSet.OnFire then pcall(self.SkinSet.OnFire, self, SkinFX.H, isLastRound == true) end
        if not skinShot then pcall(SkinFX.Sound, "Fire") end
    end
end

local JOLTS = { MagIn = 0.32, SlideRelease = 0.4, BoltForward = 0.3, PumpForward = 0.42, PumpBack = 0.25, BreakClose = 0.5,
    CylClose = 0.3, ShellIn = 0.12, ShellsIn = 0.15, BreakOpen = 0.2, MagOut = 0.12 }
-- data (optional, Update 5 INSPECTS): the event's third field -- "Sound" { Id, Volume?, Pitch? } plays a one-shot,
-- "Emit" { Name, Count? } bursts every ParticleEmitter of that name in the weapon; any event reaches the skin's set
-- (set.OnEvent(rig, name, H, data)) and the skin itself (skin.OnEvent(rig, name, data)) -- the beats Present / Tilt /
-- Flip / Settle of the class inspects included
function ViewmodelRig:FireEvent(name: string, data: any?)
    if self.OnEvent then task.spawn(self.OnEvent, name) end -- e.g. melee "Swing" = the moment the hit lands
    if JOLTS[name] and self.Def and not self.Def.IsMelee then self:Jolt(JOLTS[name]) end
    if self.SkinSet and self.SkinSet.OnEvent then pcall(self.SkinSet.OnEvent, self, name, SkinFX.H, data) end -- (MagOut / MagIn / Pump / Swing ...)
    if self.Skin and type(self.Skin.OnEvent) == "function" then pcall(self.Skin.OnEvent, self, name, data) end
    if name == "Sound" and type(data) == "table" and data.Id then
        if self.Visible == false then return end
        local snd = Instance.new("Sound")
        snd.SoundId = (type(data.Id) == "number") and ("rbxassetid://" .. data.Id) or tostring(data.Id)
        snd.Volume = data.Volume or 0.5
        snd.PlaybackSpeed = data.Pitch or 1
        snd.SoundGroup = game:GetService("SoundService"):FindFirstChild("AimRngMix_Weapons")
        snd.Parent = self.SoundFolder
        snd:Play()
        Debris:AddItem(snd, math.max(2, (data.Life or 6)))
        return
    elseif name == "Emit" and type(data) == "table" and data.Name then
        if self.Visible == false or not self.Gun then return end
        for _, d in ipairs(self.Gun:GetDescendants()) do
            if d:IsA("ParticleEmitter") and d.Name == data.Name then d:Emit(data.Count or 10) end
        end
        return
    end
    if name == "Eject" then
        self:EjectShell()
    elseif name == "SlideRelease" then
        self.SlideLocked = false
        self:PlaySound("SlideRelease")
    elseif (name == "MagOut" or name == "MagIn") and self.SkinFxKind then
        self:PlaySound(name) -- (the gun's real reload sound; the set adds a low accent under it -- v2 replaced it)
        pcall(SkinFX.Sound, name)
        if name == "MagIn" then
            for _, pe in ipairs(self.SkinEmitters or {}) do if pe:IsA("ParticleEmitter") and pe.Name == "SkinSparkle" then pe:Emit(5) end end
        end
    elseif name == "Equip" then
        if not self:PlaySound("Equip") then
            pcall(function() require(Shared:WaitForChild("SoundHelper")).Play("Equip") end)
        end
    else
        self:PlaySound(name)
    end
end

-- ==================== per-frame ====================
-- force = re-apply even when unchanged (SetWeapon on a hidden rig: the new model starts shown)
function ViewmodelRig:SetVisible(on: boolean, force: boolean?)
    if self.Visible == on and not force then return end
    self.Visible = on
    for _, d in ipairs(self.Model:GetDescendants()) do
        -- (a Decal / Texture has its OWN LocalTransparencyModifier -- the part's never reaches it. 2026-11-09, owner: Kirameki's
        -- BANG! / star stickers hung in the air beside you in the third-person hub while the rest of the gun was hidden)
        if (d:IsA("BasePart") and d ~= self.ArmsRoot) or d:IsA("Decal") then d.LocalTransparencyModifier = on and 0 or 1 end
    end
    for _, pe in ipairs(self.SkinEmitters or {}) do pe.Enabled = on end -- (particles ignore the transparency modifier)
    for _, sd in ipairs({ "R", "L" }) do -- (nor do beams / holo displays / light rays)
        if self.HandDress then GloveFX.SetShown(self.HandDress[sd], on) end
        if self.ArmDress then GloveFX.SetShown(self.ArmDress[sd], on) end
    end
    if self.SkinShown then self:SkinShown(on) end
end

-- Bend a hand's fingers toward a named shape (smoothed), with the right index finger following the trigger.
function ViewmodelRig:PoseFingers(side: string, poseName: string, dt: number, trigger: number)
    local s = self.Sides[side]
    local shapes = ArmsData.Hands
    local target = shapes[poseName] or shapes.Open
    local cur = self.Curl[side]
    local k = math.clamp(dt * 14, 0, 1)
    for finger, joints in pairs(s.Curl) do
        local want = target[finger] or shapes.Open[finger]
        if side == "R" and finger == "Index" and trigger > 0 and shapes.TriggerPull.Index then
            local pull = shapes.TriggerPull.Index
            want = { want[1] + (pull[1] - want[1]) * trigger, want[2] + (pull[2] - want[2]) * trigger, want[3] + (pull[3] - want[3]) * trigger }
        end
        cur[finger] = cur[finger] or { 0, 0, 0, 0, 0 }
        -- thumbs also swing sideways (ThumbSpread) and roll (ThumbTwist): degrees at the base joint,
        -- tapering toward the tip -- enough freedom to lay a thumb flat along a gun's frame
        local isThumb = finger == "Thumb"
        cur[finger][4] = cur[finger][4] + ((isThumb and target.ThumbSpread or 0) - cur[finger][4]) * k
        cur[finger][5] = cur[finger][5] + ((isThumb and target.ThumbTwist or 0) - cur[finger][5]) * k
        for i, j in ipairs(joints) do
            local a = cur[finger][i] + ((want[i] or 0) - cur[finger][i]) * k
            cur[finger][i] = a
            local taper = ({ 1, 0.7, 0.4 })[i]
            j.Bone.Transform = CFrame.fromAxisAngle(j.Axis, R(a) * j.Sign)
                * CFrame.fromAxisAngle(Vector3.yAxis, R(cur[finger][4] * taper) * j.Sign)
                * CFrame.fromAxisAngle(Vector3.zAxis, R(cur[finger][5] * taper))
        end
    end
end

-- Hand-posed grip (WeaponRigs Guns.<id>.GripPose, authored in Blender): gun-space joint positions per hand.
-- Returns the world wrist CFrame the pose wants.
function ViewmodelRig:GripPoseWrist(side: string, gunRoot: CFrame, gs: number): CFrame?
    local pose = self.Def.GripPose and self.Def.GripPose[side]
    if not pose then return nil end
    local target = PoseFrame(pose.Wrist * gs, pose.Index[1] * gs, pose.Pinky[1] * gs)
    return gunRoot * target * self.Sides[side].PoseRest:Inverse()
end

-- Aim each finger bone at the next posed joint, blended (w) over whatever PoseFingers already set.
function ViewmodelRig:ApplyGripPoseFingers(side: string, gunRoot: CFrame, w: number, trigger: number, mapDir: (Vector3) -> Vector3)
    local pose = self.Def.GripPose and self.Def.GripPose[side]
    if not pose or w <= 0 then return end
    local s = self.Sides[side]
    for finger, bones in pairs(s.Fingers) do
        local pts = pose[finger]
        if pts then
            for i, bone in ipairs(bones) do
                local before = bone.Transform
                AimBone(bone, s.ChildLocal[finger][i], mapDir(gunRoot:VectorToWorldSpace(pts[i + 1] - pts[i])))
                local posed = bone.Transform
                -- trigger finger: squeeze a little further when firing
                if side == "R" and finger == "Index" and trigger > 0 and i > 1 then
                    local j = s.Curl.Index[i]
                    posed = posed * CFrame.fromAxisAngle(j.Axis, R(18 * trigger) * j.Sign)
                end
                bone.Transform = (w >= 1) and posed or before:Lerp(posed, w)
            end
        end
    end
end

-- Bolt / slide offset in gun space: back by SlideTravel * slide and, for bolt-actions (def.BoltLift = degrees),
-- turned about the bolt's own axis (Points.BoltAxis) by BoltLift * lift.
function ViewmodelRig:BoltOffset(slide: number, lift: number?): CFrame
    local def, gs = self.Def, self.GunScale or 1
    local cf = CFrame.new(-(def.SlideTravel or 0) * gs * slide, 0, 0)
    if def.BoltLift and lift and lift > 0 then
        local axis = def.Points.BoltAxis
        local a = CFrame.new(0, (axis and axis.Position.Y or 0) * gs, (axis and axis.Position.Z or 0) * gs)
        cf = cf * a * CFrame.Angles(R(def.BoltLift * lift), 0, 0) * a:Inverse()
    end
    return cf
end

-- Draw the arm rig at k x its normal size (see the FOV notes in Update). Bones can't be squashed like the
-- gun's parts, so the arms scale uniformly instead -- at the mapped depth that keeps their on-screen size.
function ViewmodelRig:SetArmScale(k: number)
    if math.abs((self.ArmScale or 1) - k) < 0.002 then return end
    self.ArmScale = k
    self.Arms:ScaleTo(self.ArmsBaseScale * k)
    for _, ap in ipairs(self.ArmParts) do ap.ScaledOffset = CFrame.new(ap.Offset.Position * k) * ap.Offset.Rotation end
    for _, s in pairs(self.Sides) do
        s.ElbowLocal = s.Elbow.Position
        s.WristLocal = s.Wrist.Position
        s.L1 = s.ElbowLocal.Magnitude
        s.L2 = s.WristLocal.Magnitude
    end
end

function ViewmodelRig:SolveArm(side: string, wristTarget: CFrame, camCF: CFrame, fovScale: number?)
    local s = self.Sides[side]
    local S = s.Shoulder.TransformedWorldCFrame.Position
    local toT = wristTarget.Position - S
    -- Soft reach: a nearly straight arm makes the elbow swing wildly at the smallest hand movement (recoil),
    -- so past SoftReach of full length the arm keeps a slight bend and the shoulder eases toward the hand
    -- to make up the difference (like a real shoulder reaching forward).
    local lmax = s.L1 + s.L2
    local d0 = toT.Magnitude
    local soft = (ArmsData.SoftReach or 0.85) * lmax
    local shoulderShift = Vector3.zero
    if d0 > soft then
        local room = lmax * 0.995 - soft
        local dSoft = soft + room * (1 - math.exp(-(d0 - soft) / room))
        shoulderShift = toT.Unit * (d0 - dSoft)
        S += shoulderShift
        toT = wristTarget.Position - S
    end
    local d = math.clamp(toT.Magnitude, math.abs(s.L1 - s.L2) + 1e-3, lmax * 0.999)
    local dir = toT.Unit
    local a = (s.L1 * s.L1 - s.L2 * s.L2 + d * d) / (2 * d)
    local h = math.sqrt(math.max(0, s.L1 * s.L1 - a * a))
    local pole = camCF:PointToWorldSpace(DepthScale(s.Pole, fovScale or 1)) - S
    pole = pole - dir * pole:Dot(dir)
    if pole.Magnitude < 1e-4 then pole = camCF.RightVector end
    local E = S + dir * a + pole.Unit * h
    local W = S + dir * d
    AimBone(s.Shoulder, s.ElbowLocal, E - S)
    if shoulderShift.Magnitude > 0 then
        local restWorld = ParentWorld(s.Shoulder) * s.Shoulder.CFrame
        s.Shoulder.Transform = CFrame.new(restWorld:VectorToObjectSpace(shoulderShift)) * s.Shoulder.Transform
    end
    AimBone(s.Elbow, s.WristLocal, W - E)
    -- Forearm roll: the rig has no twist bone, so a hand turned palm-up/down would wring the sleeve at the
    -- wrist like a candy wrapper. Hand most of the turn to the forearm (a real forearm twists along its length).
    do
        local axis = (W - E).Unit
        local restW = s.Elbow.TransformedWorldCFrame * s.Wrist.CFrame
        local function Flat(v: Vector3): Vector3 return v - axis * v:Dot(axis) end
        local a, b = Flat(restW.XVector), Flat(wristTarget.XVector)
        if a.Magnitude < 0.3 or b.Magnitude < 0.3 then a, b = Flat(restW.ZVector), Flat(wristTarget.ZVector) end
        if a.Magnitude > 1e-3 and b.Magnitude > 1e-3 then
            local ang = math.atan2(a.Unit:Cross(b.Unit):Dot(axis), a.Unit:Dot(b.Unit))
            -- keep the roll continuous: atan2 wraps at +-180 deg, which spun the forearm half a turn in one frame
            -- whenever a hand's turn crossed that line (left arm during rifle inspects)
            if s.LastRoll then ang += math.round((s.LastRoll - ang) / (2 * math.pi)) * 2 * math.pi end
            s.LastRoll = ang
            local eCF = s.Elbow.TransformedWorldCFrame
            s.Elbow.Transform = s.Elbow.Transform * CFrame.fromAxisAngle(eCF:VectorToObjectSpace(axis), ang * (ArmsData.ForearmRoll or 0.85))
        end
    end
    local restWorld = s.Elbow.TransformedWorldCFrame * s.Wrist.CFrame
    s.Wrist.Transform = restWorld:ToObjectSpace(CFrame.new(restWorld.Position) * wristTarget.Rotation)
end

-- camCF: this frame's camera. sway: optional extra CFrame (bob, recoil) applied to the gun hold.
-- fov: the camera's current FieldOfView. Everything is laid out as seen at WeaponRigs.ViewmodelFOV, then
-- depth-mapped (see DepthMap) into the real camera, so the arms and gun look identical at any FOV.
function ViewmodelRig:Update(dt: number, camCF: CFrame, sway: CFrame?, fov: number?)
    if not self.Def then return end
    local def = self.Def
    local refFov = WeaponRigs.ViewmodelFOV or 90
    -- k = the viewmodel's uniform scale for this FOV (see DepthScale): > 1 for wider FOVs, < 1 for ADS zoom
    local k = math.tan(math.rad(math.clamp(fov or refFov, 5, 130)) / 2) / math.tan(math.rad(refFov) / 2)
    -- a rigid scale over-enlarges the near arms at wide FOVs, so only part of the way there: the gun still
    -- reads a little smaller at 120 (as it does in most shooters), but the hands never leave it
    if k > 1 and not EXACT_FOV then k = k ^ (WeaponRigs.WideFovCompensation or 0.6) end
    -- block arms: the owner's call -- FOV changes ONLY the camera (the viewmodel just looks more / less zoomed,
    -- like the world). Every gun is placed so both hands are still on screen at the lowest FOV (70).
    if EXACT_FOV then k = 1 end
    VM_PIVOT_Z = (self.HoldPos and self.HoldPos.Z < -0.2) and self.HoldPos.Z or -1
    self.FovScale = k
    local function Map(cf: CFrame): CFrame return (DepthMap(cf, camCF, k)) end
    local function MapDir(v: Vector3): Vector3 return v end -- a uniform scale keeps directions
    local function MapPoint(p: Vector3): Vector3 return camCF:PointToWorldSpace(DepthScale(camCF:PointToObjectSpace(p), k)) end
    -- Hands are rigid (scaled with the arm rig, see SetArmScale): each is placed with its grip point (HandFrame
    -- origin, where the gun's grip sits in the hand) on the mapped spot, so it sits on the gun at any FOV.
    local function MapHand(side: string, wristV: CFrame): CFrame
        local a = self.Sides[side].HandFrame.Position
        return CFrame.new(MapPoint(wristV:PointToWorldSpace(a)) - wristV:VectorToWorldSpace(a * self.ArmScale)) * wristV.Rotation
    end

    -- advance the current animation and fire its events
    local ch = {}
    if self.Anim then
        -- (HIT-STOP: a landed melee hit freezes the swing for a few frames, so the blow reads as connecting)
        local stop = self.HitStopUntil and os.clock() < self.HitStopUntil
        self.AnimTime += dt * (self.AnimSpeed or 1) * (stop and 0.06 or 1)
        local t = self.AnimTime
        local smooth = self.Def and self.Def.IsMelee or false
        for name, keys in pairs(self.Anim.Tracks) do ch[name] = SampleTrack(keys, t, smooth) end
        local events = self.Anim.Events or {}
        while self.EventIndex <= #events and events[self.EventIndex][1] <= t do
            self:FireEvent(events[self.EventIndex][2], events[self.EventIndex][3])
            self.EventIndex += 1
        end
        if self.AnimName == "Fire" and self.PendingLock and t >= 0.035 then
            self.SlideLocked = true
            self.PendingLock = false
        end
        if t >= self.Anim.Length then
            self.Anim = nil
            self.AnimName = nil
            self.Model:SetAttribute("Anim", nil)
        end
    end

    -- blend the whole-weapon channel in over BLEND_TIME from where the last animation left it
    if self.BlendFrom then
        self.BlendT = (self.BlendT or 0) + dt
        local k = math.clamp(self.BlendT / 0.14, 0, 1)
        k = k * k * (3 - 2 * k)
        ch.Gun = self.BlendFrom:Lerp(ch.Gun or CFrame.identity, k)
        if k >= 1 then self.BlendFrom = nil end
    end
    self.LastGunCh = ch.Gun or CFrame.identity
    if self.CylTarget then self.CylAngle = (self.CylAngle or 0) + (self.CylTarget - (self.CylAngle or 0)) * math.clamp(dt * 30, 0, 1) end

    -- procedural recoil kick (layered on top of any animation)
    local kick = self:StepSpring(dt) -- (RECOIL SPRING: shots + handling jolts)

    -- Studio-only tuning: Player attribute DevMeleeHold = "px,py,pz,pitch,yaw,roll" overrides a melee's hold live
    if def.IsMelee and IS_STUDIO then
        local h = (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:GetAttribute("DevMeleeHold"))
        if h ~= self.DevHoldStr then
            self.DevHoldStr = h
            local n = {}
            for v in string.gmatch(tostring(h or ""), "[^,]+") do table.insert(n, tonumber(v) or 0) end
            if #n >= 6 then
                self:ResolvePlacement()
                self.HoldPos = Vector3.new(n[1], n[2], n[3])
                self.HoldRot = CFrame.Angles(R(n[4]), R(n[5]), R(n[6]))
                if n[7] then self:SpinGrip(n[7]) end -- 7th value: hand spin around the handle (degrees)
            else
                self:ResolvePlacement()
            end
        end
    end
    -- Studio-only tuning: Player attribute DevGunLift = "x,y,z" (camera space) shifts a gun's hold live, on top of BlockLift
    if IS_STUDIO and game:GetService("Players").LocalPlayer then -- (melee too: the spear's hold was tuned with it)
        local lp0 = game:GetService("Players").LocalPlayer
        local h = tostring(lp0:GetAttribute("DevGunLift")) .. "|" .. tostring(lp0:GetAttribute("DevPresent")) .. "|" .. tostring(lp0:GetAttribute("DevFaceFlip")) .. "|" .. tostring(lp0:GetAttribute("DevFaceRoll"))
        if h ~= self.DevLiftStr then
            self.DevLiftStr = h
            self:ResolvePlacement()
            local n = {}
            for v in string.gmatch(tostring(lp0:GetAttribute("DevGunLift") or ""), "[^,]+") do table.insert(n, tonumber(v) or 0) end
            if #n == 3 then self.HoldPos += Vector3.new(n[1], n[2], n[3]) end
            if #n == 6 then -- "x,y,z,pitch,yaw,roll": also turn the gun (degrees, on top of its hold)
                self.HoldPos += Vector3.new(n[1], n[2], n[3])
                self.HoldRot = CFrame.Angles(0, R(n[5]), 0) * CFrame.Angles(R(n[4]), 0, R(n[6])) * self.HoldRot
            end
        end
    end
    local holdRot = self.HoldRot
    local gs = self.GunScale or 1
    local gv = self.GV or Vector3.one * gs
    local function G(cf: CFrame): CFrame -- a gun-space CFrame at this gun's Scale (+ Length)
        return (gs == 1 and gv.X == 1) and cf or (CFrame.new(cf.Position * gv) * cf.Rotation)
    end
    local gripR = G(self.Pt.GripR)
    -- (gunRoot and every target below are at the reference FOV; Map / DepthMap convert to the real camera)
    local gunRoot = camCF * CFrame.new(self.HoldPos) * (sway or CFrame.identity) * kick
        * (ch.Gun or CFrame.identity) * holdRot * FORWARD_ROT * CFrame.new(-gripR.Position)
    -- (0.93, owner: "the hand bugs through the sleeve ... make the hand not animated, it should just be the melee thats
    -- inspecting"): a melee's fist keeps its REST orientation; it only follows where the grip moves, so the weapon turns
    -- in the hand and the fist never twists through the sleeve
    self.MeleeRestGrip = def.IsMelee and (camCF * CFrame.new(self.HoldPos) * (sway or CFrame.identity) * kick * holdRot * FORWARD_ROT) or nil
    -- (Update 5 INSPECTS) the gun's REST root (no animation): the support cradle + the arm follow measure against it
    local restRoot = (not def.IsMelee and (ch.LCradle or ch.ArmFollowR or ch.ArmFollowL))
        and (camCF * CFrame.new(self.HoldPos) * (sway or CFrame.identity) * kick * holdRot * FORWARD_ROT * CFrame.new(-gripR.Position)) or nil
    -- ArmRoll (degrees): turn the weapon about the FOREARM axis (shoulder -> hand), like rotating your arm to
    -- look at a blade. The hand keeps its natural angle on the forearm, so inspects never bend the wrist.
    if ch.ArmRoll and math.abs(ch.ArmRoll) > 0.01 then
        local gp = (gunRoot * gripR).Position
        local sh = (camCF * self.RootOff).Position
        local axis = gp - sh
        if axis.Magnitude > 1e-3 then
            gunRoot = CFrame.new(gp) * CFrame.fromAxisAngle(axis.Unit, R(ch.ArmRoll)) * CFrame.new(-gp) * gunRoot
        end
    end
    -- BladeRoll (degrees, 0.97 VALORANT INSPECT): turn the weapon about its OWN handle -> tip axis through the grip -- a
    -- flip in place that shows the other face (ArmRoll turns about the forearm, which in the diagonal hold swung the blade
    -- in a wide arc off the screen)
    if ch.BladeRoll and math.abs(ch.BladeRoll) > 0.01 then
        local gp = (gunRoot * gripR).Position
        local axis = gunRoot:VectorToWorldSpace(Vector3.yAxis)
        gunRoot = CFrame.new(gp) * CFrame.fromAxisAngle(axis.Unit, R(ch.BladeRoll)) * CFrame.new(-gp) * gunRoot
    end

    -- gun parts
    local parts, cfs = {}, {}
    local slide = self.SlideLocked and 1 or (ch.Slide or 0)
    if self.SlideLocked and ch.Slide then slide = math.max(slide, ch.Slide) end
    if self.AnimName == "ReloadEmpty" then slide = ch.Slide or slide end
    local trigger = ch.Trigger or 0
    local frameF
    -- skin wings: open while inspecting (ease in over 0.45s, close over the last 0.45s)
    local open = 0
    if self.HasHinges or (self.HaloParts and #self.HaloParts > 0) or self.SkinFxKind == "Infernal" or self.SkinSet then
        local want = 0
        if self.AnimName == "Inspect" and self.Anim then
            want = math.clamp(math.min(self.AnimTime / 0.45, (self.Anim.Length - self.AnimTime) / 0.45), 0, 1)
        end
        self.WingOpen = (self.WingOpen or 0) + (want - (self.WingOpen or 0)) * math.clamp(dt * 14, 0, 1)
        open = self.WingOpen * self.WingOpen * (3 - 2 * self.WingOpen)
    end
    -- skin animation state for this frame (SkinFX.AnimOffset)
    local skinSt
    if self.HasSkinAnim then
        local nowC = os.clock()
        local sinceShot = self.LastShotT and (nowC - self.LastShotT) or 99
        local sweep = nil
        if self.SweepT0 and nowC >= self.SweepT0 then
            sweep = (nowC - self.SweepT0) / 0.6
            if sweep >= 1 then self.SweepT0 = nil; sweep = nil end
        end
        skinSt = { Open = open, Spin = 1 + 2.5 * math.exp(-sinceShot * 6), Flash = math.clamp(sinceShot / 0.06, 0, 1), FlashRoll = self.FlashRoll or 0,
            Sweep = sweep, Halo = open, Now = nowC }
        if self.SkinFxKind == "Infernal" then
            -- heat cools once you stop firing; the vents smoke while it does
            local h = self.SkinHeat or 0
            if sinceShot > 0.3 then h = math.max(0, h - dt * 0.3) end
            self.SkinHeat = h
            skinSt.Heat = 0.08 + 0.92 * h
            skinSt.Jaw = (sinceShot < 0.03) and (sinceShot / 0.03) or math.max(0, 1 - (sinceShot - 0.03) / 0.12)
            skinSt.Eye = open
            skinSt.Souls = SkinFX.Souls()
            skinSt.SinceEquip = self.IgniteT0 and (nowC - self.IgniteT0) or 99
            local rate = (sinceShot > 0.25 and h > 0.2) and (28 * h) or 0
            if self.SmokeRate ~= rate then
                self.SmokeRate = rate
                for _, pe in ipairs(self.SkinEmitters or {}) do if pe.Name == "SkinHeatSmoke" then pe.Rate = rate end end
            end
        elseif self.SkinSet then
            -- SkinSets: the generic moments every set can read, then the set's own Drive fills its keys
            skinSt.Inspect = open
            skinSt.SinceShot = sinceShot
            skinSt.SinceEquip = self.IgniteT0 and (nowC - self.IgniteT0) or 99
            skinSt.SinceInspect = self.InspectT0 and (nowC - self.InspectT0) or 99
            local an = self.AnimName
            skinSt.Reload = (an and an:find("Reload") and self.Anim and self.Anim.Length > 0) and math.clamp(self.AnimTime / self.Anim.Length, 0, 1) or 0
            skinSt.Streak = SkinFX.KillStreak()
            skinSt.Ammo = self.AmmoFrac or 1
            skinSt.AmmoCount, skinSt.AmmoMax = self.AmmoCount, self.AmmoMax
            if self.SkinSet.Drive then
                local ok, err = pcall(self.SkinSet.Drive, self, skinSt, dt, nowC, SkinFX.H)
                if not ok and not self.SkinDriveWarned then self.SkinDriveWarned = true; warn("[ViewmodelRig] skin drive: " .. tostring(err)) end
            end
        end
        -- (Update 5 INSPECTS) the playing animation's own channels reach the skin: every number track the rig doesn't use
        -- itself is st[<name>] (part drives HingeDrive / ShiftDrive / TurnDrive / GlowDrive / ShowDrive ... follow it)
        if self.Anim then
            for name, v in pairs(ch) do
                if type(v) == "number" and not Inspects.CHANNELS[name] then skinSt[name] = v end
            end
        end
        skinSt.Anim, skinSt.AnimT = self.AnimName, self.AnimTime
        -- materialise: the gun fades in over 0.35 s as it's drawn (with the light sweep running over it)
        if self.EquipT0 then
            local k = math.clamp((nowC - self.EquipT0) / 0.35, 0, 1)
            if self.Visible ~= false then
                for _, gp in pairs(self.GunParts) do
                    if not (gp.Anim and (gp.Anim.Flash or gp.Anim.Sweep or gp.Anim.Halo)) then gp.Part.LocalTransparencyModifier = 1 - k end
                end
            end
            if k >= 1 then self.EquipT0 = nil end
        end
    end
    for name, gp in pairs(self.GunParts) do
        local cf
        if name == "Slide" or name == "Bolt" then
            cf = gunRoot * self:BoltOffset(slide, ch.BoltLift) * gp.Rest
        elseif name == "Cylinder" and def.Points.CylAxis then
            -- revolver: turned a chamber per shot about its own axis, swung out about the crane for reloads
            local crane, axis = G(def.Points.Crane or def.Points.CylAxis).Position, G(def.Points.CylAxis).Position
            local swing = CFrame.new(crane) * CFrame.Angles(R((def.CylSwing or -90) * (ch.CylSwing or 0)), 0, 0) * CFrame.new(-crane)
            local spin = CFrame.new(axis) * CFrame.Angles(self.CylAngle or 0, 0, 0) * CFrame.new(-axis)
            cf = gunRoot * swing * spin * gp.Rest
        elseif name == "Pump" then
            cf = gunRoot * CFrame.new(-(def.PumpTravel or 0) * gs * (ch.Pump or 0), 0, 0) * gp.Rest
        elseif name == "Barrel" then
            cf = gunRoot * gp.Rest * CFrame.new(-def.SlideTravel * gs * 0.35 * slide, 0, 0)
        elseif name == "Break" and def.Points.Hinge then
            -- break-action barrels (0.48 double barrel): hinge down about Points.Hinge for reloads
            local hinge = G(def.Points.Hinge).Position
            cf = gunRoot * CFrame.new(hinge) * CFrame.Angles(0, 0, R((def.BreakAngle or -38) * (ch.Break or 0))) * CFrame.new(-hinge) * gp.Rest
        elseif name == "Trigger" then
            local pivot = G(self.Pt.TriggerPivot or CFrame.identity)
            cf = gunRoot * pivot * CFrame.Angles(0, 0, R((def.TriggerAngle or -15) * trigger)) * pivot:Inverse() * gp.Rest
        elseif name == "Magazine" or name == "MagGlow" or gp.Follow == "Magazine" then
            cf = nil -- placed after the left hand is solved (it may be riding in that hand; skin decorations with
            -- Follow = "Magazine" ride it too -- 2026-10-06, the Neko PPSh's cat-face drum)
        elseif gp.Follow == "Break" and def.Points.Hinge then
            -- (2026-10-06) skin decoration on break-action barrels: swings open with them on a reload (and still animates)
            local hinge = G(def.Points.Hinge).Position
            local base = gunRoot * CFrame.new(hinge) * CFrame.Angles(0, 0, R((def.BreakAngle or -38) * (ch.Break or 0))) * CFrame.new(-hinge)
            if gp.Anim and skinSt then
                local off, tr, col = SkinFX.AnimOffset(gp.Anim, skinSt.Now, skinSt)
                cf = base * off * gp.Rest
                if tr and gp.LastTr ~= tr then gp.Part.Transparency = tr; gp.LastTr = tr end
                if col and gp.LastCol ~= col then gp.Part.Color = col; gp.LastCol = col end
            else
                cf = base * gp.Rest
            end
        elseif gp.Follow == "Slide" then
            -- skin decoration on the slide: moves with it (and still animates)
            local base = gunRoot * self:BoltOffset(slide, ch.BoltLift)
            if gp.Anim and skinSt then
                local off, tr, col, sc = SkinFX.AnimOffset(gp.Anim, skinSt.Now, skinSt)
                gp.ScaleNow = sc -- (SKINS V3 ScaleDrive: resized in Squash below)
                cf = base * off * gp.Rest
                if tr and gp.LastTr ~= tr then gp.Part.Transparency = tr; gp.LastTr = tr end
                if col and gp.LastCol ~= col then gp.Part.Color = col; gp.LastCol = col end
            else
                cf = base * gp.Rest
            end
        elseif gp.Anim and skinSt then
            local off, tr, col, sc = SkinFX.AnimOffset(gp.Anim, skinSt.Now, skinSt)
            gp.ScaleNow = sc -- (SKINS V3 ScaleDrive: resized in Squash below)
            cf = gunRoot * off * gp.Rest
            if tr and gp.LastTr ~= tr then gp.Part.Transparency = tr; gp.LastTr = tr end
            if col and gp.LastCol ~= col then gp.Part.Color = col; gp.LastCol = col end
        else
            cf = gunRoot * gp.Rest
        end
        if cf then
            local mapped, f = DepthMap(cf, camCF, k)
            Squash(gp, gp.ScaleNow and f * gp.ScaleNow or f)
            table.insert(parts, gp.Part); table.insert(cfs, mapped)
            if name == "Frame" then frameF = f end
        end
    end
    -- the Frame's attachments (muzzle, ejection port, mounts...) follow its squash
    if frameF and not (self.PointF and (self.PointF - frameF).Magnitude < 1e-4) then
        self.PointF = frameF
        for name, att in pairs(self.Points) do
            local rest = self.PointRest[name]
            att.CFrame = CFrame.new(rest.Position * frameF) * rest.Rotation
        end
    end

    Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    -- (Update 5, DUAL) the left-hand copy: camera space about its own grip, channels GunL / BladeRollL
    local gunRootL
    if self.GunL and self.HoldRotQL then
        gunRootL = camCF * CFrame.new(self.HoldPosL) * (sway or CFrame.identity) * kick * (ch.GunL or CFrame.identity) * self.HoldRotQL * CFrame.new(-gripR.Position)
        if ch.BladeRollL and math.abs(ch.BladeRollL) > 0.01 then
            local gp = (gunRootL * gripR).Position
            gunRootL = CFrame.new(gp) * CFrame.fromAxisAngle(gunRootL:VectorToWorldSpace(Vector3.yAxis).Unit, R(ch.BladeRollL)) * CFrame.new(-gp) * gunRootL
        end
        local lp, lc = {}, {}
        for _, gp in ipairs(self.GunPartsL) do table.insert(lp, gp.Part); table.insert(lc, Map(gunRootL * gp.Rest)) end
        Workspace:BulkMoveTo(lp, lc, Enum.BulkMoveMode.FireCFrameChanged)
    end

    local sR, sL = self.Sides.R, self.Sides.L
    local knifeGrip = self.KnifeActive and self.Knife
    local rTarget = gunRoot * gripR
    -- hand-posed grip weights: fade to the posed hands whenever an animation isn't driving that hand
    self.PoseW = self.PoseW or { R = 0, L = 0 }
    local blendK = math.clamp(dt * 12, 0, 1)
    local wantR = (not knifeGrip and ch.RHandPose == nil and (ch.RFollowBolt or 0) <= 0.001) and 1 or 0
    local wantL = (ch.LHandPose == nil and (ch.LHand or 0) <= 0.001 and (ch.LFollowMag or 0) <= 0.001) and 1 or 0
    self.PoseW.R += (wantR - self.PoseW.R) * blendK
    self.PoseW.L += (wantL - self.PoseW.L) * blendK
    local wR, wL = self.PoseW.R, self.PoseW.L
    local rWrist = rTarget * sR.HandFrame:Inverse()
    local rPosed = wR > 0.001 and self:GripPoseWrist("R", gunRoot, gs)
    if rPosed then rWrist = rWrist:Lerp(rPosed, wR) end
    -- arms: k x size (SetArmScale), root placed so the right hand's grip point lands on the mapped gun grip;
    -- wrists are then solved onto the gun / free targets
    local armScale = k
    self:SetArmScale(armScale)
    local anchorV = rWrist:PointToWorldSpace(sR.HandFrame.Position)
    -- the body takes the recoil with the gun (translation, plus a share of the pitch), so the arms stay on it
    -- instead of re-bending every shot
    local bodyKick = CFrame.new(kick.Position) * kick.Rotation:Lerp(CFrame.identity, 0.5)
    local rootV = camCF * bodyKick * self.RootOff
    local armsRootCF = CFrame.new(MapPoint(anchorV) + (rootV.Position - anchorV) * armScale) * rootV.Rotation
    local armParts, armCFs = { self.ArmsRoot }, { armsRootCF }
    for _, ap in ipairs(self.ArmParts) do table.insert(armParts, ap.Part); table.insert(armCFs, armsRootCF * ap.ScaledOffset) end
    Workspace:BulkMoveTo(armParts, armCFs, Enum.BulkMoveMode.FireCFrameChanged)
    local rSolve = rWrist
    local onBolt = math.clamp(ch.RFollowBolt or 0, 0, 1)
    if onBolt > 0 and def.Points.BoltKnob then
        -- hand rides the bolt knob (same hand orientation as on the grip, grip point on the knob)
        local knob = gunRoot * self:BoltOffset(slide, ch.BoltLift) * G(def.Points.BoltKnob)
        local onKnob = CFrame.new(knob.Position - rWrist:VectorToWorldSpace(sR.HandFrame.Position)) * rWrist.Rotation
        rSolve = rWrist:Lerp(onKnob, onBolt)
    end
    self:SolveArm("R", MapHand("R", rSolve), camCF, k)
    local lBlend = ch.LHand or 0
    local lPoint = G(self.Pt.GripL)
    local lFree = (ch.LFree and G(ch.LFree)) or lPoint
    local lTargetGun = lPoint:Lerp(lFree, math.clamp(lBlend, 0, 1))
    -- pump-actions: the support hand rides the pump (posed grip and the GripL fallback alike)
    local pumpCF = (def.PumpTravel and (ch.Pump or 0) > 0) and CFrame.new(-def.PumpTravel * gs * ch.Pump, 0, 0) or nil
    local lRoot = pumpCF and (gunRoot * pumpCF) or gunRoot
    if pumpCF then lTargetGun = pumpCF * lTargetGun end
    -- LFollowMag: the left hand rides on the magazine (pulling it out / seating it), so hand-offs between
    -- "magazine in the gun" and "magazine in the hand" (MagHand) never pop.
    local mag = self.GunParts.Magazine
    -- the hand holds the magazine low (MagHoldOffset along the mag, default 0.13) so its top half shows
    -- (2026-10-10, owner: "The hand kind of clips through the mag" on the M249's ammo pouch): a SHORT magazine / box
    -- (half-height along MagAxis under 0.25) is cupped from below -- the fist (~0.14 half-height) stays under its edge;
    -- long magazines keep being gripped round their lower half
    local magInHand = self.MagInHand
    if not magInHand then
        local hold = def.MagHoldOffset or 0.13
        if mag then
            local ax = (def.MagAxis or Vector3.yAxis).Unit
            local s = mag.Size / gs
            local half = 0.5 * (math.abs(ax.X) * s.X + math.abs(ax.Y) * s.Y + math.abs(ax.Z) * s.Z)
            if half < 0.25 then hold = math.max(hold, half + 0.14) end
        end
        magInHand = RotBetween(def.MagAxis or Vector3.yAxis, Vector3.yAxis):Inverse() * CFrame.new(0, hold * gs, 0)
    end
    self.MagInHand = magInHand
    if mag and (ch.LFollowMag or 0) > 0 then
        local magGun = G(ch.Mag or CFrame.identity) * mag.Rest
        lTargetGun = lTargetGun:Lerp(magGun * magInHand:Inverse(), math.clamp(ch.LFollowMag, 0, 1))
    end
    local lTarget = gunRoot * lTargetGun
    -- (Update 5 INSPECTS) LFreeCam: a CAMERA-space spot for the free support hand (a one-handed inspect parks it below the
    -- screen wherever the gun turns; LFree is gun space and swung round with the gun)
    if ch.LFreeCam and lBlend > 0 then lTarget = (gunRoot * lPoint):Lerp(camCF * ch.LFreeCam, math.clamp(lBlend, 0, 1)) end
    local lWrist = lTarget * sL.HandFrame:Inverse()
    local lPosed = wL > 0.001 and self:GripPoseWrist("L", lRoot, gs)
    if lPosed then lWrist = lWrist:Lerp(lPosed, wL) end
    local oneHand = def.OneHanded or (self.Block ~= nil and def.BlockOneHand)
    local lIn = math.clamp(math.max(lBlend, ch.LFollowMag or 0), 0, 1) -- how far an animation has brought the left hand in
    self.LInNow = lIn -- (Update 6 pass 2: the steep support shoulder is a rest-hold thing -- PlaceBlockArm fades it out)
    if oneHand then
        -- one-handed (melee; pistols with block arms): the left hand rests out of view unless an animation
        -- brings it in (reloads: LHand / LFollowMag)
        local rest = camCF * bodyKick * (def.LeftRest or CFrame.new(-0.55, -1.6, -0.35))
        -- Rivals: with a melee out, the free arm stays in view at the bottom-left, pointing forward
        if self.Block and ArmsData.Block.Rivals and def.IsMelee then rest = camCF * bodyKick * CFrame.new(-0.6, -0.8, -1.2) end -- (0.93: lower + wider, out of the slashes' path; 0.97 a touch up: its sleeve shows)
        lWrist = (lIn > 0.001) and rest:Lerp(lWrist, lIn) or rest
    end
    self:SolveArm("L", MapHand("L", lWrist), camCF, k)
    if self.Block then
        local off = self.BlockOff or { R = Vector3.zero, L = Vector3.zero }
        local offR, offL = off.R, off.L
        if IS_STUDIO then -- live tuning: Player attribute DevBlock = "lx,ly,lz,rx,ry,rz" (gun space, added)
            local t = {}
            for v in string.gmatch(tostring((game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:GetAttribute("DevBlock")) or ""), "[^,]+") do table.insert(t, tonumber(v) or 0) end
            if #t == 6 then offL += Vector3.new(t[1], t[2], t[3]); offR += Vector3.new(t[4], t[5], t[6]) end
        end
        local onGripL = oneHand and 0 or (1 - lIn) -- the measured offset only while the hand is on its grip
        -- right hand: fixed to the grip (dropped a little down the grip, below the slide / receiver)
        local rHandCF = nil
        if onBolt <= 0.01 then
            -- squared up with the gun (following the grip's slant read as a twisted hand); offR is gun space
            rHandCF = Map(CFrame.new((gunRoot * gripR).Position) * gunRoot.Rotation * CFrame.new(offR - Vector3.new(0, def.BlockGripDrop or 0.07, 0)))
        end
        if ArmsData.Block.Rivals then
            -- the arm ends just under the grip (gun-fixed), so the gun sits on top of the fist
            local drop = def.IsMelee and (def.BlockGripDrop or 0) or (def.BlockGripDrop or ArmsData.Block.GripDrop) * (self.ArmFit or 1) -- (0.93: a melee's fist sits on its grip)
            local rT
            if onBolt <= 0.01 then
                rT = Map(gunRoot * gripR * CFrame.new(offR - Vector3.new(0, drop, 0))).Position
            else
                rT = MapPoint((rSolve * sR.HandFrame).Position)
            end
            local lT
            if gunRootL then
                lT = Map(gunRootL * gripR).Position -- (DUAL: the left fist holds the left weapon)
            elseif oneHand and not def.BlockLeftOnRight then
                lT = MapPoint((lWrist * sL.HandFrame).Position) -- free arm (melee rest / reload hand)
            elseif def.BlockLeftOnRight then
                -- two-handed pistol: the support fist sits beside / under the shooting fist
                local lor = def.BlockLeftOnRight
                if IS_STUDIO then
                    local t = {}
                    for v in string.gmatch(tostring((game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:GetAttribute("DevLeftOnRight")) or ""), "[^,]+") do table.insert(t, tonumber(v) or 0) end
                    if #t == 3 then lor = Vector3.new(t[1], t[2], t[3]) end
                end
                lT = rT + camCF:VectorToWorldSpace(lor * (self.ArmFit or 1))
                -- (Update 5: it used to jump from here to halfway down the reload path when LHand crossed 0.5)
                if lIn > 0.001 then lT = lT:Lerp(MapPoint((lWrist * sL.HandFrame).Position), lIn) end
            else
                -- straight onto the gun's support grip (the old IK arm couldn't reach bigger / further guns, so the
                -- fist floated); during reloads it blends to the animated hand
                -- (on the gun's centre line: the posed grip point sits off to the side, where a real palm would be)
                local gp = G(self.Pt.GripL or self.Pt.GripR).Position
                local seatG = Vector3.new(gp.X, gp.Y, 0) + offL - Vector3.new(0, 0.02, 0)
                -- (Update 5) pump-actions: the support fist rides the pump (it stayed put while the pump racked under it)
                local pumpX = (def.PumpTravel and self.GunParts.Pump and (ch.Pump or 0) > 0) and def.PumpTravel * gs * ch.Pump or 0
                seatG -= Vector3.new(pumpX, 0, 0)
                local onGrip = Map(gunRoot * CFrame.new(seatG)).Position
                -- (Update 5 INSPECTS) LCradle: as the gun rolls / turns, the fist slides round the handguard and stays under it
                -- (on the side it rested on, as seen now), like a real support hand the rifle rolls in
                local cr = math.clamp(ch.LCradle or 0, 0, 1)
                local ring = self.SupportRing
                if cr > 0.001 and ring and restRoot then
                    local cG = ring.C - Vector3.new(pumpX, 0, 0)
                    local a = gunRoot.XVector
                    -- (the side it rested on, blended toward the side the support arm comes from: still defined when the
                    -- gun stands on end, and the forearm then reaches it without crossing the gun)
                    local cW = gunRoot:PointToWorldSpace(cG)
                    local shW = camCF:PointToWorldSpace(def.BlockShoulderL or ArmsData.Block.ShoulderL)
                    local d0 = restRoot:VectorToWorldSpace(seatG - cG).Unit + (shW - cW).Unit * 0.6
                    local d = d0 - a * d0:Dot(a)
                    if d.Magnitude > 1e-3 then
                        d = d.Unit
                        local dl = gunRoot:VectorToObjectSpace(d)
                        local rr = ViewmodelRig.RingRadius(ring, math.atan2(dl.Z, dl.Y))
                        onGrip = onGrip:Lerp(Map(CFrame.new(cW + d * (rr + ring.Gap))).Position, cr)
                    end
                end
                local anim = MapPoint((lWrist * sL.HandFrame).Position)
                lT = onGrip:Lerp(anim, lIn)
            end
            -- (Update 5 INSPECTS) ArmFollowR / ArmFollowL: the forearms turn with the gun (its turn away from the rest hold),
            -- anchored on where each fist sits in the REST hold
            local folR, folL
            if restRoot then
                local rel = gunRoot.Rotation * restRoot.Rotation:Inverse()
                local wR, wL = math.clamp(ch.ArmFollowR or 0, 0, 1), math.clamp(ch.ArmFollowL or 0, 0, 1) * (1 - lIn)
                if wR > 0.001 and onBolt <= 0.01 then
                    local dropR = def.IsMelee and (def.BlockGripDrop or 0) or (def.BlockGripDrop or ArmsData.Block.GripDrop) * (self.ArmFit or 1)
                    folR = { R = rel, W = wR, Rest = Map(restRoot * gripR * CFrame.new(offR - Vector3.new(0, dropR, 0))).Position }
                end
                if wL > 0.001 and not oneHand and not def.BlockLeftOnRight then
                    local gpL = G(self.Pt.GripL or self.Pt.GripR).Position
                    folL = { R = rel, W = wL, Rest = Map(restRoot * CFrame.new(Vector3.new(gpL.X, gpL.Y, 0) + offL - Vector3.new(0, 0.02, 0))).Position }
                end
            end
            self:PlaceBlockArm("R", rT, camCF, k, def.IsMelee and onBolt <= 0.01 and self.MeleeRestGrip
                and Map(CFrame.new((gunRoot * gripR).Position) * (self.MeleeRestGrip * gripR.Rotation).Rotation) or nil, folR)
            self:PlaceBlockArm("L", lT, camCF, k, gunRootL and CFrame.new(lT) or nil, folL)
        else
        self:PlaceBlockArm("R", MapPoint((rSolve * sR.HandFrame).Position + gunRoot:VectorToWorldSpace(offR)), camCF, k, rHandCF)
        self:PlaceBlockArm("L", MapPoint((lWrist * sL.HandFrame).Position + gunRoot:VectorToWorldSpace(offL * onGripL)), camCF, k)
        end
    end

    self:PoseFingers("R", ch.RHandPose or ((onBolt > 0.3 or knifeGrip) and "Fist") or def.RHandShape or "PistolGrip", dt, trigger)
    self:PoseFingers("L", ch.LHandPose or "Support", dt, 0)
    self:ApplyGripPoseFingers("R", gunRoot, wR, trigger, MapDir)
    self:ApplyGripPoseFingers("L", lRoot, wL, 0, MapDir)

    -- magazine: seated (plus animation offset), or riding in the left hand
    if mag then
        local magCF
        if (ch.MagHand or 0) >= 0.5 then
            -- (the real hand is already in the real camera: squash the magazine around itself)
            magCF = sL.Wrist.TransformedWorldCFrame * CFrame.new(sL.HandFrame.Position * self.ArmScale) * sL.HandFrame.Rotation * magInHand
            local _, f = DepthMap(magCF.Rotation, camCF.Rotation, k)
            Squash(mag, f)
        else
            local f
            magCF, f = DepthMap(gunRoot * G(ch.Mag or CFrame.identity) * mag.Rest, camCF, k)
            Squash(mag, f)
        end
        mag.Part.CFrame = magCF
        local show = (ch.MagShow == nil or ch.MagShow >= 0.5) and self.Visible
        mag.Part.LocalTransparencyModifier = show and 0 or 1
        -- a part named "MagGlow" (the beam gun's energy cell core) rides with the magazine wherever it goes
        local core = self.GunParts.MagGlow
        if core then
            core.Part.CFrame = magCF * (mag.Rest:Inverse() * core.Rest)
            core.Part.LocalTransparencyModifier = show and 0 or 1
        end
        -- skin decorations on the magazine (Follow = "Magazine"): ride it, and still animate
        for _, gp in pairs(self.GunParts) do
            if gp.Follow == "Magazine" then
                local off = CFrame.identity
                if gp.Anim and skinSt then
                    local o, tr, col = SkinFX.AnimOffset(gp.Anim, skinSt.Now, skinSt)
                    off = o
                    if tr and gp.LastTr ~= tr then gp.Part.Transparency = tr; gp.LastTr = tr end
                    if col and gp.LastCol ~= col then gp.Part.Color = col; gp.LastCol = col end
                end
                gp.Part.CFrame = magCF * (mag.Rest:Inverse() * off * gp.Rest)
                gp.Part.LocalTransparencyModifier = show and 0 or 1
                if gp.Decals then for _, dc in ipairs(gp.Decals) do dc.LocalTransparencyModifier = show and 0 or 1 end end -- (a sticker on the mag)
            end
        end
    end

    -- HELD ROUNDS: what the support hand loads on a shell-by-shell / break / revolver reload (channel ShellHold)
    if ch.ShellHold ~= nil or self.HeldRound then
        local hr = self.HeldRound
        if self.Gun and (not hr or hr.Model.Parent ~= self.Gun) then
            hr = ViewmodelRig.BuildHeldRound(def, gs)
            hr.Model.Parent = self.Gun
            self.HeldRound = hr
        end
        if hr then
            local on = (ch.ShellHold or 0) >= 0.5 and self.Visible ~= false
            if on then
                local base = sL.Wrist.TransformedWorldCFrame * CFrame.new(sL.HandFrame.Position * self.ArmScale) * sL.HandFrame.Rotation
                for _, e in ipairs(hr.Parts) do e[1].CFrame = base * e[2] end
            end
            if hr.On ~= on then
                hr.On = on
                for _, e in ipairs(hr.Parts) do e[1].LocalTransparencyModifier = on and 0 or 1 end
            end
        end
    end

    -- knife (melee) rides in the right hand
    if self.Knife then
        self.Knife.Part.CFrame = Map(rTarget * self.Knife.Offset)
    end

    if self.Animated and #self.Animated > 0 then
        local hue = Color3.fromHSV((os.clock() * 0.09) % 1, 0.5, 1)
        for _, p in ipairs(self.Animated) do
            local sa = p:FindFirstChildOfClass("SurfaceAppearance")
            if sa then sa.Color = hue else p.Color = hue end
        end
    end
end

function ViewmodelRig:Destroy()
    self:ClearGun()
    if self.Model then self.Model:Destroy() end
    if self.SoundFolder then self.SoundFolder:Destroy() end
end

return ViewmodelRig
