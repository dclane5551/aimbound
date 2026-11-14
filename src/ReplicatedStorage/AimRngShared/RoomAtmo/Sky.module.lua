--!strict
-- ROOM ATMOSPHERE PASS 2 -- SKY (the Brass Skyport). mapvibe 2026-10-25 (replaces hubfix's untested part-built draft).
-- Real meshes: ReplicatedStorage.RoomAtmoKit.Sky (tools/atmo_kit_sky.py -> tools/atmo_kit_sky_import.py): Davit, CargoNet,
-- Crate, Winch, Propeller, RopeCoil, Gondola.
-- PLACEMENT (its own pattern): the room is dressed UPWARD -- cargo HANGS. Davit cranes stand at the walls with their arms out
-- over the deck and loads slung under them at different heights (one let down onto the deck, its rope slack), so the room
-- reads in its upper half as well as on the floor; no other biome hangs things.
--   CONTRAST  Light: sun x0.7, ambient x0.88, a warm brass grade; terrain x0.76, parts x0.76. Warm lamp light.
--   GROUND    the davits + their slung cargo, a winch wound with rope beside one, crates stacked by them, rope coils on the
--             deck, a big propeller on a wall bracket; the deck: plank / brick / slate field (terrain paint, 0 parts).
--   EDGE      (the Skyport's maps are edge decks: everything stands inside the rail; the cargo hangs over the deck, not the drop)
--   SET PIECE an airship GONDOLA come down hard on the deck, keeled over, planks broken round it, its portholes still lit,
--             ropes trailing (1 light)
--   DRIFT     cloud wisps blowing across low
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.7, Ambient = 0.88, Outdoor = 0.88, Tint = C3(255, 232, 206), TintAmt = 0.26 }
B.Palette = { Dim = 0.76 }
B.PartDim = 0.76
B.Drift = { CloudWisp = true }

local ROPE, PLANK, WARM, WISP = C3(150, 126, 88), C3(110, 80, 52), C3(255, 196, 120), C3(236, 232, 240)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Emitter = A.Part, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.WoodPlanks, 62 }, { M.Brick, 38 } }, { Scale = 24, Stretch = 2.2 }) -- (no slate: it read as dark holes in the deck)
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = root and root:FindFirstChild("Sky")
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
                if role == "Glow" then q.CastShadow = false elseif role == "Rope" then q.CastShadow = false end
            end
        end
        return m
    end
    local function Rope(a: Vector3, b: Vector3, r: number)
        local L = (b - a).Magnitude
        if L < 0.2 then return end
        local p = Part(fx, "Rope", Enum.PartType.Cylinder, Vector3.new(L, r * 2, r * 2), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), ROPE, M.Fabric)
        p.CastShadow = false
        n += 1
    end

    -- SET PIECE first: the downed gondola (1 light)
    local setAt: Vector3? = nil
    do
        local sd, spot = P.SetSpot(30, 12, nil)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z)
            setAt = at
            -- keeled over toward the room, nose down a little, its stern swung off the wall line
            local face = (CFrame.Angles(0, math.rad(vr:NextNumber(-20, 20)), 0) * CFrame.new(Vector3.zero, -o)).LookVector
            local m = Kit("Gondola", at, face, vr:NextNumber(1.05, 1.2), CFrame.Angles(math.rad(vr:NextNumber(8, 14)), 0, math.rad(vr:NextNumber(-7, 7))))
            if m then m:PivotTo(m:GetPivot() - Vector3.new(0, 0.9, 0)) end -- (through the planks)
            -- broken planks round its keel, sprung up
            for i = 1, 9 do
                local a = vr:NextNumber(0, math.pi * 2)
                local d = vr:NextNumber(5, 10)
                local p = at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
                if not P.DoorNear(p, 9) then
                    Part(fx, "BrokenPlank", nil, Vector3.new(vr:NextNumber(3, 6), 0.3, 0.9), CFrame.new(p + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0) * CFrame.Angles(0, 0, math.rad(vr:NextNumber(-35, 35))), PLANK, M.WoodPlanks)
                    n += 1
                end
            end
            -- ropes trailing off its roof over the deck
            for _ = 1, 3 do
                local s0 = at + Vector3.new(vr:NextNumber(-5, 5), 6.5, vr:NextNumber(-2, 2))
                local s1 = at - o * vr:NextNumber(6, 10) + al * vr:NextNumber(-8, 8) + Vector3.new(0, 0.2, 0)
                Rope(s0, (s0 + s1) / 2 + Vector3.new(0, 1.2, 0), 0.09)
                Rope((s0 + s1) / 2 + Vector3.new(0, 1.2, 0), s1, 0.09)
            end
            Kit("RopeCoil", at - o * 9 + al * vr:NextNumber(-4, 4), al, 1, CFrame.Angles(0, vr:NextNumber(0, 6.28), 0))
            if Lava then Lava.Glow(fx, at + Vector3.new(0, 5, 0) - o * 3, 16, WARM, 0.6, { Name = "PortholeGlow", MaxDistance = 600 }) end
            local cc = A.Carrier(fx, "GondolaLight", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 5, 0) - o * 4))
            local l = Instance.new("PointLight")
            l.Color = WARM; l.Range = 22; l.Brightness = 1; l.Shadows = false
            l.Parent = cc
            n += 1
        end
    end
    local function NearSet(p: Vector3, r: number): boolean
        return setAt ~= nil and (Vector3.new(p.X, 0, p.Z) - Vector3.new((setAt :: Vector3).X, 0, (setAt :: Vector3).Z)).Magnitude < r
    end

    -- THE DAVITS + SLUNG CARGO: on every wall, 1-2 cranes; the loads hang at different heights
    local winchDone, lampDone = false, false
    for _, sd in ipairs(P.order) do
        local o, al = P.SIDES[sd], P.Along(sd)
        local into = -o
        local count = vr:NextInteger(1, 2)
        for k = 1, count do
            local f = (count == 1) and vr:NextNumber(-0.4, 0.4) or ((k == 1) and vr:NextNumber(-0.75, -0.3) or vr:NextNumber(0.3, 0.75))
            local at = C0 + o * (half - 2.5) + al * f * half
            at = Vector3.new(at.X, F, at.Z)
            if not P.DoorNear(at, 16) and not NearSet(at, 18) then
                local kk = vr:NextNumber(0.95, 1.15)
                local face = (CFrame.Angles(0, math.rad(vr:NextNumber(-15, 15)), 0) * CFrame.new(Vector3.zero, into)).LookVector
                local d = Kit("Davit", at, face, kk, nil)
                if d then
                    local cf, sz = d:GetBoundingBox()
                    local tip = cf.Position + face * (sz.Z / 2 - 0.75 * kk)
                    local pulley = Vector3.new(tip.X, cf.Position.Y + sz.Y / 2 - 1.6 * kk, tip.Z)
                    local t = KIT and KIT:FindFirstChild("CargoNet")
                    local netH = 7.6
                    if t and t:IsA("Model") then
                        local _, nbb = t:GetBoundingBox()
                        netH = nbb.Y
                    end
                    local nk = vr:NextNumber(0.75, 0.95)
                    local down = vr:NextNumber() < 0.25 -- (one let down onto the deck, its rope slack)
                    local bottom = down and F or math.max(F + 3, pulley.Y - 1.5 - netH * nk - vr:NextNumber(0, 4))
                    local net = Kit("CargoNet", Vector3.new(pulley.X, bottom, pulley.Z), al, nk, CFrame.Angles(0, vr:NextNumber(0, 6.28), down and math.rad(vr:NextNumber(4, 9)) or 0))
                    if net then
                        local ring = Vector3.new(pulley.X, bottom + netH * nk, pulley.Z)
                        if down then
                            local mid = (pulley + ring) / 2 + into * 1.4 - Vector3.new(0, 1.5, 0)
                            Rope(pulley, mid, 0.08); Rope(mid, ring, 0.08)
                        else
                            Rope(pulley, ring, 0.08)
                        end
                    end
                    -- crates stacked by the post, a winch by one of them
                    local cAt = at + into * 3 + al * ((vr:NextNumber() < 0.5) and -3.5 or 3.5)
                    if not P.DoorNear(cAt, 10) then
                        Kit("Crate", cAt, into, vr:NextNumber(0.9, 1.1), CFrame.Angles(0, vr:NextNumber(-0.4, 0.4), 0))
                        if vr:NextNumber() < 0.6 then Kit("Crate", cAt + Vector3.new(0, 2.6, 0) + al * vr:NextNumber(-0.3, 0.3), into, vr:NextNumber(0.75, 0.9), CFrame.Angles(0, vr:NextNumber(-0.6, 0.6), 0)) end
                    end
                    if not winchDone then
                        winchDone = true
                        local wAt = at + into * 3 - al * ((cAt - at):Dot(al) > 0 and 4 or -4)
                        if not P.DoorNear(wAt, 10) then Kit("Winch", wAt, al, 1, CFrame.Angles(0, vr:NextNumber(-0.3, 0.3), 0)) end
                    end
                    if not lampDone and Lava then
                        lampDone = true
                        Lava.Glow(fx, pulley + Vector3.new(0, 0.6, 0), 9, WARM, 0.62, { Name = "DavitLamp", MaxDistance = 400 })
                    end
                end
            end
        end
    end
    -- a big propeller on a wall bracket (the wall with the fewest davits is fine: first free spot)
    for _ = 1, 4 do
        local sd = P.order[vr:NextInteger(1, #P.order)]
        local o, al = P.SIDES[sd], P.Along(sd)
        local at = C0 + o * (half - 1.5) + al * vr:NextNumber(-0.5, 0.5) * half
        at = Vector3.new(at.X, F, at.Z)
        if not P.DoorNear(at, 16) and not NearSet(at, 20) then
            Kit("Propeller", at, -o, vr:NextNumber(1.1, 1.3), nil)
            break
        end
    end
    -- rope coils on the deck
    for _ = 1, vr:NextInteger(2, 3) do
        local p = P.Spot(12)
        if not P.DoorNear(p, 10) and not NearSet(p, 12) then Kit("RopeCoil", p, Vector3.zAxis, vr:NextNumber(0.9, 1.2), CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)) end
    end

    -- DRIFT: cloud wisps blowing across low
    local wind = (CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)).LookVector
    Emitter(fx, "CloudWisp", CFrame.lookAt(C0 + Vector3.new(0, 2, 0), C0 + Vector3.new(0, 2, 0) + wind), Vector3.new(half * 1.6, 2, half * 1.6), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(WISP), LightEmission = 0.2, LightInfluence = 0.8,
        Rate = 1.5, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 5), SpreadAngle = Vector2.new(10, 5), EmissionDirection = Enum.NormalId.Front,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.8), NumberSequenceKeypoint.new(1, 1) }),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 10) }) })
    return n
end

return B
