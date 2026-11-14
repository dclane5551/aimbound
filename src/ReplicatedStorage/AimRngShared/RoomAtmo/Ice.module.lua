--!strict
-- ROOM ATMOSPHERE PASS 2 -- ICE (the frozen biome; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment, not the
-- molten one re-tinted (coordinator: "cold light, a frozen channel / meltwater band at wall feet, ice shelves and icicle
-- overhangs on the rim, a frozen set piece (a ship or giant's weapon in the ice), drifting snow"):
--   CONTRAST  Light: the low morning sun x0.45, ambient pulled toward blue, the grade a touch colder; palette x0.7 (snow /
--             ice / glacier x0.8-0.85: they stay the brightest thing in the room), parts x0.7.
--   GROUND    FROZEN CHANNELS at the wall foot: a cold meltwater glow under a translucent ice sheet, a wall of jagged ice
--             blocks behind, a low snow bank in front, cold glows + one cold PointLight a channel, frost mist off it. FROST
--             CRACKS run out of it (pale, a few bright), frozen puddles with their own cracks in the open floor, snow + ice
--             fields (terrain), low snow drifts, ice plates, ice shards -- all < 0.6 stud.
--   EDGE      ICE SHELVES jutting over the rim with ICICLES hanging off their front edge, ice-crystal spires on the rim
--   SET PIECE a GIANT'S SWORD driven point-down into a block of glacier ice at a wall (cold light at its foot)
--   DRIFT     snow blown low across the floor (on top of pass 1's falling snow)
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.35, Ambient = Color3.new(0.84, 0.9, 1), Outdoor = Color3.new(0.84, 0.9, 1), Tint = C3(200, 222, 255), TintAmt = 0.35 }
B.Palette = { Dim = 0.7, Mats = { [M.Snow] = 0.85, [M.Glacier] = 0.8, [M.Ice] = 0.8 }, Base = { [M.Snow] = C3(222, 230, 240) } }
B.PartDim = 0.7

local ICE, ICE_DEEP, SNOW = C3(178, 218, 240), C3(120, 175, 215), C3(225, 233, 242)
local GLOW = C3(150, 210, 255)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    -- FLOOR FIELD (terrain paint, 0 parts): the whole open floor in big irregular blobs / drifts of the biome's ground
    -- materials (A.PaintField; its own Random so the room's other draws -- the layout -- stay where they were). The big
    -- round field blobs below only draw their numbers when the field ran.
    local field = A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Snow, 40 }, { M.Glacier, 25 }, { M.Ice, 20 }, { M.Rock, 15 } }, { Scale = 24, Stretch = 2.2 }) > 0
    local function FieldPaint(x: number, z: number, r: number, mat: Enum.Material, rr: Random)
        if field then rr:NextNumber(0, math.pi * 2) else Paint(x, z, r, mat, rr) end
    end
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    -- FROZEN CHANNEL: meltwater glow under an ice sheet, ice-block wall behind, snow bank in front
    local function Channel(b0: Vector3, b1: Vector3, w: number, o: Vector3, light: boolean)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local cf = CFrame.lookAt(mid, mid + u)
        -- (meltwater: a cold Neon strip under the sheet -- not the lava image tinted: blue x orange = brown)
        local melt = Part(fx, "Meltwater", nil, Vector3.new(w * 0.55, 0.08, len), cf * CFrame.new(0, 0.16, 0), C3(120, 200, 255), M.Neon)
        melt.Transparency = 0.35; melt.CastShadow = false
        n += 1
        local sheet = Part(fx, "IceSheet", nil, Vector3.new(w, 0.25, len), cf * CFrame.new(0, 0.34, 0), ICE, M.Ice)
        sheet.Transparency = 0.38; sheet.Reflectance = 0.15; sheet.CastShadow = false
        n += 1
        -- the wall side: jagged ice blocks; the room side: a low snow bank
        local t = 0
        while t < len - 3 do
            local seg = math.min(vr:NextNumber(12, 18), len - t)
            local at = b0:Lerp(b1, (t + seg / 2) / len)
            local h = vr:NextNumber(2.5, 5.5)
            local base = Vector3.new(at.X, F + h / 2 - 1.8, at.Z) + o * (w / 2 + 1.2) -- (sunk: probe 1.3 over the wall foot)
            local blk = Part(fx, "IceBlock", nil, Vector3.new(2.6, h, seg - vr:NextNumber(0.5, 2)),
                CFrame.lookAt(base, base + u) * CFrame.Angles(math.rad(vr:NextNumber(-8, 8)), vr:NextNumber(-0.15, 0.15), math.rad(vr:NextNumber(-6, 6))), ICE_DEEP, M.Glacier)
            blk.Transparency = 0.12
            -- (the room side's snow bank = terrain snow along it: no parts)
            if ctx.Terrain then
                local lip = at - o * (w / 2 + 2)
                Paint(lip.X, lip.Z, 4, M.Snow, vr)
            end
            n += 1
            t += seg
        end
        local glows = math.max(1, math.floor(len / 24))
        for g = 1, glows do
            if Lava then Lava.Glow(fx, b0:Lerp(b1, (g - 0.5) / glows) + Vector3.new(0, F + 1.2 - b0.Y, 0), 22, GLOW, 0.45, { Name = "FrostGlow", MaxDistance = 400 }) end
        end
        if light then
            local c = A.Carrier(fx, "ColdLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 1.5, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(150, 200, 255); l.Range = 30; l.Brightness = 1.1; l.Shadows = false
            l.Parent = c
            n += 1
        end
        Emitter(fx, "FrostMist", CFrame.lookAt(mid + Vector3.new(0, 0.6, 0), mid + Vector3.new(0, 0.6, 0) + u), Vector3.new(w, 0.2, len), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(225, 238, 255)), LightInfluence = 0.8,
            Rate = math.clamp(len / 20, 1, 3), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.4, 1), EmissionDirection = Enum.NormalId.Top,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) }) })
        -- frost cracks out of it
        local al = Vector3.new(-o.Z, 0, o.X)
        for _ = 1, vr:NextInteger(2, 3) do
            local s = b0:Lerp(b1, vr:NextNumber(0.1, 0.9)) - o * (w / 2 + 1.6)
            n += A.Cracks(fx, P, ctx, vr, s, -o + al * vr:NextNumber(-0.5, 0.5), vr:NextNumber(0.8, 1.1),
                { Neon = true, Hot = C3(200, 235, 255), Dark = C3(120, 175, 225), HotT = 0.25, DarkT = 0.6, HotShare = 0.15, Wall = o, Reach = 40, Limit = 7, Y = 0.12 })
        end
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4.5, 18)
        if b0 then
            isBand[sd] = true
            Channel(b0, b1, wi == 1 and 6 or 4.8, P.SIDES[sd], wi == 1)
        end
    end
    -- THE OPEN FLOOR: snow + ice fields, frozen puddles with frost cracks, low drifts, ice plates, shards (< 0.6 stud)
    if ctx.Terrain then
        for _ = 1, vr:NextInteger(5, 7) do
            local p = P.Spot(12)
            FieldPaint(p.X, p.Z, vr:NextNumber(9, 16), ({ M.Snow, M.Snow, M.Glacier, M.Ice })[vr:NextInteger(1, 4)], vr)
        end
    end
    for _ = 1, vr:NextInteger(2, 3) do
        local p = P.Spot(14)
        if not P.DoorNear(p, 14) then
            local r = vr:NextNumber(2.2, 3.4)
            local pud = Part(fx, "FrozenPuddle", Enum.PartType.Cylinder, Vector3.new(0.16, r * 2, r * 2 * vr:NextNumber(0.7, 1)),
                CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)), C3(150, 205, 240), M.Ice)
            pud.Transparency = 0.2; pud.Reflectance = 0.2; pud.CastShadow = false
            n += 1
            for _ = 1, vr:NextInteger(2, 3) do
                local a = vr:NextNumber(0, math.pi * 2)
                n += A.Cracks(fx, P, ctx, vr, p, Vector3.new(math.cos(a), 0, math.sin(a)), vr:NextNumber(0.6, 0.85),
                    { Neon = true, Hot = C3(200, 235, 255), Dark = C3(120, 175, 225), HotT = 0.25, DarkT = 0.6, HotShare = 0.1, Limit = 4, Start = 1, Y = 0.12 })
            end
        end
    end
    for _ = 1, vr:NextInteger(4, 6) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            local cf = CFrame.new(p + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)
            if vr:NextNumber() < 0.4 and ctx.Terrain then
                -- (a snow drift = terrain snow; flat white parts read as boxes lying on the floor)
                Paint(p.X, p.Z, vr:NextNumber(4, 6), M.Snow, vr)
            else
                -- (an irregular clear-blue shard, never one rectangle)
                for _, pl in ipairs(A.Shard(fx, "IcePlate", p, vr:NextNumber(2.5, 4), 0.18, ICE_DEEP, M.Ice, vr)) do
                    pl.Transparency = 0.4; pl.Reflectance = 0.25
                end
            end
            n += 1
        end
    end
    for _ = 1, 2 do
        local c = P.Spot(10)
        for _ = 1, 3 do
            local sz = vr:NextNumber(0.35, 0.6)
            local sh = Part(fx, "IceShard", nil, Vector3.new(sz * 0.6, sz, sz * 1.6), CFrame.new(c + Vector3.new(vr:NextNumber(-3, 3), sz * 0.25, vr:NextNumber(-3, 3)))
                * CFrame.Angles(vr:NextNumber(-0.6, 0.6), vr:NextNumber(0, 6.28), vr:NextNumber(-0.6, 0.6)), ICE_DEEP, M.Glacier)
            sh.Transparency = 0.15; sh.CastShadow = false
            n += 1
        end
    end
    -- EDGE: ice shelves jutting over the rim with icicles off their front edge (two walls, away from doors)
    local shelves = 0
    for _, sd in ipairs(P.order) do
        if shelves >= 2 then break end
        local o = P.SIDES[sd]
        local al = P.Along(sd)
        local f = vr:NextNumber(-0.45, 0.45)
        local at = C0 + o * (half + 3) + al * f * half
        if not P.DoorNear(at, 24) then
            shelves += 1
            local y = F + vr:NextNumber(16, 22)
            local w, dp = vr:NextNumber(18, 26), vr:NextNumber(10, 13)
            local base = Vector3.new(at.X, y, at.Z)
            local cf = CFrame.lookAt(base, base - o) * CFrame.Angles(math.rad(-vr:NextNumber(4, 9)), 0, 0)
            local shelf = Part(fx, "IceShelf", nil, Vector3.new(w, 2.4, dp), cf, ICE_DEEP, M.Glacier)
            shelf.Transparency = 0.08
            Part(fx, "IceShelfSnow", nil, Vector3.new(w - 1, 1, dp - 1.5), cf * CFrame.new(0, 1.6, 0.6), SNOW, M.Snow)
            n += 2
            -- icicles along the front edge: a thick upper piece and a thin tip under it
            local front = cf * CFrame.new(0, -1.2, -dp / 2 + 0.8)
            for k = 1, vr:NextInteger(4, 6) do
                local x = (k / 7 - 0.5) * w + vr:NextNumber(-1, 1)
                local L1 = vr:NextNumber(3, 6)
                local top = front * CFrame.new(x, 0, 0)
                local ic = Part(fx, "Icicle", Enum.PartType.Wedge, Vector3.new(1.2, L1, 1.4), CFrame.new(top.Position - Vector3.new(0, L1 / 2, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0) * CFrame.Angles(math.pi, 0, 0), ICE, M.Ice) -- (a wedge upside down: a tooth pointing down)
                ic.Transparency = 0.15
                n += 1
            end
        end
    end
    -- EDGE: an ice-crystal spire on the rim at a corner (the biome's kit)
    if ctx.EnvKit and ctx.EnvKit.Has("Ice", "IceCrystalsA") then
        local o, o2 = P.SIDES[P.order[1]], P.SIDES[(P.order[1] <= 2) and 3 or 1]
        local corner = C0 + o * (half + 6) + o2 * (half + 6)
        local sz = ctx.EnvKit.Size("Ice", "IceCrystalsA")
        local k = sz and math.clamp(26 / math.max(sz.Y, 0.1), 0.5, 8) or 3
        ctx.EnvKit.Place("Ice", "IceCrystalsA", CFrame.new(corner - Vector3.new(0, 3, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), { Scale = k, Parent = fx, Hitbox = false, Name = "IceSpire" })
        n += 1
    end
    -- SET PIECE: a giant's sword driven point-down into a block of glacier ice at a wall
    do
        local sd, spot = P.SetSpot(24, 6, isBand)
        if sd and spot then
            local o = P.SIDES[sd]
            local al = P.Along(sd)
            local blockC = Vector3.new(spot.X, F + 3.3, spot.Z) + o * 2
            local blk = Part(fx, "SwordIce", nil, Vector3.new(18, 11, 12), CFrame.lookAt(blockC, blockC - o) * CFrame.Angles(0, vr:NextNumber(-0.25, 0.25), math.rad(vr:NextNumber(-4, 4))), C3(150, 200, 235), M.Glacier)
            blk.Transparency = 0.3
            Part(fx, "SwordIceSnow", nil, Vector3.new(17, 1.4, 11), blk.CFrame * CFrame.new(0, 6, 0), SNOW, M.Snow)
            -- the blade leans out toward the room a little; guard + grip high over the block
            local lean = CFrame.Angles(0, 0, 0)
            local axis = (Vector3.yAxis * math.cos(math.rad(16)) - o * math.sin(math.rad(16)) + al * 0.08).Unit
            local foot = blockC - Vector3.new(0, 3, 0)
            local bladeLen = 34
            local bc = foot + axis * (bladeLen / 2)
            local bcf = CFrame.fromMatrix(bc, axis:Cross(o).Unit, axis) * lean
            local blade = Part(fx, "GiantBlade", nil, Vector3.new(3, bladeLen, 0.8), bcf, C3(150, 158, 172), M.Metal)
            blade.Reflectance = 0.25
            Part(fx, "GiantFuller", nil, Vector3.new(0.9, bladeLen - 6, 0.9), bcf * CFrame.new(0, 1.5, 0), C3(90, 96, 108), M.Metal)
            local guardC = foot + axis * (bladeLen + 0.9)
            local gcf = CFrame.fromMatrix(guardC, axis:Cross(o).Unit, axis)
            Part(fx, "GiantGuard", nil, Vector3.new(14, 1.8, 2.2), gcf, C3(64, 66, 76), M.Metal)
            Part(fx, "GiantGrip", Enum.PartType.Cylinder, Vector3.new(8, 1.6, 1.6), CFrame.fromMatrix(foot + axis * (bladeLen + 5.8), axis, o), C3(64, 46, 36), M.Fabric)
            Part(fx, "GiantPommel", Enum.PartType.Ball, Vector3.new(3, 3, 3), CFrame.new(foot + axis * (bladeLen + 10.6)), C3(64, 66, 76), M.Metal)
            if Lava then Lava.Glow(fx, blockC, 16, GLOW, 0.4, { Name = "SwordGlow", MaxDistance = 500 }) end
            local c = A.Carrier(fx, "SwordLight", Vector3.new(1, 1, 1), CFrame.new(blockC - o * 7 + Vector3.new(0, 2, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(160, 210, 255); l.Range = 24; l.Brightness = 1; l.Shadows = false
            l.Parent = c
            if ctx.Terrain then Paint(spot.X - o.X * 6, spot.Z - o.Z * 6, 9, M.Snow, vr) end
            n += 8
        end
    end
    -- DRIFT: snow blown low across the floor
    Emitter(fx, "SnowDrift", CFrame.new(C0 + Vector3.new(0, 1.2, 0)), Vector3.new(half * 1.6, 0.4, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(235, 242, 255)), LightEmission = 0.4, LightInfluence = 0.6,
        Rate = 14, Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(10, 3),
        EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -0.4, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.08) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
