--!nocheck
-- ============================================================================================
-- BIOME MOODS (0.86, owner: "lets add like infinite biome possibilities in terms of colors, aesthetics etc sort of like poe
-- does. Just make sure they still LOOK GOOD and HIGH QUALITY").
-- Every floor rolls a MOOD for its biome: a hand-picked look (each one a deliberate palette, checked in play) + a small
-- seeded JITTER on top (hue, saturation, value, accent hue, fog, haze density, time of day, exposure) -- no two floors are
-- the same, none of them is a random colour soup.
-- QUALITY RULES (why it can't look bad): surfaces keep their VALUE (dark stays dark: big areas never turn pastel / neon),
-- non-accent saturation is capped at 0.78, hue pulls are partial (Amt), the accent / light keep their own saturation and
-- brightness (only the hue turns), fog pulls stop at ~45%, the clock moves at most ~1 h (the painted skies stay right).
-- Seeded from the floor rng -> party servers, clients and spectators see the same mood.
-- The generator tints the room's theme (Theme) and stamps the mood on the floor folder (Stamp); the client reads it back
-- (FromFolder) for the light profile, haze and terrain colours (LightAdjust / AtmoAdjust / Shift).
-- ============================================================================================
local BiomeMood = {}
local C = Color3.fromRGB

-- { Id, Name, W, H (target hue) + Amt (pull 0..1), Sat / Val (multipliers), Acc (accent hue, nil = keep), Fog + FogAmt,
--   Clock (hours), Exp (exposure), Dens (haze density x), CCSat (grade saturation +) }
BiomeMood.MOODS = {
    Fire = {
        { Id = "Molten", W = 3 },
        { Id = "Ashfall", Name = "Ashfall", W = 2, Sat = 0.62, Val = 0.96, Fog = C(150, 132, 122), FogAmt = 0.38, Dens = 1.25, Exp = -0.03, CCSat = -0.08 },
        { Id = "EmberDusk", Name = "Ember Dusk", W = 2, H = 0.0, Amt = 0.3, Acc = 0.985, Fog = C(196, 58, 48), FogAmt = 0.3, Clock = -0.8, Exp = -0.05 },
        { Id = "Sulfur", Name = "Sulfur Haze", W = 2, H = 0.13, Amt = 0.35, Acc = 0.12, Fog = C(214, 186, 92), FogAmt = 0.35, Dens = 1.15, CCSat = -0.03 },
        { Id = "Obsidian", Name = "Obsidian Night", W = 1, Sat = 0.8, Val = 0.86, Acc = 0.035, Fog = C(70, 22, 32), FogAmt = 0.35, Clock = 0.9, Exp = -0.06, CCSat = 0.05 },
        { Id = "BlueFlame", Name = "Blue Flame", W = 1, H = 0.6, Amt = 0.15, Acc = 0.55, Fog = C(70, 110, 180), FogAmt = 0.25 },
    },
    Ice = {
        { Id = "Glacial", W = 3 },
        { Id = "Aurora", Name = "Aurora Night", W = 2, Val = 0.9, Acc = 0.43, Fog = C(60, 150, 140), FogAmt = 0.3, Exp = -0.08 },
        { Id = "RoseDawn", Name = "Rose Dawn", W = 2, H = 0.95, Amt = 0.25, Acc = 0.93, Fog = C(238, 182, 202), FogAmt = 0.35 },
        { Id = "Whiteout", Name = "Whiteout", W = 1, Sat = 0.5, Fog = C(228, 234, 240), FogAmt = 0.45, Dens = 1.3 },
        { Id = "DeepIce", Name = "Deep Glacier", W = 2, H = 0.6, Amt = 0.4, Sat = 1.25, Val = 0.9, Acc = 0.6, Fog = C(80, 130, 200), FogAmt = 0.3 },
    },
    Void = {
        { Id = "Rift", W = 3 },
        { Id = "AbyssTeal", Name = "Abyssal Teal", W = 2, H = 0.5, Amt = 0.35, Acc = 0.48, Fog = C(30, 120, 130), FogAmt = 0.35 },
        { Id = "Crimson", Name = "Crimson Rift", W = 2, H = 0.95, Amt = 0.3, Acc = 0.97, Fog = C(150, 30, 60), FogAmt = 0.35 },
        { Id = "Starfall", Name = "Starfall", W = 1, Acc = 0.12, Fog = C(150, 112, 60), FogAmt = 0.25 },
        { Id = "Ultraviolet", Name = "Ultraviolet", W = 2, Sat = 1.2, Acc = 0.78, Fog = C(120, 40, 200), FogAmt = 0.3, CCSat = 0.06 },
    },
    Cyber = {
        { Id = "Neon", W = 3 },
        { Id = "Matrix", Name = "Mainframe", W = 2, H = 0.35, Amt = 0.25, Acc = 0.36, Fog = C(40, 160, 90), FogAmt = 0.3 },
        { Id = "IceGrid", Name = "Ice Grid", W = 2, H = 0.58, Amt = 0.2, Acc = 0.55, Fog = C(60, 150, 230), FogAmt = 0.3 },
        { Id = "Blackout", Name = "Blackout", W = 1, Val = 0.86, Acc = 0.08, Fog = C(110, 60, 30), FogAmt = 0.25, Exp = -0.05 },
        { Id = "Synthwave", Name = "Synthwave", W = 2, Acc = 0.8, Fog = C(255, 110, 60), FogAmt = 0.3, Clock = 0.5 },
    },
    Storm = {
        { Id = "Tempest", W = 3 },
        { Id = "Squall", Name = "Squall", W = 2, Sat = 0.7, Fog = C(130, 140, 160), FogAmt = 0.35, Dens = 1.3 },
        { Id = "GreenSky", Name = "Green Sky", W = 1, H = 0.3, Amt = 0.2, Acc = 0.33, Fog = C(110, 150, 100), FogAmt = 0.35 },
        { Id = "VioletBolt", Name = "Violet Lightning", W = 2, Acc = 0.75, Fog = C(110, 90, 150), FogAmt = 0.3 },
        { Id = "GoldenBreak", Name = "Golden Break", W = 2, Acc = 0.12, Fog = C(210, 170, 110), FogAmt = 0.3, Exp = 0.04, Clock = -0.6 },
    },
    Dream = {
        { Id = "Lucid", W = 3 },
        { Id = "Mint", Name = "Mint Dream", W = 2, H = 0.45, Amt = 0.3, Acc = 0.45, Fog = C(170, 238, 218), FogAmt = 0.35 },
        { Id = "Peach", Name = "Peach Dream", W = 2, H = 0.06, Amt = 0.3, Acc = 0.05, Fog = C(255, 200, 170), FogAmt = 0.35 },
        { Id = "Midnight", Name = "Midnight Dream", W = 2, Val = 0.86, Acc = 0.65, Fog = C(80, 70, 160), FogAmt = 0.35, Exp = -0.06 },
    },
    Flats = {
        { Id = "Highway", W = 3 },
        { Id = "Noon", Name = "Noon Glare", W = 2, Sat = 0.85, Fog = C(255, 220, 170), FogAmt = 0.3, Exp = 0.04, Clock = -0.8 },
        { Id = "TealDusk", Name = "Teal Dusk", W = 2, Acc = 0.5, Fog = C(60, 170, 180), FogAmt = 0.3 },
        { Id = "PurpleNight", Name = "Purple Night", W = 2, H = 0.8, Amt = 0.2, Acc = 0.82, Fog = C(120, 60, 170), FogAmt = 0.35, Exp = -0.05 },
    },
}

-- (0.87 WORLDS: each world brings its own moods)
do
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for k, v in pairs(WB.Moods) do BiomeMood.MOODS[k] = v end end
end

local SURFACES = { "Floor", "FloorAlt", "Wall", "WallTrim", "Ceiling", "Prop", "PropAlt", "Hazard" }

-- roll a mood (force = a mood Id, Studio / maps)
function BiomeMood.Roll(biome: string, rng: Random, force: string?): any
    local list = BiomeMood.MOODS[biome]
    if not list then return nil end
    local pick = nil
    if force then
        for _, m in ipairs(list) do if m.Id == force then pick = m end end
    end
    if not pick then
        local total = 0
        for _, m in ipairs(list) do total += m.W end
        local r = rng:NextNumber() * total
        for _, m in ipairs(list) do
            r -= m.W
            if r <= 0 then pick = m break end
        end
        pick = pick or list[1]
    end
    -- the jitter (always, the default mood too: every floor is a little different)
    return {
        Id = pick.Id, Name = pick.Name or "",
        H = pick.H or 0, Amt = pick.Amt or 0,
        Sat = (pick.Sat or 1) * rng:NextNumber(0.92, 1.08),
        Val = (pick.Val or 1) * rng:NextNumber(0.95, 1.05),
        HueJ = rng:NextNumber(-0.02, 0.02),
        Acc = pick.Acc and ((pick.Acc + rng:NextNumber(-0.025, 0.025)) % 1) or -1,
        Fog = pick.Fog or Color3.new(0.5, 0.5, 0.5),
        FogAmt = (pick.FogAmt or 0) * rng:NextNumber(0.85, 1.15),
        Clock = (pick.Clock or 0) + rng:NextNumber(-0.4, 0.4),
        Exp = (pick.Exp or 0) + rng:NextNumber(-0.03, 0.03),
        Dens = (pick.Dens or 1) * rng:NextNumber(0.9, 1.12),
        CCSat = pick.CCSat or 0,
    }
end

-- one colour through the mood. accent = the accent / light colours (only their hue turns)
function BiomeMood.Shift(c: Color3, m: any, accent: boolean?): Color3
    if not m then return c end
    local h, s, v = c:ToHSV()
    if accent then
        if m.Acc and m.Acc >= 0 and s > 0.06 then h = m.Acc end
        return Color3.fromHSV(h % 1, s, v)
    end
    if (m.Amt or 0) > 0 then
        -- (only COLOURED surfaces turn: pulling a dark neutral stone toward yellow / green made olive mud -- seen in play,
        -- Molten + Sulfur. Neutral stone keeps its hue; the mood reaches it through the light grade instead.)
        local w = math.clamp((s - 0.3) / 0.35, 0, 1)
        local d = ((m.H - h + 0.5) % 1) - 0.5 -- (shortest way round the hue circle)
        h += d * m.Amt * w
        s = s * (1 + m.Amt * 0.4 * w)
    end
    h += (m.HueJ or 0) * math.clamp(s / 0.4, 0, 1)
    s = math.clamp(s * (m.Sat or 1), 0, math.max(0.78, s)) -- (never more saturated than 0.78 unless it already was)
    v = math.clamp(v * (m.Val or 1), 0, 1)
    return Color3.fromHSV(h % 1, s, v)
end

-- a tinted copy of a biome theme (the tables are shared: never edit them in place)
function BiomeMood.Theme(theme: any, m: any): any
    if not m then return theme end
    local t = table.clone(theme)
    for _, k in ipairs(SURFACES) do
        if type(theme[k]) == "table" and theme[k].Color then
            local s = table.clone(theme[k])
            s.Color = BiomeMood.Shift(s.Color, m)
            t[k] = s
        end
    end
    if typeof(theme.Accent) == "Color3" then t.Accent = BiomeMood.Shift(theme.Accent, m, true) end
    if typeof(theme.Light) == "Color3" then t.Light = BiomeMood.Shift(theme.Light, m, true) end
    return t
end

local FIELDS = { "H", "Amt", "Sat", "Val", "HueJ", "Acc", "FogAmt", "Clock", "Exp", "Dens", "CCSat" }
function BiomeMood.Stamp(folder: Instance, m: any)
    if not m then return end
    folder:SetAttribute("MoodId", m.Id)
    folder:SetAttribute("MoodName", m.Name)
    folder:SetAttribute("MoodFog", m.Fog)
    for _, k in ipairs(FIELDS) do folder:SetAttribute("Mood" .. k, m[k]) end
end
function BiomeMood.FromFolder(folder: Instance?): any
    if not folder or not folder:GetAttribute("MoodId") then return nil end
    local m = { Id = folder:GetAttribute("MoodId"), Name = folder:GetAttribute("MoodName"), Fog = folder:GetAttribute("MoodFog") }
    for _, k in ipairs(FIELDS) do m[k] = folder:GetAttribute("Mood" .. k) or 0 end
    return m
end
-- a key that changes when the mood does (the client's light cache)
function BiomeMood.Key(m: any): string
    if not m then return "" end
    return string.format("%s%.3f%.3f%.3f", m.Id, m.HueJ, m.Clock, m.FogAmt)
end

BiomeMood.LIGHT_FLOOR = 0.92 -- (a mood's ambient / grade tint keeps >= this share of the profile's luminance)
BiomeMood.EXP_FLOOR = 0.02 -- (a mood lowers exposure by at most this)
-- the client light profile under a mood (a copy)
function BiomeMood.LightAdjust(p: any, m: any): any
    if not m then return p end
    local q = table.clone(p)
    local f = m.FogAmt or 0
    q.ClockTime = (p.ClockTime or 12) + (m.Clock or 0)
    -- (UPDATE 4: Roblox dims a painted skybox once the sun is down -- a day clock never jitters past dusk / before dawn;
    -- Molten 17.7 + Obsidian Night's +0.9 used to land at ~19 and black its sky out)
    local base = p.ClockTime or 12
    if base >= 6.5 and base <= 17.8 then q.ClockTime = math.clamp(q.ClockTime, 6.5, 17.8) end
    -- (UPDATE 4 LIGHTING FLOOR, owner: "its incredibly dark in some biomes, you cant even see the gun": a mood may
    -- recolour the light but never darken it -- ambients / grade tint keep >= LIGHT_FLOOR of the profile's luminance,
    -- exposure drops at most EXP_FLOOR. Obsidian Night's dark-red fog pull + -0.06 left a textured gun black)
    local function Floor(c: Color3, base: Color3): Color3
        local lb = 0.3 * base.R + 0.59 * base.G + 0.11 * base.B
        local lc = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
        if lc <= 1e-4 or lc >= lb * BiomeMood.LIGHT_FLOOR then return c end
        local s = math.min(lb * BiomeMood.LIGHT_FLOOR / lc, 1 / math.max(c.R, c.G, c.B))
        return Color3.new(c.R * s, c.G * s, c.B * s)
    end
    if p.FogColor then q.FogColor = p.FogColor:Lerp(m.Fog, f) end
    if p.Ambient then q.Ambient = Floor(BiomeMood.Shift(p.Ambient:Lerp(m.Fog, f * 0.4), { Sat = 1, Val = 1, HueJ = m.HueJ }), p.Ambient) end
    if p.OutdoorAmbient then q.OutdoorAmbient = Floor(p.OutdoorAmbient:Lerp(m.Fog, f * 0.4), p.OutdoorAmbient) end
    q.Exposure = (p.Exposure or 0) + math.max(m.Exp or 0, -BiomeMood.EXP_FLOOR)
    q.CCSaturation = (p.CCSaturation or 0) + (m.CCSat or 0)
    -- (the grade is where most of a mood shows: a soft tint of the whole frame toward the mood's colour)
    if p.CCTint then q.CCTint = Floor(p.CCTint:Lerp(m.Fog:Lerp(Color3.new(1, 1, 1), 0.5), math.min(0.4, f * 0.85)), p.CCTint) end
    return q
end
-- the client's Atmosphere entry { Density, Color, Decay, Haze, Glare } under a mood
function BiomeMood.AtmoAdjust(a: { any }, m: any): { any }
    if not m then return a end
    local f = m.FogAmt or 0
    return { math.clamp(a[1] * (m.Dens or 1), 0, 0.6), a[2]:Lerp(m.Fog, f), a[3]:Lerp(m.Fog:Lerp(Color3.new(0, 0, 0), 0.5), f), a[4], a[5] }
end

return BiomeMood
