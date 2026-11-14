--!nocheck
-- MovementSanity (server): the server never simulates player movement (the client owns its character). It only watches
-- for the impossible: a horizontal speed above SourceMovementConfig.SanityMaxStudsPerSecond (sv_maxvelocity) held over
-- a check, or a jump of SanityTeleportStuds+ in one check (teleporting). LOG-ONLY for now (2026-10-03, Source movement
-- phase 1): the Aimbound dash / grapple / jump pads and server teleports (floors, respawns) would trip a hard
-- correction until they are accounted for. Flags show as "[MoveSanity]" warnings + the player attribute MoveFlags.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- (every floor change / respawn is a server teleport and trips the teleport check -- only Studio prints them for now,
-- live servers just count them in MoveFlags, so real server logs don't fill with false alarms)
local function Report(msg: string) if RunService:IsStudio() then warn(msg) end end
-- (limits were in SourceMovementConfig, retired with the Source movement style 2026-10-03)
local C = { SanityMaxStudsPerSecond = 300, SanityTeleportStuds = 60 }

local M = {}
local CHECK = 0.25
local last = {} -- [player] = { Pos, At, Spawned }

local function Check(player: Player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then last[player] = nil return end
    local now = os.clock()
    local rec = last[player]
    if not rec or rec.Root ~= root then
        last[player] = { Pos = root.Position, At = now, Root = root }
        return
    end
    local dt = now - rec.At
    local delta = root.Position - rec.Pos
    local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
    if flat >= C.SanityTeleportStuds then
        player:SetAttribute("MoveFlags", (player:GetAttribute("MoveFlags") or 0) + 1)
        Report(string.format("[MoveSanity] %s moved %.0f studs in %.2f s (teleport? server teleports also show here)", player.Name, flat, dt))
    elseif dt > 0 and flat / dt > C.SanityMaxStudsPerSecond then
        player:SetAttribute("MoveFlags", (player:GetAttribute("MoveFlags") or 0) + 1)
        Report(string.format("[MoveSanity] %s at %.0f studs/s (limit %.0f)", player.Name, flat / dt, C.SanityMaxStudsPerSecond))
    end
    rec.Pos, rec.At = root.Position, now
end

function M.Start()
    Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
    task.spawn(function()
        while true do
            task.wait(CHECK)
            for _, p in ipairs(Players:GetPlayers()) do pcall(Check, p) end
        end
    end)
end

return M
