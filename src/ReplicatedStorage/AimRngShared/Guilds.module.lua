--!nocheck
-- ============================================================================================
-- GUILDS (UPDATE 7 B9; placeholder name): a group of players (any servers) with a name, a 2-4 letter TAG on every member's
-- name tag, ranks (Leader / Officer / Member), a gold BANK members donate to, and a RESEARCH tree the leader / officers fund
-- from the bank. Research perks are SIDEWAYS and apply to every member (bag room, market listings, bounty rerolls, a little
-- Season XP, tag colours). Server: GuildService (DataStore Guilds_v1 live, memory in Studio). Client: GuildMenu.
-- state.Guild = the guild id (saved); state.GuildPerks = this guild's perks (refreshed by the server, not saved).
-- ============================================================================================
local Guilds = {}

Guilds.ON = true
Guilds.UNLOCK = 20
Guilds.CREATE_COST = 250000
Guilds.MAX_MEMBERS = 30
Guilds.NAME_MIN, Guilds.NAME_MAX = 3, 20
Guilds.TAG_MIN, Guilds.TAG_MAX = 2, 4
Guilds.COLOR = Color3.fromRGB(150, 200, 255)
Guilds.RANKS = { Leader = 3, Officer = 2, Member = 1 }

-- the research tree: Levels = gold from the bank per level; Perk(level) -> perk fields
Guilds.RESEARCH = {
    { Id = "VAULT", Name = "Shared Vault", Text = "+5 bag slots per level for every member", Costs = { 200000, 600000, 1500000 }, Perk = function(l) return { Bag = 5 * l } end },
    { Id = "LEDGER", Name = "Exchange Desk", Text = "+1 Exchange listing per level", Costs = { 300000, 900000, 2000000 }, Perk = function(l) return { Listings = l } end },
    { Id = "BOARD", Name = "Job Board", Text = "+1 Job Board reroll per level", Costs = { 400000, 1200000 }, Perk = function(l) return { Rerolls = l } end },
    { Id = "BANNER", Name = "War Banner", Text = "+3% Season XP per level", Costs = { 500000, 1500000, 3000000 }, Perk = function(l) return { SeasonXP = 0.03 * l } end },
    { Id = "CREST", Name = "Crest Dyes", Text = "unlocks a new tag colour per level", Costs = { 150000, 450000, 1000000 }, Perk = function(l) return { Colors = l } end },
}
Guilds.ById = {}
for _, r in ipairs(Guilds.RESEARCH) do Guilds.ById[r.Id] = r end
-- tag colours: the first is free, the rest come with CREST levels
Guilds.TAG_COLORS = {
    { Id = "Steel", Color = Color3.fromRGB(200, 210, 225) },
    { Id = "Gold", Color = Color3.fromRGB(255, 205, 90) },
    { Id = "Jade", Color = Color3.fromRGB(110, 230, 160) },
    { Id = "Ember", Color = Color3.fromRGB(255, 120, 80) },
}

-- the summed perks of a guild record's research
function Guilds.Perks(g: any): any
    local out = { Bag = 0, Listings = 0, Rerolls = 0, SeasonXP = 0, Colors = 0 }
    for _, r in ipairs(Guilds.RESEARCH) do
        local lvl = math.clamp(math.floor(tonumber(type(g) == "table" and type(g.Research) == "table" and g.Research[r.Id]) or 0), 0, #r.Costs)
        if lvl > 0 then for k, v in pairs(r.Perk(lvl)) do out[k] = (out[k] or 0) + v end end
    end
    return out
end
function Guilds.ColorOf(g: any): Color3
    for i, c in ipairs(Guilds.TAG_COLORS) do
        if c.Id == (type(g) == "table" and g.Color) and (i == 1 or Guilds.Perks(g).Colors >= i - 1) then return c.Color end
    end
    return Guilds.TAG_COLORS[1].Color
end
function Guilds.CleanTag(t: any): string?
    if type(t) ~= "string" then return nil end
    t = string.upper(string.gsub(t, "[^%w]", ""))
    if #t < Guilds.TAG_MIN or #t > Guilds.TAG_MAX then return nil end
    return t
end
function Guilds.CleanName(n: any): string?
    if type(n) ~= "string" then return nil end
    n = string.gsub(string.gsub(n, "[^%w %-']", ""), "^%s*(.-)%s*$", "%1")
    if #n < Guilds.NAME_MIN or #n > Guilds.NAME_MAX then return nil end
    return n
end

return Guilds
