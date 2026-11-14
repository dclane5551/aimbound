-- BOSS LOOK v2 (2026-10-13, owner: "all the bosses need an appearance touch up: they should be unique, but maintain a
-- similar pill / orb look in some way. The bosses right now look far lower quality than the rest of our game.")
-- Pilot approved ("I like this direction ... duelist looks the best"); roll-out to every boss. Design language + numbers:
-- docs/BOSSES_LOOK.md. Every boss is an ASCENDED PILL BOT:
--   1 THE VESSEL   a smooth pill / orb body (one clean MeshPart) in a deep matte tone -- the mobs' capsule, grown up
--   2 THE HEAD     an orb on top, always in the open (the lime WeakGlow covers it on the client). Its colour is NOT the
--                  child's Palette.Head: BossLook.HeadColor gives every boss the same rule (owner 2026-10-13: "The bosses
--                  head can match it, just make it slightly different colored so you know its the head hitbox") -- a
--                  lighter, saturated tint of the boss's Glow hue (Body hue if the Glow is grey), checked against the Body
--                  (CIE Lab distance >= HEAD_MIN_DE, else deeper, else darker). A child may set HeadTint = Color3 instead.
--   3 THE SEAM     one thin glowing ring round the vessel in the boss's own colour (the family mark)
--   4 THE MANTLE   one hard silhouette piece that says who it is
--   5 THE TOOLS    weapons / fists FLOAT beside the body -- the pill family has no limbs
--   6 THE CROWN    a small ring element over or behind the head turning slowly
-- Materials: SmoothPlastic only (no metal, no reflectance, no texture maps), Neon only on the seam + edges (Glow + KeepNeon
-- attrs: HeatGlow heats them with the phase, NeonTamer leaves them alone). Budget: <= ~16 parts, <= 1 light (BossAI's
-- aura), <= 2 slow emitters per boss.
--
-- PLUG-INS: every boss is ONE child ModuleScript AimRngShared/BossLook/<Key> (Key = DecorateBoss kind, "Super" .. biome
-- for superbosses incl. the world ones ("SuperJungle"), or the trial id). Builders add / edit only their own child.
-- A child returns a table (it may require(script.Parent) for the helpers: children load lazily, after this module):
--   return {
--       On = true,                        -- the switch (false / missing = the boss keeps its old dress)
--       Bottom = -2.95, Hover = 0.75,     -- the kit's lowest point (look space) + how high it floats over the floor
--       Hit = { Torso = { Shape = "Ball", Size = Vector3.one * 1.5, Pos = Vector3.new(0, 0.3, 0) },
--               Core = { ... }, Head = { ..., Show = true } },   -- the gameplay parts re-laid over the new body
--       Palette = { Body = Color3, Shell = Color3, Glow = Color3, Head = Color3, ... },   -- role -> colour
--       Glow = { Glow = true },           -- roles drawn Neon (+ Glow / KeepNeon attrs)
--       Emit = { { Part = "Torso", Kind = "Smoke" | "Fire" | "Spark", Color, Rate, Size, Speed, Life, Y? } },
--       Build = function(model, look, spec) end,                -- optional: extra dressing after the shared build
--       Animate = function(B, pivot, now, Pose, dy) end,        -- poses its Deco_* pieces (see BossLook.Animate)
--   }
-- The meshes are made by tools/boss_look_blender.py (build_<Key>) -> tools/boss_look_import.py <Key> --upload -> the Edit
-- Luau builds ReplicatedStorage.BossKit.<Key> (in the PLACE: needs a save). Each piece carries attr Role (palette role).
-- EnemyModels.DecorateBoss / DecorateTrialBoss call BossLook.Build first; if the child is off / missing or the kit is not in
-- the place they fall back to the old dress. BossAI poses Deco_* pieces through BossLook.Animate (BossAI M.LookAnimate).
-- Attacks / mechanics are untouched.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local BossLook = {}
BossLook.FLOOR_TOP = 2 -- (DungeonGenerator FLOOR_TOP: every chamber floor's top)
BossLook.NEON, BossLook.SMOOTH = Enum.Material.Neon, Enum.Material.SmoothPlastic
function BossLook.C(r, g, b) return Color3.fromRGB(r, g, b) end
BossLook.TEX = { Smoke = "rbxasset://textures/particles/smoke_main.dds", Fire = "rbxasset://textures/particles/fire_main.dds",
    Spark = "rbxasset://textures/particles/sparkles_main.dds" }
-- eased 0..1 state on the BossAI brain (B[field]), for Animate
function BossLook.Ease(B, field: string, want: number, rate: number): number
    local v = B[field] or 0
    v += (want - v) * rate
    B[field] = v
    return v
end

-- the plug-ins (lazy: a child may require this module)
local cache = {}
function BossLook.Get(key: string)
    if cache[key] ~= nil then return cache[key] or nil end
    local m = script:FindFirstChild(key)
    local spec = false
    if m and m:IsA("ModuleScript") then
        local ok, res = pcall(require, m)
        if ok and type(res) == "table" then spec = res else warn("[BossLook] " .. key .. ": " .. tostring(res)) end
    end
    cache[key] = spec
    return spec or nil
end

-- the key a boss model asks for, and whether that boss wears the v2 look right now
-- (Studio test hook: workspace attr DevBossLook = "v1" puts every boss in the old look -- before / after shots)
function BossLook.Key(kind: string, biome: string?): string
    if kind == "SuperBoss" then return "Super" .. tostring(biome) end
    return kind
end
function BossLook.On(key: string): boolean
    if RunService:IsStudio() and workspace:GetAttribute("DevBossLook") == "v1" then return false end
    local spec = BossLook.Get(key)
    return spec ~= nil and spec.On == true
end
local function Kit(key)
    local kit = RS:FindFirstChild("BossKit")
    return kit and kit:FindFirstChild(key)
end
function BossLook.Has(key: string): boolean
    return BossLook.On(key) and Kit(key) ~= nil
end

-- THE HEAD COLOUR (see the header; tools: scratchpad-free mirror in docs/BOSSES_LOOK.md "Head tint" table)
BossLook.HEAD_MIN_DE = 32
local function Lin(c) return (c <= 0.04045) and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function Lab(c: Color3)
    local r, g, b = Lin(c.R), Lin(c.G), Lin(c.B)
    local x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    local z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    local function f(t) return (t > 0.008856) and t ^ (1 / 3) or 7.787 * t + 16 / 116 end
    local fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end
function BossLook.DeltaE(a: Color3, b: Color3): number
    local l1, a1, b1 = Lab(a)
    local l2, a2, b2 = Lab(b)
    return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end
function BossLook.HeadColor(spec): Color3
    if typeof(spec.HeadTint) == "Color3" then return spec.HeadTint end
    local pal = spec.Palette or {}
    local body = pal.Body or Color3.fromRGB(40, 40, 50)
    local h, s = (pal.Glow or body):ToHSV()
    if s < 0.25 then h, s = body:ToHSV() end
    local c = Color3.fromHSV(h, math.clamp(s * 0.8, 0.5, 0.75), 0.88)
    if BossLook.DeltaE(c, body) < BossLook.HEAD_MIN_DE then c = Color3.fromHSV(h, math.min(s * 1.1, 0.85), 0.62) end -- light body
    if BossLook.DeltaE(c, body) < BossLook.HEAD_MIN_DE then c = Color3.fromHSV(h, math.min(s * 1.1, 0.85), 0.32) end
    return c
end

-- a particle accent on `host`
function BossLook.Emit(host: Instance, e, look: CFrame?)
    local att = Instance.new("Attachment")
    att.Name = "LookFx"
    att.Parent = host
    if e.Y and look then att.WorldPosition = (look * CFrame.new(0, e.Y, 0)).Position end
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "LookFx"
    pe.Texture = BossLook.TEX[e.Kind] or BossLook.TEX.Spark
    pe.Color = ColorSequence.new(e.Color)
    pe.LightEmission = (e.Kind == "Smoke") and 0.2 or 0.9
    pe.Size = NumberSequence.new(e.Size, (e.Kind == "Smoke") and e.Size * 1.6 or 0)
    pe.Transparency = NumberSequence.new((e.Kind == "Smoke") and 0.55 or 0.15, 1)
    pe.Lifetime = NumberRange.new(e.Life * 0.7, e.Life)
    pe.Rate = e.Rate
    pe.Speed = NumberRange.new(e.Speed * 0.5, e.Speed)
    if e.Kind == "Fire" then
        pe.SpreadAngle = Vector2.new(14, 14)
        pe.Acceleration = Vector3.new(0, 6, 0)
        pe.EmissionDirection = Enum.NormalId.Top
    elseif e.Kind == "Smoke" then
        pe.SpreadAngle = Vector2.new(180, 30)
        pe.Acceleration = Vector3.new(0, -0.4, 0)
    else
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.Acceleration = Vector3.new(0, 4, 0)
    end
    pe.Parent = att
    return pe
end

-- dress `model` (its Torso / Core / Head built by DungeonGenerator, pivot at `pos`) in the v2 look. false = not done
-- (switch off / kit missing): the caller falls back to the old dress.
function BossLook.Build(model: Model, key: string, pos: Vector3): boolean
    local spec = BossLook.Get(key)
    local src = Kit(key)
    if not (spec and src and BossLook.On(key)) then return false end
    local lookY = BossLook.FLOOR_TOP + (spec.Hover or 0.6) - (spec.Bottom or -3)
    local look = CFrame.new(pos.X, lookY, pos.Z)
    local pal = spec.Palette or {}
    local glow = spec.Glow or { Glow = true }
    -- the gameplay parts, re-laid over the new body
    for nm, h in pairs(spec.Hit or {}) do
        local p = model:FindFirstChild(nm)
        if p and p:IsA("Part") then
            p.Shape = (h.Shape == "Ball") and Enum.PartType.Ball or Enum.PartType.Block
            p.Size = h.Size
            p.CFrame = look * CFrame.new(h.Pos)
            p.Material = BossLook.SMOOTH
            p.Reflectance = 0
            p.CastShadow = false
            p:SetAttribute("Glow", nil)
            -- (the old bodies hung their own PointLight on the Core: the v2 look keeps only BossAI's one aura light)
            for _, l in ipairs(p:GetChildren()) do if l:IsA("Light") then l:Destroy() end end
            if h.Show then
                p.Transparency = 0
                p.Color = BossLook.HeadColor(spec)
            else
                p.Transparency = 1
            end
        end
    end
    -- the pieces
    for _, mp in ipairs(src:GetChildren()) do
        if mp:IsA("BasePart") then
            local c = mp:Clone()
            local role = mp:GetAttribute("Role") or "Body"
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
            c.Color = pal[role] or pal.Body or c.Color
            c.Reflectance = 0
            if glow[role] then
                c.Material = BossLook.NEON
                c:SetAttribute("Glow", true)
                c:SetAttribute("KeepNeon", true)
            else
                c.Material = BossLook.SMOOTH
            end
            c.CFrame = look * mp.CFrame
            c:SetAttribute("BossLook", true)
            c.Parent = model
        end
    end
    for _, e in ipairs(spec.Emit or {}) do
        local host = model:FindFirstChild(e.Part)
        if host then BossLook.Emit(host, e, look) end
    end
    if spec.Build then spec.Build(model, look, spec) end
    model:SetAttribute("BossLook", 2)
    model:SetAttribute("LookKey", key)
    model:SetAttribute("LookDY", lookY - pos.Y) -- (Animate's hinges are in look space; the pivot stays at pos)
    return true
end

-- ==================== ANIMATION (BossAI M.LookAnimate -> here; Pose = BossAI's Pose) ====================
-- Pose(B, pattern, pivot, hinge, rot): every part whose name CONTAINS pattern is turned by rot about hinge (pivot space;
-- BossAI scales the offsets with the model). A child's Animate gets dy = the look origin's height over the pivot: write
-- hinges as CFrame.new(x, y + dy, z) in look space. Only Deco_* pieces move -- never the Head / Torso (the weak spot is
-- never a separately animated part).
function BossLook.Animate(B, pivot: CFrame, now: number, Pose)
    local key = B.model:GetAttribute("LookKey")
    local spec = key and BossLook.Get(key)
    if spec and spec.Animate then spec.Animate(B, pivot, now, Pose, B.model:GetAttribute("LookDY") or 0) end
end

return BossLook
