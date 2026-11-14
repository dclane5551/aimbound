--!nocheck
-- TRY RANGE (Update 6, owner: "Trialing bundles should bring you to its own more lit area, as the hub doesn't properly
-- showcase them"). TRY IN FIRST PERSON takes you to a small, evenly lit studio range of your own and brings you back to
-- where you stood when the try-on ends.
--   * built on THIS client only, far west of the city (Zones.SHOWCASE_*): nobody else is ever in it. Zones.Kind = "showcase"
--     -> InstanceKey "showcase:<userid>" (other players don't see you there and you don't see them), the hub is parked
--     while you're in it (Zones.AwayFromCity), and the client's light loop switches to LIGHT_PROFILES.Showcase (bright,
--     neutral, no haze, no fog) -- and back to the hub's own profile the moment you leave, so nothing has to be restored
--     by hand.
--   * a light warm-grey studio: floor, a curved cove into the back wall, side walls, a dark ceiling with two long
--     softbox strips, a thin accent line in the item's rarity colour, distance lines, three target stands. 20 parts, no
--     lights (voxel lighting: the sun, with shadows off outside the hub, lights it evenly from behind your left shoulder).
--   * Leave(): teleports you back only if it's still the same, living character and it is still in the range (a death
--     respawns you in the hub as usual; a run that starts mid-try-on has already moved you).
local TryRange = {}

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Shared = script.Parent
local Zones = require(Shared:WaitForChild("Zones"))
local LocalPlayer = Players.LocalPlayer

-- the studio's frame: the player starts at its origin (feet on the floor) looking down -Z. Turned so the sun of the
-- Showcase light profile (ClockTime 14, latitude 41.7) comes from behind your left shoulder, high: it lights the side of
-- the gun you see and the targets' faces.
TryRange.YAW = 0 -- (set from the sun at build time, see Frame())
local W, L, H = 30, 54, 18 -- inner width / length / height
local COVE = 6 -- radius of the curved floor -> back wall cove

local function Frame(): CFrame
    -- the sun direction for the Showcase clock (Lighting:GetSunDirection follows the live clock, which may still be the
    -- hub's while we build): ClockTime 14 at latitude 41.7 -> measured in Studio
    local sun = TryRange.SUN or Vector3.new(-0.42, 0.75, 0.51)
    local flat = Vector3.new(sun.X, 0, sun.Z)
    if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, 1) end
    flat = flat.Unit
    -- local "behind-left" (-X, +Z)/sqrt2 must point at the sun: look = the sun's horizontal direction turned 135 deg
    local behindLeft = Vector3.new(-1, 0, 1).Unit
    local yaw = math.atan2(flat.X, flat.Z) - math.atan2(behindLeft.X, behindLeft.Z)
    return CFrame.new(Zones.SHOWCASE_ORIGIN) * CFrame.Angles(0, yaw, 0)
end

local function Part(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, refl: number?): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanTouch = false
    p.CastShadow = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat or Enum.Material.SmoothPlastic
    p.Reflectance = refl or 0
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p:SetAttribute("NoSkin", true)
    p.Parent = m
    return p
end

-- build the studio (local); returns the model, the start CFrame and the target stand spots
function TryRange.Build(accent: Color3?): (Model, CFrame, { CFrame })
    local old = workspace:FindFirstChild("TryRangeWorld")
    if old then old:Destroy() end
    local m = Instance.new("Model")
    m.Name = "TryRangeWorld"
    m:SetAttribute("NoSkin", true)
    local F = Frame()
    local function At(x, y, z) return F * CFrame.new(x, y, z) end
    local C = Color3.fromRGB
    local FLOOR = C(186, 182, 176) -- warm light grey (a touch under the walls: it took the sun full on)
    local WALL = C(206, 203, 198)
    local SIDE = C(184, 181, 176)
    local CEIL = C(52, 54, 60)
    local z0, z1 = 6, 6 - L -- front (behind you) / back
    local back = z1
    local floorLen = L - COVE
    -- floor (to where the cove starts) + the cove: 4 flat strips round a quarter circle into the back wall
    Part(m, "Floor", Vector3.new(W, 1, floorLen), At(0, -0.5, z0 - floorLen / 2), FLOOR, Enum.Material.SmoothPlastic, 0.02)
    local cx, cy = back + COVE, COVE -- the cove's centre (local z, y)
    for i = 0, 3 do
        local a0, a1 = math.rad(i * 22.5), math.rad((i + 1) * 22.5)
        -- arc points from the floor (angle 0: straight down from the centre) round to the wall (90: straight back)
        local p0 = Vector3.new(0, cy - COVE * math.cos(a0), cx - COVE * math.sin(a0))
        local p1 = Vector3.new(0, cy - COVE * math.cos(a1), cx - COVE * math.sin(a1))
        local mid = (p0 + p1) / 2
        local len = (p1 - p0).Magnitude + 0.08
        local dir = (p1 - p0).Unit
        local col = FLOOR:Lerp(WALL, (i + 0.5) / 4)
        -- the strip's outer face sits on the arc: push it half its thickness out from the centre
        local out = (mid - Vector3.new(0, cy, cx)).Unit
        local cf = CFrame.lookAt(Vector3.zero, dir, out)
        Part(m, "Cove" .. i, Vector3.new(W, 0.4, len), At(0, mid.Y, mid.Z) * cf.Rotation * CFrame.new(0, -0.2, 0), col, Enum.Material.SmoothPlastic, 0.02)
    end
    Part(m, "BackWall", Vector3.new(W, H - COVE, 1), At(0, COVE + (H - COVE) / 2, back - 0.5), WALL)
    Part(m, "FrontWall", Vector3.new(W, H, 1), At(0, H / 2, z0 + 0.5), SIDE)
    Part(m, "WallL", Vector3.new(1, H, L), At(-W / 2 - 0.5, H / 2, (z0 + z1) / 2), SIDE)
    Part(m, "WallR", Vector3.new(1, H, L), At(W / 2 + 0.5, H / 2, (z0 + z1) / 2), SIDE)
    Part(m, "Ceiling", Vector3.new(W + 2, 1, L + 2), At(0, H + 0.5, (z0 + z1) / 2), CEIL, Enum.Material.SmoothPlastic)
    -- softboxes: two long glowing strips under the ceiling + a frame round each (the studio's "lights")
    for _, sx in ipairs({ -7, 7 }) do
        Part(m, "Softbox", Vector3.new(3, 0.2, L - 12), At(sx, H - 0.15, (z0 + z1) / 2), C(255, 250, 240), Enum.Material.Neon)
        Part(m, "SoftboxFrame", Vector3.new(3.6, 0.3, L - 11.4), At(sx, H - 0.05, (z0 + z1) / 2), C(30, 31, 36), Enum.Material.Metal)
    end
    -- the accent: a thin line in the item's colour where the floor meets each side wall + along the cove's foot
    local acc = accent or C(255, 190, 60)
    acc = acc:Lerp(C(255, 255, 255), 0.15)
    for _, sx in ipairs({ -W / 2 + 0.1, W / 2 - 0.1 }) do
        Part(m, "Accent", Vector3.new(0.2, 0.12, floorLen), At(sx, 0.06, z0 - floorLen / 2), acc, Enum.Material.Neon)
    end
    Part(m, "AccentBack", Vector3.new(W, 0.12, 0.2), At(0, H - 0.6, back + 0.1), acc, Enum.Material.Neon)
    -- distance lines across the floor (10 / 20 / 30 studs out)
    for _, d in ipairs({ 10, 20, 30 }) do
        Part(m, "Mark", Vector3.new(W - 4, 0.04, 0.16), At(0, 0.02, -d), C(150, 147, 142), Enum.Material.SmoothPlastic)
    end
    for _, p in ipairs(m:GetChildren()) do
        if p:IsA("BasePart") then p.CanQuery = p.Name == "Floor" or string.sub(p.Name, 1, 4) == "Cove" or string.sub(p.Name, 1, 4) == "Wall" or p.Name == "BackWall" end
    end
    m.Parent = workspace
    -- you start a few studs in, facing the targets; three stands at 12 / 19 / 27 studs, spread so each reads alone
    local start = At(0, 3.2, -1)
    local spots = { At(-5, 0, -12), At(4.5, 0, -19), At(-1, 0, -27) }
    for i, s in ipairs(spots) do spots[i] = CFrame.lookAt(s.Position, Vector3.new(start.X, s.Y, start.Z)) end
    return m, start, spots
end

-- enter: build + teleport (teleport = the client's TeleportClient: it also turns the custom camera). Returns a session.
function TryRange.Enter(teleport: (CFrame) -> (), accent: Color3?): any
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum and hum.Health > 0) then return nil end
    -- the sun of the Showcase profile, measured live once (the profile's clock + latitude, read back from Lighting)
    if not TryRange.SUN then
        local ct, lat = Lighting.ClockTime, Lighting.GeographicLatitude
        local ok, dir = pcall(function()
            Lighting.ClockTime, Lighting.GeographicLatitude = 14, 41.7
            return Lighting:GetSunDirection()
        end)
        Lighting.ClockTime, Lighting.GeographicLatitude = ct, lat
        if ok and dir then TryRange.SUN = dir end
    end
    local model, start, spots = TryRange.Build(accent)
    local s = { Model = model, Char = char, Back = root.CFrame, Spots = spots }
    pcall(teleport, start)
    return s
end

function TryRange.Leave(s: any, teleport: (CFrame) -> ())
    if not s then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if char == s.Char and root and hum and hum.Health > 0 and Zones.Kind(root.Position) == "showcase" then
        pcall(teleport, s.Back)
    end
    if s.Model then s.Model:Destroy() end
end

return TryRange
