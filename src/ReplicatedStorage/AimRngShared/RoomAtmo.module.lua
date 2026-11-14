--!strict
-- ROOM ATMOSPHERE (MAPVIBE 2026-10-25). Owner: "why does it feel like only the first room has the atmosphere and everything
-- else is empty?" + "use POEs biomes and environment as an example to bring ours to life" (docs/MAP_REFERENCE_2026-10-25.md).
-- Room 1's life (BuildAmbience: motes, rain, embers, scenery) is centred on room 1 only. This gives EVERY other room of a
-- linked floor (main rooms, exit, side room; paths a lighter share) its own layer, built into that room's own visual folder
-- (dungeon.LinkedRooms.R<i>) so parking / LinkSleepFx / QualityMode already handle it -- only the room you are in and its
-- neighbours are drawn. Per room, varied by the room's own stream (never room 1 copied):
--   GROUND LAYERS  the floor's voxels re-painted (material only, the height never changes: FlushGround stays flush) in
--                  irregular blobs along the wall feet + a worn trail from door to door in the biome's path material
--   LIGHT POOLS    2-3 self-lit glows at wall feet in the biome's SIGNATURE colour (no Light objects); molten rooms get a
--                  lava trough set into one wall foot (LavaFX, no light)
--   AIR            one low mote / mist / spore / ember / snow emitter sized to the room (QualityMode Thin on Low); storm rooms
--                  one rain sheet
--   SET PIECE      one big biome kit piece set into a wall, off-centre (never mid-room; it stands past the wall line)
-- Budgets (per room): <= ~12 parts, 0 lights, <= ~30 particles/s. Studio A/B: workspace attr DevAtmoOff = true.
-- PASS 2 (2026-10-25): a biome's own dark, lit layer in a child module RoomAtmo/<Biome> -- see ATMOSPHERE PASS 2 near the end.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local M = Enum.Material

local RoomAtmo = {}

local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

-- per biome: Sig = the signature colour (light pools, motes), Mote2, Rise (motes rise / fall), Air = mote look, Ground =
-- edge layer materials, Trail = the worn path's material, Set = set-piece kit names (EnvKit set = Kit, or WorldProps world)
RoomAtmo.LOOK = {
    Fire = { Sig = C3(255, 110, 40), Mote2 = C3(255, 70, 30), Rise = true, Air = "Ember", Ground = { M.Basalt, M.CrackedLava }, Trail = M.Slate,
        Kit = "Fire", Set = { "Furnace", "FortTower", "BasaltSpire", "Cage" }, Lava = true },
    Ice = { Sig = C3(150, 200, 255), Mote2 = C3(235, 245, 255), Rise = false, Air = "Snow", Ground = { M.Snow, M.Glacier }, Trail = M.Ice,
        Kit = "Ice", Set = { "FrozenStatue", "MonasteryTower", "FrozenArch", "IceStatue" } },
    Void = { Sig = C3(170, 90, 255), Mote2 = C3(120, 70, 220), Rise = true, Air = "Mist", Ground = { M.Slate, M.Glacier }, Trail = M.Basalt,
        Kit = "Void", Set = { "EldritchArch", "VoidMonolith", "BrokenObelisk", "RuinTower" } },
    Cyber = { Sig = C3(60, 255, 190), Mote2 = C3(40, 200, 255), Rise = true, Air = "Mote", Ground = { M.DiamondPlate, M.Metal }, Trail = M.Concrete,
        Kit = "Cyber", Set = { "ServerRack", "Container", "Terminal", "NeonPole" } },
    Storm = { Sig = C3(150, 210, 255), Mote2 = C3(200, 225, 255), Rise = false, Air = "Rain", Ground = { M.Slate, M.Mud }, Trail = M.Pavement,
        Kit = "Storm", Set = { "TeslaTower", "StruckTree", "AqueductEnd", "Lighthouse" } },
    Dream = { Sig = C3(255, 150, 230), Mote2 = C3(190, 160, 255), Rise = true, Air = "Mote", Ground = { M.Salt, M.Glacier }, Trail = M.Marble },
    Flats = { Sig = C3(255, 90, 180), Mote2 = C3(255, 200, 120), Rise = true, Air = "Dust", Ground = { M.Sand, M.Salt }, Trail = M.Asphalt,
        Kit = "Flats", Set = { "FlatsSedan", "SecLight", "FlatsPole" } },
    -- the 12 worlds (their own kits: WorldProps.<World>)
    Jungle = { Sig = C3(120, 255, 140), Mote2 = C3(255, 230, 120), Rise = true, Air = "Spore", Ground = { M.LeafyGrass, M.Mud }, Trail = M.Limestone,
        World = "Jungle", Set = { "Idol", "RuinA", "Banyan" } },
    Gothic = { Sig = C3(170, 190, 255), Mote2 = C3(220, 220, 255), Rise = false, Air = "Mist", Ground = { M.Slate, M.Mud }, Trail = M.Cobblestone,
        World = "Gothic", Set = { "Angel", "Tomb", "Lantern", "ClockFace" } },
    Desert = { Sig = C3(255, 190, 90), Mote2 = C3(255, 230, 170), Rise = true, Air = "Dust", Ground = { M.Sand, M.Sandstone }, Trail = M.Sandstone,
        World = "Desert", Set = { "Obelisk", "Columns", "Palm" } },
    Abyss = { Sig = C3(60, 230, 230), Mote2 = C3(160, 120, 255), Rise = true, Air = "Bubble", Ground = { M.Sand, M.Rock }, Trail = M.Pebble,
        World = "Abyss", Set = { "Wreck", "SeaFan", "Kelp" } },
    Sakura = { Sig = C3(255, 150, 190), Mote2 = C3(255, 220, 230), Rise = false, Air = "Petal", Ground = { M.Grass, M.LeafyGrass }, Trail = M.Slate,
        World = "Sakura", Set = { "Torii", "Cherry", "Toro" } },
    Waste = { Sig = C3(170, 255, 60), Mote2 = C3(220, 255, 140), Rise = true, Air = "Spore", Ground = { M.Mud, M.Ground }, Trail = M.Concrete,
        World = "Waste", Set = { "Mast", "Bunker", "Scrap" } },
    Fungal = { Sig = C3(220, 120, 255), Mote2 = C3(140, 230, 255), Rise = true, Air = "Spore", Ground = { M.Mud, M.Rock }, Trail = M.Slate,
        World = "Fungal", Set = { "Shroom", "Pod", "Tendrils" } },
    Sky = { Sig = C3(255, 200, 110), Mote2 = C3(255, 240, 210), Rise = true, Air = "Dust", Ground = { M.WoodPlanks, M.Brick }, Trail = M.WoodPlanks,
        World = "Sky", Set = { "GearStand", "Boiler", "Lamp" } },
    Autumn = { Sig = C3(255, 150, 60), Mote2 = C3(230, 90, 40), Rise = false, Air = "Leaf", Ground = { M.LeafyGrass, M.Ground }, Trail = M.Cobblestone,
        World = "Autumn", Set = { "Maple", "Hay", "Arch" } },
    Station = { Sig = C3(120, 200, 255), Mote2 = C3(255, 120, 90), Rise = true, Air = "Mote", Ground = { M.DiamondPlate, M.Metal }, Trail = M.Concrete,
        World = "Station", Set = { "Console", "Pipes", "Reactor" } },
    Aztec = { Sig = C3(255, 200, 60), Mote2 = C3(80, 230, 140), Rise = true, Air = "Dust", Ground = { M.Limestone, M.Grass }, Trail = M.Limestone,
        World = "Aztec", Set = { "SunStone", "Brazier", "Serpent" } },
    Bayou = { Sig = C3(150, 255, 120), Mote2 = C3(200, 200, 120), Rise = true, Air = "Mist", Ground = { M.Mud, M.Grass }, Trail = M.WoodPlanks,
        World = "Bayou", Set = { "Shack", "Totem", "Cypress" } },
}

function RoomAtmo.On(): boolean
    return not (RunService:IsStudio() and Workspace:GetAttribute("DevAtmoOff") == true)
end

-- the floor's voxels re-painted (material only, never height): cells of the top two layers inside an irregular blob
local function Paint(cx: number, cz: number, r: number, mat: Enum.Material, vr: Random)
    local T = Workspace.Terrain
    local reg = Region3.new(Vector3.new(cx - r, -4, cz - r), Vector3.new(cx + r, 8, cz + r)):ExpandToGrid(4)
    local mats, occ = T:ReadVoxels(reg, 4)
    local sz = mats.Size
    local lo = reg.CFrame.Position - reg.Size / 2
    local wob = vr:NextNumber(0, math.pi * 2)
    local changed = false
    for i = 1, sz.X do
        for k = 1, sz.Z do
            local x, z = lo.X + (i - 0.5) * 4, lo.Z + (k - 0.5) * 4
            local a = math.atan2(z - cz, x - cx)
            local rr = r * (0.75 + 0.25 * math.sin(a * 3 + wob))
            if (x - cx) ^ 2 + (z - cz) ^ 2 <= rr * rr then
                for j = 1, sz.Y do
                    local m = mats[i][j][k]
                    if m ~= M.Air and m ~= M.Water and occ[i][j][k] > 0 then mats[i][j][k] = mat; changed = true end
                end
            end
        end
    end
    if changed then T:WriteVoxels(reg, 4, mats, occ) end
end

local function Carrier(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
    local p = Instance.new("Part")
    p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Transparency = 1; p.Size = size; p.CFrame = cf
    p.Parent = parent
    return p
end

local AIR = {
    Ember = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.22, Speed = { 2, 5 }, Acc = 0.5, Rate = 10 },
    Snow = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.28, Speed = { 1, 3 }, Acc = -0.7, Rate = 12 },
    Mist = { Tex = "rbxasset://textures/particles/smoke_main.dds", Size = 9, Speed = { 0.3, 0.8 }, Acc = 0, Rate = 1.6, Low = true, T = 0.86 },
    Mote = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.2, Speed = { 0.6, 1.6 }, Acc = 0.2, Rate = 8 },
    Spore = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.26, Speed = { 0.4, 1.2 }, Acc = 0.15, Rate = 8 },
    Dust = { Tex = "rbxasset://textures/particles/smoke_main.dds", Size = 3, Speed = { 1, 3 }, Acc = 0, Rate = 2, Low = true, T = 0.9, Side = true },
    Bubble = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.3, Speed = { 1, 2.4 }, Acc = 0.8, Rate = 8 },
    Petal = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.3, Speed = { 0.6, 1.4 }, Acc = -0.4, Rate = 8 },
    Leaf = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.34, Speed = { 0.8, 2 }, Acc = -0.5, Rate = 7 },
    Rain = { Tex = "rbxasset://textures/particles/sparkles_main.dds", Size = 0.16, Speed = { 48, 60 }, Acc = 0, Rate = 22, Rain = true },
}

local function Air(parent: Instance, L: any, cx: number, cz: number, half: number, F: number, light: boolean?)
    local a = AIR[L.Air] or AIR.Mote
    local y = a.Rain and (F + 34) or (a.Low and (F + 1.5) or (L.Rise and F + 2 or F + 22))
    local src = Carrier(parent, "AtmoAir", Vector3.new(half * 1.6, 1, half * 1.6), CFrame.new(cx, y, cz))
    local e = Instance.new("ParticleEmitter")
    e.Texture = a.Tex
    e.Color = ColorSequence.new(L.Sig, L.Mote2)
    e.LightEmission = a.Low and 0.2 or 1; e.LightInfluence = a.Low and 0.8 or 0
    e.Rate = a.Rate * (light and 0.45 or 1)
    e.Lifetime = a.Rain and NumberRange.new(0.9, 1.3) or NumberRange.new(6, 11)
    e.Speed = NumberRange.new(a.Speed[1], a.Speed[2])
    e.SpreadAngle = a.Rain and Vector2.new(4, 4) or Vector2.new(30, 30)
    e.EmissionDirection = a.Rain and Enum.NormalId.Bottom or ((L.Rise or a.Low) and Enum.NormalId.Top or Enum.NormalId.Bottom)
    e.Acceleration = Vector3.new(0, a.Acc, 0)
    e.Drag = 0.4
    if a.Rain then
        e.Size = NumberSequence.new(a.Size); e.Transparency = NumberSequence.new(0.2)
        e.Orientation = Enum.ParticleOrientation.VelocityParallel; e.Squash = NumberSequence.new(-2.5)
    else
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, a.Size * 0.5), NumberSequenceKeypoint.new(0.5, a.Size), NumberSequenceKeypoint.new(1, a.Size * 0.3) })
        local t = a.T or 0.15
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, t), NumberSequenceKeypoint.new(0.8, math.min(t + 0.15, 0.97)), NumberSequenceKeypoint.new(1, 1) })
        e.RotSpeed = NumberRange.new(-30, 30)
    end
    e.Parent = src
    CollectionService:AddTag(e, "QThin") -- (QualityMode: Low thins it)
end

-- ctx = { Biome, Tpl, X, Z, Half, Doors = { Vector3 }, Seed, Lava (LavaFX), EnvKit, Kind ("Room" | "Path"), Terrain (bool),
--         Box (path: { x0, x1, z0, z1 }) }
-- (optimization pass 2026-10-27) a pass-2 layer's own emitters were never tagged, so Graphics Quality Low kept them at
-- full rate: thin them like pass 1's air. Lights stay (pass-2 rooms are dark by design and lit by them).
local function LowTag(fx: Instance)
    for _, d in ipairs(fx:GetDescendants()) do
        if d:IsA("ParticleEmitter") and not CollectionService:HasTag(d, "QThin") and not CollectionService:HasTag(d, "QDetail") then
            CollectionService:AddTag(d, "QThin")
        end
    end
end

function RoomAtmo.Build(parent: Instance, ctx: any): number
    if not RoomAtmo.On() then return 0 end
    local L = RoomAtmo.LOOK[ctx.Biome]
    if not L then return 0 end
    do -- (a pass-2 biome may re-colour pass 1's own layers: def.Look = { Sig, Mote2, ... } over the LOOK row)
        local pd = RoomAtmo.Pilot2(ctx.Biome)
        if pd and pd.Look then L = setmetatable(table.clone(pd.Look), { __index = L }) :: any end
    end
    local vr = Random.new(ctx.Seed or 1)
    local F = 2
    local fx = Instance.new("Folder")
    fx.Name = "RoomAtmo"
    fx.Parent = parent
    if ctx.Kind == "Path" then
        local b = ctx.Box
        local cx, cz = (b[1] + b[2]) / 2, (b[3] + b[4]) / 2
        Air(fx, L, cx, cz, math.max(b[2] - b[1], b[4] - b[3]) / 3, F, true)
        local pd = RoomAtmo.Pilot2(ctx.Biome)
        if ctx.Terrain then Paint(cx, cz, 6, (pd and pd.Trail) or L.Trail, vr) end
        return 1
    end
    local cx, cz, half = ctx.X, ctx.Z, ctx.Half
    local n = 0
    local pilot = RoomAtmo.Pilot2(ctx.Biome) -- (ATMOSPHERE PASS 2: the biome's own layer; Fire's replaces the pass-1 trough + set piece)
    if pilot then
        local dg = parent.Parent and parent.Parent.Parent
        if dg then RoomAtmo.Dim(dg, parent, pilot.PartDim, pilot.SADim) end
    end
    -- GROUND LAYERS: blobs along the wall feet (the open middle stays the room's own ground) + the worn trail between doors
    if ctx.Terrain then
        for side = 1, 4 do
            local out = ({ Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) })[side]
            local along = Vector3.new(-out.Z, 0, out.X)
            for _ = 1, vr:NextInteger(1, 3) do
                local p = Vector3.new(cx, 0, cz) + out * (half - vr:NextNumber(3, 9)) + along * vr:NextNumber(-half * 0.8, half * 0.8)
                Paint(p.X, p.Z, vr:NextNumber(6, 13), L.Ground[vr:NextInteger(1, #L.Ground)], vr)
            end
        end
        local d = ctx.Doors or {}
        for i = 1, #d - 1 do
            local a, b = d[i], d[i + 1]
            local len = (Vector3.new(b.X - a.X, 0, b.Z - a.Z)).Magnitude
            local steps = math.floor(len / 5)
            for s = 1, steps - 1 do
                local t = s / steps
                local p = a:Lerp(b, t) + Vector3.new(vr:NextNumber(-2.5, 2.5), 0, vr:NextNumber(-2.5, 2.5))
                Paint(p.X, p.Z, vr:NextNumber(4, 5.5), (pilot and pilot.Trail) or L.Trail, vr)
            end
        end
    end
    -- LIGHT POOLS at 2-3 wall feet, never the same wall twice
    local Lava = ctx.Lava
    local used = {}
    for _ = 1, vr:NextInteger(2, 3) do
        local side = vr:NextInteger(1, 4)
        if not used[side] then
            used[side] = true
            local out = ({ Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) })[side]
            local along = Vector3.new(-out.Z, 0, out.X)
            local p = Vector3.new(cx, F + 1.2, cz) + out * (half - 2.5) + along * vr:NextNumber(-half * 0.7, half * 0.7)
            if Lava then
                Lava.Glow(fx, p, vr:NextNumber(16, 26), L.Sig, 0.45, { Name = "AtmoGlow", MaxDistance = 260, Bright = 1.3 })
                n += 1
                if L.Lava and n == 1 and not pilot then
                    -- a lava trough set into this wall's foot (molten rooms)
                    local a0 = p + along * -11 - Vector3.new(0, 0.95, 0)
                    local a1 = p + along * 11 - Vector3.new(0, 0.95, 0)
                    Lava.Flow(fx, a0, a1, 3, { Light = false, Smoke = false, Sparks = false, Speed = 0.06 })
                    -- glowing cracks running in from the wall feet (thin, never across the middle of the room)
                    for _ = 1, vr:NextInteger(3, 5) do
                        local s3 = vr:NextInteger(1, 4)
                        local o3 = ({ Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) })[s3]
                        local a3 = Vector3.new(-o3.Z, 0, o3.X)
                        local c0 = Vector3.new(cx, F + 0.3, cz) + o3 * (half - 1) + a3 * vr:NextNumber(-half * 0.8, half * 0.8)
                        local dir = (-o3 + a3 * vr:NextNumber(-0.6, 0.6)).Unit
                        local len = vr:NextNumber(8, 16)
                        local mid = c0 + dir * len * 0.5 + a3 * vr:NextNumber(-1.5, 1.5)
                        Lava.Flow(fx, c0, mid, vr:NextNumber(0.7, 1.1), { Light = false, Smoke = false, Sparks = false, Speed = 0.04 })
                        Lava.Flow(fx, mid, c0 + dir * len, vr:NextNumber(0.5, 0.8), { Light = false, Smoke = false, Sparks = false, Speed = 0.04 })
                    end
                    -- + a few crusted lava pools at the wall feet (reference: the cracked, glowing floors of a forge)
                    for _ = 1, vr:NextInteger(1, 2) do
                        local s2 = vr:NextInteger(1, 4)
                        local o2 = ({ Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) })[s2]
                        local a2 = Vector3.new(-o2.Z, 0, o2.X)
                        local pp = Vector3.new(cx, F + 0.25, cz) + o2 * (half - vr:NextNumber(5, 9)) + a2 * vr:NextNumber(-half * 0.6, half * 0.6)
                        Lava.Pool(fx, CFrame.new(pp) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), vr:NextNumber(2.5, 4.5), { Light = false, Smoke = false, Sparks = false })
                    end
                end
            end
        end
    end
    -- AIR
    Air(fx, L, cx, cz, half, F)
    if pilot then
        local m = pilot.Build(fx, ctx, vr, RoomAtmo.API)
        LowTag(fx)
        return n + m
    end
    -- SET PIECE: one big kit piece set into a wall, off-centre (past the wall line: never in the fight box)
    if L.Set and (ctx.EnvKit or L.World) then
        local name = L.Set[vr:NextInteger(1, #L.Set)]
        local tmpl
        if L.World then
            local wp = game:GetService("ReplicatedStorage"):FindFirstChild("WorldProps")
            local w = wp and wp:FindFirstChild(L.World)
            tmpl = w and w:FindFirstChild(name)
        elseif ctx.EnvKit and ctx.EnvKit.Has(L.Kit, name) then
            tmpl = ctx.EnvKit.Get(L.Kit, name)
        end
        if tmpl and tmpl:IsA("Model") then
            local side = vr:NextInteger(1, 4)
            -- (not the wall with the most doors: try the four, take the first without a door within 18 of the spot)
            for _ = 1, 4 do
                local out = ({ Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) })[side]
                local along = Vector3.new(-out.Z, 0, out.X)
                local u = (vr:NextNumber() < 0.5 and -1 or 1) * vr:NextNumber(0.3, 0.6) * half
                local spot = Vector3.new(cx, F, cz) + out * half + along * u
                local clear = true
                for _, dp in ipairs(ctx.Doors or {}) do
                    if (Vector3.new(dp.X - spot.X, 0, dp.Z - spot.Z)).Magnitude < 18 then clear = false end
                end
                if clear then
                    local m = tmpl:Clone()
                    for _, q in ipairs(m:GetDescendants()) do
                        if q:IsA("BasePart") then q.Anchored = true; q.CanCollide = false; q.CanQuery = false; q.CanTouch = false end
                    end
                    local _, bb = m:GetBoundingBox()
                    local k = math.clamp(22 / math.max(bb.Y, 0.1), 0.6, 2.6) -- (a landmark's height: ~22 studs)
                    pcall(function() m:ScaleTo(m:GetScale() * k) end)
                    local _, bb2 = m:GetBoundingBox()
                    local depth = math.max(bb2.X, bb2.Z) * 0.5
                    m:PivotTo(CFrame.lookAt(spot + out * (depth * 0.45 + 1.5), spot - out * 10) * CFrame.Angles(0, vr:NextNumber(-0.25, 0.25), 0))
                    local cf3, bb3 = m:GetBoundingBox()
                    m:PivotTo(m:GetPivot() + Vector3.new(0, F - 0.6 - (cf3.Position.Y - bb3.Y / 2), 0))
                    m.Name = "AtmoSet_" .. name
                    m:SetAttribute("Src", name)
                    m.Parent = fx
                    n += 1
                    break
                end
                side = side % 4 + 1
            end
        end
    end
    return n
end

-- ==================== ATMOSPHERE PASS 2 (2026-10-25): A BIOME'S OWN ROOMS ====================
-- (coordinator after the owner's reference: "after is almost the same image as before ... evenly lit, flat, empty floor
-- with a plain rock rim; the reference is dark, with lava troughs cut into the architecture as the light source". Molten
-- pilot approved, then "ROLL OUT with each biome's own treatment, not lava re-tinted")
-- Every biome with a pass-2 treatment is a CHILD MODULE of this one: RoomAtmo/<Biome> (the RoomAtmo.LOOK key: Fire, Ice,
-- Bayou ...). Its file is all its own, so builders can work on different biomes in parallel. A child returns a table:
--   Light   = { Sun = x (sun Brightness multiplier), Ambient = x | Color3 (multiplier), Outdoor = x | Color3, Exposure = +-n,
--               Tint = Color3 (grade tint goal), TintAmt = 0..1, FogEnd = x, FogColor = Color3 }
--   Palette = { Dim = x (every terrain material of the biome's palette), Mats = { [Enum.Material] = x | Color3 } (overrides),
--               Base = { [Enum.Material] = Color3 } (materials its maps use that the client palette lacks) }
--   PartDim = x                      every non-glowing part of the floor (RoomAtmo.Dim; enemies / portals / loot never)
--   Build(fx, ctx, vr, A) -> parts   the room's layer, in the room's RoomAtmo folder, after pass 1 (A = RoomAtmo.API)
-- A layer has: the WALL-FOOT BAND (A.Plan(ctx, vr).Band), a crack / FLOOR-DETAIL field (Spot, A.Cracks, A.Paint), EDGE
-- silhouettes outside the box, ONE SET PIECE (Plan.SetSpot), a DRIFT layer (A.Emitter). Rules: never in the fight lane or a
-- doorway, no collision / query, <= ~60 parts + <= 3 lights a room, the gun checked with the GearLight plate test.
-- Studio A/B: workspace attr DevAtmo2Off = true (pass 1 only). The client asks RoomAtmo.Light / Palette in ApplyLightProfile.
-- How to add a biome: docs/MAPVIBE_PLAN_2026-10-24.md "PASS 2: HOW TO ADD A BIOME".
local PASS2 = {}
function RoomAtmo.Pass2Def(biome: string?): any
    if not biome then return nil end
    local d = PASS2[biome]
    if d == nil then
        d = false
        local m = script:FindFirstChild(biome)
        if m and m:IsA("ModuleScript") then
            local ok, r = pcall(require, m)
            if ok and type(r) == "table" then d = r else warn("[RoomAtmo] pass 2 " .. biome .. ": " .. tostring(r)) end
        end
        PASS2[biome] = d
    end
    return d or nil
end
function RoomAtmo.Pilot2(biome: string?): any
    local d = RoomAtmo.Pass2Def(biome)
    if not d or not RoomAtmo.On() then return nil end
    if RunService:IsStudio() and Workspace:GetAttribute("DevAtmo2Off") == true then return nil end
    return d
end
local function Mul(c: Color3, k: any): Color3
    if typeof(k) == "Color3" then return Color3.new(c.R * k.R, c.G * k.G, c.B * k.B) end
    return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end
-- the client light setup passes its terrain palette for `key` through here (AimRngClient TERRAIN PALETTES)
function RoomAtmo.Palette(key: string, want: { [Enum.Material]: Color3 }): { [Enum.Material]: Color3 }
    local biome = string.match(key or "", "^([%a]+)")
    local d = RoomAtmo.Pilot2(biome)
    if not d or string.find(key, "Boss") or not d.Palette then return want end
    local P = d.Palette
    local out = {}
    for mat, col in pairs(P.Base or {}) do out[mat] = col end
    for mat, col in pairs(want) do out[mat] = col end
    for mat, col in pairs(out) do
        local k = (P.Mats and P.Mats[mat]) or P.Dim or 1
        out[mat] = Mul(col, k)
    end
    return out
end
-- the Atmosphere under a biome's pass 2: a = { Density, Color, Decay, Haze, Glare } (the client's ATMO row, a copy back);
-- d.Atmo = the same fields by name (Density / Haze / Glare: x, Color / Decay: a Color3 that replaces)
function RoomAtmo.Atmo(key: string, a: any): any
    local biome = string.match(key or "", "^([%a]+)")
    local d = RoomAtmo.Pilot2(biome)
    if not d or string.find(key, "Boss") or not a or not d.Atmo then return a end
    local T = d.Atmo
    local q = table.clone(a)
    if T.Density then q[1] = a[1] * T.Density end
    if T.Color then q[2] = T.Color end
    if T.Decay then q[3] = T.Decay end
    if T.Haze then q[4] = a[4] * T.Haze end
    if T.Glare then q[5] = a[5] * T.Glare end
    return q
end
-- ROOM 1 (coordinator 2026-10-25: "pass 2 runs on rooms 2.. only, so the FIRST room is now the plainest"): a biome's pass 2
-- in the combat room every floor starts in (linked or not, not boss arenas), called once from DungeonGenerator after the
-- room is finished (flush ground, props, portal-zone clear). Pass 1 never ran here -- the room's air is BuildAmbience's --
-- so only pass 2's layer, minus its whole-room DRIFT emitters (no double drift). ctx as Build + Keep (boxes, see Plan).
RoomAtmo.DRIFT = { SnowDrift = true, Pollen = true, WindRain = true, VoidMist = true, FloorMist = true, SporeHaze = true, BigSpores = true }
function RoomAtmo.BuildRoom1(dungeon: Instance, ctx: any): number
    if not RoomAtmo.On() then return 0 end
    local pilot = RoomAtmo.Pilot2(ctx.Biome)
    if not pilot then return 0 end
    RoomAtmo.Dim(dungeon, nil, pilot.PartDim, pilot.SADim) -- (a floor with no linked rooms never dimmed its parts)
    local fx = Instance.new("Folder")
    fx.Name = "RoomAtmo"
    fx:SetAttribute("Room1", true)
    fx.Parent = dungeon
    ctx.Room1 = true
    local drift = pilot.Drift or RoomAtmo.DRIFT -- (a module may name its own drift emitters: def.Drift = { name = true })
    local A = table.clone(RoomAtmo.API)
    A.Emitter = function(parent: Instance, name: string, cf: CFrame, size: Vector3, props: any)
        if drift[name] then return nil end
        return RoomAtmo.API.Emitter(parent, name, cf, size, props)
    end
    local ok, n = pcall(pilot.Build, fx, ctx, Random.new(ctx.Seed or 1), A)
    if not ok then warn("[RoomAtmo] room 1 " .. tostring(ctx.Biome) .. ": " .. tostring(n)); return 0 end
    LowTag(fx)
    fx:SetAttribute("Parts", n)
    return n
end
-- the light profile under a biome's pass 2 (a copy)
function RoomAtmo.Light(key: string, p: any): any
    local biome = string.match(key or "", "^([%a]+)")
    local d = RoomAtmo.Pilot2(biome)
    if not d or string.find(key, "Boss") or not p or not d.Light then return p end
    local L = d.Light
    local q = table.clone(p)
    if L.Sun then q.Brightness = (p.Brightness or 1) * L.Sun end
    if L.Ambient and p.Ambient then q.Ambient = Mul(p.Ambient, L.Ambient) end
    if L.Outdoor and p.OutdoorAmbient then q.OutdoorAmbient = Mul(p.OutdoorAmbient, L.Outdoor) end
    if L.Exposure then q.Exposure = (p.Exposure or 0) + L.Exposure end
    if L.Tint and p.CCTint then q.CCTint = p.CCTint:Lerp(L.Tint, L.TintAmt or 0.5) end
    if L.FogEnd and p.FogEnd then q.FogEnd = p.FogEnd * L.FogEnd end
    if L.FogColor then q.FogColor = L.FogColor end
    return q
end
local KEEP = { Portal = true, Chest = true, Vault = true, Merchant = true, Encounter = true, LinkCache = true, GroundLoot = true }
-- every non-glowing part of the floor darker (once a floor + every linked room folder handed in, parked or not; skips enemies,
-- portals, chests, anything with a prompt, Neon, glass, the atmosphere layers' own pieces)
local DIM_ROOMS = setmetatable({}, { __mode = "k" })
function RoomAtmo.Dim(dungeon: Instance, room: Instance?, k: number?, kSA: number?)
    local list = DIM_ROOMS[dungeon]
    if room then
        if not list then list = {}; DIM_ROOMS[dungeon] = list end
        table.insert(list, room)
    end
    if dungeon:GetAttribute("AtmoDim") then return end
    dungeon:SetAttribute("AtmoDim", true)
    local kk = k or 0.55
    -- (hubfix 2026-10-25: SurfaceAppearance-textured props (scans: MossRock, BoulderE, HorseHead, Vase, Color 255) were dimmed
    -- by the same factor -- measured in Jungle room 2: SA.Color = 0.69 x the kit Tint -- but a bright scan texture still reads
    -- pale next to plain parts. A biome may dim them harder: def.SADim (default = PartDim). The original SA colour is kept
    -- in attr AtmoOrig on the SurfaceAppearance.)
    local ks = kSA or kk
    task.spawn(function()
        for _ = 1, 200 do
            if dungeon:IsDescendantOf(Workspace) then break end
            task.wait(0.05)
        end
        task.wait(0.2)
        local function Skip(x: Instance, top: Instance): boolean
            local p = x
            while p and p ~= top do
                if CollectionService:HasTag(p, "AimRngEnemy") or (p:IsA("Model") and p:FindFirstChildOfClass("Humanoid")) then return true end
                for word in pairs(KEEP) do if string.find(p.Name, word) then return true end end
                if p.Name == "RoomAtmo" or p.Name == "Ambience" then return true end
                p = p.Parent
            end
            return false
        end
        local seen, n = {}, 0
        local function Pass(top: Instance)
            for _, x in ipairs(top:GetDescendants()) do
                if x:IsA("BasePart") and not seen[x] and x.Material ~= Enum.Material.Neon and x.Material ~= Enum.Material.Glass and x.Transparency < 0.95 then
                    seen[x] = true
                    if not x:FindFirstChildWhichIsA("ProximityPrompt") and not Skip(x, top) then
                        local sa = x:FindFirstChildOfClass("SurfaceAppearance")
                        if sa then
                            if sa:GetAttribute("AtmoOrig") == nil then sa:SetAttribute("AtmoOrig", sa.Color) end
                            sa.Color = Color3.new(sa.Color.R * ks, sa.Color.G * ks, sa.Color.B * ks)
                        else x.Color = Color3.new(x.Color.R * kk, x.Color.G * kk, x.Color.B * kk) end
                        for _, t in ipairs(x:GetChildren()) do
                            if t:IsA("Texture") or t:IsA("Decal") then t.Color3 = Color3.new(t.Color3.R * kk, t.Color3.G * kk, t.Color3.B * kk) end
                        end
                        n += 1
                    end
                end
            end
        end
        Pass(dungeon)
        for _, r in ipairs(DIM_ROOMS[dungeon] or {}) do Pass(r) end
        dungeon:SetAttribute("AtmoDimmed", n)
    end)
end

-- ---- RoomAtmo.API: the shared toolkit a biome's Build gets as A ----
local function Part(parent: Instance, name: string, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): Part
    local p = Instance.new("Part")
    p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = true
    if shape then p.Shape = shape end
    p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat
    p.Parent = parent
    return p
end
local SIDES = { Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) }
-- a ParticleEmitter on an invisible carrier (tagged QThin: Low graphics thins it); props = the emitter's properties
local function Emitter(parent: Instance, name: string, cf: CFrame, size: Vector3, props: { [string]: any }): ParticleEmitter
    local src = Carrier(parent, name, size, cf)
    local e = Instance.new("ParticleEmitter")
    for k, v in pairs(props) do (e :: any)[k] = v end
    e.Parent = src
    CollectionService:AddTag(e, "QThin")
    return e
end
-- the room's layout helpers: walls without a door, a wall-foot band clear of doors / massifs, interior spots, a set-piece spot
local function Plan(ctx: any, vr: Random): any
    local P: any = {}
    P.F = 2
    P.cx, P.cz, P.half = ctx.X, ctx.Z, ctx.Half
    P.C0 = Vector3.new(ctx.X, P.F, ctx.Z)
    P.doors = ctx.Doors or {}
    P.SIDES = SIDES
    P.keep = ctx.Keep or {} -- (room 1: { { x0, x1, z0, z1 } } boxes nothing may stand in -- the entry wall + its rim, the merchant /
    -- event spot, the portal row; DoorNear says yes for any point inside one)
    function P.DoorNear(p: Vector3, r: number): boolean
        for _, dp in ipairs(P.doors) do if (Vector3.new(dp.X - p.X, 0, dp.Z - p.Z)).Magnitude < r then return true end end
        for _, b in ipairs(P.keep) do if p.X >= b[1] and p.X <= b[2] and p.Z >= b[3] and p.Z <= b[4] then return true end end
        return false
    end
    function P.Along(sd: number): Vector3 local o = SIDES[sd]; return Vector3.new(-o.Z, 0, o.X) end
    local order = { 1, 2, 3, 4 }
    for i = 4, 2, -1 do local j = vr:NextInteger(1, i); order[i], order[j] = order[j], order[i] end
    P.order = order
    local function Clear(sd: number): boolean return not P.DoorNear(P.C0 + SIDES[sd] * (P.half - 6), P.half * 0.75) end
    local walls = {}
    for _, sd in ipairs(order) do
        if Clear(sd) then
            table.insert(walls, sd)
            local opp = (sd % 2 == 1) and sd + 1 or sd - 1
            if Clear(opp) then table.insert(walls, opp) end
            break
        end
    end
    P.walls = walls -- (0-2 doorless walls, the opposite pair first)
    -- a band along wall sd, `inset` studs in from the wall line, trimmed 14 short of a door on that wall and (terrain maps) to
    -- its longest stretch where the wall foot is open floor (a voxel read of the cell above the floor). nil if < minLen
    function P.Band(sd: number, inset: number, minLen: number?): (Vector3?, Vector3?)
        local o = SIDES[sd]
        local al = P.Along(sd)
        local half = P.half
        local mid = P.C0 + o * (half - inset)
        local b0, b1 = mid - al * half * 0.62, mid + al * half * 0.62
        for _, dp in ipairs(P.doors) do
            local rel = Vector3.new(dp.X, 0, dp.Z) - Vector3.new(mid.X, 0, mid.Z)
            if math.abs(rel:Dot(o)) < 12 then
                local du = rel:Dot(al)
                if du > 0 then b1 = mid + al * math.min(half * 0.62, du - 14) else b0 = mid + al * math.max(-half * 0.62, du + 14) end
            end
        end
        local need = minLen or 16
        if (b1 - b0).Magnitude < need then return nil, nil end
        if ctx.Terrain then
            local T = Workspace.Terrain
            local d = b1 - b0
            local len = Vector3.new(d.X, 0, d.Z).Magnitude
            local steps = math.max(1, math.floor(len / 4))
            local open = {}
            for k = 0, steps do
                local q = b0:Lerp(b1, k / steps) - o * 2.5
                local gx, gz = math.floor(q.X / 4) * 4, math.floor(q.Z / 4) * 4
                local _, occ = T:ReadVoxels(Region3.new(Vector3.new(gx, 4, gz), Vector3.new(gx + 4, 8, gz + 4)), 4)
                open[k] = occ[1][1][1] < 0.3
            end
            local bestA, bestB, a = nil, nil, nil
            for k = 0, steps + 1 do
                if open[k] then a = a or k
                elseif a then
                    if not bestA or (k - 1 - a) > (bestB - bestA) then bestA, bestB = a, k - 1 end
                    a = nil
                end
            end
            if not bestA or (bestB - bestA) * len / steps < need then return nil, nil end
            b0, b1 = b0:Lerp(b1, bestA / steps), b0:Lerp(b1, bestB / steps)
        end
        return b0, b1
    end
    -- a random interior floor point at least `margin` in from the walls (y = floor)
    function P.Spot(margin: number): Vector3
        return P.C0 + Vector3.new(vr:NextNumber(-1, 1) * (P.half - margin), 0, vr:NextNumber(-1, 1) * (P.half - margin))
    end
    -- a set-piece spot at a wall foot `inset` in, no door within `clear`: walls not in `avoid` first, each tried at the
    -- corners first (a door wall's middle is never clear). Returns sd, spot (floor y), along-fraction (+-)
    function P.SetSpot(clear: number, inset: number, avoid: { [number]: boolean }?): (number?, Vector3?, number?)
        local cands = {}
        for _, sd in ipairs(order) do if not (avoid and avoid[sd]) then table.insert(cands, sd) end end
        for _, sd in ipairs(order) do if avoid and avoid[sd] then table.insert(cands, sd) end end
        for _, sd in ipairs(cands) do
            for _, f in ipairs({ 0.7, 0.55, 0.35 }) do
                local sg = vr:NextNumber() < 0.5 and -1 or 1
                for _, fr in ipairs({ f * sg, -f * sg }) do
                    local spot = P.C0 + SIDES[sd] * (P.half - inset) + P.Along(sd) * fr * P.half
                    if not P.DoorNear(spot, clear) then return sd, spot, fr end
                end
            end
        end
        return nil, nil, nil
    end
    return P
end
-- a branching crack / seam network on the floor (flat self-lit strips from ctx.Lava's Flow) from p along dir. opts = { Hot =
-- tint of the bright ones (nil = the image's own lava colour), Dark = tint of the dull ones, HotShare, HotBright, DarkBright,
-- MaxDepth, Wall = o (stay within Reach of that wall), Reach, Limit (segments), Y, Speed, Start (depth), Neon (flat Neon strips in
-- Hot / Dark instead of the lava image -- any colour; HotT / DarkT = their transparency) }. Returns segments.
local function Cracks(fx: Instance, P: any, ctx: any, vr: Random, p: Vector3, dir: Vector3, w: number, opts: any): number
    local Lava = ctx.Lava
    if not Lava then return 0 end
    local count = 0
    local limit = opts.Limit or 25
    local holder: BasePart? = nil
    local function Seg(a: Vector3, d: Vector3, wd: number, depth: number)
        if count >= limit then return end
        local q = a + d * vr:NextNumber(opts.Seg and opts.Seg[1] or 4, opts.Seg and opts.Seg[2] or 9)
        local rel = q - P.C0
        if math.abs(rel.X) > P.half - 3 or math.abs(rel.Z) > P.half - 3 then return end
        if opts.Wall and rel:Dot(opts.Wall) < P.half - (opts.Reach or 46) then return end
        if P.DoorNear(q, 9) then return end
        local hot = depth == 0 or vr:NextNumber() < (opts.HotShare or 0.12)
        local y = opts.Y or 0.3
        if opts.Neon then
            -- (a flat untextured Beam in the given colours: the lava image is orange and a tint only multiplies it -- blue x
            -- orange came out brown on the ice. Beams on one carrier: no part a segment)
            if not holder then holder = Carrier(fx, "Seams", Vector3.new(0.2, 0.2, 0.2), CFrame.new(P.C0)) end
            local p0, p1 = a + Vector3.new(0, y, 0), q + Vector3.new(0, y, 0)
            local fwd = (p1 - p0).Unit
            local side = fwd:Cross(Vector3.yAxis).Unit
            local function At(pos: Vector3): Attachment
                local at = Instance.new("Attachment")
                at.CFrame = holder.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, Vector3.yAxis, side, Vector3.yAxis:Cross(side)))
                at.Parent = holder
                return at
            end
            local b = Instance.new("Beam")
            b.Attachment0, b.Attachment1 = At(p0), At(p1)
            b.FaceCamera = false; b.Segments = 1; b.Width0 = wd * 0.6; b.Width1 = wd * 0.5
            b.Color = ColorSequence.new(hot and (opts.Hot or Color3.new(1, 1, 1)) or (opts.Dark or Color3.new(0.5, 0.5, 0.5)))
            local t0 = hot and (opts.HotT or 0.2) or (opts.DarkT or 0.55)
            b.Transparency = NumberSequence.new(t0, math.min(1, t0 + (opts.Fade or 0)))
            b.LightEmission = 1; b.LightInfluence = 0
            b.Parent = holder
        else
            Lava.Flow(fx, a + Vector3.new(0, y, 0), q + Vector3.new(0, y, 0), wd, { Light = false, Smoke = false, Sparks = false, Speed = opts.Speed or 0.03,
                Tint = hot and opts.Hot or opts.Dark, Bright = hot and (opts.HotBright or 1.9) or (opts.DarkBright or 1.1) })
        end
        count += 1
        if depth < (opts.MaxDepth or 4) then
            local turn = vr:NextNumber(opts.Turn and opts.Turn[1] or 0.25, opts.Turn and opts.Turn[2] or 0.7)
            Seg(q, (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, d)).LookVector, math.max(0.35, wd * 0.72), depth + 1)
            if vr:NextNumber() < 0.5 then Seg(q, (CFrame.Angles(0, -turn, 0) * CFrame.new(Vector3.zero, d)).LookVector, math.max(0.35, wd * 0.62), depth + 1) end
        end
    end
    Seg(Vector3.new(p.X, P.F, p.Z), dir.Unit, w, opts.Start or 0)
    return count
end
-- a WorldProps model (the 12 worlds' kits) or nil
local function WorldProp(world: string, name: string): Model?
    local wp = game:GetService("ReplicatedStorage"):FindFirstChild("WorldProps")
    local w = wp and wp:FindFirstChild(world)
    local m = w and w:FindFirstChild(name)
    return (m and m:IsA("Model")) and m or nil
end
-- a clone of a model, anchored and visual only (no collision / query / touch), scaled to `height`, bottom centre at cf
local function PlaceModel(tmpl: Model, parent: Instance, cf: CFrame, height: number, name: string?): Model
    local m = tmpl:Clone()
    for _, q in ipairs(m:GetDescendants()) do
        if q:IsA("BasePart") then q.Anchored = true; q.CanCollide = false; q.CanQuery = false; q.CanTouch = false
        elseif q:IsA("Script") or q:IsA("LocalScript") or q:IsA("Sound") then q:Destroy() end
    end
    local _, bb = m:GetBoundingBox()
    pcall(function() m:ScaleTo(m:GetScale() * math.clamp(height / math.max(bb.Y, 0.1), 0.2, 8)) end)
    m:PivotTo(cf)
    -- seat on the WORLD-space box (every part's 8 corners): Model:GetBoundingBox is in the model's own oriented frame, so a
    -- tilted / lying / leaning model was lifted by half its LOCAL height (hubfix: a mushroom on its side floated ~12 studs)
    local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, q in ipairs(m:GetDescendants()) do
        if q:IsA("BasePart") and q.Transparency < 1 then
            local h = q.Size / 2
            for _, c in ipairs({ Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1),
                Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) }) do
                local w = q.CFrame:PointToWorldSpace(h * c)
                lo = Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
                hi = Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
            end
        end
    end
    if lo.Y < math.huge then
        m:PivotTo(m:GetPivot() + Vector3.new(cf.Position.X - (lo.X + hi.X) / 2, cf.Position.Y - lo.Y, cf.Position.Z - (lo.Z + hi.Z) / 2))
    end
    if name then m.Name = name end
    m.Parent = parent
    return m
end
-- a flat IRREGULAR plate on the floor (review: a single rectangular part read as "a stray box"): k (3) right-triangle wedges
-- lying flat (triangle face up), overlapping at random yaws and sizes round `at` (floor y), ~`r` across, `t` thick
local function Shard(parent: Instance, name: string, at: Vector3, r: number, t: number, color: Color3, mat: Enum.Material, vr: Random, k: number?): { BasePart }
    local out = {}
    local yaw0 = vr:NextNumber(0, math.pi * 2)
    for i = 1, k or 3 do
        local a, b = r * vr:NextNumber(0.6, 1.1), r * vr:NextNumber(0.5, 1)
        local off = Vector3.new(vr:NextNumber(-0.3, 0.3) * r, 0, vr:NextNumber(-0.3, 0.3) * r)
        local cf = CFrame.new(at + off + Vector3.new(0, t / 2 + 0.01 * i, 0)) * CFrame.Angles(0, yaw0 + (i - 1) * 2.1 + vr:NextNumber(-0.5, 0.5), 0)
            * CFrame.Angles(0, 0, math.rad(90))
        local w = Part(parent, name, Enum.PartType.Wedge, Vector3.new(t, a, b), cf, color, mat)
        w.CastShadow = false
        table.insert(out, w)
    end
    return out
end
-- PAINT FIELD (terrain paint over the whole open floor: 0 parts). mats = { { material, weight }, ... }; every 4-stud
-- ground column of the room box (inset from the walls) gets ONE of them from a warped, stretched Perlin field, so the
-- materials lie in big irregular blobs and drifts (never a grid or circles), in the weights' proportions. Only open-floor
-- columns are rewritten (nothing at 8..12, not under a TFill cover piece: cover rock / massifs keep their stone); air and
-- water are never touched and occupancy is kept: heights (FlushGround) are unchanged. Footsteps / bots read the floor
-- PART, not terrain. opts = { Scale (blob size, studs, default 22), Stretch (drift length x, default 1.8), Dir (drift
-- direction, default random), Warp (default 9 studs), Edge (fine break-up of the borders, default 0.25), Inset (default 2) }.
-- Returns the columns painted. A material not in the biome's terrain palette needs a Palette.Base colour.
local function PaintField(P: any, ctx: any, vr: Random, mats: { any }, opts: any?): number
    if not ctx.Terrain or #mats == 0 then return 0 end
    opts = opts or {}
    local T = Workspace.Terrain
    local half = P.half - (opts.Inset or 2)
    local reg = Region3.new(Vector3.new(P.C0.X - half, -4, P.C0.Z - half), Vector3.new(P.C0.X + half, 12, P.C0.Z + half)):ExpandToGrid(4)
    local vm, occ = T:ReadVoxels(reg, 4)
    local sz = vm.Size
    local lo = reg.CFrame.Position - reg.Size / 2
    local scale = opts.Scale or 22
    local stretch = opts.Stretch or 1.8
    local da = opts.Dir and math.atan2(opts.Dir.Z, opts.Dir.X) or vr:NextNumber(0, math.pi * 2)
    local ca, sa = math.cos(da), math.sin(da)
    local ox, oz, wx, wz, fx0 = vr:NextNumber(0, 500), vr:NextNumber(0, 500), vr:NextNumber(0, 500), vr:NextNumber(0, 500), vr:NextNumber(0, 500)
    local warp, edge = opts.Warp or 9, opts.Edge or 0.25
    -- cover pieces Terrainify turned into rock (parts tagged TFill, as MapShell.FlushGround guards them): never repaint
    -- their columns (RoomAtmo runs before FlushGround flattens the ground's bumps, so height alone can't tell them apart)
    local guard = {}
    local dg = Workspace:FindFirstChild("DungeonFacility")
    local geo = dg and dg:FindFirstChild("StaticGeometry")
    if geo then
        for _, q in ipairs(geo:GetDescendants()) do
            if q:IsA("BasePart") and q:GetAttribute("TFill") and math.abs(q.Position.X - P.C0.X) < P.half + 20 and math.abs(q.Position.Z - P.C0.Z) < P.half + 20 then
                local cf, h = q.CFrame, q.Size / 2
                local ex = math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z
                local ez = math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
                table.insert(guard, { q.Position.X - ex - 2, q.Position.X + ex + 2, q.Position.Z - ez - 2, q.Position.Z + ez + 2 })
            end
        end
    end
    local function Guarded(x: number, z: number): boolean
        for _, g in ipairs(guard) do if x >= g[1] and x <= g[2] and z >= g[3] and z <= g[4] then return true end end
        return false
    end
    local vals, cols = {}, {}
    for i = 1, sz.X do
        for k = 1, sz.Z do
            -- open floor: solid ground in the y -4..0 or 0..4 cell, nothing at 8..12 (massifs), not under a TFill cover
            -- piece, no water on top (the 4..8 cell may hold the ground's own bumps: FlushGround flattens them later and
            -- copies the painted material down)
            local top = ((sz.Y >= 4 and occ[i][4][k] > 0.05) and 1 or 0)
            if top == 0 and #guard > 0 and Guarded(lo.X + (i - 0.5) * 4, lo.Z + (k - 0.5) * 4) then top = 1 end
            local m1, m2 = vm[i][1][k], vm[i][2][k]
            local solid2 = occ[i][2][k] > 0 and m2 ~= M.Air
            local solid1 = occ[i][1][k] > 0 and m1 ~= M.Air
            if top == 0 and (solid2 or solid1) and m1 ~= M.Water and m2 ~= M.Water then
                local x, z = lo.X + (i - 0.5) * 4, lo.Z + (k - 0.5) * 4
                x += math.noise(x / 30 + wx, z / 30 + wz) * warp
                z += math.noise(x / 30 + wz, z / 30 + wx) * warp
                local u, v = (x * ca + z * sa) / stretch, (-x * sa + z * ca)
                local nv = math.noise(u / scale + ox, v / scale + oz) + edge * math.noise(x / 7 + fx0, z / 7 + fx0)
                table.insert(vals, nv)
                table.insert(cols, { i, k, nv })
            end
        end
    end
    if #vals == 0 then
        if game:GetService("RunService"):IsStudio() then Workspace:SetAttribute("DevFieldLog", string.sub(tostring(Workspace:GetAttribute("DevFieldLog") or "") .. string.format(" %d,%d:0", P.C0.X, P.C0.Z), -300)) end
        return 0
    end
    table.sort(vals)
    local total = 0
    for _, e in ipairs(mats) do total += e[2] end
    local cuts, acc = {}, 0
    for idx, e in ipairs(mats) do
        acc += e[2]
        cuts[idx] = vals[math.clamp(math.floor(acc / total * #vals + 0.5), 1, #vals)]
    end
    for _, c in ipairs(cols) do
        local mat = mats[#mats][1]
        for idx, e in ipairs(mats) do if c[3] <= cuts[idx] then mat = e[1]; break end end
        for j = 1, math.min(3, sz.Y) do
            local m = vm[c[1]][j][c[2]]
            if m ~= M.Air and m ~= M.Water and occ[c[1]][j][c[2]] > 0 then vm[c[1]][j][c[2]] = mat end
        end
    end
    T:WriteVoxels(reg, 4, vm, occ)
    if game:GetService("RunService"):IsStudio() then -- (Studio: workspace attr DevFieldLog = "x,z:cols" per room, newest last)
        local log = tostring(Workspace:GetAttribute("DevFieldLog") or "")
        Workspace:SetAttribute("DevFieldLog", string.sub(log .. string.format(" %d,%d:%d", P.C0.X, P.C0.Z, #cols), -300))
    end
    return #cols
end
RoomAtmo.API = { Part = Part, Carrier = Carrier, Paint = Paint, Emitter = Emitter, Plan = Plan, Cracks = Cracks, SIDES = SIDES, C3 = C3, M = M,
    WorldProp = WorldProp, PlaceModel = PlaceModel, Shard = Shard, PaintField = PaintField }

return RoomAtmo
