--!strict
-- ROOM ATMOSPHERE PASS 2 -- CYBER (the Cyber floors; the Station has its OWN layout in RoomAtmo/Station). mapvibe
-- 2026-10-25 (took over hubfix's part-built drafts; coordinator: "a mesh-kit treatment like Fungal's", references Vaal
-- Factory / the Matriarch Halls -- heavy dark machinery, ribbed machine walls, tanks and pipe runs, engraved floor plates,
-- cold blue energy). The pieces are REAL MESHES: ReplicatedStorage.RoomAtmoKit.Cyber (tools/atmo_kit_cyber.py ->
-- tools/atmo_kit_cyber_import.py): ServerRack, Tank, PipeRun, RibArc, Coil, CableNest, FloorPlate, Console, Reactor, Truss.
-- Every one of these maps is PART-BUILT with nothing outside the walls (a rooftop's drop, open space round the station deck),
-- so everything stands INSIDE the wall line, backed onto the walls (never in the fight lane, no collision).
--   CONTRAST  Light: sun x0.55, ambient x0.92, a light cold grade (gun ~10% darker); parts x0.6.
--   GROUND    a MACHINE WALL on the doorless walls: a lopsided continuous row (a rib-arc housing off-centre, racks with pipe
--             runs on one side, tank + console on the other), a lit floor channel in front (1 light). The open floor:
--             ENGRAVED FLOOR PLATES on an 8-stud grid, short broken inset circuit traces (Beams, fading) between them.
--   EDGE      energy COILS in the corners (tall, glowing: read from 60), a TRUSS gantry high over a machine wall on two legs
--   SET PIECE a BREACHED REACTOR at a wall foot: casing torn open on its cyan core, pipes down, cables out, sparks (1 light)
--   DRIFT     slow cold dust
-- (Make(variant) stays for a future recolour; the owner rule is no two biomes with the same placement pattern.)
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

local LOOK = {
    Cyber = {
        Light = { Sun = 0.55, Ambient = 0.92, Outdoor = 0.92, Tint = C3(206, 230, 255), TintAmt = 0.22 }, -- (plate test: 0.4 / 0.8 /
        -- 0.3 left the gun 18-20% darker; the others sit ~10%)
        PartDim = 0.6, Glow = C3(70, 225, 235), Glow2 = C3(60, 150, 255), Hull = C3(36, 39, 46), Panel = C3(72, 76, 86),
        Trim = C3(150, 116, 40), Pipe = C3(86, 58, 44), Lamp = C3(110, 220, 255), Dust = C3(170, 220, 255), Broken = 0,
    },
}

local Mod = {}

function Mod.Make(variant: string): any
    local V = LOOK[variant] or LOOK.Cyber
    local B: any = {}
    B.Light = V.Light
    B.Palette = { Dim = 0.6 }
    B.PartDim = V.PartDim
    B.Drift = { ColdDust = true, FrostDrift = true }
    B.Variant = variant

    function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
        local Part, Emitter = A.Part, A.Emitter
        local Lava = ctx.Lava
        local P = A.Plan(ctx, vr)
        local F, C0, half = P.F, P.C0, P.half
        local n = 0
        local root = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
        local KIT = root and root:FindFirstChild("Cyber")
        local ROLE = { Glow = V.Glow, Trim = V.Trim, Hull = V.Hull, Panel = V.Panel, Pipe = V.Pipe }
        -- a kit piece standing at `at` (its base), its front (the kit's -Y) toward `face`, scale k (the kit is in studs);
        -- tilt = extra rotation about its own base (knocked-over Station pieces)
        local function Kit(name: string, at: Vector3, face: Vector3, k: number, tilt: CFrame?, glow: Color3?): Model?
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
                    local c = (role == "Glow" and glow) or ROLE[role]
                    if c then q.Color = c end
                    if role == "Glow" then q.CastShadow = false end
                end
            end
            return m
        end
        -- CIRCUIT TRACES (review: long straight neon strips read as tape at eye height -- the Storm lightning lesson): short
        -- legs (Seg 1.6-3.6), 45 / 90-degree turns, the odd break, each an INSET groove (a wider dark beam) with a thin glowing
        -- core that FADES along the trace. Flat Beams on one carrier per room: no part a leg.
        local holder: BasePart? = nil
        local GROOVE = C3(10, 12, 16)
        local function Beam(p0: Vector3, p1: Vector3, w: number, col: Color3, t0: number, t1: number, emit: boolean)
            if not holder then holder = A.Carrier(fx, "Traces", Vector3.new(0.2, 0.2, 0.2), CFrame.new(C0)); n += 1 end
            local fwd = (p1 - p0)
            if fwd.Magnitude < 0.1 then return end
            local side = fwd.Unit:Cross(Vector3.yAxis).Unit
            local function At(pos: Vector3): Attachment
                local at = Instance.new("Attachment")
                at.CFrame = (holder :: BasePart).CFrame:ToObjectSpace(CFrame.fromMatrix(pos, Vector3.yAxis, side, Vector3.yAxis:Cross(side)))
                at.Parent = holder
                return at
            end
            local b = Instance.new("Beam")
            b.Attachment0, b.Attachment1 = At(p0), At(p1)
            b.FaceCamera = false; b.Segments = 1; b.Width0 = w; b.Width1 = w
            b.Color = ColorSequence.new(col)
            b.Transparency = NumberSequence.new(t0, t1)
            b.LightEmission = emit and 1 or 0; b.LightInfluence = emit and 0 or 1
            b.Parent = holder
        end
        local traceLeft = 34 -- (legs a room)
        local function Trace(p: Vector3, dir: Vector3, legs: number)
            local cur, d = p, dir
            local col = (vr:NextNumber() < 0.5) and V.Glow2 or V.Glow
            for k = 1, legs do
                if traceLeft <= 0 then break end
                traceLeft -= 1
                local nxt = cur + d * vr:NextNumber(1.6, 3.6)
                if math.abs(nxt.X - C0.X) > half - 7 or math.abs(nxt.Z - C0.Z) > half - 7 or P.DoorNear(nxt, 9) then break end
                local y = Vector3.new(0, 0.07, 0)
                Beam(cur + y - d * 0.15, nxt + y + d * 0.15, 0.42, GROOVE, 0.2, 0.2, false)
                local t0 = 0.15 + 0.6 * (k - 1) / math.max(1, legs) -- (fades out along the trace)
                Beam(cur + y * 1.3, nxt + y * 1.3, 0.14, col, t0, math.min(0.95, t0 + 0.6 / legs), true)
                cur = nxt
                if vr:NextNumber() < 0.22 then cur += d * vr:NextNumber(0.5, 1.1) end -- (a broken stretch)
                local turn = (vr:NextNumber() < 0.5 and 1 or -1) * ((vr:NextNumber() < 0.55) and math.pi / 4 or math.pi / 2)
                if vr:NextNumber() < 0.35 then turn = 0 end
                d = (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, d)).LookVector
            end
            -- a pad at the end
            Beam(cur + Vector3.new(0, 0.09, 0) - d * 0.3, cur + Vector3.new(0, 0.09, 0) + d * 0.3, 0.6, col, 0.35, 0.35, true)
        end

        -- GROUND: the machine wall(s)
        local lit = false
        local function MachineWall(b0: Vector3, b1: Vector3, o: Vector3, main: boolean)
            local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
            local len, u = d.Magnitude, d.Unit
            local into = -o
            local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
            -- (v2, first look: five separate pieces at 1x read as a few boxes on a 123-stud wall. Now a CONTINUOUS row of heavy
            -- machinery at ~1.6x (the reference halls' wall of housings): the row is laid out end to end and centred on the band,
            -- pipe runs ride the rack tops, a piece in a doorway is left out)
            -- (review: the row was mirror-symmetric round the arch. Now one of two lopsided line-ups, flipped at random, and the
            -- whole row shifted off the band's middle: a rack pair with pipes on one side, a tank + console on the other)
            local MAIN = {
                { { "ServerRack", 1.6 }, { "ServerRack", 1.6 }, { "Console", 1.5 }, { "RibArc", 2.0 }, { "Tank", 1.55 }, { "ServerRack", 1.75 } },
                { { "Tank", 1.7 }, { "ServerRack", 1.6 }, { "RibArc", 2.0 }, { "Console", 1.5 }, { "ServerRack", 1.6 }, { "ServerRack", 1.6 } },
            }
            local SECOND = {
                { { "Console", 1.5 }, { "ServerRack", 1.45 }, { "ServerRack", 1.45 }, { "Tank", 1.4 }, { "Console", 1.5 }, { "ServerRack", 1.45 } },
                { { "ServerRack", 1.45 }, { "Tank", 1.4 }, { "Tank", 1.25 }, { "Console", 1.5 }, { "ServerRack", 1.45 }, { "ServerRack", 1.45 } },
            }
            local pick = (main and MAIN or SECOND)[vr:NextInteger(1, 2)]
            local row = table.clone(pick)
            if vr:NextNumber() < 0.5 then
                for i = 1, math.floor(#row / 2) do row[i], row[#row + 1 - i] = row[#row + 1 - i], row[i] end
            end
            local W = { ServerRack = 5.0, Tank = 7.0, RibArc = 14.4, Console = 3.4 }
            local D = { ServerRack = 5.0, Tank = 7.2, RibArc = 2.4, Console = 2.4 } -- (kit depths: each piece's back on the wall)
            local total = 0
            for _, it in ipairs(row) do total += W[it[1]] * it[2] + 0.6 end
            local room = len - 6
            while total > room and #row > 3 do -- (a short wall drops its outer pieces)
                local cut = table.remove(row, 1); total -= W[cut[1]] * cut[2] + 0.6
                if #row > 3 and total > room then cut = table.remove(row); total -= W[cut[1]] * cut[2] + 0.6 end
            end
            local slack = math.max(0, room - total)
            local x = -total / 2 + (vr:NextNumber() < 0.5 and -1 or 1) * vr:NextNumber(0.4, 1) * slack / 2
            local rackTop = {}
            for _, it in ipairs(row) do
                local w = W[it[1]] * it[2]
                local at = mid + o * (3.8 - D[it[1]] * it[2] / 2) + u * (x + w / 2)
                x += w + 0.6
                if not P.DoorNear(at, 6 + w / 2) then
                    local tilt = nil
                    if V.Broken > 0 and it[1] == "ServerRack" and vr:NextNumber() < 0.3 then
                        tilt = CFrame.Angles(math.rad(-vr:NextNumber(14, 24)), 0, math.rad(vr:NextNumber(-6, 6))) -- (fallen forward, propped)
                    elseif it[1] == "ServerRack" then
                        table.insert(rackTop, at)
                    end
                    Kit(it[1], at, into, it[2], tilt)
                end
            end
            -- pipe runs along the rack tops (one per pair of neighbouring racks)
            for i = 1, #rackTop - 1 do
                local p0, p1 = rackTop[i], rackTop[i + 1]
                if (p1 - p0).Magnitude < 10 then
                    local mid2 = (p0 + p1) / 2 + o * 1.2 + Vector3.new(0, 16.1, 0)
                    Kit("PipeRun", mid2, into, 1.1, CFrame.Angles(0, 0, 0))
                end
            end
            -- the lit floor channel in front of the machines
            local ch = mid + into * 3.6
            local strip = Part(fx, "ChannelGlow", nil, Vector3.new(0.6, 0.06, len - 4), CFrame.lookAt(ch + Vector3.new(0, 0.1, 0), ch + Vector3.new(0, 0.1, 0) + u), V.Glow2, M.Neon)
            strip.Transparency = 0.25; strip.CastShadow = false
            n += 1
            if Lava then
                for g = 1, math.max(1, math.floor(len / 28)) do
                    Lava.Glow(fx, b0:Lerp(b1, (g - 0.5) / math.max(1, math.floor(len / 28))) + into * 2 + Vector3.new(0, F + 2 - b0.Y, 0), 18, V.Glow, 0.6, { Name = "MachineGlow", MaxDistance = 400 })
                end
            end
            if not lit then
                lit = true
                local c = A.Carrier(fx, "MachineLamp", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 4, 0) + into * 3))
                local l = Instance.new("PointLight")
                l.Color = V.Lamp; l.Range = 28; l.Brightness = 1; l.Shadows = false
                l.Parent = c
                n += 1
            end
            for _ = 1, main and 2 or 1 do -- traces out of the channel
                local s = b0:Lerp(b1, vr:NextNumber(0.15, 0.85)) + into * 4.2
                Trace(Vector3.new(s.X, F, s.Z), into, vr:NextInteger(4, 7))
            end
            if V.Broken > 0 then -- (Station) cables hanging from the dark ceiling line down to the floor
                for _ = 1, 2 do
                    local top = mid + u * vr:NextNumber(-len / 3, len / 3) + Vector3.new(0, vr:NextNumber(16, 20), 0) + o * 1
                    local foot = Vector3.new(top.X, F + 0.3, top.Z) + into * vr:NextNumber(2, 4)
                    local c = Part(fx, "HangingCable", Enum.PartType.Cylinder, Vector3.new((top - foot).Magnitude, 0.4, 0.4), CFrame.lookAt((top + foot) / 2, foot) * CFrame.Angles(0, math.rad(90), 0), C3(24, 24, 28), M.SmoothPlastic)
                    c.CastShadow = false
                    n += 1
                end
            end
        end
        local isBand = {}
        for wi, sd in ipairs(P.walls) do
            local b0, b1 = P.Band(sd, 4, 22)
            if b0 then
                isBand[sd] = true
                MachineWall(b0, b1, P.SIDES[sd], wi == 1)
            end
        end
        -- THE OPEN FLOOR: engraved plates in a loose grid, traces, cable nests
        do
            local placed = {}
            for _ = 1, vr:NextInteger(3, 5) do
                local p = P.Spot(14)
                p = Vector3.new(math.floor((p.X - C0.X) / 8 + 0.5) * 8 + C0.X, F, math.floor((p.Z - C0.Z) / 8 + 0.5) * 8 + C0.Z) -- (on an 8-stud grid)
                local clash = P.DoorNear(p, 12)
                for _, q in ipairs(placed) do if (q - p).Magnitude < 9 then clash = true end end
                if not clash then
                    table.insert(placed, p)
                    Kit("FloorPlate", p + Vector3.new(0, 0.02, 0), Vector3.new(0, 0, 1), 1, CFrame.Angles(0, math.rad(90 * vr:NextInteger(0, 3)), 0))
                    -- (a plate's own glow pips + one trace leaving it)
                    local axes = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
                    local ax = axes[vr:NextInteger(1, 4)]
                    Trace(p + ax * 4.2, ax, vr:NextInteger(3, 6))
                end
            end
            -- (no CableNest on the open floor: a 14-stud tangle of black cables read as a giant spider from eye height)
        end
        local reactorAt: Vector3? = nil
        -- SET PIECE: the breached reactor at a wall foot
        do
            local sd, spot = P.SetSpot(26, 9, isBand)
            if sd and spot then
                local o, al = P.SIDES[sd], P.Along(sd)
                local at = Vector3.new(spot.X, F, spot.Z) + o * 1.5
                reactorAt = at
                local m = Kit("Reactor", at, -o, 1.15)
                if m then
                    for _ = 1, 3 do -- cables spilling out across the floor
                        local a = vr:NextNumber(-1.1, 1.1)
                        local dir = (-o * math.cos(a) + al * math.sin(a)).Unit
                        local Ln = vr:NextNumber(9, 14)
                        local c = Part(fx, "ReactorCable", Enum.PartType.Cylinder, Vector3.new(Ln, 0.7, 0.7), CFrame.lookAt(at + dir * (Ln / 2 + 6) + Vector3.new(0, 0.35, 0), at + dir * (Ln + 6) + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, math.rad(90), 0), C3(20, 20, 24), M.SmoothPlastic)
                        c.CastShadow = false
                        n += 1
                    end
                    Emitter(fx, "ReactorSparks", CFrame.new(at + Vector3.new(0, 12, 0) - o * 3) * CFrame.Angles(math.rad(-90), 0, 0), Vector3.new(3, 0.4, 3), {
                        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.new(1, 1, 1), V.Glow), LightEmission = 1, LightInfluence = 0,
                        Rate = 7, Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -30, 0),
                        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }) })
                    if Lava then Lava.Glow(fx, at + Vector3.new(0, 9, 0) - o * 1, 22, V.Glow, 0.4, { Name = "ReactorGlow", MaxDistance = 700 }) end
                    local c = A.Carrier(fx, "ReactorLight", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 8, 0) - o * 7))
                    local l = Instance.new("PointLight")
                    l.Color = V.Lamp; l.Range = 26; l.Brightness = 1.1; l.Shadows = false
                    l.Parent = c
                    n += 1
                end
            end
        end
        -- EDGE: energy coils in two corners (inside the walls), a truss gantry over the main machine wall
        do
            local corners = {}
            for _, a in ipairs({ { 1, 3 }, { 1, 4 }, { 2, 3 }, { 2, 4 } }) do
                local c = C0 + (P.SIDES[a[1]] + P.SIDES[a[2]]) * (half - 6)
                if not P.DoorNear(c, 14) and not (reactorAt and (c - reactorAt).Magnitude < 22) then table.insert(corners, c) end
            end
            for i = #corners, 2, -1 do local j = vr:NextInteger(1, i); corners[i], corners[j] = corners[j], corners[i] end
            for i = 1, math.min(2, #corners) do
                local c = corners[i]
                local tilt = (V.Broken > 0 and i == 2) and CFrame.Angles(math.rad(vr:NextNumber(10, 16)), 0, math.rad(vr:NextNumber(-6, 6))) or nil
                local m = Kit("Coil", c, (C0 - c).Unit, 1.6, tilt)
                if m and Lava then Lava.Glow(fx, c + Vector3.new(0, 13, 0), 16, V.Glow, 0.5, { Name = "CoilGlow", MaxDistance = 900 }) end
            end
            local sd = P.walls[1]
            if sd then
                local o, al = P.SIDES[sd], P.Along(sd)
                local mid = C0 + o * (half - 11) -- (in front of the 8-deep machine row: the legs never stand in it)
                local H = vr:NextNumber(23, 26) -- (over the 16-stud rack row + its pipes)
                local span = math.min(54, half * 0.9)
                if not P.DoorNear(mid, 30) then
                    for k = -1, 1, 2 do
                        local leg = mid + al * k * (span / 2 - 1)
                        Part(fx, "GantryLeg", nil, Vector3.new(2.2, H, 2.2), CFrame.new(leg.X, F + H / 2, leg.Z), V.Hull, M.Metal)
                        Part(fx, "GantryFoot", nil, Vector3.new(3, 0.6, 3), CFrame.new(leg.X, F + 0.3, leg.Z), V.Hull, M.Metal)
                        n += 2
                    end
                    local t = Kit("Truss", mid + Vector3.new(0, H, 0), -o, span / 30)
                    local _ = t
                end
            end
        end
        -- DRIFT: slow cold dust (Station: frost crystals)
        Emitter(fx, (V.Broken > 0) and "FrostDrift" or "ColdDust", CFrame.new(C0 + Vector3.new(0, 6, 0)), Vector3.new(half * 1.6, 8, half * 1.6), {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(V.Dust), LightEmission = 0.5, LightInfluence = 0.4,
            Rate = 5, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.14), NumberSequenceKeypoint.new(1, 0) }) })
        return n
    end
    return B
end

local B = Mod.Make("Cyber")
B.Make = Mod.Make
return B
