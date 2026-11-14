--!nocheck
-- Moved to ReplicatedStorage.AimRngShared.DungeonGenerator: dungeons are built and run on each player's
-- client now (private worlds), and the server uses the same module to roll enemy stats.
return require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonGenerator"))
