--!nocheck
-- ============================================================================================
-- WORLD FOES (0.89, owner overnight list: "Own enemies and superbosses for the new worlds ... each with about 5 enemy
-- types, a specialist, attack visuals and a superboss"). One module per world in AimRngShared.WorldFoes (Folder):
--   Enemies   { Name, Def (a BotArchetypes entry: Hp / Dmg / Speed / Body / Head / Color / Range / Fire / Pattern / Ground),
--               Lore { Role, Text, Tip }, Attack (a shape from WF.SHAPES + its numbers), Decor(model, H), Hard?, Weight? }
--   Specialist  the name of one Enemies entry (slow, tanky, a bigger attack)
--   Super     { Name, Names (3 phase titles), Color, Hitbox (SUPER_HITBOX layout), Body(model, M, col, H),
--               Kit(H) -> a BossAI SUPER kit, Evade }
-- Wiring: WorldBiomes.MergeInto -> WF.MergeInto(NB): a world with foes stops borrowing its sister's roster / superboss.
-- NB.Attack falls through to WF.Attack (kinds "W:<Name>"); EnemyModels.Decorate calls WF.Decor[style]; EnemyModels +
-- BossAI register the superbosses (SUPER_HITBOX / SUPER_BODIES / SUPER / EVADE) at load.
-- RULES (owner): every attack is a telegraphed red area AIMED at the player -- no outward / radial sprays; decorations
-- stay close to the body (they're hittable on bots); bosses keep moving, aim rounds come from BossAI itself.
-- A foe module must not require game modules.
-- ============================================================================================
local WF = {}
WF.ORDER = { "Jungle", "Gothic", "Desert", "Abyss", "Sakura", "Waste", "Fungal", "Sky", "Autumn", "Station", "Aztec", "Bayou" }
WF.F = {}
local folder = script -- (the world modules are this module's children, like SkinSets)
if folder then
    for _, id in ipairs(WF.ORDER) do
        local m = folder:FindFirstChild(id)
        if m then
            local ok, f = pcall(require, m)
            if ok and type(f) == "table" then WF.F[id] = f else warn("[WorldFoes] " .. id .. " failed: " .. tostring(f)) end
        end
    end
end

-- ==================== THE ATTACK LIBRARY ====================
-- every shape: (EA, a = the enemy's attack spec, atk, model, pos, lead, rng) -> wind-up used
local function Frame(pos: Vector3, lead: Vector3)
    local from = Vector3.new(pos.X, lead.Y, pos.Z)
    local flat = Vector3.new(lead.X - pos.X, 0, lead.Z - pos.Z)
    local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
    return from, flat, dir, Vector3.new(-dir.Z, 0, dir.X)
end
local function Alive(model) return model.Parent ~= nil and model:GetAttribute("Dead") ~= true end
local function Later(model, t, fn) task.delay(t, function() if Alive(model) then fn() end end) end
local function TargetAt(atk, lead)
    local tgt = atk.Targets and atk.Targets()[1]
    local hrp = tgt and tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart")
    return hrp and Vector3.new(hrp.Position.X, lead.Y, hrp.Position.Z) or lead
end
WF.SHAPES = {}
local S = WF.SHAPES
-- one circle where you are
function S.Burst(EA, a, atk, model, pos, lead, rng)
    local w = a.W or 0.8
    EA.Circle(atk, lead, a.R or 5, w, { Mult = a.Mult or 1 })
    return w
end
-- two circles either side of you: step forward / back out of the gap's edges
function S.Pair(EA, a, atk, model, pos, lead, rng)
    local _, _, dir, side = Frame(pos, lead)
    local w = a.W or 0.8
    for _, sx in ipairs({ -1, 1 }) do EA.Circle(atk, lead + side * sx * (a.Gap or 3.4), a.R or 3.6, w, { Mult = a.Mult or 0.8 }) end
    return w
end
-- a circle on you, then a bigger one on the same spot a beat later (don't step back in)
function S.Echo(EA, a, atk, model, pos, lead, rng)
    local w = a.W or 0.75
    EA.Circle(atk, lead, a.R or 4, w, { Mult = a.Mult or 0.8 })
    Later(model, a.Delay or 0.7, function() EA.Circle(atk, lead, (a.R or 4) * 1.7, 0.6, { Mult = a.Mult or 0.8 }) end)
    return w
end
-- a row of circles laid along its line to you and past (step sideways)
function S.Row(EA, a, atk, model, pos, lead, rng)
    local _, _, dir = Frame(pos, lead)
    local n, gap, w = a.N or 5, a.Gap or 4.2, a.W or 0.8
    for i = 1, n do
        local at = lead + dir * ((i - (n + 1) / 2) * gap)
        Later(model, (i - 1) * (a.Step or 0.07), function() EA.Circle(atk, at, a.R or 3.2, w, { Mult = a.Mult or 0.7 }) end)
    end
    return w
end
-- two lanes crossing on you (an X, or a + when Plus)
function S.Cross(EA, a, atk, model, pos, lead, rng)
    local _, _, dir = Frame(pos, lead)
    local w, L = a.W or 0.85, a.L or 22
    local angles = a.Plus and { 0, math.rad(90) } or { math.rad(45), math.rad(-45) }
    for _, ang in ipairs(angles) do
        local d = CFrame.Angles(0, ang, 0):VectorToWorldSpace(dir)
        EA.Line(atk, lead - d * L, lead + d * L, a.Width or 3.4, w, { Mult = a.Mult or 0.8, Height = 9 })
    end
    return w
end
-- a lane from it straight through you (strafe out)
function S.Lane(EA, a, atk, model, pos, lead, rng)
    local from, flat, dir = Frame(pos, lead)
    local w = a.W or 0.85
    local len = math.min(flat.Magnitude + (a.Past or 14), a.Max or 60)
    EA.Line(atk, from, from + dir * len, a.Width or 4, w, { Mult = a.Mult or 1, Height = 9 })
    return w
end
-- a lane lying across you, side to side (step toward / away from it)
function S.Bar(EA, a, atk, model, pos, lead, rng)
    local _, _, dir, side = Frame(pos, lead)
    local w, L = a.W or 0.85, a.L or 20
    local at = lead + dir * (a.Shift or 0)
    EA.Line(atk, at - side * L, at + side * L, a.Width or 4, w, { Mult = a.Mult or 0.9, Height = 9 })
    return w
end
-- a low wall rolling from it toward you (jump it)
function S.Roller(EA, a, atk, model, pos, lead, rng)
    local from, flat, dir = Frame(pos, lead)
    local w = a.W or 0.7
    EA.Wall(atk, from, dir, math.min(flat.Magnitude + 16, 60), a.L or 20, w, { Mult = a.Mult or 0.9 })
    return w
end
-- a cone toward you
function S.Cone(EA, a, atk, model, pos, lead, rng)
    local from, flat, dir = Frame(pos, lead)
    local w = a.W or 0.85
    EA.Cone(atk, from, dir, math.min(flat.Magnitude + (a.Past or 12), a.Max or 48), a.Half or 22, w, { Mult = a.Mult or 0.9 })
    return w
end
-- lingering puddles along where you were heading (keep moving off them)
function S.Trail(EA, a, atk, model, pos, lead, rng)
    local _, _, dir = Frame(pos, lead)
    local w = a.W or 0.7
    for i = 0, (a.N or 3) - 1 do
        local at = lead + dir * ((i - 1) * (a.Gap or 5))
        Later(model, i * 0.25, function() EA.Zone(atk, at, a.R or 3.6, w, a.Life or 2.4, { Mult = a.Mult or 0.3, Height = 5 }) end)
    end
    return w
end
-- a burst on you that leaves a puddle behind
function S.Puddle(EA, a, atk, model, pos, lead, rng)
    local w = a.W or 0.8
    EA.Circle(atk, lead, a.R or 4.2, w, { Mult = a.Mult or 0.8 })
    Later(model, w, function() EA.Zone(atk, lead, (a.R or 4.2) * 0.9, 0.1, a.Life or 2.6, { Mult = 0.25, Height = 5 }) end)
    return w
end
-- three strikes that follow you, each landing where you are when it starts
function S.Chase(EA, a, atk, model, pos, lead, rng)
    local w = a.W or 0.6
    for i = 0, (a.N or 3) - 1 do
        Later(model, i * (a.Gap or 0.55), function() EA.Circle(atk, TargetAt(atk, lead), a.R or 3.4, w, { Mult = a.Mult or 0.6 }) end)
    end
    return w
end
-- four circles boxing you in at the corners (the middle is safe for a moment, then a centre strike)
function S.Box(EA, a, atk, model, pos, lead, rng)
    local _, _, dir, side = Frame(pos, lead)
    local w, g = a.W or 0.8, a.Gap or 5
    for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
        EA.Circle(atk, lead + dir * c[1] * g + side * c[2] * g, a.R or 3.6, w, { Mult = a.Mult or 0.7 })
    end
    Later(model, w + 0.35, function() EA.Circle(atk, lead, a.R or 3.6, 0.55, { Mult = a.Mult or 0.7 }) end)
    return w
end
-- SPECIALISTS: a lattice of lanes round you, one gap safe
function S.Lattice(EA, a, atk, model, pos, lead, rng)
    local _, _, dir, side = Frame(pos, lead)
    local w = a.W or 1.0
    for i = -1, 1 do
        local o = side * (i * 7.5 + 2)
        EA.Line(atk, lead + o - dir * 26, lead + o + dir * 26, 3, w, { Mult = a.Mult or 0.9, Height = 9 })
    end
    for i = -1, 1, 2 do
        local o = dir * (i * 6)
        EA.Line(atk, lead + o - side * 26, lead + o + side * 26, 3, w + 0.15, { Mult = a.Mult or 0.9, Height = 9 })
    end
    return w
end
-- SPECIALISTS: a plus of lanes on you, then the centre
function S.Sunburst(EA, a, atk, model, pos, lead, rng)
    local _, _, dir, side = Frame(pos, lead)
    local w = a.W or 0.95
    for _, d in ipairs({ dir, side }) do EA.Line(atk, lead - d * 24, lead + d * 24, 3.4, w, { Mult = a.Mult or 0.9, Height = 9 }) end
    Later(model, w + 0.3, function() EA.Circle(atk, lead, 6, 0.6, { Mult = a.Mult or 0.9 }) end)
    return w
end
-- SPECIALISTS: a hash # of four lanes round you (the middle square is safe, then it closes)
function S.Grid(EA, a, atk, model, pos, lead, rng)
    local _, _, dir, side = Frame(pos, lead)
    local w, g = a.W or 0.95, a.Gap or 6
    for _, sgn in ipairs({ -1, 1 }) do
        EA.Line(atk, lead + side * sgn * g - dir * 24, lead + side * sgn * g + dir * 24, 3, w, { Mult = a.Mult or 0.9, Height = 9 })
        EA.Line(atk, lead + dir * sgn * g - side * 24, lead + dir * sgn * g + side * 24, 3, w, { Mult = a.Mult or 0.9, Height = 9 })
    end
    Later(model, w + 0.4, function() EA.Circle(atk, lead, g * 0.8, 0.6, { Mult = a.Mult or 0.9 }) end)
    return w
end

WF.ATTACKS = {}
-- (filled at LOAD, not in MergeInto: BossAI / EnemyModels can load before the worlds merge -- seen in play: the superboss
-- fell back to the Molten kit and a bare body)
WF.Decor = {}       -- style -> fn(model, H)
WF.Super = {}       -- world id -> Super def
for id, f in pairs(WF.F) do
    for _, e in ipairs(f.Enemies or {}) do
        if e.Decor then WF.Decor[(e.Def and e.Def.Style) or e.Name] = e.Decor end
        if e.Attack then WF.ATTACKS["W:" .. e.Name] = e.Attack end
    end
    if f.Super then WF.Super[id] = f.Super end
end
function WF.Attack(EA, kind, atk, model, pos, lead, rng)
    local spec = WF.ATTACKS[kind]
    if not spec then return nil end
    local f = S[spec.Shape]
    if not f then return nil end
    return f(EA, spec, atk, model, pos, lead, rng)
end

-- ==================== MERGE ====================
function WF.MergeInto(NB: any)
    NB.WorldAttack = WF.Attack
    NB.SUPER_NAMES = NB.SUPER_NAMES or {}
    NB.SUPER_COLOR = NB.SUPER_COLOR or {}
    for id, f in pairs(WF.F) do
        if f.Enemies and #f.Enemies > 0 then
            local pool, hard = {}, {}
            for _, e in ipairs(f.Enemies) do
                local def = table.clone(e.Def)
                def.Style = def.Style or e.Name
                def.Label = def.Label or e.Label or e.Name
                def.Biome = id
                NB.ARCHETYPES[e.Name] = def
                NB.LORE[e.Name] = e.Lore
                if e.Attack then
                    NB.RANGED_KIND[e.Name] = "W:" .. e.Name
                    WF.ATTACKS["W:" .. e.Name] = e.Attack
                end
                if e.Decor then WF.Decor[def.Style] = e.Decor end
                if e.Name ~= f.Specialist then
                    for _ = 1, (e.Weight or 1) do table.insert(pool, e.Name) end
                    if e.Hard then table.insert(hard, e.Name) end
                end
            end
            NB.POOLS[id] = pool
            if f.Specialist then
                NB.SPECIALIST[id] = f.Specialist
                NB.SLOW[f.Specialist] = true
            end
            if #hard > 0 then NB.HARD[id] = hard end
            if NB.SISTER then NB.SISTER[id] = nil end -- (its own roster now: no more borrowing)
        end
        if f.Super then
            WF.Super[id] = f.Super
            NB.SUPER_NAMES[id] = f.Super.Name
            NB.SUPER_COLOR[id] = f.Super.Color
            if NB.BOSS_OF then NB.BOSS_OF[id] = nil end -- (its own superboss now)
        end
    end
end

return WF
