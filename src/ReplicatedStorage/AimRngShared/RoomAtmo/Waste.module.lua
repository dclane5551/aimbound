--!strict
-- ROOM ATMOSPHERE PASS 2 -- WASTE (the Toxic Wastes). mapvibe 2026-10-25 (replaces hubfix's untested part-built draft).
-- Real meshes: ReplicatedStorage.RoomAtmoKit.Waste (tools/atmo_kit_waste.py -> tools/atmo_kit_waste_import.py): ChemTank,
-- Drum, DrumStack, Barrier, CrushedCar, PipeBroken, WarnSign, Drain.
-- PLACEMENT (its own pattern): everything is laid out by THE BREACH -- a ruptured chemical tank at one wall is the source;
-- drums lie BLOWN OUTWARD from it along the walls (tipped and leaking near it, upright further off), a broken hazard CORDON
-- stands in an arc round it, and the glowing SEEP runs from its spill across the floor to a choked drain on the far side,
-- branching as it goes. Nothing else is laid out radially from one source.
--   CONTRAST  Light: sun x0.55, ambient x0.86, a sick yellow-green grade; terrain x0.7, parts x0.7. The only clean colour is
--             the toxic green.
--   GROUND    the drums, the cordon (plastic barriers, some knocked over, warning signs), crushed cars and a broken pipe at
--             the other walls; the floor: mud / ground / asphalt / slate field (terrain paint, 0 parts), the seep.
--   EDGE      a stack of crushed cars against a far wall
--   SET PIECE the RUPTURED TANK on its saddles, sludge pouring out into a pool, fumes rising (1 green light)
--   DRIFT     low green smog
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.55, Ambient = 0.86, Outdoor = 0.86, Tint = C3(232, 240, 204), TintAmt = 0.28 }
B.Palette = { Dim = 0.7 }
B.PartDim = 0.7
B.Drift = { ToxicSmog = true }

local TOXIC, TOXIC_DK, SMOG, FUME = C3(140, 255, 60), C3(70, 150, 30), C3(150, 170, 90), C3(170, 200, 110)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Emitter = A.Part, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Mud, 35 }, { M.Ground, 30 }, { M.Asphalt, 20 }, { M.Slate, 15 } }, { Scale = 22, Stretch = 2 })
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = root and root:FindFirstChild("Waste")
    local function Kit(name: string, at: Vector3, face: Vector3, k: number, tilt: CFrame?): Model?
        local t = KIT and KIT:FindFirstChild(name)
        if not (t and t:IsA("Model")) then return nil end
        local _, bb = t:GetBoundingBox()
        local cf = CFrame.lookAt(at, at + Vector3.new(face.X, 0, face.Z)) * (tilt or CFrame.new())
        local ok, m = pcall(A.PlaceModel, t, fx, cf, bb.Y * k, name)
        if not ok or not m then return nil end
        for _, q in ipairs(m:GetDescendants()) do
            if q:IsA("BasePart") then
                n += 1
                local role = q:GetAttribute("Role")
                if role == "Sludge" then q.CastShadow = false
                elseif role == "Orange" then q.Color = Color3.fromRGB(150, 74, 30) end -- (196 orange read as a plastic toy)
            end
        end
        return m
    end
    local function Inside(p: Vector3, m: number): boolean
        return math.abs(p.X - C0.X) <= half - m and math.abs(p.Z - C0.Z) <= half - m
    end
    local function Puddle(at: Vector3, r: number)
        for i = 1, 2 do
            local d = Part(fx, "Sludge", Enum.PartType.Cylinder, Vector3.new(0.06, r * 2 * (1 - 0.3 * (i - 1)), r * 2 * vr:NextNumber(0.6, 0.9)),
                CFrame.new(at.X + vr:NextNumber(-0.4, 0.4), F + 0.07 + 0.01 * i, at.Z + vr:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)),
                (i == 1) and TOXIC_DK or TOXIC, M.Neon)
            d.Transparency = (i == 1) and 0.45 or 0.25; d.CastShadow = false
            n += 1
        end
    end

    -- THE BREACH (set piece) first: the source of everything else
    local src: Vector3? = nil
    local srcO: Vector3? = nil
    do
        local sd, spot = P.SetSpot(30, 10, nil)
        if sd and spot then
            local o = P.SIDES[sd]
            local at = Vector3.new(spot.X, F, spot.Z) + o * 2
            Kit("ChemTank", at, -o, vr:NextNumber(1.25, 1.4), CFrame.Angles(0, math.rad(vr:NextNumber(-8, 8)), math.rad(vr:NextNumber(-3, 3))))
            src = at - o * 6
            srcO = o
            Puddle(at - o * 7.5, 5)
            Emitter(fx, "Fumes", CFrame.new(at - o * 6 + Vector3.new(0, 1, 0)), Vector3.new(6, 1, 6), {
                Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(FUME), LightEmission = 0.3, LightInfluence = 0.7,
                Rate = 3, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top,
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) }) })
            if Lava then Lava.Glow(fx, at - o * 7 + Vector3.new(0, 1.5, 0), 18, TOXIC, 0.6, { Name = "SpillGlow", MaxDistance = 700 }) end
            local cc = A.Carrier(fx, "SpillLight", Vector3.new(1, 1, 1), CFrame.new(at - o * 8 + Vector3.new(0, 3, 0)))
            local l = Instance.new("PointLight")
            l.Color = TOXIC; l.Range = 26; l.Brightness = 1.1; l.Shadows = false
            l.Parent = cc
            n += 1
        end
    end
    local S = src or (C0 + P.SIDES[P.order[1]] * (half - 12))
    local SO = srcO or P.SIDES[P.order[1]]
    local function NearSrc(p: Vector3, r: number): boolean
        return (Vector3.new(p.X, 0, p.Z) - Vector3.new(S.X, 0, S.Z)).Magnitude < r
    end

    -- DRUMS BLOWN OUTWARD along the walls: walk the wall band away from the source both ways; near = tipped + leaking
    for _, sd in ipairs(P.order) do
        local o, al = P.SIDES[sd], P.Along(sd)
        for k = 1, vr:NextInteger(2, 4) do
            local f = vr:NextNumber(-0.85, 0.85)
            local p = C0 + o * (half - vr:NextNumber(3, 11)) + al * f * half
            p = Vector3.new(p.X, F, p.Z)
            local dist = (p - S).Magnitude
            if not P.DoorNear(p, 10) and not NearSrc(p, 12) then
                local away = Vector3.new(p.X - S.X, 0, p.Z - S.Z)
                away = away.Magnitude > 0.1 and away.Unit or al
                if dist < 55 and vr:NextNumber() < 0.75 then -- knocked flat, rolled away from the blast, leaking
                    local roll = CFrame.Angles(0, vr:NextNumber(-0.6, 0.6), 0) * CFrame.Angles(0, 0, math.rad(90))
                    Kit("Drum", p, Vector3.new(away.Z, 0, -away.X), vr:NextNumber(1.0, 1.15), roll)
                    if vr:NextNumber() < 0.5 then Puddle(p + away * 2, vr:NextNumber(1.3, 2.2)) end
                else
                    Kit("Drum", p, -o, vr:NextNumber(1.0, 1.15), CFrame.Angles(math.rad(vr:NextNumber(-6, 6)), vr:NextNumber(0, 6.28), 0))
                end
            end
        end
    end
    -- THE CORDON: an arc of barriers round the breach, gaps, some knocked over; warning signs at its ends
    do
        local R = 17
        local tang = SO:Cross(Vector3.yAxis).Unit
        local count = 7
        for i = 1, count do
            local a = -1.2 + (i - 1) * 2.4 / (count - 1) + vr:NextNumber(-0.08, 0.08)
            local dir = (-SO * math.cos(a) + tang * math.sin(a))
            local p = S + dir * R
            p = Vector3.new(p.X, F, p.Z)
            if Inside(p, 4) and not P.DoorNear(p, 9) and vr:NextNumber() < 0.8 then
                local over = vr:NextNumber() < 0.3
                Kit("Barrier", p, dir, vr:NextNumber(0.95, 1.05), over and CFrame.Angles(math.rad(80), vr:NextNumber(-0.4, 0.4), 0) or CFrame.Angles(0, math.rad(vr:NextNumber(-12, 12)), 0))
            end
            if i == 1 or i == count then
                local q = S + dir * (R + 2.5)
                q = Vector3.new(q.X, F, q.Z)
                if Inside(q, 3) and not P.DoorNear(q, 9) then
                    Kit("WarnSign", q, dir, 1, CFrame.Angles(math.rad(vr:NextNumber(-14, 6)), 0, math.rad(vr:NextNumber(-10, 10))))
                end
            end
        end
    end
    -- THE SEEP: from the spill across the floor to a drain on the far side, branching (Neon cracks: Beams, no parts a leg)
    do
        local far = C0 - SO * (half - 9) + SO:Cross(Vector3.yAxis) * vr:NextNumber(-0.4, 0.4) * half
        far = Vector3.new(far.X, F, far.Z)
        if not P.DoorNear(far, 12) then
            Kit("Drain", far, SO, 1.1, CFrame.Angles(0, vr:NextNumber(0, 6.28), 0))
            Puddle(far, 2.6)
        end
        local start = S - SO * 3
        local dir = (far - start)
        if dir.Magnitude > 1 and A.Cracks then
            n += A.Cracks(fx, P, ctx, vr, start, dir.Unit, 0.7,
                { Neon = true, Hot = TOXIC, Dark = TOXIC_DK, HotT = 0.35, DarkT = 0.6, HotShare = 0.35, Limit = 16, MaxDepth = 6,
                  Seg = { 3, 6.5 }, Turn = { 0.15, 0.55 }, Fade = 0.2, Start = 0, Y = 0.09 })
        end
    end
    -- the other walls: crushed cars stacked (edge), a broken pipe run, a drum pallet -- each on a wall away from the breach
    do
        local walls = {}
        for _, sd in ipairs(P.order) do if P.SIDES[sd]:Dot(SO) < 0.5 then table.insert(walls, sd) end end
        local jobs = { "Cars", "Pipe", "Stack" }
        for i, job in ipairs(jobs) do
            local sd = walls[((i - 1) % math.max(1, #walls)) + 1]
            if sd then
                local o, al = P.SIDES[sd], P.Along(sd)
                for _ = 1, 3 do
                    local p = C0 + o * (half - 5) + al * vr:NextNumber(-0.7, 0.7) * half
                    p = Vector3.new(p.X, F, p.Z)
                    if not P.DoorNear(p, 12) and not NearSrc(p, 20) then
                        if job == "Cars" then
                            local yaw = vr:NextNumber(-0.3, 0.3)
                            Kit("CrushedCar", p, -o, 1.1, CFrame.Angles(0, yaw, 0))
                            Kit("CrushedCar", p + Vector3.new(0, 2.9, 0) + al * vr:NextNumber(-0.8, 0.8), -o, 1.05, CFrame.Angles(0, yaw + vr:NextNumber(-0.3, 0.3), math.rad(vr:NextNumber(-4, 4))))
                            if vr:NextNumber() < 0.6 then Kit("CrushedCar", p + Vector3.new(0, 5.7, 0), -o, 1.0, CFrame.Angles(0, yaw + vr:NextNumber(-0.4, 0.4), 0)) end
                        elseif job == "Pipe" then
                            Kit("PipeBroken", p - o * 1.5, -o, vr:NextNumber(1.0, 1.2), CFrame.Angles(0, math.rad(vr:NextNumber(-10, 10)), 0))
                        else
                            Kit("DrumStack", p, -o, vr:NextNumber(0.95, 1.1), CFrame.Angles(0, vr:NextNumber(0, 6.28), 0))
                        end
                        break
                    end
                end
            end
        end
    end
    -- DRIFT: low green smog
    Emitter(fx, "ToxicSmog", CFrame.new(C0 + Vector3.new(0, 1.5, 0)), Vector3.new(half * 1.6, 1.5, half * 1.6), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(SMOG), LightEmission = 0.15, LightInfluence = 0.8,
        Rate = 2, Lifetime = NumberRange.new(7, 11), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 10),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.84), NumberSequenceKeypoint.new(1, 1) }),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 12) }) })
    return n
end

return B
