--!nocheck
-- ============================================================================================
-- FRIEND INVITES (2026-10-20, owner picked "50 BOUND each, up to 10 friends, titles at 1 / 3 / 10" + "make sure the player
-- has to join and that it isnt just alt accounts"). Shared rules (server: AimRngServer/ReferralService, client: ReferralMenu).
-- A friend COUNTS only when ALL of these hold:
--   * they joined from your invite (Roblox join data ReferredByPlayerId -- set by an invite / following you),
--   * they're on your Roblox friends list at that moment,
--   * their Roblox account is at least ACCOUNT_AGE days old (fresh alts can't be used),
--   * they've NEVER played Aimbound (no save in this wipe or the one before),
--   * they then reach LEVEL with PLAY_SECONDS of play on DAYS different days (UTC) -- real playing, not a quick alt run.
-- Then both get REWARD_BP BOUND points; the inviter is paid for at most MAX_PAID friends (titles still count every friend).
-- ============================================================================================
local Referrals = {}

Referrals.LEVEL = 20
Referrals.PLAY_SECONDS = 2 * 3600
Referrals.DAYS = 2
Referrals.ACCOUNT_AGE = 30
Referrals.REWARD_BP = 50
Referrals.MAX_PAID = 10
Referrals.TITLES = { -- (ItemData titles, Check Granted, no stats)
    { Need = 1, Title = "Recruiter" },
    { Need = 3, Title = "SquadLeader" },
    { Need = 10, Title = "Commander" },
}
Referrals.COLOR = Color3.fromRGB(110, 220, 150)

-- the player-facing rules, one line each
Referrals.RULES = {
    "They join from your invite and are on your Roblox friends list.",
    "Their Roblox account is at least " .. Referrals.ACCOUNT_AGE .. " days old, and they've never played Aimbound before.",
    "They reach level " .. Referrals.LEVEL .. " with " .. (Referrals.PLAY_SECONDS // 3600) .. " hours of play on " .. Referrals.DAYS .. " different days.",
    "Then you BOTH get " .. Referrals.REWARD_BP .. " BOUND points (you: for up to " .. Referrals.MAX_PAID .. " friends).",
}

function Referrals.Today(): number return os.time() // 86400 end

-- the invited player's own progress: { Level, Play, Days } each as { have, need }
function Referrals.Progress(level: number, playSeconds: number, days: number): any
    return {
        Level = { math.min(level or 1, Referrals.LEVEL), Referrals.LEVEL },
        Play = { math.min(math.floor((playSeconds or 0) / 60), Referrals.PLAY_SECONDS // 60), Referrals.PLAY_SECONDS // 60 },
        Days = { math.min(days or 0, Referrals.DAYS), Referrals.DAYS },
    }
end

return Referrals
