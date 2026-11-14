--!nocheck
-- ============================================================================================
-- MAP BOSSES (MAPS V2 2026-10-30, owner's Next List F21: "A new boss for maps (Phantom-style: human-sized, always moving,
-- target switching)"). Maps-only guardians (BossTrials.MapBosses, Rifts.BAND_GUARDIANS). BossAI registers every Defs row at
-- load (M.RegisterMapBosses: KITS[id] + EVADE[id]) -- the kit code lives here because BossAI's main chunk is at Luau's local
-- limit. Kit(H) gets BossAI's helpers: H.M (shared moves), H.EA (EnemyAttacks), H.VFX, H.Pose, H.Unit, H.Flat, H.Part, H.Info,
-- H.Body, H.Sound.
-- THE BOSS RULES (owner, many rounds): human-sized, always moving, methodical flat wind-ups, attacks AIMED at you (no radial /
-- outward spray, no laser fans, nothing positional), ONE mechanic = the TARGET ROUND (BossAI M.AimRound: the same lime targets,
-- counting, timer and stagger as every boss) dressed in the boss's own theme (kit.AimTheme), ONE weak point = the head
-- (BossCues WeakGlow), never two mechanics at once, no light / part spam.
-- ============================================================================================
local MapBosses = {}

-- ===== THE LAMPLIGHTER (Annihilation maps, tier 10-12) =====
-- A slim pill in a short brass-clasped capelet with a tall lamp-pole floating at its right; the caged lantern on the pole is
-- his weapon. He circles you (Orbit), side-steps your aim (EVADE, close to the Phantom's) and glides to new spots.
-- Moves (one at a time, a flat wind-up each):
--   WICK SHOT   two lock-on shots from his lantern, 0.45 s apart (M.Snipe: a plain, evadable hit)
--   SNUFF       three circles drop where you stand, one after another (M.Rain)
--   LAMPLINE    he raises the lantern, a long lane draws from him THROUGH you, then fires (one lane, aimed)
--   GLIDE       (phase 2+) the ghost shows where he goes, he glides there, then one short cone at you (M.Step)
--   TWIN WICKS  (phase 2+) two lanes, the second re-aimed at where you are 0.4 s later
--   LAST LIGHT  (phase 3) four circles on you and just ahead of where you're running (M.Predict)
-- TARGETS = his LAMPS (AimTheme):
--   SWITCH  HANGING LAMPS     3-4 lamps hang on chains at eye height round him, each swaying slowly side to side
--   TRACK   SWINGING LANTERN  one lantern swings on a long chain in front of him, across your view: fast at the bottom,
--                             slowing to a hang at each end (the chain's pivot moves with him)
--   FLICK   LAMPLIGHT         lamps flare up one at a time round YOU, each at least 60 degrees from the last, inside the half
--                             of the room you're facing him in
MapBosses.Defs = {}
MapBosses.Order = { "Lamplighter" }

local AMBER = Color3.fromRGB(255, 178, 76)
local CHAIN = Color3.fromRGB(34, 32, 36)

MapBosses.Defs.Lamplighter = {
    Evade = { Amp = 13, Rate = 2.4, Dodge = 2.6 },
    Kit = function(H)
        local M, EA, Unit = H.M, H.EA, H.Unit
        local function Lampline(B, n)
            for k = 1, n do
                if not B:Alive() then return end
                local r = B:Root()
                if not r then return end
                local dir = Unit(r.Position - B.pos)
                B:Hold(B:W(0.95) + 0.5)
                B.lampAt = os.clock()
                EA.Line(B.ctx, B.pos, B.pos + dir * 110, 6, 0.95, { Mult = 1.4, Height = 10 })
                if k < n then B:Wait(0.4) end
            end
            B:Wait(B:W(0.95))
        end
        local function Wick(B, n)
            B.lampAt = os.clock()
            M.Snipe(B, n, 0.95)
        end
        -- ----- the target theme (BossAI M.AimRound hooks) -----
        local theme = {
            Label = { Switch = "SHOOT EVERY LAMP", Track = "TRACK THE LANTERN", Flick = "FLICK TO EACH LAMP" },
            Size = { Switch = 3.8, Track = 4.2, Flick = 3.6 },
        }
        -- where a lamp first lights
        function theme.Spot(B, pattern, k, n, a0, floorY, prev)
            if pattern == "Flick" then
                local r = B:Root()
                local me = r and r.Position or B.pos
                local base = math.atan2(B.pos.Z - me.Z, B.pos.X - me.X) -- (toward him: the half of the room you face)
                local prevA = prev and prev.Base and math.atan2(prev.Base.Z - me.Z, prev.Base.X - me.X) or nil
                local best
                for _ = 1, 14 do
                    local a = base + math.rad(math.random(-70, 70))
                    local d = 16 + math.random() * 12
                    local p = B:Clamp(Vector3.new(me.X + math.cos(a) * d, 0, me.Z + math.sin(a) * d))
                    local pa = math.atan2(p.Z - me.Z, p.X - me.X)
                    local gap = prevA and math.abs(math.atan2(math.sin(pa - prevA), math.cos(pa - prevA))) or math.pi
                    if (p - Vector3.new(me.X, 0, me.Z)).Magnitude >= 12 and gap >= math.rad(60) then best = p break end
                    best = best or p
                end
                return Vector3.new(best.X, floorY + 3.8 + math.random() * 2.4, best.Z)
            end
            local a = a0 + (k - 1) * math.pi * 2 / math.max(1, n) + (math.random() - 0.5) * 0.4
            local d = 15 + math.random() * 8
            local p = B:Clamp(Vector3.new(B.pos.X + math.cos(a) * d, 0, B.pos.Z + math.sin(a) * d))
            return Vector3.new(p.X, floorY + 4.4 + math.random() * 1.4, p.Z)
        end
        -- a chain up from the lamp + a dark cap on it (children of the lamp: gone with it; never CanQuery)
        function theme.Dress(B, o, pattern)
            local cap = H.Part({ Name = "LampCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, o.R * 0.7, o.R * 0.7),
                Color = CHAIN, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(o.Base) })
            cap.Parent = o.Part
            o.Cap = cap
            if pattern ~= "Flick" then
                local chain = H.Part({ Name = "LampChain", Size = Vector3.new(0.16, 0.16, 6), Color = CHAIN, Material = Enum.Material.SmoothPlastic,
                    CFrame = CFrame.new(o.Base) })
                chain.Parent = o.Part
                o.Chain = chain
                o.Top = o.Base + Vector3.new(0, 6, 0)
                local a = math.random() * math.pi * 2
                o.Sway = Vector3.new(math.cos(a), 0, math.sin(a))
            else
                -- (a flare as it lights: a pop-up you notice from the side of your view)
                pcall(H.VFX.Burst, B.d.Fx, o.Base, M.AIM_COLOR, 6)
            end
        end
        function theme.Move(B, pattern, o, now, t0, floorY)
            if pattern == "Switch" then
                -- HANGING LAMPS: a slow pendulum sway (+-2 studs), each lamp on its own beat
                local th = 0.34 * math.sin((now - t0) * 2.0 + o.Ph)
                local L = 6
                o.Top = o.Base + Vector3.new(0, L, 0)
                return CFrame.new(o.Top + o.Sway * (math.sin(th) * L) - Vector3.new(0, math.cos(th) * L, 0))
            elseif pattern == "Track" then
                -- SWINGING LANTERN: a long pendulum hung in front of him, swinging across your view
                local r = B:Root()
                local me = r and r.Position or (B.pos + Vector3.new(0, 0, -20))
                local toMe = Unit(me - B.pos)
                local side = toMe:Cross(Vector3.yAxis)
                o.Side = o.Side and o.Side:Lerp(side, 0.06).Unit or side
                local L = 10
                local period = 3.4 - 0.3 * B.phase
                local th = math.rad(55) * math.sin((now - t0) * math.pi * 2 / period)
                local pivot = B:Clamp(B.pos + toMe * 5)
                o.Top = Vector3.new(pivot.X, floorY + 5 + L, pivot.Z)
                local p = o.Top + o.Side * (math.sin(th) * L) - Vector3.new(0, math.cos(th) * L, 0)
                local q = B:Clamp(Vector3.new(p.X, 0, p.Z))
                return CFrame.new(q.X, p.Y, q.Z)
            end
            -- LAMPLIGHT: a lit lamp bobs a little (client only: the server keeps it still, as every boss's targets)
            if game:GetService("RunService"):IsServer() then return nil end
            return CFrame.new(o.Base + Vector3.new(0, math.sin(now * 1.6 + o.Ph) * 0.5, 0))
        end
        function theme.Place(B, o, cf)
            local p = cf.Position
            local half = o.Part.Size.Y * 0.5
            if o.Cap then o.Cap.CFrame = CFrame.new(p + Vector3.new(0, half * 0.92, 0)) * CFrame.Angles(0, 0, math.pi / 2) end
            if o.Chain and o.Top then
                local from = p + Vector3.new(0, half, 0)
                local len = math.max(0.5, (o.Top - from).Magnitude)
                o.Chain.Size = Vector3.new(0.16, 0.16, len)
                o.Chain.CFrame = CFrame.lookAt((from + o.Top) / 2, o.Top)
            end
        end
        return {
            Color = AMBER, Move = "Orbit", Range = 32, SpeedMul = 1.0,
            Names = { "THE LAMPLIGHTER", "THE LAMPLIGHTER: DUSK", "THE LAMPLIGHTER: LAST LIGHT" },
            AimTheme = theme,
            -- (while a target round is up: one light, slow attack at a time)
            MechMoves = {
                { function(B)
                    local r = B:Root()
                    if r then EA.Circle(B.ctx, r.Position, 6, 1.4, { Mult = 0.7 }) end
                    B:Wait(B:W(1.4))
                end, "EMBER" },
                { function(B)
                    local r = B:Root()
                    B.lampAt = os.clock()
                    if r then EA.Beam(B.ctx, function() return B.pos + Vector3.new(0, 1, 0) end, r, 1.3, { Mult = 0.8, LockTime = 0.3, Width = 2, Range = 240 }) end
                    B:Wait(B:W(1.3))
                end, "SIGHTLINE" },
            },
            Moves = {
                { { function(B) Wick(B, 2) end, "WICK SHOT" }, { function(B) M.Rain(B, 3, 6, 1.0, 0, 0.55, { Mult = 1.1 }) end, "SNUFF" },
                  { function(B) Lampline(B, 1) end, "LAMPLINE" } },
                { { function(B) M.Step(B, 46, 22) end, "GLIDE" }, { function(B) Lampline(B, 2) end, "TWIN WICKS" }, { function(B) Wick(B, 2) end, "WICK SHOT" },
                  { function(B) M.Rain(B, 3, 6, 1.0, 0, 0.55, { Mult = 1.1 }) end, "SNUFF" } },
                { { function(B) M.Predict(B, 4) end, "LAST LIGHT" }, { function(B) M.Step(B, 46, 22) end, "GLIDE" }, { function(B) Lampline(B, 2) end, "TWIN WICKS" },
                  { function(B) Wick(B, 3) end, "WICK SHOT" } },
            },
            -- (the old-look fallback, EnemyModels.MajorDecor.Lamplighter; the v2 look poses itself: BossLook/Lamplighter)
            Animate = function(B, pivot, now)
                local raise = (os.clock() < (B.lampAt or 0) + 1.2) and 1 or 0
                H.Pose(B, "Deco_Pole", pivot, CFrame.new(1.9, 1.5, 0), CFrame.Angles(-0.35 * raise + math.sin(now * 1.4) * 0.05, 0, math.sin(now * 0.9) * 0.04))
                H.Pose(B, "Deco_Halo", pivot, CFrame.new(0, 6.0, 0.3), CFrame.Angles(0, now * (0.6 + 0.3 * B.phase), 0))
            end,
        }
    end,
}

return MapBosses
