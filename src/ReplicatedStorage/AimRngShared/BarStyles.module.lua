--!nocheck
-- HEALTH BAR STYLES (cosmetic, 2026-10-02). Owner: "alternate appearances / cosmetics, paid with Robux (one super
-- rare one from the final boss)" + "make them 10x cooler: animated, small skulls on the side, devil wings, varying
-- colours" + "they look low effort -- need a lot of improvement in quality and overall aesthetic".
-- Shared by the client (EnemyBars draws with it, CosmeticsMenu previews + sells) and the server (CombatServer
-- validates ownership, sells, drops).
--   Unlock = "Free"  everyone owns it
--            "Robux" a Developer Product: ProductId 0 = not set up yet -> "Coming soon" (free in Studio tests)
--            "Drop"  only from DropSource; DropChance per kill of that boss, per player
-- Saved: state.BarStyle (equipped id), state.BarStylesOwned ({ [id] = true }). Player attributes "BarStyle" and
-- "BarStylesOwned" (comma list) mirror them for the client.
--
-- Look: real art (tools/make_bar_art.py -> art/ui/bars, uploaded; ids in ART). A style = an animated fill texture
-- (Tex, scrolling), colours (Chip = the drain segment, Back, Glow = soft light behind the bar), a bevelled metal
-- Frame tinted FrameTint, Anim extras ("Shimmer" light sweep, "Rainbow", "Pulse"), Segments (tick marks) and Decor:
-- animated image pieces around / inside the bar (wings that beat, skulls whose eyes glow and jaws rattle, flames,
-- icicles, lightning, a crown, gems, a halo, particles). Every hit pops an impact spark where the bar drained to.
-- BARS v2 (FX roll-out 2026-10-14, owner: "The health bars also need some work, they are super boring right now"; rules in
-- docs/FX_AUDIT.md "ROLL-OUT RULES" 4): style.Look = "Ink" = the house frame (dark back, 2 px ink edge, one hard lit facet
-- on the fill, no gloss band, no bevelled frame image); style.FillColor (else the enemy tint); style.TexColor (tints Tex); style.ChipMotion = "Drain"
-- (default) | "Shatter" (the lost piece breaks into shards that drop) | "Burn" (it glows hot and chars) | "Snap" (holds,
-- then clicks out in three steps). Decor ctx v2: + Back, Clip, ChipFrame, Fill, Tier ("Small" 84x8 | "Elite" 124x10 |
-- "Boss" | "Preview"); step info v2: + Chip, Drop (fraction lost this frame), DropX0 / DropX1 (pixels of the lost piece).
-- Studio: BarStyles.DevPreview(playerGui, id) (client DevAct "bars:<Id>") = the three sizes taking hits.
local BarStyles = {}

local C = Color3.fromRGB
BarStyles.ART = {
    glow = "rbxassetid://127666194839162", spark = "rbxassetid://80536041931702", bubble = "rbxassetid://98566335138058",
    snowflake = "rbxassetid://140627402783444", skull = "rbxassetid://131597795473689", crown = "rbxassetid://81915829022708",
    gem = "rbxassetid://81535014317662", halo = "rbxassetid://99807098544710", icicle = "rbxassetid://85815365362962",
    horn_L = "rbxassetid://78482188211250", horn_R = "rbxassetid://122684375171759", frame = "rbxassetid://72591574099342",
    flame1 = "rbxassetid://110967380412848", flame2 = "rbxassetid://72154640398897", flame3 = "rbxassetid://128257739433111",
    bolt1 = "rbxassetid://75939210582658", bolt2 = "rbxassetid://82860142434497", bolt3 = "rbxassetid://120631168154385",
    wing_bat_L = "rbxassetid://139808015092139", wing_bat_R = "rbxassetid://130507888241971",
    wing_angel_L = "rbxassetid://113275258865722", wing_angel_R = "rbxassetid://74702137322648",
    wing_gold_L = "rbxassetid://137065059870844", wing_gold_R = "rbxassetid://86784272634266",
    tex_blood = "rbxassetid://89956722440462", tex_electric = "rbxassetid://81754488559663", tex_gold = "rbxassetid://103988004421665",
    tex_hell = "rbxassetid://136959192776727", tex_hex = "rbxassetid://77782383651554", tex_holy = "rbxassetid://123002730938850",
    tex_ice = "rbxassetid://124824718707655", tex_lava = "rbxassetid://105867401475034", tex_prism = "rbxassetid://132135997714854",
    tex_toxic = "rbxassetid://127521214586653", tex_velvet = "rbxassetid://116286437145797", tex_void = "rbxassetid://95321800800049",
    tex_infernal = "rbxassetid://86150271711502", -- (INFERNAL set: CosmeticArt.Infernal -- obsidian split by hellfire cracks)
    tex_seraphim = "rbxassetid://124255685671248", -- (SERAPHIM set: pearl + gold filigree, tools/make_bar_art.py seraphim_tex)
    feather = "rbxassetid://80460881443909", -- (CosmeticArt.Feather)
}
local ART = BarStyles.ART

BarStyles.List = {
    -- (BARS v2: the house look -- ink edge, one lit facet, a white chip that drains; no gloss)
    -- (UI CLEAN R-C 2026-10-28: Standard = Clean -- a flat bar: dark track, flat fill in the enemy's colour, an off-white chip
    -- that drains; no ink edge, no facet, no gloss, no impact spark -- 6 instances a bar)
    { Id = "Standard", Name = "Standard", Rarity = "Common", Unlock = "Free", Desc = "Clean and readable. Takes each enemy's colour.",
      Look = "Ink", Clean = true, Chip = C(236, 232, 225) },
    { Id = "Tactical", Name = "Tactical HUD", Rarity = "Uncommon", Unlock = "Robux", Price = 49, ProductId = 3716099790,
      Desc = "Targeting brackets that kick on every hit, a scan line, 10% segments.",
      Tex = "tex_hex", TexSpeed = 30, Chip = C(230, 255, 240), Back = C(4, 16, 10), FrameTint = C(90, 200, 140), Glow = C(60, 255, 150), Square = true, Segments = 10,
      Decor = { "Brackets", "Scanline" } },
    { Id = "Inferno", Name = "Inferno", Rarity = "Rare", Unlock = "Robux", Price = 79, ProductId = 3716099805,
      Desc = "Molten lava churns inside, flames lick off the top and embers rise as it burns down.",
      Tex = "tex_lava", TexSpeed = 40, Chip = C(255, 240, 150), Back = C(22, 6, 2), FrameTint = C(140, 70, 40), Glow = C(255, 90, 20),
      Decor = { "Flames", "Embers" } },
    { Id = "Glacier", Name = "Glacier", Rarity = "Rare", Unlock = "Robux", Price = 79, ProductId = 3716099812,
      Desc = "Cracked ice with a cold glint, icicles hanging off the bottom, snow drifting down.",
      Tex = "tex_ice", TexSpeed = 12, Chip = C(220, 245, 255), Back = C(6, 12, 24), FrameTint = C(200, 235, 255), Glow = C(120, 200, 255),
      Anim = "Shimmer", Decor = { "Icicles", "Snow" } },
    { Id = "Toxic", Name = "Toxic Waste", Rarity = "Rare", Unlock = "Robux", Price = 79, ProductId = 3716099821,
      Desc = "Bubbling radioactive sludge that throbs and drips off the bar.",
      Tex = "tex_toxic", TexSpeed = 22, Chip = C(235, 255, 170), Back = C(8, 18, 4), FrameTint = C(120, 140, 110), Glow = C(140, 255, 40),
      Anim = "Pulse", Decor = { "Bubbles", "Drips" } },
    { Id = "Storm", Name = "Storm Caller", Rarity = "Rare", Unlock = "Robux", Price = 79, ProductId = 3716099825,
      Desc = "Living plasma inside; lightning crackles around the bar and arcs wildly on every hit.",
      Tex = "tex_electric", TexSpeed = 70, Chip = C(255, 255, 255), Back = C(4, 6, 20), FrameTint = C(150, 180, 230), Glow = C(100, 160, 255),
      Decor = { "Lightning", "Sparks" } },
    { Id = "BoneCollector", Name = "Bone Collector", Rarity = "Epic", Unlock = "Robux", Price = 99, ProductId = 3716099834,
      Desc = "A skull on each end: red eyes burn brighter and they rattle with every hit. Veined blood inside, bone dust falls.",
      Tex = "tex_blood", TexSpeed = 18, Chip = C(240, 230, 210), Back = C(10, 4, 4), FrameTint = C(235, 222, 195), Segments = 5,
      Decor = { "Skulls", "BoneDust" } },
    { Id = "VoidRift", Name = "Void Rift", Rarity = "Epic", Unlock = "Robux", Price = 99, ProductId = 3716099841,
      Desc = "A slice of deep space: a drifting nebula, twinkling stars, comets orbiting the bar.",
      Tex = "tex_void", TexSpeed = 14, Chip = C(230, 190, 255), Back = C(4, 0, 10), FrameTint = C(150, 110, 210), Glow = C(150, 60, 255),
      Decor = { "Stars", "Orbit" } },
    { Id = "Hellspawn", Name = "Hellspawn", Rarity = "Legendary", Unlock = "Robux", Price = 149, ProductId = 3716099853,
      Desc = "Beating bat wings, curled horns, hellfire inside and flames on top. It flares up on every hit.",
      Tex = "tex_hell", TexSpeed = 45, Chip = C(255, 200, 120), Back = C(8, 0, 0), FrameTint = C(90, 40, 36), Glow = C(255, 40, 20),
      Decor = { "Flames", "DevilWings", "Horns", "Embers" } },
    { Id = "Seraph", Name = "Seraph", Rarity = "Legendary", Unlock = "Robux", Price = 149, ProductId = 3716099860,
      Desc = "Feathered angel wings, a floating halo, holy light inside and drifting motes.",
      Tex = "tex_holy", TexSpeed = 16, Chip = C(255, 255, 255), Back = C(20, 18, 12), FrameTint = C(255, 235, 180), Glow = C(255, 240, 190),
      Anim = "Shimmer", Decor = { "AngelWings", "Halo", "Motes" } },
    { Id = "Prismatic", Name = "Prismatic", Rarity = "Legendary", Unlock = "Robux", Price = 149, ProductId = 3716099871,
      Desc = "Crystal shot through with every colour, cycling forever, with rainbow comets in orbit.",
      Tex = "tex_prism", TexSpeed = 20, Chip = C(255, 255, 255), Back = C(10, 10, 14), FrameTint = C(235, 235, 255), Glow = C(255, 255, 255),
      Anim = "Rainbow", Shine = true, Decor = { "Orbit", "Sparks" } },
    { Id = "Infernal", Name = "Infernal Pact", Rarity = "Mythic", Unlock = "Robux", Price = 199, ProductId = 0, Set = "Infernal",
      Desc = "Obsidian split by living hellfire under curled horns, a skull at each end whose eyes burn violet, violet comets circling the bar and embers rising off it. Part of the Infernal set.",
      Tex = "tex_infernal", TexSpeed = 22, Chip = C(255, 160, 175), Back = C(6, 0, 6), FrameTint = C(74, 40, 54), Glow = C(160, 60, 255),
      Anim = "Pulse", Segments = 4, Decor = { "Horns", "Skulls", "Orbit", "Embers" } },
    { Id = "SeraphimAscendant", Name = "Seraphim Ascendant", Rarity = "Mythic", Unlock = "Robux", Price = 199, ProductId = 0, Set = "Seraphim",
      Desc = "Polished pearl laced with gold filigree under a floating halo, white wings that beat at each end, feathers drifting down and gold star glints. Part of the Seraphim set.",
      Tex = "tex_seraphim", TexSpeed = 10, Chip = C(255, 226, 140), Back = C(26, 22, 14), FrameTint = C(255, 222, 150), Glow = C(255, 236, 180),
      Anim = "Shimmer", Segments = 4, Decor = { "AngelWings", "Halo", "Feathers", "Stars" } },
    { Id = "Sovereign", Name = "Sovereign's Crown", Rarity = "Mythic", Unlock = "Drop", DropSource = "SuperBoss", DropChance = 0.01,
      Desc = "Crimson velvet laced with gold under a floating crown, gilded wings, jewelled ends and falling gold dust. Only from a final-floor superboss, 1 in 100. Can't be bought.",
      Tex = "tex_velvet", TexSpeed = 14, Chip = C(255, 215, 90), Back = C(6, 2, 4), FrameTint = C(255, 205, 90), Glow = C(255, 185, 50),
      Anim = "Shimmer", Segments = 3, Decor = { "GoldWings", "Crown", "Gems", "GoldDust" } },
}
-- every SkinSets set's health bar (set.Bar = an entry like the ones above; its art in set.Art, its own decor pieces in
-- set.BarDecor = { Name = function(ctx, K) -> Step }, registered below once DECOR exists)
local SetsForBars = {}
do
    local okS, SkinFX = pcall(require, script.Parent:WaitForChild("SkinFX"))
    for _, set in ipairs(okS and SkinFX.SetOrder or {}) do
        for k, id in pairs(set.Art or {}) do if ART[k] == nil then ART[k] = id end end
        if set.Bar then
            local b = set.Bar
            b.Set = b.Set or set.Kind
            b.Rarity = b.Rarity or "Mythic"
            b.Unlock = b.Unlock or "Robux"
            b.ProductId = b.ProductId or 0
            table.insert(BarStyles.List, b)
        end
        table.insert(SetsForBars, set)
    end
end
BarStyles.ById = {}
for i, s in ipairs(BarStyles.List) do s.Order = i; BarStyles.ById[s.Id] = s end
BarStyles.Default = "Standard"

BarStyles.RarityColor = {
    Common = C(200, 200, 200), Uncommon = C(90, 220, 90), Rare = C(70, 150, 255), Epic = C(190, 90, 255),
    Legendary = C(255, 180, 40), Mythic = C(255, 60, 80),
}

function BarStyles.Get(id) return BarStyles.ById[id] or BarStyles.ById.Standard end

-- owned = { [id] = true } (server state) or a comma string (player attribute)
function BarStyles.Owns(owned, id)
    local s = BarStyles.ById[id]
    if not s then return false end
    if s.Unlock == "Free" then return true end
    if type(owned) == "string" then return table.find(string.split(owned, ","), id) ~= nil end
    return type(owned) == "table" and owned[id] == true
end

function BarStyles.OwnedString(owned)
    local t = {}
    if type(owned) == "table" then for id, v in pairs(owned) do if v == true and BarStyles.ById[id] then table.insert(t, id) end end end
    table.sort(t)
    return table.concat(t, ",")
end

-- ===================== drawing (client) =====================
local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function Img(key, props, parent)
    props.Image = ART[key] or key
    props.BackgroundTransparency = 1
    props.BorderSizePixel = 0
    return New("ImageLabel", props, parent)
end
local function Hue(t, s) return Color3.fromHSV(t % 1, s or 0.8, 1) end

-- items registered with a base transparency follow the bar's alpha
local function Fader()
    local items = {}
    local self = {}
    function self.Add(inst, base, prop) table.insert(items, { inst, base or 0, prop or "ImageTransparency" }) return inst end
    function self.Apply(alpha)
        for _, it in ipairs(items) do it[1][it[3]] = 1 - (1 - it[2]) * alpha end
    end
    return self
end

-- a small particle system made of image sprites
local function Particles(parent, opts)
    local pool, live = {}, {}
    local acc = 0
    local self = {}
    function self.Emit(x, y, vx, vy, life, size, color, spin)
        local f = table.remove(pool) or Img(opts.Image or "glow", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = opts.Z or 8 }, parent)
        f.Visible = true
        f.ImageColor3 = color
        table.insert(live, { F = f, X = x, Y = y, VX = vx, VY = vy, Life = life, T = 0, S = size, R = math.random() * 360, Spin = spin or 0 })
    end
    function self.Step(dt, alpha, rate)
        acc += dt * (rate or opts.Rate or 0)
        while acc >= 1 do acc -= 1; opts.Spawn(self) end
        for i = #live, 1, -1 do
            local p = live[i]
            p.T += dt
            if p.T >= p.Life then
                p.F.Visible = false
                table.insert(pool, p.F)
                table.remove(live, i)
            else
                p.VY += (opts.Gravity or 0) * dt
                p.X += p.VX * dt
                p.Y += p.VY * dt
                p.R += p.Spin * dt
                local k = p.T / p.Life
                local s = p.S * (opts.Shrink and (1 - k * 0.7) or 1)
                p.F.Position = UDim2.fromOffset(p.X, p.Y)
                p.F.Size = UDim2.fromOffset(s, s)
                p.F.Rotation = p.R
                local fadeIn = math.min(1, p.T / 0.08)
                p.F.ImageTransparency = 1 - (1 - k) * fadeIn * alpha * (opts.Alpha or 1)
            end
        end
    end
    return self
end

-- a pivot: a container centred on a point whose children rotate around that point
local function Pivot(parent, z)
    return New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 2), ZIndex = z or 1 }, parent)
end

-- ===================== DECOR =====================
-- ctx = { Holder, Inner (full-width fill content, clipped to the fill), W, H, U (decor unit), Style, Big }
-- returns Step(now, dt, alpha, info) with info = { Shown (0..1), Hit (0..1 flash), Big }
local DECOR = {}

DECOR.Brackets = function(ctx)
    local f, U = Fader(), ctx.U
    local pieces = {}
    for i = 1, 4 do
        local hx = New("Frame", { BackgroundColor3 = C(150, 255, 200), BorderSizePixel = 0, ZIndex = 9 }, ctx.Holder)
        local vy = New("Frame", { BackgroundColor3 = C(150, 255, 200), BorderSizePixel = 0, ZIndex = 9 }, ctx.Holder)
        f.Add(hx, 0, "BackgroundTransparency"); f.Add(vy, 0, "BackgroundTransparency")
        pieces[i] = { hx, vy }
    end
    local reticle = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = C(120, 255, 180), ZIndex = 1 }, ctx.Holder)
    return function(now, dt, alpha, info)
        local gap = 4 + info.Hit * U * 1.1 + math.sin(now * 3) * 0.8
        local len, th = math.max(5, U * 0.9), math.max(1.5, math.floor(U / 5))
        local W, H = ctx.W, ctx.H
        local corners = { { -gap, -gap, 1, 1 }, { W + gap, -gap, -1, 1 }, { -gap, H + gap, 1, -1 }, { W + gap, H + gap, -1, -1 } }
        for i, c in ipairs(corners) do
            local hx, vy = pieces[i][1], pieces[i][2]
            hx.Size = UDim2.fromOffset(len, th); vy.Size = UDim2.fromOffset(th, len)
            hx.Position = UDim2.fromOffset(c[3] > 0 and c[1] or c[1] - len, c[4] > 0 and c[2] or c[2] - th)
            vy.Position = UDim2.fromOffset(c[3] > 0 and c[1] or c[1] - th, c[4] > 0 and c[2] or c[2] - len)
        end
        reticle.Size = UDim2.fromOffset(U * 2.2 * (1 + info.Hit), U * 2.2 * (1 + info.Hit))
        reticle.Position = UDim2.fromOffset(W * info.Shown, H / 2)
        reticle.ImageTransparency = 1 - alpha * (0.25 + info.Hit * 0.5)
        f.Apply(alpha)
    end
end

DECOR.Scanline = function(ctx)
    local line = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), ZIndex = 6 }, ctx.Inner)
    New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, line)
    return function(now, dt, alpha)
        line.Position = UDim2.new((now * 0.7) % 1.2 - 0.1, 0, 0, 0)
        line.BackgroundTransparency = 1 - 0.85 * alpha
    end
end

DECOR.Flames = function(ctx)
    local U = ctx.U
    local n = math.max(5, math.floor(ctx.W / (U * 0.65)))
    local list = {}
    for i = 1, n do
        local f = Img("flame" .. math.random(1, 3), { AnchorPoint = Vector2.new(0.5, 1), ZIndex = 1 }, ctx.Holder)
        list[i] = { F = f, X = (i - 0.5) / n, Seed = math.random() * 50, Swap = 0 }
    end
    return function(now, dt, alpha, info)
        for _, t in ipairs(list) do
            local on = t.X <= info.Shown + 0.02
            local flick = 0.65 + 0.2 * math.sin(now * 11 + t.Seed) + 0.15 * math.sin(now * 23 + t.Seed * 1.7)
            local h = on and U * (1.5 * flick + info.Hit * 1.6) or 0
            t.F.Visible = h > 1 and alpha > 0.02
            t.F.Size = UDim2.fromOffset(h * 0.55, h)
            t.F.Position = UDim2.fromOffset(t.X * ctx.W + math.sin(now * 6 + t.Seed) * U * 0.08, ctx.H * 0.55)
            t.F.ImageTransparency = 1 - alpha * 0.95
            if now > t.Swap then t.Swap = now + 0.12 + math.random() * 0.2; t.F.Image = ART["flame" .. math.random(1, 3)] end
        end
    end
end

local function Rising(ctx, colors, speed, size, image)
    local U = ctx.U
    return Particles(ctx.Holder, { Image = image or "glow", Shrink = true, Z = 8, Spawn = function(ps)
        local x = math.random() * ctx.W * math.max(0.05, ctx.Shown or 1)
        ps.Emit(x, ctx.H * 0.3, (math.random() - 0.5) * U * 1.5, -speed * U * (0.6 + math.random() * 0.8), 0.5 + math.random() * 0.7,
            math.max(3, size * U * (0.6 + math.random() * 0.7)), colors[math.random(1, #colors)])
    end })
end

DECOR.Embers = function(ctx)
    local ps = Rising(ctx, { C(255, 210, 80), C(255, 130, 30), C(255, 70, 20) }, 3.4, 0.55)
    return function(now, dt, alpha, info)
        ctx.Shown = info.Shown
        ps.Step(dt, alpha, (info.Big and 30 or 12) * (1 + info.Hit * 5))
    end
end

DECOR.Motes = function(ctx)
    local ps = Rising(ctx, { C(255, 250, 220), C(255, 230, 150) }, 1.5, 0.5, "spark")
    return function(now, dt, alpha, info) ctx.Shown = 1; ps.Step(dt, alpha, info.Big and 16 or 6) end
end

DECOR.Sparks = function(ctx)
    local U = ctx.U
    local rainbow = ctx.Style.Anim == "Rainbow"
    local ps = Particles(ctx.Holder, { Image = "spark", Gravity = U * 16, Shrink = true, Z = 9, Spawn = function(ps)
        local x = ctx.W * (ctx.Shown or 1)
        local a = math.random() * math.pi * 2
        local sp = U * (4 + math.random() * 7)
        local col = rainbow and Hue(math.random()) or C(210, 235, 255)
        ps.Emit(x, ctx.H / 2, math.cos(a) * sp, math.sin(a) * sp - U * 3, 0.35 + math.random() * 0.3, math.max(4, U * 0.7), col, 400)
    end })
    return function(now, dt, alpha, info)
        ctx.Shown = info.Shown
        ps.Step(dt, alpha, (info.Big and 5 or 2) + info.Hit * 110)
    end
end

DECOR.Snow = function(ctx)
    local U = ctx.U
    local ps = Particles(ctx.Holder, { Image = "snowflake", Z = 8, Spawn = function(ps)
        ps.Emit(math.random() * ctx.W, ctx.H, (math.random() - 0.5) * U, U * (1 + math.random()), 1.2 + math.random() * 0.9,
            math.max(4, U * (0.45 + math.random() * 0.3)), C(240, 250, 255), (math.random() - 0.5) * 180)
    end })
    return function(now, dt, alpha, info) ps.Step(dt, alpha, info.Big and 14 or 5) end
end

DECOR.GoldDust = function(ctx)
    local U = ctx.U
    local ps = Particles(ctx.Holder, { Image = "spark", Z = 8, Shrink = true, Spawn = function(ps)
        ps.Emit(math.random() * ctx.W * (ctx.Shown or 1), ctx.H, (math.random() - 0.5) * U * 0.8, U * (0.7 + math.random()), 1 + math.random() * 0.8,
            math.max(4, U * 0.6), math.random() < 0.5 and C(255, 215, 90) or C(255, 250, 210), 200)
    end })
    return function(now, dt, alpha, info) ctx.Shown = info.Shown; ps.Step(dt, alpha, (info.Big and 18 or 7) * (1 + info.Hit * 3)) end
end

DECOR.BoneDust = function(ctx)
    local U = ctx.U
    local ps = Particles(ctx.Holder, { Image = "glow", Z = 8, Shrink = true, Gravity = U * 3, Spawn = function(ps)
        ps.Emit(math.random() * ctx.W, ctx.H, (math.random() - 0.5) * U * 0.5, U * 0.4, 0.9 + math.random() * 0.6, math.max(3, U * 0.4), C(230, 220, 200))
    end })
    return function(now, dt, alpha, info) ps.Step(dt, alpha, (info.Big and 10 or 3) + info.Hit * 30) end
end

DECOR.Icicles = function(ctx)
    local U, f = ctx.U, Fader()
    local n = math.max(4, math.floor(ctx.W / (U * 0.9)))
    local list = {}
    for i = 1, n do
        local ic = Img("icicle", { AnchorPoint = Vector2.new(0.5, 0), ZIndex = 1 }, ctx.Holder)
        f.Add(ic, 0.05)
        list[i] = { F = ic, X = (i - 0.5 + (math.random() - 0.5) * 0.5) / n, L = 0.7 + math.random() * 1.1, Seed = math.random() * 10 }
    end
    return function(now, dt, alpha, info)
        for _, ic in ipairs(list) do
            local shake = info.Hit * math.sin(now * 70 + ic.Seed) * U * 0.2
            local h = U * 1.6 * ic.L
            ic.F.Size = UDim2.fromOffset(h / 3, h)
            ic.F.Position = UDim2.fromOffset(ic.X * ctx.W + shake, ctx.H - 2)
        end
        f.Apply(alpha)
    end
end

DECOR.Bubbles = function(ctx)
    local list = {}
    for i = 1, (ctx.Big and 16 or 7) do
        local b = Img("bubble", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, ImageColor3 = C(230, 255, 190) }, ctx.Inner)
        list[i] = { F = b, X = math.random(), P = math.random(), Sp = 0.5 + math.random() * 0.8, Sz = 0.35 + math.random() * 0.4 }
    end
    return function(now, dt, alpha)
        for _, b in ipairs(list) do
            b.P += dt * b.Sp
            if b.P > 1 then b.P = 0; b.X = math.random() end
            local s = math.max(3, ctx.H * b.Sz)
            b.F.Size = UDim2.fromOffset(s, s)
            b.F.Position = UDim2.new(b.X, math.sin(now * 3 + b.X * 20) * 2, 1 - b.P, 0)
            b.F.ImageTransparency = 1 - alpha * (1 - b.P) * 0.95
        end
    end
end

DECOR.Drips = function(ctx)
    local U = ctx.U
    local ps = Particles(ctx.Holder, { Image = "glow", Gravity = U * 30, Z = 7, Spawn = function(ps)
        ps.Emit(math.random() * ctx.W * (ctx.Shown or 1), ctx.H, 0, U * 0.5, 0.7, math.max(4, U * 0.6), C(160, 255, 50))
    end })
    return function(now, dt, alpha, info) ctx.Shown = info.Shown; ps.Step(dt, alpha, (info.Big and 7 or 2.5) + info.Hit * 25) end
end

DECOR.Lightning = function(ctx)
    local U = ctx.U
    local bolts = {}
    for b = 1, 3 do
        bolts[b] = { F = Img("bolt" .. b, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 }, ctx.Holder), Until = 0, Next = math.random() }
    end
    local flash = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = C(120, 170, 255), ZIndex = 1 }, ctx.Holder)
    return function(now, dt, alpha, info)
        local anyOn = false
        for _, b in ipairs(bolts) do
            if now >= b.Next or (info.Hit > 0.8 and now > b.Until) then
                b.Until = now + 0.07 + math.random() * 0.09
                b.Next = now + (info.Big and 0.3 or 0.6) + math.random() * (info.Big and 0.7 or 1.5)
                local len = ctx.W * (0.35 + math.random() * 0.4)
                local up = math.random() < 0.5
                b.F.Image = ART["bolt" .. math.random(1, 3)]
                b.F.Size = UDim2.fromOffset(len, U * 1.6)
                b.F.Position = UDim2.fromOffset(len / 2 + math.random() * (ctx.W - len), up and -U * 0.15 or ctx.H + U * 0.15)
                b.F.Rotation = (up and 0 or 180) + (math.random() - 0.5) * 14
            end
            local on = now < b.Until and alpha > 0.05
            b.F.Visible = on
            b.F.ImageTransparency = 1 - alpha
            anyOn = anyOn or on
        end
        flash.Size = UDim2.fromOffset(ctx.W * 1.3, ctx.H + U * 3)
        flash.Position = UDim2.fromOffset(ctx.W / 2, ctx.H / 2)
        flash.ImageTransparency = anyOn and (1 - alpha * 0.35) or 1
    end
end

DECOR.Stars = function(ctx)
    local list = {}
    for i = 1, (ctx.Big and 26 or 9) do
        local s = Img("spark", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Position = UDim2.fromScale(math.random(), 0.15 + math.random() * 0.7) }, ctx.Inner)
        list[i] = { F = s, Seed = math.random() * 20, Sp = 1 + math.random() * 3 }
    end
    return function(now, dt, alpha)
        for _, s in ipairs(list) do
            local tw = 0.5 + 0.5 * math.sin(now * s.Sp + s.Seed)
            local sz = math.max(3, ctx.H * 0.55 * (0.4 + tw))
            s.F.Size = UDim2.fromOffset(sz, sz)
            s.F.ImageTransparency = 1 - alpha * (0.2 + 0.8 * tw)
        end
    end
end

DECOR.Orbit = function(ctx)
    local U = ctx.U
    local rainbow = ctx.Style.Anim == "Rainbow"
    local motes = {}
    for i = 1, 2 do
        local head = Img("spark", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = ctx.Style.Glow or Color3.new(1, 1, 1) }, ctx.Holder)
        local trail = {}
        for t = 1, 10 do trail[t] = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = ctx.Style.Glow or Color3.new(1, 1, 1) }, ctx.Holder) end
        motes[i] = { F = head, Trail = trail, Ph = (i - 1) * math.pi }
    end
    return function(now, dt, alpha, info)
        local cx, cy = ctx.W / 2, ctx.H / 2
        local rx, ry = ctx.W / 2 + U * 0.9, ctx.H / 2 + U * 0.8
        for i, m in ipairs(motes) do
            for t = 0, 10 do
                local a = now * (1.3 + info.Hit * 3) + m.Ph - t * 0.04
                local f = (t == 0) and m.F or m.Trail[t]
                local s = (t == 0) and U * 1.4 or math.max(2, U * 0.7 * (1 - t * 0.08))
                f.Position = UDim2.fromOffset(cx + math.cos(a) * rx, cy + math.sin(a) * ry)
                f.Size = UDim2.fromOffset(s, s)
                f.ZIndex = math.sin(a) > 0 and 10 or 0 -- in front on the bottom half, behind on the top
                f.ImageTransparency = 1 - alpha * (1 - t * 0.09)
                if rainbow then f.ImageColor3 = Hue(now * 0.3 + i / 2 - t * 0.02, 0.7) end
            end
        end
    end
end

DECOR.Halo = function(ctx)
    local U = ctx.U
    local glow = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = C(255, 230, 150), ZIndex = 1 }, ctx.Holder)
    local ring = Img("halo", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 }, ctx.Holder)
    return function(now, dt, alpha, info)
        local bob = math.sin(now * 2) * U * 0.2
        local w = U * 4.2 * (1 + info.Hit * 0.15)
        ring.Size = UDim2.fromOffset(w, w * 0.375)
        ring.Position = UDim2.fromOffset(ctx.W / 2, -U * 1.0 + bob)
        glow.Size = UDim2.fromOffset(w * 1.2, w * 0.6)
        glow.Position = ring.Position
        ring.ImageTransparency = 1 - alpha
        glow.ImageTransparency = 1 - alpha * (0.35 + 0.15 * math.sin(now * 4) + info.Hit * 0.4)
    end
end

-- wings: an image whose root (the shoulder) sits on the bar's end; it beats around that root
local WING_ROOT = { bat = Vector2.new(492 / 512, 214 / 384), angel = Vector2.new(492 / 512, 330 / 384), gold = Vector2.new(492 / 512, 330 / 384) }
local function Wings(ctx, kind, sizeMul, beatSpeed, beatAmp)
    local U, f = ctx.U, Fader()
    local wings = {}
    for _, side in ipairs({ -1, 1 }) do
        local piv = Pivot(ctx.Holder, 0)
        local root = WING_ROOT[kind]
        local img = Img("wing_" .. kind .. (side < 0 and "_L" or "_R"),
            { AnchorPoint = side < 0 and root or Vector2.new(1 - root.X, root.Y), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 0 }, piv)
        f.Add(img, 0)
        wings[side] = { Piv = piv, Img = img }
    end
    return function(now, dt, alpha, info)
        local beat = math.sin(now * (beatSpeed + info.Hit * 8))
        local h = U * sizeMul * (1 + info.Hit * 0.12)
        for side, w in pairs(wings) do
            w.Piv.Position = UDim2.fromOffset(side < 0 and U * 0.15 or ctx.W - U * 0.15, ctx.H * 0.5)
            -- the wing folds (squashes toward the body) and rocks on the down-beat
            local fold = 0.82 + 0.18 * (beat * 0.5 + 0.5)
            w.Img.Size = UDim2.fromOffset(h * 1.333 * fold, h * (0.92 + 0.08 * fold))
            w.Piv.Rotation = side * (beat * beatAmp - info.Hit * 10)
        end
        f.Apply(alpha)
    end
end
DECOR.DevilWings = function(ctx) return Wings(ctx, "bat", 2.6, 5, 9) end
-- feathers that come loose from the wings and drift down, rocking side to side (SERAPHIM); hits shake a few more loose
DECOR.Feathers = function(ctx)
    local U = ctx.U
    local pool = {}
    for i = 1, (ctx.Big and 8 or 4) do
        pool[i] = { F = Img("feather", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = C(255, 248, 230), ZIndex = 1, ImageTransparency = 1 }, ctx.Holder), T = 99, Life = 1 }
    end
    local acc = 0
    local function Spawn()
        for _, p in ipairs(pool) do
            if p.T >= p.Life then
                local side = math.random() < 0.5 and -1 or 1
                p.T, p.Life = 0, 2.2 + math.random() * 1.4
                p.X = (side < 0 and -U * 1.2 or ctx.W + U * 1.2) + (math.random() - 0.5) * U * 1.5
                p.Y = ctx.H * 0.5 - U * (0.2 + math.random() * 0.8)
                p.Ph, p.Sw, p.Drift = math.random() * 6.28, U * (0.5 + math.random() * 0.5), -side * U * (0.2 + math.random() * 0.5)
                p.S = U * (0.9 + math.random() * 0.5)
                return
            end
        end
    end
    return function(now, dt, alpha, info)
        acc += dt * ((info.Big and 1.6 or 0.7) + info.Hit * 12)
        while acc >= 1 do acc -= 1; Spawn() end
        for _, p in ipairs(pool) do
            if p.T < p.Life then
                p.T += dt
                local k = p.T / p.Life
                local sway = math.sin(p.T * 2.4 + p.Ph)
                p.F.Position = UDim2.fromOffset(p.X + p.Drift * p.T + sway * p.Sw, p.Y + U * 1.1 * p.T)
                p.F.Size = UDim2.fromOffset(p.S, p.S)
                p.F.Rotation = sway * 35 + 20
                p.F.ImageTransparency = 1 - alpha * math.min(1, k * 6) * (1 - k) * 0.9
            else
                p.F.ImageTransparency = 1
            end
        end
    end
end

DECOR.AngelWings = function(ctx) return Wings(ctx, "angel", 2.8, 2.6, 6) end
DECOR.GoldWings = function(ctx) return Wings(ctx, "gold", 2.4, 2.6, 6) end

DECOR.Horns = function(ctx)
    local U, f = ctx.U, Fader()
    local horns = {}
    for _, side in ipairs({ -1, 1 }) do
        local img = Img(side < 0 and "horn_L" or "horn_R", { AnchorPoint = Vector2.new(side < 0 and 0.3 or 0.7, 0.95), ZIndex = 1 }, ctx.Holder)
        f.Add(img)
        horns[side] = img
    end
    return function(now, dt, alpha, info)
        local h = U * 1.9 * (1 + info.Hit * 0.15)
        for side, img in pairs(horns) do
            img.Size = UDim2.fromOffset(h * 0.5, h)
            img.Position = UDim2.fromOffset(side < 0 and ctx.W * 0.1 or ctx.W * 0.9, ctx.H * 0.3 - info.Hit * U * 0.25)
            img.Rotation = side * (-8 + math.sin(now * 2) * 2)
        end
        f.Apply(alpha)
    end
end

DECOR.Skulls = function(ctx)
    local U, f = ctx.U, Fader()
    local skulls = {}
    for _, side in ipairs({ -1, 1 }) do
        local piv = Pivot(ctx.Holder, 10)
        local aura = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = C(255, 30, 20), ZIndex = 9 }, piv)
        local img = Img("skull", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 10 }, piv)
        local eyes = {}
        for i, ex in ipairs({ 0.355, 0.645 }) do
            eyes[i] = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(ex, 0.46), Size = UDim2.fromScale(0.36, 0.36), ImageColor3 = C(255, 40, 20), ZIndex = 11 }, img)
        end
        f.Add(img)
        skulls[side] = { Piv = piv, Img = img, Eyes = eyes, Aura = aura }
    end
    return function(now, dt, alpha, info)
        local s = U * 2.3
        for side, sk in pairs(skulls) do
            local rattle = info.Hit * math.sin(now * 60 + side) * 10
            sk.Piv.Position = UDim2.fromOffset(side < 0 and -s * 0.32 or ctx.W + s * 0.32, ctx.H / 2 + math.sin(now * 2.2 + side) * U * 0.08)
            sk.Piv.Rotation = side * (8 + math.sin(now * 1.5) * 4) + rattle
            sk.Img.Size = UDim2.fromOffset(s * (1 + info.Hit * 0.12), s * (1 + info.Hit * 0.12))
            sk.Aura.Size = UDim2.fromOffset(s * 1.9, s * 1.9)
            sk.Aura.ImageTransparency = 1 - alpha * (0.15 + 0.15 * math.sin(now * 3) + info.Hit * 0.4)
            local burn = 0.55 + 0.3 * math.sin(now * 5 + side) + info.Hit * 0.5
            for _, e in ipairs(sk.Eyes) do
                e.ImageTransparency = 1 - alpha * math.clamp(burn, 0, 1)
                local es = 0.36 * (1 + info.Hit * 0.6)
                e.Size = UDim2.fromScale(es, es)
            end
        end
        f.Apply(alpha)
    end
end

DECOR.Crown = function(ctx)
    local U, f = ctx.U, Fader()
    local glow = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = C(255, 200, 80), ZIndex = 1 }, ctx.Holder)
    local crown = Img("crown", { AnchorPoint = Vector2.new(0.5, 1), ZIndex = 10 }, ctx.Holder)
    f.Add(crown)
    local glints = {}
    for i = 1, 3 do glints[i] = { F = Img("spark", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 }, crown), Seed = i * 2.1 } end
    return function(now, dt, alpha, info)
        local w = U * 3.4 * (1 + info.Hit * 0.12)
        crown.Size = UDim2.fromOffset(w, w * 0.6875)
        crown.Position = UDim2.fromOffset(ctx.W / 2, ctx.H * 0.35 + math.sin(now * 2) * U * 0.15 - info.Hit * U * 0.5)
        crown.Rotation = math.sin(now * 1.3) * 4
        glow.Size = UDim2.fromOffset(w * 1.5, w)
        glow.Position = UDim2.fromOffset(ctx.W / 2, ctx.H * 0.35 - w * 0.3)
        glow.ImageTransparency = 1 - alpha * (0.4 + 0.1 * math.sin(now * 3))
        for _, g in ipairs(glints) do
            local cyc = (now * 0.8 + g.Seed) % 1.6
            if cyc < 0.05 then g.F.Position = UDim2.fromScale(0.15 + math.random() * 0.7, 0.2 + math.random() * 0.6) end
            local k = math.clamp(1 - math.abs(cyc - 0.3) / 0.3, 0, 1)
            g.F.Size = UDim2.fromOffset(U * 1.2 * k, U * 1.2 * k)
            g.F.ImageTransparency = 1 - alpha * k
            g.F.Rotation = now * 90
        end
        f.Apply(alpha)
    end
end

DECOR.Gems = function(ctx)
    local U, f = ctx.U, Fader()
    local gems = {}
    for _, side in ipairs({ -1, 1 }) do
        local gl = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = C(255, 40, 70), ZIndex = 9 }, ctx.Holder)
        local g = Img("gem", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 }, ctx.Holder)
        local tw = Img("spark", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.3), ZIndex = 11 }, g)
        f.Add(g)
        gems[side] = { G = g, Glow = gl, Tw = tw }
    end
    return function(now, dt, alpha, info)
        for side, g in pairs(gems) do
            local s = U * 1.5 * (1 + info.Hit * 0.25)
            local pos = UDim2.fromOffset(side < 0 and -U * 0.1 or ctx.W + U * 0.1, ctx.H / 2)
            g.G.Size = UDim2.fromOffset(s, s); g.G.Position = pos
            g.Glow.Size = UDim2.fromOffset(s * 2.2, s * 2.2); g.Glow.Position = pos
            g.Glow.ImageTransparency = 1 - alpha * (0.35 + 0.2 * math.sin(now * 3 + side))
            local k = math.max(0, math.sin(now * 2.5 + side * 1.3)) ^ 6
            g.Tw.Size = UDim2.fromScale(0.9 * k, 0.9 * k)
            g.Tw.ImageTransparency = 1 - alpha * k
        end
        f.Apply(alpha)
    end
end

-- Builds a bar widget. tint = the enemy's own colour (Standard). big = boss bar (more particles).
-- SkinSets decor pieces (their names are prefixed by nothing: keep them unique, e.g. "SolarFlares")
do
    local K = { New = New, Img = Img, Hue = Hue, Fader = Fader, Particles = Particles, Pivot = Pivot, Rising = Rising, C = C, ART = ART }
    for _, set in ipairs(SetsForBars) do
        for name, fn in pairs(set.BarDecor or {}) do
            if DECOR[name] == nil then DECOR[name] = function(ctx) return fn(ctx, K) end end
        end
    end
    -- (0.93 COLORWAYS) "Tempest#2" = the set's bar from its recoloured copy (SkinFX.Sets["Tempest#2"]); its own decor
    -- pieces are registered as "<Name>#2". The server puts this id in the player's BarStyle attribute.
    local Colorways = require(script.Parent:WaitForChild("Colorways"))
    setmetatable(BarStyles.ById, { __index = function(t, key)
        if type(key) ~= "string" then return nil end
        local id, v = Colorways.Parse(key)
        local base = v > 1 and rawget(t, id)
        local okS, SkinFX = pcall(require, script.Parent:WaitForChild("SkinFX"))
        local set = base and base.Set and okS and SkinFX.Sets[base.Set .. "#" .. v]
        if not (set and set.Bar) then rawset(t, key, false) return nil end
        for k, aid in pairs(set.Art or {}) do if ART[k] == nil then ART[k] = aid end end
        local kit = table.clone(K)
        kit.C = Colorways.C3For(base.Set, v) -- (decor pieces colour with the kit's C)
        for name, fn in pairs(set.BarDecor or {}) do
            DECOR[name .. "#" .. v] = function(ctx) return fn(ctx, kit) end
        end
        local b = table.clone(set.Bar)
        if type(b.Decor) == "table" then
            local d = {}
            for i, n in ipairs(b.Decor) do d[i] = (set.BarDecor and set.BarDecor[n]) and (n .. "#" .. v) or n end
            b.Decor = d
        end
        b.Id, b.BaseId, b.Variant, b.Set = key, id, v, base.Set
        b.Rarity, b.Unlock, b.ProductId, b.Order = base.Rarity, base.Unlock, base.ProductId, base.Order
        rawset(t, key, b)
        return b
    end })
end

-- (UI CLEAN R-C) the Clean look: holder > track (flat, square) > clip > chip + fill > inner; Paint has a matching short path
local function MakeClean(parent, w, h, style, tint, big)
    local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 1) }, parent)
    local back = New("Frame", { Name = "Back", BackgroundColor3 = C(10, 11, 14), BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, holder)
    local clip = New("Frame", { Name = "Clip", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 2 }, back)
    local chip = New("Frame", { Name = "Chip", BackgroundColor3 = style.Chip or C(236, 232, 225), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, clip)
    local fill = New("Frame", { Name = "Fill", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 3 }, clip)
    local inner = New("Frame", { Name = "Inner", BackgroundColor3 = tint or C(232, 92, 92), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, fill)
    local scale = New("UIScale", { Scale = 1 }, holder)
    return { Holder = holder, Back = back, Clip = clip, Chip = chip, Fill = fill, Inner = inner, Scale = scale, W = w, H = h, Style = style,
        Clean = true, Ticks = {}, Decor = {}, Tier = big and "Boss" or "Small", LastShown = 1, DropAt = -99, Seed = 0, U = math.max(9, h) }
end

function BarStyles.MakeBar(parent, w, h, style, tint, big)
    style = style or BarStyles.ById.Standard
    if style.Clean then return MakeClean(parent, w, h, style, tint, big) end
    local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 1) }, parent)
    local glow
    if style.Glow then
        glow = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, h * 3, 1, h * 3.2), ImageColor3 = style.Glow, ZIndex = 1 }, holder)
    end
    local ink = style.Look == "Ink"
    local back = New("Frame", { Name = "Back", BackgroundColor3 = style.Back or C(12, 12, 16), BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, holder)
    if ink then
        New("UICorner", { CornerRadius = UDim.new(0, 2) }, back)
    elseif not style.Square then New("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(h / 2.5))) }, back) end
    local stroke = New("UIStroke", { Color = ink and C(8, 8, 10) or Color3.new(0, 0, 0), Thickness = ink and 2 or 1.5, Transparency = ink and 0 or 0.15,
        LineJoinMode = ink and Enum.LineJoinMode.Miter or Enum.LineJoinMode.Round }, back)
    local inset = (style.FrameTint and not ink) and math.max(1, math.floor(h * 0.12)) or (ink and 1 or 2)
    local clip = New("Frame", { Name = "Clip", BackgroundTransparency = 1, Size = UDim2.new(1, -inset * 2, 1, -inset * 2), Position = UDim2.fromOffset(inset, inset), ClipsDescendants = true, ZIndex = 2 }, back)
    if not style.Square and not ink then New("UICorner", { CornerRadius = UDim.new(0, math.max(1, math.floor(h / 3))) }, clip) end
    local chip = New("Frame", { Name = "Chip", BackgroundColor3 = style.Chip or C(255, 236, 170), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, clip)
    local fill = New("Frame", { Name = "Fill", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 3 }, clip)
    -- the fill's content is laid out over the FULL bar width (an inner frame inside the shrinking fill), so the
    -- colour / texture under a spot never shifts as health drains
    local inner = New("Frame", { Name = "Inner", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, fill)
    local grad = New("UIGradient", { Name = "Colors", Rotation = 0 }, inner)
    local tex, texGrad, tileW
    local innerH = h - inset * 2
    if style.Tex then
        inner.BackgroundColor3 = style.Back or C(0, 0, 0)
        tileW = math.max(16, innerH * 4)
        tex = Img(style.Tex, { Size = UDim2.new(1, tileW, 1, 0), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(tileW, innerH), ZIndex = 3 }, inner)
        if style.Anim == "Rainbow" then
            texGrad = New("UIGradient", { Rotation = 0 }, tex)
        else
            New("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(230, 230, 230)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)) }) }, tex)
        end
        grad.Enabled = false
    else
        local fc = style.FillColor or tint or C(235, 60, 60)
        grad.Rotation = 90
        if ink then -- (one hard facet: a lit top band, a darker body -- no soft gradient)
            grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, fc:Lerp(Color3.new(1, 1, 1), 0.28)), ColorSequenceKeypoint.new(0.42, fc:Lerp(Color3.new(1, 1, 1), 0.28)),
                ColorSequenceKeypoint.new(0.43, fc), ColorSequenceKeypoint.new(1, fc:Lerp(Color3.new(0, 0, 0), 0.12)) })
        else
            grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, fc:Lerp(Color3.new(1, 1, 1), 0.25)), ColorSequenceKeypoint.new(1, fc:Lerp(Color3.new(0, 0, 0), 0.25)) })
        end
    end
    local gloss = New("Frame", { Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.42), ZIndex = 5 }, inner)
    if ink then
        -- (the house facet over a textured fill: a flat lit band with a hard lower edge; a plain fill has it in its colours)
        gloss.BackgroundTransparency = style.Tex and 0.82 or 1
        gloss:SetAttribute("Facet", true)
    else
        New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.5, 1) }, gloss)
    end
    local shine
    if style.Anim == "Shimmer" or style.Shine then
        shine = New("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0.06, math.max(6, h), 1, 0), ZIndex = 6, Rotation = 0 }, inner)
        New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) }) }, shine)
    end
    local ticks = {}
    if style.Segments then
        for i = 1, style.Segments - 1 do
            ticks[i] = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 7,
                Size = UDim2.new(0, math.max(1, math.floor(h / 7)), 1, 0), Position = UDim2.new(i / style.Segments, 0, 0, 0) }, clip)
        end
    end
    local flash = New("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, clip)
    -- bevelled metal frame over the edge (9-slice, tinted)
    local frame
    if style.FrameTint and not ink then
        local pad = math.max(2, math.floor(h * 0.28))
        frame = Img("frame", { ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(16, 16, 80, 32), SliceScale = math.max(0.12, (pad + 1) / 14),
            ImageColor3 = style.FrameTint, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, pad * 2, 1, pad * 2), ZIndex = 9 }, holder)
        stroke.Enabled = false
    end
    -- impact spark where the bar drained to (every hit, every style)
    local impact = Img("spark", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 12, ImageTransparency = 1 }, holder)
    local impactGlow = Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11, ImageTransparency = 1, ImageColor3 = style.Chip or C(255, 236, 170) }, holder)
    local scale = New("UIScale", { Scale = 1 }, holder)
    local bar = { Holder = holder, Back = back, Stroke = stroke, Glow = glow, Clip = clip, Chip = chip, Fill = fill, Inner = inner,
        Grad = grad, Tex = tex, TexGrad = texGrad, TileW = tileW, Gloss = gloss, Shine = shine, Ticks = ticks, Flash = flash, Frame = frame,
        Impact = impact, ImpactGlow = impactGlow, ImpactT = 99, PrevFlash = 0,
        Scale = scale, W = w, H = h, Style = style, Seed = math.random() * 10, Decor = {} }
    local tier = big and "Boss" or ((h <= 8) and "Small") or ((w >= 120 and w <= 130 and h <= 10) and "Elite") or "Preview"
    local ctx = { Holder = holder, Inner = inner, W = w, H = h, U = math.max(9, h * (big and 1.35 or 1.6)), Style = style, Big = big,
        Back = back, Clip = clip, ChipFrame = chip, Fill = fill, Tier = tier }
    bar.Tier, bar.LastShown, bar.DropAt, bar.Ink = tier, 1, -99, ink
    bar.U = ctx.U
    for _, name in ipairs(style.Decor or {}) do
        local mk = DECOR[name]
        if mk then table.insert(bar.Decor, mk(ctx)) end
    end
    return bar
end

-- per frame: shown / chip fractions, flash 0..1 (just hit), alpha (1 = fully visible), dt, big (boss bar)
function BarStyles.Paint(bar, shown, chip, flash, alpha, now, dt, big)
    local st = bar.Style
    dt = dt or 0
    shown = math.clamp(shown, 0, 1)
    if bar.Clean then -- (UI CLEAN R-C: sizes + one transparency each; property writes only when they change)
        local fs, cs = UDim2.fromScale(shown, 1), UDim2.fromScale(math.clamp(chip, 0, 1), 1)
        if bar.Fill.Size ~= fs then bar.Fill.Size = fs; bar.Inner.Size = UDim2.fromScale(shown > 0.001 and 1 / shown or 1, 1) end
        if bar.Chip.Size ~= cs then bar.Chip.Size = cs end
        local t = 1 - alpha
        if bar.LastT ~= t then
            bar.LastT = t
            bar.Inner.BackgroundTransparency = t
            bar.Chip.BackgroundTransparency = t
            bar.Back.BackgroundTransparency = 0.3 + 0.7 * t
        end
        return
    end
    bar.Fill.Size = UDim2.fromScale(shown, 1)
    bar.Inner.Size = UDim2.fromScale(shown > 0.001 and 1 / shown or 1, 1)
    bar.Chip.Size = UDim2.fromScale(math.clamp(chip, 0, 1), 1)
    local t = 1 - alpha
    local low = 0
    -- (0.78, owner: "The enemy health bar flashing when hit is annoying": no low-health strobe either)
    bar.Flash.BackgroundTransparency = 1 - math.clamp(flash * 0.7 + low * 0.22, 0, 1) * alpha
    bar.Inner.BackgroundTransparency = t
    if bar.Tex then
        local speed = st.TexSpeed or 20
        bar.Tex.Position = UDim2.fromOffset(-((now * speed + bar.Seed * 50) % bar.TileW), 0)
        local pulse = (st.Anim == "Pulse") and (0.5 + 0.5 * math.sin(now * 5 + bar.Seed)) or 0
        bar.Tex.ImageColor3 = (st.TexColor or Color3.new(1, 1, 1)):Lerp(Color3.fromRGB(170, 190, 160), pulse * 0.5) -- (BARS v2: style.TexColor tints the fill texture)
        bar.Tex.ImageTransparency = t
        if bar.TexGrad then
            local kp = {}
            for i = 0, 6 do table.insert(kp, ColorSequenceKeypoint.new(i / 6, Hue(now * 0.25 + i / 6, 0.75))) end
            bar.TexGrad.Color = ColorSequence.new(kp)
        end
    end
    if st.Anim == "Rainbow" then
        if bar.Glow then bar.Glow.ImageColor3 = Hue(now * 0.25) end
        if bar.Frame then bar.Frame.ImageColor3 = Hue(now * 0.25 + 0.5, 0.35) end
    end
    if bar.Ink then
        bar.Gloss.BackgroundTransparency = (st.Tex and 0.82 or 1) + (st.Tex and 0.18 * t or 0)
    else
        bar.Gloss.BackgroundTransparency = t
    end
    if bar.Shine then
        bar.Shine.Position = UDim2.new((now * 0.5 + bar.Seed) % 1.7 - 0.3, 0, 0, 0)
        bar.Shine.BackgroundTransparency = t
    end
    bar.Back.BackgroundTransparency = 0.2 + 0.8 * t
    -- (BARS v2) how the lost piece leaves
    local last = bar.LastShown or shown
    local drop = math.max(0, last - shown)
    if shown > last + 0.2 then drop = 0 end -- (a heal / a new enemy reusing the bar)
    bar.LastShown = shown
    if drop > 0.001 then
        if not bar.DropFrom or now - (bar.DropAt or -99) > 0.6 then bar.DropFrom = last else bar.DropFrom = math.max(bar.DropFrom, last) end
        bar.DropAt = now
    end
    local cm = st.ChipMotion
    if cm == "Shatter" then
        bar.Chip.BackgroundTransparency = 1
        if drop > 0.002 then
            bar.Shards = bar.Shards or {}
            if #bar.Shards == 0 then
                for i = 1, 6 do
                    local f = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = st.Chip or C(255, 250, 240), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 13 }, bar.Holder)
                    New("UIStroke", { Color = C(8, 8, 10), Thickness = 1 }, f)
                    bar.Shards[i] = { F = f, T = 99 }
                end
            end
            local x0, x1 = bar.W * shown, bar.W * last
            local n = math.clamp(math.floor((x1 - x0) / 5) + 2, 2, 6)
            for i = 1, n do
                local sh = bar.Shards[i]
                sh.T, sh.X, sh.Y = 0, x0 + (x1 - x0) * (i - 0.5) / n, bar.H / 2
                sh.VX, sh.VY, sh.R, sh.VR = (math.random() - 0.3) * 50, -20 - math.random() * 50, math.random(0, 90), (math.random() - 0.5) * 600
                sh.S = math.max(2, math.min(bar.H, (x1 - x0) / n))
                sh.F.Visible = true
            end
        end
        for _, sh in ipairs(bar.Shards or {}) do
            if sh.T < 0.5 then
                sh.T += dt
                sh.VY += 260 * dt
                sh.X += sh.VX * dt; sh.Y += sh.VY * dt; sh.R += sh.VR * dt
                sh.F.Position = UDim2.fromOffset(sh.X, sh.Y)
                sh.F.Size = UDim2.fromOffset(sh.S, math.max(2, sh.S * 0.7))
                sh.F.Rotation = sh.R
                sh.F.BackgroundTransparency = math.clamp(sh.T / 0.5, 0, 1) + t
            elseif sh.F.Visible then sh.F.Visible = false end
        end
    elseif cm == "Burn" then
        local k = math.clamp((now - (bar.DropAt or -99)) / 0.45, 0, 1)
        bar.Chip.BackgroundColor3 = (st.Chip or C(255, 220, 140)):Lerp(st.Back or C(20, 10, 6), k)
        bar.Chip.BackgroundTransparency = t
    elseif cm == "Snap" then
        local since = now - (bar.DropAt or -99)
        local from = bar.DropFrom or shown
        local step = (since < 0.25) and 0 or math.min(3, math.floor((since - 0.25) / 0.05) + 1)
        local w = shown + (from - shown) * (1 - step / 3)
        if step >= 3 then bar.DropFrom = shown end
        bar.Chip.Size = UDim2.fromScale(math.clamp(w, 0, 1), 1)
        bar.Chip.BackgroundTransparency = t
    else
        bar.Chip.BackgroundTransparency = t
    end
    bar.Stroke.Transparency = 0.15 + 0.85 * t
    if bar.Frame then bar.Frame.ImageTransparency = t end
    if bar.Glow then bar.Glow.ImageTransparency = 1 - alpha * (0.55 + 0.25 * flash + 0.08 * math.sin(now * 3)) end
    for _, tk in ipairs(bar.Ticks) do tk.BackgroundTransparency = 0.25 + 0.75 * t end
    -- impact spark on each new hit
    if flash > bar.PrevFlash + 0.3 then bar.ImpactT = 0 end
    bar.PrevFlash = flash
    bar.ImpactT += dt
    local k = math.clamp(bar.ImpactT / 0.22, 0, 1)
    local ix = UDim2.fromOffset(bar.W * shown, bar.H / 2)
    local is = bar.U * (1.2 + 2.2 * (1 - (1 - k) ^ 3))
    bar.Impact.Position, bar.ImpactGlow.Position = ix, ix
    bar.Impact.Size = UDim2.fromOffset(is, is)
    bar.Impact.Rotation = k * 60
    bar.ImpactGlow.Size = UDim2.fromOffset(is * 1.6, is * 1.6)
    bar.Impact.ImageTransparency = 1 - (1 - k) * alpha
    bar.ImpactGlow.ImageTransparency = 1 - (1 - k) * alpha * 0.8
    local info = { Shown = shown, Hit = flash, Big = big, Chip = chip, Drop = drop, DropX0 = bar.W * shown, DropX1 = bar.W * last, Tier = bar.Tier }
    for _, step in ipairs(bar.Decor) do step(now, dt, alpha, info) end
end

-- Studio test (client DevAct "bars:<Id>"): the three in-game sizes taking a hit every 0.45 s for 7 s, in a test window
function BarStyles.DevPreview(pg: Instance, id: string)
    local style = BarStyles.ById[id] or BarStyles.ById.Standard
    local old = pg:FindFirstChild("BarTest")
    if old then old:Destroy() end
    local gui = New("ScreenGui", { Name = "BarTest", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60 }, pg)
    local panel = New("Frame", { BackgroundColor3 = C(40, 44, 52), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170),
        Size = UDim2.fromOffset(640, 150) }, gui)
    local bars = {}
    for i, spec in ipairs({ { 84, 8, false, 0.2, 40 }, { 124, 10, false, 0.45, 40 }, { 560, 18, true, 0.5, 120 } }) do
        local b = BarStyles.MakeBar(panel, spec[1], spec[2], style, C(235, 70, 60), spec[3])
        b.Holder.Position = UDim2.new(spec[4], 0, 0, spec[5])
        bars[i] = { B = b, Shown = 1, Chip = 1, Flash = 0, ChipAt = 0 }
    end
    task.spawn(function()
        local t0 = os.clock()
        local lastHit = 0
        local RunService = game:GetService("RunService")
        while gui.Parent and os.clock() - t0 < 7 do
            local now = os.clock()
            local dt = RunService.RenderStepped:Wait()
            if now - lastHit > 0.45 then
                lastHit = now
                for _, r in ipairs(bars) do
                    r.Shown = (r.Shown <= 0.15) and 1 or (r.Shown - 0.08 - math.random() * 0.06)
                    r.Flash, r.ChipAt = 1, now
                    if r.Shown >= 1 then r.Chip = 1 end
                end
            end
            for _, r in ipairs(bars) do
                r.Flash = math.max(0, r.Flash - dt * 4)
                if now - r.ChipAt > 0.32 then r.Chip = math.max(r.Shown, r.Chip - dt * 0.8) end
                BarStyles.Paint(r.B, r.Shown, r.Chip, r.Flash, 1, now, dt, r.B.Tier == "Boss")
            end
        end
        if gui.Parent then gui:Destroy() end
    end)
end

return BarStyles
