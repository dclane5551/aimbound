--!strict
-- ROOM ATMOSPHERE PASS 2 -- DREAM (the Dreamscape). mapvibe 2026-10-25. Its own treatment: a sleeper's bedroom DISSOLVING into
-- the dream. Real meshes: ReplicatedStorage.RoomAtmoKit.Dream (tools/atmo_kit_dream.py -> tools/atmo_kit_dream_import.py):
-- Bed, Wardrobe, Armchair, FloorLamp, GrandClock, Hourglass, BookStack, Page, MeltClock.
-- PLACEMENT (its own pattern -- no other biome does this): along every wall the furniture GROWS from one end to the other
-- (dream scale, x0.75 .. x2), each piece SINKING into the floor at a tilt with pale ripples round it, never in a row.
--   CONTRAST  Light: sun x0.5, ambient x0.86, a lavender grade; terrain x0.72, parts x0.72 (the pastels read as pastel
--             AGAINST something now). The glows: rose lamp light, gold sand.
--   GROUND    sinking furniture along the walls (bed, wardrobe with light spilling out of its open door, grandfather clock,
--             armchair, floor lamps, book stacks); a MELTING CLOCK draped over one wardrobe's top. The floor: a field of the
--             dream's ground stones (terrain paint, 0 parts) and a TRAIL OF PAGES drifting from one door to another.
--   EDGE      a giant BOOK TOWER leaning in a corner
--   SET PIECE the Sandman's HOURGLASS toppled on its side, half sunk, a thin stream of gold sand falling out of the sky onto a
--             glowing dune beside it (1 light)
--   DRIFT     slow gold sand flecks falling
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.5, Ambient = 0.86, Outdoor = 0.86, Tint = C3(226, 212, 255), TintAmt = 0.3 }
B.Palette = { Dim = 0.72 }
B.PartDim = 0.72
B.Drift = { DreamSand = true }

local ROSE, GOLD, RIPPLE, RIPPLE2, DUNE = C3(255, 176, 214), C3(255, 206, 120), C3(214, 196, 240), C3(150, 132, 196), C3(214, 170, 96)
local FURNITURE = { "Bed", "Wardrobe", "GrandClock", "Armchair", "FloorLamp", "BookStack" }
local DEPTH = { Bed = 10, Wardrobe = 3.3, GrandClock = 2.2, Armchair = 4.5, FloorLamp = 4.6, BookStack = 4 } -- (kit depths, studs)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Emitter = A.Part, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    -- FLOOR FIELD (terrain paint, 0 parts; own Random so the layout draws stay put)
    A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Salt, 34 }, { M.Limestone, 26 }, { M.Glacier, 22 }, { M.Snow, 18 } }, { Scale = 26, Stretch = 2.4 })
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = root and root:FindFirstChild("Dream")
    local function Kit(name: string, at: Vector3, face: Vector3, k: number, tilt: CFrame?): (Model?, number)
        local t = KIT and KIT:FindFirstChild(name)
        if not (t and t:IsA("Model")) then return nil, 0 end
        local _, bb = t:GetBoundingBox()
        local cf = CFrame.lookAt(at, at + Vector3.new(face.X, 0, face.Z)) * (tilt or CFrame.new())
        local ok, m = pcall(A.PlaceModel, t, fx, cf, bb.Y * k, name)
        if not ok or not m then return nil, 0 end
        for _, q in ipairs(m:GetDescendants()) do
            if q:IsA("BasePart") then
                n += 1
                local role = q:GetAttribute("Role")
                if role == "Paper" then q.Color = Color3.fromRGB(156, 146, 166) -- (raw cream read as white litter under the lavender)
                elseif role == "Glass" then q.Transparency = 0.62; q.CastShadow = false
                elseif role == "Glow" or role == "Sand" then q.CastShadow = false end
            end
        end
        return m, bb.Y * k
    end
    local function Disc(name: string, at: Vector3, r: number, col: Color3, t: number, y: number)
        local d = Part(fx, name, Enum.PartType.Cylinder, Vector3.new(0.05, r * 2, r * 2 * vr:NextNumber(0.75, 1)),
            CFrame.new(at.X, F + y, at.Z) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)), col, M.SmoothPlastic)
        d.Transparency = t; d.CastShadow = false
        n += 1
    end

    -- SET PIECE first: the toppled hourglass, the sand stream, the dune
    local setAt: Vector3? = nil
    do
        local sd, spot = P.SetSpot(26, 11, nil)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z)
            setAt = at
            -- lying on its side along the wall (rolled about its front axis), a little turned, sunk a quarter of its girth
            local m = Kit("Hourglass", at, -o, vr:NextNumber(1.05, 1.25), CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(vr:NextNumber(-6, 6)), 0, 0))
            if m then
                local _, sz = m:GetBoundingBox()
                m:PivotTo(m:GetPivot() - Vector3.new(0, math.min(sz.X, sz.Y, sz.Z) * 0.22, 0))
                Disc("SinkRipple", at, math.max(sz.X, sz.Z) * 0.62, RIPPLE, 0.55, 0.08)
                Disc("SinkRipple", at, math.max(sz.X, sz.Z) * 0.85, RIPPLE2, 0.78, 0.07)
            end
            -- the dune of gold sand in front of it, and the stream falling out of the sky onto it
            local dune = at - o * 9 + al * vr:NextNumber(-3, 3)
            for i = 1, 4 do
                local r = 5.2 - i * 1.05
                local d = Part(fx, "SandDune", Enum.PartType.Cylinder, Vector3.new(0.7, r * 2, r * 2 * 0.85), CFrame.new(dune.X, F + 0.1 + i * 0.5, dune.Z) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)), DUNE, M.Sand)
                d.CastShadow = false
                n += 1
            end
            local top = Part(fx, "SandGlow", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(dune.X, F + 2.3, dune.Z), GOLD, M.Neon)
            top.CastShadow = false; top.Transparency = 0.25
            n += 1
            Emitter(fx, "SandFall", CFrame.new(dune + Vector3.new(0, 34, 0)) * CFrame.Angles(math.rad(-90), 0, 0), Vector3.new(0.6, 0.6, 0.2), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(GOLD), LightEmission = 1, LightInfluence = 0,
                Rate = 14, Lifetime = NumberRange.new(2.2, 2.4), Speed = NumberRange.new(0.5, 1), SpreadAngle = Vector2.new(2, 2), -- (40/s: particles 72 -> 174-314)
                Acceleration = Vector3.new(0, -13, 0), EmissionDirection = Enum.NormalId.Back,
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.22) }) })
            Emitter(fx, "SandSplash", CFrame.new(dune + Vector3.new(0, 2.4, 0)), Vector3.new(1, 0.2, 1), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(GOLD), LightEmission = 1, LightInfluence = 0,
                Rate = 3, Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -9, 0),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0) }) })
            if Lava then Lava.Glow(fx, dune + Vector3.new(0, 2.5, 0), 14, GOLD, 0.55, { Name = "DuneGlow", MaxDistance = 700 }) end
            local cc = A.Carrier(fx, "SandLight", Vector3.new(1, 1, 1), CFrame.new(dune + Vector3.new(0, 4, 0)))
            local l = Instance.new("PointLight")
            l.Color = GOLD; l.Range = 24; l.Brightness = 1.1; l.Shadows = false
            l.Parent = cc
            n += 1
        end
    end
    local function NearSet(p: Vector3, r: number): boolean
        return setAt ~= nil and (Vector3.new(p.X, 0, p.Z) - Vector3.new((setAt :: Vector3).X, 0, (setAt :: Vector3).Z)).Magnitude < r
    end

    -- THE SINKING FURNITURE: along every wall, growing from one end to the other
    local lampLit = false
    local drapeOn: { Model }? = nil
    local drapeInfo: any = nil
    for wi, sd in ipairs(P.order) do
        local o, al = P.SIDES[sd], P.Along(sd)
        local into = -o
        local dirSign = (vr:NextNumber() < 0.5) and -1 or 1 -- (which end is the small one)
        local count = vr:NextInteger(2, 3)
        local fs = {}
        for k = 1, count do fs[k] = -0.8 + (k - 0.5) * 1.6 / count + vr:NextNumber(-0.12, 0.12) end
        for k, f in ipairs(fs) do
            local name = FURNITURE[vr:NextInteger(1, #FURNITURE)]
            local grow = (f * dirSign + 0.8) / 1.6 -- 0 .. 1 along the wall
            local scale = 1.1 + 1.7 * grow + vr:NextNumber(-0.12, 0.12) -- (walls sheet: x0.75..2 read small at the wall foot)
            if name == "Bed" then scale *= 0.85 end
            local depth = DEPTH[name] * scale
            local inset = math.min(depth / 2 + vr:NextNumber(1.5, 4), 14) -- (a giant bed never reaches the fight lane)
            local at = C0 + o * (half - inset) + al * f * half
            at = Vector3.new(at.X, F, at.Z)
            if not P.DoorNear(at, 10 + depth * 0.5) and not NearSet(at, 16 + depth * 0.5) then
                local yaw = math.rad(vr:NextNumber(-35, 35))
                local face = (CFrame.Angles(0, yaw, 0) * CFrame.new(Vector3.zero, into)).LookVector
                local straight = (name == "Wardrobe" and drapeOn == nil)
                local tilt = straight and CFrame.new() or CFrame.Angles(math.rad(vr:NextNumber(-16, 10)), 0, math.rad(vr:NextNumber(-14, 14)))
                local m, h = Kit(name, at, straight and into or face, scale, tilt)
                if m then
                    local sink = straight and 0.08 or vr:NextNumber(0.1, 0.32)
                    m:PivotTo(m:GetPivot() - Vector3.new(0, h * sink, 0))
                    local _, sz = m:GetBoundingBox()
                    local foot = math.max(sz.X, sz.Z)
                    if sink > 0.15 then
                        Disc("SinkRipple", at, foot * 0.55, RIPPLE, 0.6, 0.08)
                        Disc("SinkRipple", at, foot * 0.78, RIPPLE2, 0.8, 0.07)
                    end
                    if straight then
                        drapeOn = { m }
                        drapeInfo = { At = at, Into = into, Top = F + h * (1 - sink), Depth = depth, Scale = scale }
                    end
                    if name == "FloorLamp" and not lampLit then
                        lampLit = true
                        local cc = A.Carrier(fx, "LampLight", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, h * (1 - sink) * 0.75, 0)))
                        local l = Instance.new("PointLight")
                        l.Color = ROSE; l.Range = 20; l.Brightness = 1; l.Shadows = false
                        l.Parent = cc
                        n += 1
                    end
                end
            end
        end
    end
    -- THE MELTING CLOCK draped over the straight wardrobe's front edge
    if drapeInfo then
        local t = KIT and KIT:FindFirstChild("MeltClock")
        if t and t:IsA("Model") then
            local _, bb = t:GetBoundingBox()
            local k = drapeInfo.Scale * 0.7
            local edge = drapeInfo.At + drapeInfo.Into * (drapeInfo.Depth / 2 + 0.1)
            local base = edge - drapeInfo.Into * 0.45 * k + Vector3.new(0, drapeInfo.Top + 0.05 - bb.Y * k - F, 0)
            Kit("MeltClock", base, drapeInfo.Into, k, nil)
        end
    end

    -- EDGE: a giant book tower leaning in a free corner
    do
        local corners = {}
        for _, a in ipairs({ { 1, 3 }, { 1, 4 }, { 2, 3 }, { 2, 4 } }) do
            local c = C0 + (P.SIDES[a[1]] + P.SIDES[a[2]]) * (half - 6)
            if not P.DoorNear(c, 14) and not NearSet(c, 22) then table.insert(corners, c) end
        end
        if #corners > 0 then
            local c = corners[vr:NextInteger(1, #corners)]
            Kit("BookStack", Vector3.new(c.X, F, c.Z), (C0 - c).Unit, vr:NextNumber(2.6, 3.2), CFrame.Angles(math.rad(vr:NextNumber(-8, -4)), 0, math.rad(vr:NextNumber(-5, 5))))
        end
    end

    -- THE TRAIL OF PAGES: drifting from one doorway toward another (or across the room), thinning out
    do
        local a, b
        if #P.doors >= 2 then
            a, b = P.doors[1], P.doors[2]
        else
            a = C0 + Vector3.new(-half * 0.6, 0, -half * 0.6); b = C0 + Vector3.new(half * 0.6, 0, half * 0.6)
        end
        a, b = Vector3.new(a.X, F, a.Z), Vector3.new(b.X, F, b.Z)
        local side = (b - a).Magnitude > 1 and (b - a).Unit:Cross(Vector3.yAxis) or Vector3.xAxis
        local bow = vr:NextNumber(-0.35, 0.35) * (b - a).Magnitude
        local placed = 0
        for i = 1, 22 do
            if placed >= 8 then break end
            local t = (i - 0.5) / 22
            local p = a:Lerp(b, t) + side * (math.sin(t * math.pi) * bow + vr:NextNumber(-4, 4))
            if math.abs(p.X - C0.X) < half - 4 and math.abs(p.Z - C0.Z) < half - 4 and not P.DoorNear(p, 8) and not NearSet(p, 12)
                and vr:NextNumber() < 0.75 - 0.35 * math.abs(t - 0.5) then
                Kit("Page", p, Vector3.new(math.cos(vr:NextNumber(0, 6.28)), 0, 1), vr:NextNumber(0.9, 1.3), CFrame.Angles(0, vr:NextNumber(0, 6.28), 0))
                placed += 1
            end
        end
    end

    -- DRIFT: slow gold sand flecks falling over the room
    Emitter(fx, "DreamSand", CFrame.new(C0 + Vector3.new(0, 22, 0)), Vector3.new(half * 1.6, 1, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(GOLD, ROSE), LightEmission = 0.8, LightInfluence = 0.2,
        Rate = 3, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -0.6, 0),
        EmissionDirection = Enum.NormalId.Bottom,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.14), NumberSequenceKeypoint.new(1, 0.08) }) })
    return n
end

return B
