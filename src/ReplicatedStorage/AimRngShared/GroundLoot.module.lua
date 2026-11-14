--!nocheck
-- ============================================================================================
-- GROUND LOOT (client): items dropped by enemies / chests lie where they fell, each with a light beam in its
-- rarity color (taller for rarer items, Borderlands style). Walk up to one and a card shows the item (stats,
-- affixes, prefix, power, and how it compares to what you have equipped); press the prompt key (E) to pick it
-- up. The difficulty's two best kinds of drop play their rarity's sound (LOOT FEEL v2 below); every drop flies out of the
-- enemy / chest, lands, and its beam shoots up.
-- Server side: CombatServer GROUND LOOT (LootDropped / LootPicked / LootCleared, PickupLoot).
--   GroundLoot.Init({ GetState = fn() -> clientState, PlaySound = fn(name, part?), Toast = fn(text), Parent = ScreenGui })
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = script.Parent
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local GameSettings = require(script.Parent:WaitForChild("GameSettings"))
local GemData = require(Shared:WaitForChild("GemData"))
local DropRules = require(Shared:WaitForChild("DropRules")) -- (UPDATE 7 C9: your drop rules hide / glow drops)
local LoadoutScore = require(Shared:WaitForChild("LoadoutScore")) -- (QOL2 I4: gear vs equipped, EQUIP BEST's score)

local LocalPlayer = Players.LocalPlayer
local GroundLoot = {}

-- beam height (studs) and glow per rarity
local BEAM = {
    -- (UPDATE 8 RARITY v4: Rare = the old Epic beam (yellow), Mythic the old Mythic, Relic taller still; the old names stay for gems)
    Common = { H = 9, W = 0.45, Light = 6 }, Uncommon = { H = 14, W = 0.5, Light = 8 }, Rare = { H = 34, W = 0.7, Light = 13 },
    Relic = { H = 130, W = 1.25, Light = 26 },
    Epic = { H = 34, W = 0.7, Light = 13 }, Legendary = { H = 60, W = 0.9, Light = 18 }, Mythic = { H = 90, W = 1.15, Light = 24 },
    Celestial = { H = 120, W = 1.2, Light = 26 }, Transcendent = { H = 160, W = 1.25, Light = 28 },
    Astral = { H = 175, W = 1.3, Light = 28 }, Empyrean = { H = 190, W = 1.35, Light = 29 }, Primordial = { H = 205, W = 1.4, Light = 30 },
    Sovereign = { H = 220, W = 1.45, Light = 30 }, Eclipse = { H = 235, W = 1.5, Light = 31 }, Genesis = { H = 250, W = 1.55, Light = 32 },
    Infinite = { H = 280, W = 1.65, Light = 34 },
}

-- how far away a drop's name tag stays visible (through walls), by rarity -- rarer = seen from further
-- (playtester 2026-10-02: "change chest to be more aware of items dropping / maybe audio cues when items drop")
-- (RARITY v4: Rare 140 -> 300, + Relic)
local TAG_DIST = { Relic = 1000, Common = 60, Uncommon = 90, Rare = 300, Epic = 220, Legendary = 1000, Mythic = 1000, Celestial = 1000, Transcendent = 1000,
    Astral = 1000, Empyrean = 1000, Primordial = 1000, Sovereign = 1000, Eclipse = 1000, Genesis = 1000, Infinite = 1000 }

-- BEAMS v2 (2026-10-23, owner after the first loot-feel pass: "The beams still look the same"). Each rarity is its own SHAPE, not a
-- recolour: Common / Uncommon a faint stub, Rare a thin warm pillar, Mythic a tall thick red pillar whose core PULSES over a
-- pulsing ground ring, Relic a towering orange pillar with a rotating light shaft (two crossed flat beams spun by the item), a flare
-- at the top and a turning ground glyph. Height, width, brightness and motion all climb. Readable on bright floors too: Rare+
-- cores are drawn half-solid (LightEmission < 1 keeps the hue instead of washing to white) over a dark backing beam (an outline
-- the eye reads against lava / snow). Old look for A/B screenshots: workspace attr DevLootOldLook = true.
local STYLE = {
    Common = { H = 7, Core = 0.3, Glow = 0.9, CoreLE = 1, GlowT = 0.82, Ring = 1.8 },
    Uncommon = { H = 12, Core = 0.38, Glow = 1.1, CoreLE = 1, GlowT = 0.78, Ring = 2.0 },
    Rare = { Far = 2.2, H = 32, Core = 0.4, Glow = 1.2, Back = 0.75, CoreLE = 0.2, GlowT = 0.72, Ring = 2.4 },
    Mythic = { Far = 3.2, H = 85, Core = 1.3, Glow = 4.0, Back = 2.1, CoreLE = 0.1, GlowT = 0.62, Ring = 3.6, Ring2 = 5.4, Pulse = true },
    Relic = { Far = 3.8, H = 160, Core = 2.0, Glow = 6.5, Back = 3.0, CoreLE = 0.1, GlowT = 0.58, Ring = 4.2, Ring2 = 6.6, Pulse = true,
        Shaft = 5.0, Flare = true, Glyph = 7.5, Hot = 0.4 },
    -- (CHASE ITEMS 2026-11-06) ZENITH: the Relic pillar, taller + wider, in the Zenith white-teal (Spawn keeps its own colour)
    Zenith = { Far = 4.4, H = 220, Core = 2.4, Glow = 8.0, Back = 3.4, CoreLE = 0.15, GlowT = 0.55, Ring = 4.8, Ring2 = 7.6, Pulse = true,
        Shaft = 6.5, Flare = true, Glyph = 9.0, Hot = 0.5 },
}
-- a soft-edged strip (alpha falls off across the width: art/fx/loot/beam_soft.png): wide glows read as light, not flat slabs
local SOFT_BEAM = "rbxassetid://90693482173337"
local function StyleFor(item: any, rank: number, relic: boolean): any
    if relic and ItemData.ZenithOf(item) then return STYLE.Zenith end
    if relic then return STYLE.Relic end
    return STYLE[ItemData.Rarities[rank] or "Common"] or STYLE.Common
end

local burst, burstT = 0, 0

local drops: { [string]: { Model: Model, Item: any, Kind: string } } = {}
local hooks: any = {}

-- DROP SOUNDS (0.72, owner: "The sound effects for drops are a bit obnoxious ... Noises should only play for the 2 rarest
-- respective drops of that difficulty"): no thud / chime on every drop any more. ItemData.DropExcitement picks NiceDrop
-- (the difficulty's second-rarest) or JackpotDrop (its rarest, or better); everything else is silent. A burst (a chest, a
-- boss) plays ONE sound -- its best -- and an item heard as it dropped stays quiet when it's picked up.
-- LOOT FEEL v2 (2026-10-23, owner: "It's kind of just loud unpleasant noises for drops and such, and the loot doesn't feel
-- very satisfying getting good drops"). The old NiceDrop / JackpotDrop were 5.3 s music-library clips (a shimmer with 28% of
-- its energy at 2-5 kHz; a chime bed held near its peak for ~2 s at volume 1.1 + reverb = as loud as a gunshot, for two
-- seconds). Now each rarity has its own SHORT signature built from real recordings (tools/make_loot_sfx.py; README + WAVs in
-- art/sounds/preview/loot): wood marimba notes, a pouch landing, a felt bass-drum "thoom", a harp run -- no held tones, all
-- mixed under gunfire. WHICH plays = the rarity; WHETHER anything plays = still the 0.72 rule (DropExcitement >= 1: only
-- the difficulty's two best things). Mythic / Relic start with a soft swell while the item flies and hit as it lands (Lead).
GroundLoot.SOUNDS = {
    Rare = { Id = 124558573370036, Vol = 0.55, Lead = 0 },       -- loot_drop_rare: pouch lands + one warm marimba note
    RareTop = { Id = 135802941646798, Vol = 0.55, Lead = 0 },    -- loot_drop_rare_top: + a rising pair (a top-tier line)
    Mythic = { Id = 83989488987497, Vol = 0.55, Lead = 0.42 },   -- loot_drop_mythic: swell -> deep thoom -> 3-note sparkle
    Relic = { Id = 130941342081824, Vol = 0.55, Lead = 0.60 },   -- loot_drop_relic: longer swell -> ba-DOOM -> chord + harp run
    Zenith = { Id = 130941342081824, Vol = 0.8, Lead = 0.60 },   -- (CHASE ITEMS: the best jackpot recording, reused louder -- no new sound)
    Pickup = { Id = 134994214045811, Vol = 0.45 },               -- loot_pickup: a quiet pouch grab (any item)
    PickupGood = { Id = 80362761283634, Vol = 0.5 },             -- loot_pickup_good: the grab + "into the bag" (Rare+)
}
local KEY_RANK = { Rare = 1, RareTop = 2, Mythic = 3, Relic = 4, Zenith = 5 }
local SoundService = game:GetService("SoundService")
local pools = {}
local function PlayLoot(key: string)
    local def = GroundLoot.SOUNDS[key]
    if not def or (def.Id or 0) == 0 then return end
    local p = pools[key]
    if not p then
        p = { Next = 1 }
        for i = 1, 2 do
            local s = Instance.new("Sound")
            s.Name = "Loot_" .. key
            s.SoundId = "rbxassetid://" .. tostring(def.Id)
            s.Parent = SoundService
            p[i] = s
        end
        pools[key] = p
    end
    local s = p[p.Next]
    p.Next = p.Next % 2 + 1
    s.Volume = def.Vol
    s.SoundGroup = SoundService:FindFirstChild("AimRngMix_Effects") -- (Settings > Audio > Effects)
    s.TimePosition = 0
    s:Play()
end
GroundLoot.PlayLoot = PlayLoot
-- the signature for an item that made the cut (Relic > Mythic > a Rare with a top-tier line > Rare; gems: Rare)
local function SoundKey(item: any): string
    if ItemData.ZenithOf(item) then return "Zenith" end
    if item.Exotic or item.Rarity == "Relic" then return "Relic" end
    if item.Kind == "Gem" then return "Rare" end
    if (ItemData.RarityRank[item.Rarity or ""] or 1) >= ItemData.RarityRank.Mythic then return "Mythic" end
    if ItemData.HasTopTierLine(item) then return "RareTop" end
    return "Rare"
end
local heard: { [string]: number } = {}
local lastDropT, lastDropRank = 0, 0
local pendKey, pendLand = nil, 0
-- landIn = seconds until the item touches the ground (0 = straight into the bag). A burst (a chest, a boss, a pack) lands
-- over a few frames: gather 0.12 s, play only its BEST signature, timed so its hit lands with the item; within 1.2 s of the
-- last one only a better one plays.
local function QueueSound(key: string, landIn: number)
    if pendKey then
        if KEY_RANK[key] > KEY_RANK[pendKey] then pendKey, pendLand = key, landIn end
        return
    end
    pendKey, pendLand = key, landIn
    task.delay(0.12, function()
        local k, land = pendKey, pendLand
        pendKey = nil
        if not k then return end
        local now = os.clock()
        if now - lastDropT < 1.2 and KEY_RANK[k] <= lastDropRank then return end
        lastDropT, lastDropRank = now, KEY_RANK[k]
        local wait = land - 0.12 - (GroundLoot.SOUNDS[k].Lead or 0)
        if wait > 0.02 then task.delay(wait, PlayLoot, k) else PlayLoot(k) end
    end)
end
local function DropSound(item: any, landIn: number?): number
    local st = hooks.GetState and hooks.GetState()
    local ex = ItemData.DropExcitement(item, st and st.DungeonDifficulty)
    if ex <= 0 then return ex end
    QueueSound(SoundKey(item), landIn or 0)
    return ex
end
-- the loot message (an item put straight into your bag): its sound, unless it was already heard as a ground drop
function GroundLoot.AnnounceSound(item: any)
    local uid = type(item) == "table" and item.Uid
    if uid and heard[uid] and os.clock() - heard[uid] < 600 then return end
    DropSound(item, 0)
end
-- picked up from the ground in the last few seconds? (the client's LootAnnounce shows the bag toast instead of the big card)
local picked: { [string]: number } = {}
function GroundLoot.WasPicked(item: any): boolean
    local uid = type(item) == "table" and item.Uid
    return uid ~= nil and picked[uid] ~= nil and os.clock() - picked[uid] < 5
end
local folder: Folder? = nil
local card: Frame? = nil
local cardTitle, cardSub, cardBody, cardCompare, cardKey, cardStroke
local cardPickup: TextButton? = nil -- (touch: the card's PICK UP button -- phones have no [E])
local cardEntry: any = nil           -- the drop the card is showing
local cardAll: TextButton? = nil     -- (QOL L2, touch: PICK UP ALL NEARBY under the PICK UP button)

local function Folder(): Folder
    if folder and folder.Parent then return folder end
    folder = Instance.new("Folder")
    folder.Name = "GroundLoot"
    folder.Parent = Workspace
    return folder
end

local function RarityColor(item: any): Color3
    return ItemData.ItemColor(item) -- (exotics: exotic orange beam, ring, tag)
end

-- ----- the card -----
-- (PRE-PUBLISH 2026-10-31: the UI CLEAN look -- the same card as the loot popups / the bag's item card: flat slate, a 2 px
-- rarity line along the top, one 1 px hairline, no corner / facet / thick rarity stroke; texts on the roles (no letter
-- outlines); line colours Text / Sub / Muted like the item card, only meaning colours (Good / Bad) kept; PICK UP buttons in
-- the RunHud button roles. The card stays clear of the top-centre run lines (PlaceCard).)
local function BuildCard(parent: Instance)
    local RunHud = require(Shared:WaitForChild("RunHud"))
    local C = UIStyle.Colors
    card = UIStyle.New("Frame", { Name = "GroundLootCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 70, 0.5, 0), Size = UDim2.fromOffset(330, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 40, Parent = parent })
    RunHud.Plate(card, RunHud.CARD_T)
    UIStyle.New("UIStroke", { Name = "RunHudHair", Color = C.Line, Thickness = 1, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
    cardStroke = UIStyle.New("Frame", { Name = "RunHudRarity", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Text, ZIndex = 41, Parent = card })
    cardStroke:SetAttribute("Skinned", true)
    local body = UIStyle.New("Frame", { Name = "RunHudBody", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 40, Parent = card })
    body:SetAttribute("Skinned", true)
    UIStyle.New("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = body })
    UIStyle.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
    cardTitle = UIStyle.Text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, ZIndex = 41, Parent = body })
    RunHud.Role(cardTitle, "Title", { Keep = true })
    cardSub = UIStyle.Text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, ZIndex = 41, Parent = body })
    RunHud.Role(cardSub, "Label")
    cardSub.TextSize = 13
    cardBody = UIStyle.Text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
        RichText = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 41, Parent = body })
    RunHud.Role(cardBody, "Body")
    cardBody.TextSize = 13
    cardCompare = UIStyle.Text({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
        RichText = true, ZIndex = 41, Parent = body })
    RunHud.Role(cardCompare, "Body")
    cardCompare.TextSize = 13
    cardKey = UIStyle.Text({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 24), ZIndex = 41, Parent = body })
    RunHud.Role(cardKey, "Button")
    cardKey.TextYAlignment = Enum.TextYAlignment.Bottom
    -- phones / tablets: the custom-styled prompt draws no tappable bubble, so the card itself gets a big button
    -- (playtest 2026-10-02: touch players couldn't pick anything up)
    local b = UIStyle.New("TextButton", { Name = "PickUp", LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 52), Text = "TAP TO PICK UP",
        Visible = false, ZIndex = 42, Parent = body })
    RunHud.Btn(b, "Primary")
    b.TextSize = 20
    b.Activated:Connect(function()
        if cardEntry and cardEntry.Pickup then cardEntry.Pickup() end
    end)
    cardPickup = b :: TextButton
    local all = UIStyle.New("TextButton", { Name = "PickUpAll", LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 40), Text = "PICK UP ALL NEARBY",
        Visible = false, ZIndex = 42, Parent = body })
    RunHud.Btn(all, "Secondary")
    all.TextSize = 16
    all.Activated:Connect(function() task.spawn(GroundLoot.PickupNearby) end)
    cardAll = all :: TextButton
    -- (2026-10-13 phones: the HUD's 0.55 short-screen scale left ~7 pt text and a 29 pt PICK UP button; the card is
    -- drawn ~1.2x bigger -- sized as a 330 x 480 piece so it stays clear of the fire buttons at the bottom right)
    task.defer(function() if card then UIStyle.PhoneBoost(card, 330, 480) end end)
end

local function Hex(c: Color3): string return "#" .. c:ToHex() end

-- (PRE-PUBLISH 2026-10-31: the card sat on the ROOM line under the floor banner on a 1084 x 734 view.) Centred on the
-- crosshair's height as before, then pushed down so its top clears the room strip (and never above 30% of the screen) and
-- pulled up so its bottom stays on screen. Runs on show + when the card's size changes -- no per-frame work.
local GuiService = game:GetService("GuiService")
local function TopLinesBottom(): number -- screen px from the very top, under the room strip when it shows
    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local lr = pg and pg:FindFirstChild("LinkedRoomsHud")
    local w = lr and lr:IsA("ScreenGui") and lr.Enabled and lr:FindFirstChild("Where")
    if w and w:IsA("TextLabel") and w.Visible and w.Text ~= "" then
        local inset = lr.IgnoreGuiInset and 0 or GuiService:GetGuiInset().Y
        return w.AbsolutePosition.Y + w.AbsoluteSize.Y + inset
    end
    return 0
end
local function PlaceCard()
    if not card or not card.Visible then return end
    local gui = card:FindFirstAncestorWhichIsA("LayerCollector")
    if not gui or not gui:IsA("ScreenGui") then return end
    local hs = gui:FindFirstChildOfClass("UIScale")
    local k = math.max(hs and hs.Scale or 1, 0.1)
    local inset = gui.IgnoreGuiInset and 0 or GuiService:GetGuiInset().Y
    local screenH = gui.AbsoluteSize.Y + inset
    card.Position = UDim2.new(0.5, 70, 0.5, 0)
    local top = card.AbsolutePosition.Y + inset
    local h = card.AbsoluteSize.Y
    local want = math.max(top, TopLinesBottom() + 10, screenH * 0.30)
    if want + h > screenH - 12 then want = math.max(GuiService:GetGuiInset().Y + 8, screenH - 12 - h) end
    if math.abs(want - top) > 0.5 then card.Position = UDim2.new(0.5, 70, 0.5, (want - top) / k) end
end

local function ShowCard(d: any, keyName: string)
    if not card then return end
    local item, kind = d.Item, d.Kind
    local col = RarityColor(item)
    cardStroke.BackgroundColor3 = col
    cardTitle.TextColor3 = col
    local lines = {}
    if kind == "Gem" then
        -- (0.71: the same text as every other gem tooltip -- GemData.Describe; the radius line used to read "nodes in
        -- radius also grant" when only ALLOCATED nodes count)
        local d = GemData.Describe(item)
        cardTitle.Text = GemData.Icon(item) .. " " .. d.Title
        cardSub.Text = d.Subtitle .. "  •  socket it at the Skill Tree"
        for _, l in ipairs(d.Lines) do table.insert(lines, '<font color="' .. Hex(UIStyle.Colors.Text) .. '">' .. l .. "</font>") end
        if d.Special then table.insert(lines, '<font color="' .. Hex(UIStyle.Colors.Sub) .. '">' .. d.Special .. "</font>") end
        cardCompare.Text = ""
    else
        local desc = (kind == "Gear") and ItemData.DescribeGear(item) or ItemData.DescribeWeapon(item)
        cardTitle.Text = desc.Title
        cardSub.Text = desc.Subtitle
        for _, l in ipairs(desc.Lines) do
            -- (the item card's colours: modifiers Text, base stats / traits Sub, notes Muted; a line's own colour only when it
            -- means good / bad, a negative line Bad)
            local UC = UIStyle.Colors
            local col3 = (l.Kind == "affix" and UC.Text) or (l.Kind == "note" and UC.Muted) or UC.Sub
            if l.Color then
                local hh, ss = l.Color:ToHSV()
                if ss > 0.35 and hh >= 0.22 and hh <= 0.45 then col3 = UC.Good elseif ss > 0.35 and (hh < 0.04 or hh > 0.95) then col3 = UC.Bad end
            end
            if l.Negative then col3 = UC.Bad end
            local c = Hex(col3)
            table.insert(lines, string.format('<font color="%s">%s</font>', c, l.Text))
        end
        local st = hooks.GetState and hooks.GetState()
        if kind ~= "Gear" and st and st.EquippedWeapon then
            local mine = ItemData.CalculateTrueDPS(st.EquippedWeapon)
            local theirs = ItemData.CalculateTrueDPS(item)
            local diff = (mine > 0) and ((theirs - mine) / mine) or 0
            local c = Hex((diff >= 0) and UIStyle.Colors.Good or UIStyle.Colors.Bad)
            cardCompare.Text = string.format('vs equipped <b>%s</b>: <font color="%s"><b>%+d%% DPS</b></font>', st.EquippedWeapon.Name, c, math.round(diff * 100))
        elseif kind == "Gear" and st then
            -- (QOL2 I4 2026-10-28) gear: EQUIP BEST's build score with this piece in its slot (rings: the weaker ring) vs now
            local gain, vs = LoadoutScore.GearGain(st, item)
            if gain then
                local c = Hex((gain >= 0.0005) and UIStyle.Colors.Good or ((gain <= -0.0005) and UIStyle.Colors.Bad or UIStyle.Colors.Sub))
                local what = (type(vs) == "table") and ("vs equipped <b>" .. tostring(vs.Name) .. "</b>") or "fills an empty slot"
                cardCompare.Text = string.format('%s: <font color="%s"><b>%s%.1f%%</b></font> build score', what, c, gain >= 0 and "+" or "", gain * 100)
            else
                cardCompare.Text = ""
            end
        else
            cardCompare.Text = ""
        end
    end
    cardBody.Text = table.concat(lines, "\n")
    cardEntry = d
    local touch = GameSettings.TouchOnly()
    -- (QOL L3 2026-10-28: a controller picks up with RB -- X is Reload; the key shown follows the last input)
    local lastIn = game:GetService("UserInputService"):GetLastInputType().Name
    local pad = string.sub(lastIn, 1, 7) == "Gamepad"
    if pad then keyName = "RB" end
    -- (QOL L2: 2+ drops in reach -> the PICK UP ALL key / button too; counted once per card show, not per frame)
    local near = GroundLoot.NearbyCount and GroundLoot.NearbyCount() or 0
    local allKey = pad and "D-PAD LEFT" or ((hooks.PickupAllKey and hooks.PickupAllKey()) or "Z")
    cardKey.Text = "[" .. keyName .. "]  PICK UP" .. ((near >= 2 and allKey ~= "") and ("    [" .. allKey .. "]  ALL " .. near) or "")
    cardKey.Visible = not touch
    if cardPickup then cardPickup.Visible = touch end
    if cardAll then cardAll.Visible = touch and near >= 2; cardAll.Text = "PICK UP ALL NEARBY (" .. near .. ")" end
    -- (PRE-PUBLISH 2026-10-31: no Back pop -- it also grabbed the card's PhoneBoost UIScale (FindFirstChildOfClass) and set it
    -- back to 1, so phones lost the bigger card after the first show)
    if not card.Visible then
        card.Visible = true
        if not card:GetAttribute("PlaceHooked") then
            card:SetAttribute("PlaceHooked", true)
            card:GetPropertyChangedSignal("AbsoluteSize"):Connect(PlaceCard)
        end
    end
    PlaceCard()
end

-- Chest loot is fanned out ~5 studs in front of you -- i.e. onto / into the chest you just opened (owner: "items
-- glitch inside of the chest and can't be picked up": the chest's own [E] prompt won over the item's). A drop that lands
-- in a chest's footprint is pushed out of it, on your side.
local function ChestOf(inst: Instance): Model?
    local m = inst:FindFirstAncestorOfClass("Model")
    while m do
        local n = m.Name
        if n:sub(1, 6) == "Chest_" or n == "VictoryVaultChest" or n:sub(1, 17) == "ArenaSupplyChest_" then return m end
        m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
    end
    return nil
end
local function OutOfChests(pos: Vector3): Vector3
    local seen = {}
    for _, p in ipairs(Workspace:GetPartBoundsInRadius(pos, 6)) do
        local m = ChestOf(p)
        if m and not seen[m] then
            seen[m] = true
            local cf, size = m:GetBoundingBox()
            local loc = cf:PointToObjectSpace(pos)
            local hx, hz = size.X / 2 + 1.6, size.Z / 2 + 1.6
            if math.abs(loc.X) < hx and math.abs(loc.Z) < hz then
                local lp = Players.LocalPlayer
                local root = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                local to = root and cf:PointToObjectSpace((root :: BasePart).Position) or Vector3.new(0, 0, 1)
                -- out through the side that faces you (keeping the drop's spread along that side)
                if math.abs(to.X) / hx > math.abs(to.Z) / hz then
                    loc = Vector3.new((to.X >= 0 and 1 or -1) * hx, loc.Y, loc.Z)
                else
                    loc = Vector3.new(loc.X, loc.Y, (to.Z >= 0 and 1 or -1) * hz)
                end
                pos = cf:PointToWorldSpace(loc)
            end
        end
    end
    return pos
end

-- ----- the world object -----
-- The floor under a drop spot (flying enemies die in mid-air): first solid, non-enemy, non-player surface below.
local function FloorBelow(pos: Vector3): Vector3
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { Folder() }
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
    for _, m in ipairs(game:GetService("CollectionService"):GetTagged("AimRngEnemy")) do table.insert(ignore, m) end
    params.FilterDescendantsInstances = ignore
    for _ = 1, 6 do
        local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -250, 0), params)
        if not hit then return pos end
        if hit.Instance.CanCollide and hit.Instance.Transparency < 0.95 and not ChestOf(hit.Instance) then return hit.Position end
        table.insert(ignore, hit.Instance) -- see-through / non-solid decoration: look past it
        params.FilterDescendantsInstances = ignore
    end
    return pos
end

-- CHEST SLOTS (owner 2026-10-05: "loot lands randomly out of chest, should always fall in the same place"): a drop that
-- comes from a chest (the server sets it ~5 studs in front of you, i.e. right by the chest) snaps to that chest's own row
-- in front of its lock side -- centre first, then right / left, a second row behind after five -- wherever you stood.
local chestSlots = setmetatable({}, { __mode = "k" })
local function ChestBody(m: Model): BasePart?
    if m.PrimaryPart and m.Name:sub(1, 6) == "Chest_" then return m.PrimaryPart end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("Model") and d.Name:sub(1, 6) == "Chest_" and d.PrimaryPart then return d.PrimaryPart end
    end
    return m.PrimaryPart
end
local function ChestSlot(pos: Vector3): (Vector3?, Vector3?)
    local best, bestD = nil, 10
    for _, p in ipairs(Workspace:GetPartBoundsInRadius(pos, 10)) do
        local m = ChestOf(p)
        local body = m and ChestBody(m)
        -- (only a chest that's been opened -- the floor is cleared by then, so nothing else drops by it; a kill next to a
        -- closed chest drops where it died. A BACK PORTAL revisit re-sends the drops: they line up the same way again)
        local opened = body and ((body.Parent :: Instance):GetAttribute("Opened") or (m :: Model):GetAttribute("Opened"))
        if body and opened then
            local d = (Vector3.new(body.Position.X, pos.Y, body.Position.Z) - pos).Magnitude
            if d < bestD then best, bestD = body, d end
        end
    end
    if not best then return nil end
    local cf = best.CFrame
    local fwd = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
    fwd = fwd.Magnitude > 0.05 and fwd.Unit or Vector3.zAxis
    local right = fwd:Cross(Vector3.yAxis)
    local n = (chestSlots[best] or 0)
    chestSlots[best] = n + 1
    local row, k = n // 5, n % 5
    local slot = (k == 0) and 0 or (((k % 2 == 1) and 1 or -1) * math.ceil(k / 2))
    local out = best.Size.Z / 2 + 3 + row * 2.6
    return Vector3.new(cf.Position.X, pos.Y, cf.Position.Z) + fwd * out + right * (slot * 2.4), cf.Position -- (+ where it flies out of)
end

-- ----- LOOT FEEL v2 visuals (2026-10-23): pop out + land, the beam shoots up, the name pops in, a ground burst for Mythic /
-- Relic, a clean bag toast. Budget ("must run on almost anything"): ONE Heartbeat loop for every drop (BulkMoveTo, far drops
-- every 6th frame, off when nothing is on the ground), lights capped (MAX_LIGHTS, Mythic / Relic first), sparkle emitters
-- capped (MAX_SPARKLES), ONE pooled burst emitter + 3 pooled shock rings for every landing.
local MAX_LIGHTS, MAX_SPARKLES = 6, 8
local liveLights, liveSparkles = 0, 0
local WHITE = Color3.new(1, 1, 1)

local burstPart: BasePart? = nil
local burstPE: ParticleEmitter? = nil
local shockRings: { BasePart } = {}
local shockN = 0
local function BurstFx(ground: Vector3, col: Color3, big: boolean)
    local f = Folder()
    if not burstPart or not burstPart.Parent then
        local bp = Instance.new("Part")
        bp.Name = "LootBurst"
        bp.Size = Vector3.new(1, 1, 1)
        bp.Transparency = 1
        bp.Anchored, bp.CanCollide, bp.CanQuery, bp.CanTouch = true, false, false, false
        bp.Parent = f
        local at = Instance.new("Attachment")
        at.Parent = bp
        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 0
        pe.LightEmission, pe.LightInfluence = 1, 0
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
        pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
        pe.Lifetime = NumberRange.new(0.45, 0.85)
        pe.Speed = NumberRange.new(9, 16)
        pe.SpreadAngle = Vector2.new(65, 65)
        pe.EmissionDirection = Enum.NormalId.Top
        pe.Acceleration = Vector3.new(0, -32, 0)
        pe.Drag = 2.5
        pe.Parent = at
        burstPart, burstPE = bp, pe
        shockRings = {}
        for i = 1, 3 do
            local r = Instance.new("Part")
            r.Name = "LootShock"
            r.Shape = Enum.PartType.Cylinder
            r.Material = Enum.Material.Neon
            r.Size = Vector3.new(0.1, 1, 1)
            r.Transparency = 1
            r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch = true, false, false, false
            r.Parent = f
            shockRings[i] = r
        end
    end
    (burstPart :: BasePart).CFrame = CFrame.new(ground + Vector3.new(0, 0.4, 0))
    local pe = burstPE :: ParticleEmitter
    pe.Color = ColorSequence.new(col:Lerp(WHITE, 0.35), col)
    pe:Emit(big and 28 or 16)
    shockN = shockN % #shockRings + 1
    local r = shockRings[shockN]
    r.Color = col
    r.Size = Vector3.new(0.1, 1.2, 1.2)
    r.Transparency = 0.15
    r.CFrame = CFrame.new(ground + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
    local d = big and 17 or 11
    TweenService:Create(r, TweenInfo.new(big and 0.6 or 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, d, d), Transparency = 1 }):Play()
end

-- THE BAG TOAST (owner 2026-10-23: "SLIM LINE ONLY" -- it replaced the old stats popup for every item that reaches your bag;
-- modes "bag" / "upgrade" (a better gun: ▲ UPGRADE, equip it from the bag) / "sold" / "drop"): one clean row per item that goes into your bag ("+ ◆ Name" in its colour) and per sounded
-- drop as it lands ("▼ Name ... RARE DROP"; the difficulty's very best already gets the global drop feed row). Right edge
-- above the drop feed (top centre on touch screens), 4 at most,
-- icon look: dark facet slab, ink edge, a colour block. Never near the crosshair.
local GLYPH = ItemData.RARITY_GLYPHS -- (QOL2 I2: one shared table)
local toastStack: Frame? = nil
local toastOrder = 0
local function ToastStack(): Frame?
    if toastStack and toastStack.Parent then return toastStack end
    if not hooks.Parent then return nil end
    local st = Instance.new("Frame")
    st.Name = "LootToasts"
    st.BackgroundTransparency = 1
    st.Size = UDim2.fromOffset(320, 170)
    st.ZIndex = 45
    st:SetAttribute("NoSkin", true)
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 4)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = st
    st.Parent = hooks.Parent
    toastStack = st
    return st
end
function GroundLoot.Toast(item: any, kind: string?, mode: string?)
    local st = ToastStack()
    if not st or type(item) ~= "table" then return end
    -- (PLAYTEST 2026-10-31: the lines sat on top of an open window -- the inventory's bag column; the bag itself shows the item)
    local menuUp = hooks.MenuOpen ~= nil and hooks.MenuOpen() == true
    st.Visible = not menuUp
    if menuUp then return end
    local touch = GameSettings.TouchOnly()
    local lay = st:FindFirstChildOfClass("UIListLayout") :: UIListLayout
    if touch then
        st.AnchorPoint, st.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 132)
        lay.VerticalAlignment = Enum.VerticalAlignment.Top
    else
        st.AnchorPoint, st.Position = Vector2.new(1, 1), UDim2.new(1, -16, 0.36, 0) -- (right edge, above the global drop feed)
        lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
    end
    local col = RarityColor(item)
    local rar = (ItemData.RarityLabel and ItemData.RarityLabel(item)) or item.Rarity or "Common"
    local name = (kind == "Gem") and (item.Name or "Gem") or item.Name or "Item" -- (QOL2 I2: a relic's ★ symbol replaces DisplayName's "◆ " -- it read "★ ◆ Name")
    toastOrder += 1
    local row = Instance.new("Frame")
    row.Name = "LootToast"
    row.LayoutOrder = toastOrder
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = WHITE
    row.BorderSizePixel = 0
    row:SetAttribute("Skinned", true)
    row:SetAttribute("UIStyled", true)
    UIStyle.FacetGrad(UIStyle.Colors.Bg1, UIStyle.Colors.Bg0, 0.62).Parent = row
    local edge = UIStyle.InkEdge(2)
    edge.Parent = row
    local blk = Instance.new("Frame")
    blk.BorderSizePixel = 0
    blk.BackgroundColor3 = col
    blk.Size = UDim2.new(0, 5, 1, 0)
    blk.Parent = row
    local nm = Instance.new("TextLabel")
    nm.BackgroundTransparency = 1
    nm.Position = UDim2.fromOffset(14, 0)
    nm.Size = UDim2.new(1, -112, 1, 0)
    nm.Font = Enum.Font.GothamBold
    nm.TextSize = 16
    nm.TextXAlignment = Enum.TextXAlignment.Left
    nm.TextTruncate = Enum.TextTruncate.AtEnd
    nm.TextColor3 = col
    nm.Text = ((mode == "drop") and "▼ " or (mode == "sold") and "⇄ " or "+ ") .. ((item.Exotic and ItemData.ItemGlyph and ItemData.ItemGlyph(item)) or GLYPH[rar] or "◆") .. " " .. name -- (CHASE ITEMS: a Zenith's ❖ / a relic's ★)
    nm:SetAttribute("KeepFont", true)
    if not item.Exotic then ItemData.StyleRarityText(nm, item.Rarity) end
    nm.Parent = row
    local tag = Instance.new("TextLabel")
    tag.BackgroundTransparency = 1
    tag.AnchorPoint = Vector2.new(1, 0)
    tag.Position = UDim2.new(1, -10, 0, 0)
    tag.Size = UDim2.new(0, 94, 1, 0)
    tag.Font = Enum.Font.GothamBold
    tag.TextSize = 12
    tag.TextXAlignment = Enum.TextXAlignment.Right
    tag.TextColor3 = (mode == "drop") and col:Lerp(WHITE, 0.4) or (mode == "upgrade") and UIStyle.Colors.Good or (mode == "sold") and UIStyle.Colors.Gold or UIStyle.Colors.Sub
    tag.Text = (mode == "drop") and (string.upper(rar) .. " DROP") or (mode == "upgrade") and "▲ UPGRADE" or (mode == "sold") and "SOLD" or "INTO BAG"
    tag:SetAttribute("KeepFont", true)
    tag.Parent = row
    -- slide in from the side, settle, fade out
    local sc = Instance.new("UIScale")
    sc.Scale = 0.86
    sc.Parent = row
    row.BackgroundTransparency = 1
    nm.TextTransparency, tag.TextTransparency, blk.BackgroundTransparency, edge.Transparency = 1, 1, 1, 1
    row.Parent = st
    local ti = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    TweenService:Create(row, ti, { BackgroundTransparency = 0.05 }):Play()
    TweenService:Create(nm, ti, { TextTransparency = 0 }):Play()
    TweenService:Create(tag, ti, { TextTransparency = 0 }):Play()
    TweenService:Create(blk, ti, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(edge, ti, { Transparency = 0 }):Play()
    local rows = {}
    for _, c in ipairs(st:GetChildren()) do if c:IsA("Frame") then table.insert(rows, c) end end
    table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #rows > 4 do table.remove(rows, 1):Destroy() end
    local life = (mode == "drop") and 4.5 or 3.2
    task.delay(life, function()
        if not row.Parent then return end
        local fo = TweenInfo.new(0.35)
        TweenService:Create(row, fo, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(nm, fo, { TextTransparency = 1 }):Play()
        TweenService:Create(tag, fo, { TextTransparency = 1 }):Play()
        TweenService:Create(blk, fo, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(edge, fo, { Transparency = 1 }):Play()
        task.delay(0.4, function() row:Destroy() end)
    end)
end

-- ITEM LOOKS (2026-10-23, owner: "the loot is literally just a box on the floor"): a drop looks like the ITEM. Guns = the
-- gun's own base model (no skin, the factory look; scripts / sounds / lights stripped, welded to the drop's anchor, never
-- collides or takes rays), hovering on a slight tilt with a slow turn; gear = a clean low-poly piece per slot in the house
-- palette (helmet, chest piece, gloves, leggings, boots, ring, necklace); gems = a faceted crystal round a lit heart.
-- Rarity on the item: a neon rim / trim in the rarity colour (+ a light tint over the gun's own colours). CHEAP: one visual a
-- drop, built at most 3 a frame (a burst never builds 30 in one frame), POOLED per gun / slot when picked up, MAX_GUNS 20 real
-- gun models alive (past that a part silhouette), and beyond FAR studs only the beam + name tag (the model is parented out).
-- Studio A/B: workspace attr DevLootOldLook = true -> the old neon box + old beam.
local Looks = { MAX_GUNS = 20, Guns = 0, Pool = {}, Queue = {}, NEAR = 75, FAR = 85, POOL_MAX = 3 }
do
    local SLATE, STEEL, DARK = Color3.fromRGB(40, 44, 56), Color3.fromRGB(96, 102, 116), Color3.fromRGB(24, 26, 34) -- (deep: warm biome light lifted the first pass to salmon)
    local BRASS = Color3.fromRGB(176, 150, 104)
    local CF, ANG, R = CFrame.new, CFrame.Angles, math.rad
    local function New(key: string): any
        local m = Instance.new("Model")
        m.Name = "Look_" .. key
        local root = Instance.new("Part")
        root.Name = "LookRoot"
        root.Size = Vector3.new(0.2, 0.2, 0.2)
        root.Transparency = 1
        root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch, root.Massless, root.CastShadow = false, false, false, false, true, false
        root.CFrame = CFrame.identity
        root.Parent = m
        m.PrimaryPart = root
        return { Model = m, Root = root, Key = key, Rim = {}, Soft = {}, Tint = {} }
    end
    -- a part of a built look, welded to its root (cf = its place in the look's own space)
    local K = 1.3 -- (the built looks are drawn 1.3x: they read at a glance next to the 2-4 stud ground rings)
    local function P(v: any, size: Vector3, cf: CFrame, color: Color3, role: string?, shape: Enum.PartType?): Part
        size, cf = size * K, CFrame.new(cf.Position * K) * cf.Rotation
        local p = Instance.new("Part")
        if shape then p.Shape = shape end
        p.Size = size
        p.Color = color
        p.Material = (role == "Rim") and Enum.Material.Neon or Enum.Material.SmoothPlastic
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
        p.CFrame = cf
        local w = Instance.new("Weld")
        w.Part0, w.Part1, w.C0 = v.Root, p, cf
        w.Parent = p
        p.Parent = v.Model
        if role == "Rim" then table.insert(v.Rim, p) elseif role == "Soft" then table.insert(v.Soft, p) end
        return p
    end
    local B = {}
    function B.Helmet(v: any)
        P(v, Vector3.new(1.5, 1.5, 1.5), CF(0, 0.12, 0), SLATE, nil, Enum.PartType.Ball)
        P(v, Vector3.new(0.18, 1.05, 1.05), CF(0, -0.58, 0) * ANG(0, 0, R(90)), DARK, nil, Enum.PartType.Cylinder) -- neck ring
        P(v, Vector3.new(1.08, 0.3, 0.3), CF(0, 0.06, -0.62), DARK) -- visor housing
        P(v, Vector3.new(0.98, 0.18, 0.12), CF(0, 0.06, -0.78), WHITE, "Rim") -- visor
        P(v, Vector3.new(0.18, 0.24, 1.3), CF(0, 0.86, 0.04), STEEL) -- crest
        P(v, Vector3.new(0.07, 0.07, 1.1), CF(0, 1.0, 0.04), WHITE, "Rim")
        for _, s in ipairs({ -1, 1 }) do P(v, Vector3.new(0.2, 0.62, 0.62), CF(s * 0.68, -0.22, -0.12), STEEL) end -- cheek guards
    end
    function B.ChestPiece(v: any)
        P(v, Vector3.new(1.35, 1.45, 0.62), CF(0, 0, 0), SLATE)
        P(v, Vector3.new(1.15, 0.72, 0.14), CF(0, 0.27, -0.36), STEEL) -- chest plate
        P(v, Vector3.new(0.9, 0.42, 0.12), CF(0, -0.3, -0.35), DARK) -- abdomen plate
        P(v, Vector3.new(0.08, 1.12, 0.06), CF(0, 0.02, -0.45), WHITE, "Rim") -- centre seam
        P(v, Vector3.new(0.72, 0.18, 0.5), CF(0, 0.79, 0), DARK) -- collar
        P(v, Vector3.new(1.42, 0.16, 0.68), CF(0, -0.62, 0), STEEL) -- belt band
        P(v, Vector3.new(1.0, 0.05, 0.05), CF(0, -0.62, -0.36), WHITE, "Rim")
        for _, s in ipairs({ -1, 1 }) do
            P(v, Vector3.new(0.52, 0.34, 0.82), CF(s * 0.86, 0.56, 0) * ANG(0, 0, R(-s * 22)), STEEL) -- shoulder pads
            P(v, Vector3.new(0.5, 0.05, 0.05), CF(s * 0.86, 0.6, -0.42) * ANG(0, 0, R(-s * 22)), WHITE, "Rim")
        end
    end
    function B.Gloves(v: any)
        for _, s in ipairs({ -1, 1 }) do
            local x = s * 0.4
            local base = CF(x, 0, 0) * ANG(0, R(s * 10), 0)
            P(v, Vector3.new(0.55, 0.5, 0.72), base, SLATE) -- fist
            P(v, Vector3.new(0.5, 0.18, 0.22), base * CF(0, 0.13, -0.33), STEEL) -- knuckle guard
            P(v, Vector3.new(0.42, 0.06, 0.05), base * CF(0, 0.13, -0.46), WHITE, "Rim")
            P(v, Vector3.new(0.16, 0.2, 0.36), base * CF(-s * 0.32, -0.06, -0.1), SLATE) -- thumb
            P(v, Vector3.new(0.42, 0.66, 0.66), base * CF(0, 0, 0.52) * ANG(0, R(90), 0), DARK, nil, Enum.PartType.Cylinder) -- cuff
            P(v, Vector3.new(0.06, 0.69, 0.69), base * CF(0, 0, 0.33) * ANG(0, R(90), 0), WHITE, "Rim", Enum.PartType.Cylinder)
        end
    end
    function B.Leggings(v: any)
        P(v, Vector3.new(1.25, 0.24, 0.56), CF(0, 0.76, 0), DARK) -- belt
        P(v, Vector3.new(0.26, 0.16, 0.06), CF(0, 0.76, -0.3), WHITE, "Rim") -- buckle
        for _, s in ipairs({ -1, 1 }) do
            P(v, Vector3.new(0.5, 1.32, 0.5), CF(s * 0.32, 0, 0), SLATE)
            P(v, Vector3.new(0.44, 0.36, 0.12), CF(s * 0.32, -0.06, -0.29), STEEL) -- knee pads
            P(v, Vector3.new(0.05, 1.1, 0.06), CF(s * 0.585, 0.04, 0), WHITE, "Rim")
        end
    end
    function B.Boots(v: any)
        for _, s in ipairs({ -1, 1 }) do
            local x = s * 0.36
            P(v, Vector3.new(0.46, 0.72, 0.5), CF(x, 0.24, 0.12), SLATE) -- shaft
            P(v, Vector3.new(0.5, 0.32, 0.96), CF(x, -0.25, -0.1), SLATE) -- foot
            P(v, Vector3.new(0.53, 0.27, 0.26), CF(x, -0.26, -0.5), STEEL) -- toe cap
            P(v, Vector3.new(0.53, 0.06, 0.98), CF(x, -0.43, -0.1), WHITE, "Rim") -- sole
            P(v, Vector3.new(0.5, 0.12, 0.54), CF(x, 0.56, 0.12), DARK) -- cuff
        end
    end
    function B.Ring(v: any)
        local n = 12
        for i = 0, n - 1 do
            local a = i / n * math.pi * 2
            P(v, Vector3.new(0.2, 0.3, 0.24), CF(math.cos(a) * 0.55, math.sin(a) * 0.55, 0) * ANG(0, 0, a), BRASS)
        end
        P(v, Vector3.new(0.36, 0.14, 0.3), CF(0, 0.72, 0), DARK) -- setting
        P(v, Vector3.new(0.4, 0.4, 0.4), CF(0, 0.92, 0), WHITE, "Rim", Enum.PartType.Ball) -- stone
    end
    function B.Necklace(v: any)
        local n = 13
        for i = 0, n - 1 do
            local a = math.rad(-60) + i / (n - 1) * math.rad(300) -- open at the bottom, where the pendant hangs
            P(v, Vector3.new(0.16, 0.16, 0.16), CF(math.sin(a) * 0.5, math.cos(a) * 0.62 + 0.1, 0), BRASS, nil, Enum.PartType.Ball)
        end
        P(v, Vector3.new(0.46, 0.46, 0.08), CF(0, -0.68, 0.03) * ANG(0, 0, R(45)), DARK) -- pendant frame
        P(v, Vector3.new(0.32, 0.32, 0.12), CF(0, -0.68, 0) * ANG(0, 0, R(45)), WHITE, "Rim")
    end
    function B.Gem(v: any)
        local tilt = ANG(R(45), 0, R(35.26))
        local sh = P(v, Vector3.new(0.78, 0.78, 0.78), tilt, WHITE, "Soft") -- clear shell
        sh.Transparency = 0.32
        P(v, Vector3.new(0.4, 0.4, 0.4), tilt, WHITE, "Rim") -- lit heart
        P(v, Vector3.new(0.12, 0.12, 0.12), CF(0, 0.78, 0), WHITE, "Rim", Enum.PartType.Ball) -- a spark above it
    end
    -- the part silhouette for a gun with no model (or past MAX_GUNS)
    function B.GunShape(v: any)
        P(v, Vector3.new(1.9, 0.44, 0.24), CF(0, 0, 0), SLATE) -- receiver
        P(v, Vector3.new(1.05, 0.15, 0.15), CF(1.45, 0.06, 0), DARK) -- barrel
        P(v, Vector3.new(0.24, 0.56, 0.2), CF(-0.35, -0.42, 0) * ANG(0, 0, R(-14)), DARK) -- grip
        P(v, Vector3.new(0.24, 0.52, 0.18), CF(0.32, -0.46, 0) * ANG(0, 0, R(8)), STEEL) -- magazine
        P(v, Vector3.new(0.62, 0.34, 0.2), CF(-1.25, -0.04, 0), SLATE) -- stock
        P(v, Vector3.new(1.6, 0.05, 0.05), CF(0.1, -0.24, -0.14), WHITE, "Rim")
    end
    -- the gun's own model: ViewmodelRig.ModelFor (the one model lookup every view uses), scaled to read on the ground
    local VR = nil
    local function GunModel(item: any): any?
        if not VR then
            local ok, mod = pcall(require, Shared:WaitForChild("ViewmodelRig", 5))
            if not ok then return nil end
            VR = mod
        end
        local WR = require(Shared:WaitForChild("WeaponRigs"))
        local def = item.BaseId and WR.Guns[item.BaseId]
        if not def then return nil end
        local ok, src = pcall(VR.ModelFor, def, nil, nil, nil)
        if not ok or not src then return nil end
        local frame = src:FindFirstChild("Frame")
        if not (frame and frame:IsA("BasePart")) then src:Destroy() return nil end
        for _, d in ipairs(src:GetDescendants()) do
            if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam")
                or d:IsA("Trail") or d:IsA("ProximityPrompt") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
                d:Destroy()
            end
        end
        src.PrimaryPart = frame
        local _, size = src:GetBoundingBox()
        local long = math.max(size.X, size.Y, size.Z)
        if long > 0.05 then
            local want = math.clamp(long, 1.9, 3.4)
            pcall(function() src:ScaleTo(src:GetScale() * want / long) end)
        end
        local bcf, bsize = src:GetBoundingBox()
        local v = { Model = src, Root = frame, Key = "Gun:" .. item.BaseId, Rim = {}, Soft = {}, Tint = {}, Gun = true }
        for _, p in ipairs(src:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
                local sa = p:FindFirstChildOfClass("SurfaceAppearance")
                if p.Material == Enum.Material.Neon then
                    table.insert(v.Rim, p)
                else
                    table.insert(v.Tint, { p, sa, p.Color, sa and sa.Color })
                end
                if p ~= frame then
                    local w = Instance.new("Weld")
                    w.Part0, w.Part1, w.C0 = frame, p, frame.CFrame:ToObjectSpace(p.CFrame)
                    w.Parent = p
                end
            end
        end
        -- the rarity rim: a thin neon line along the underside of the gun
        local rim = Instance.new("Part")
        rim.Name = "LookRim"
        rim.Material = Enum.Material.Neon
        rim.Size = Vector3.new(math.max(bsize.X, bsize.Z) * 0.82, 0.05, 0.05)
        rim.Anchored, rim.CanCollide, rim.CanQuery, rim.CanTouch, rim.Massless, rim.CastShadow = false, false, false, false, true, false
        local axis = (bsize.Z > bsize.X) and ANG(0, R(90), 0) or CFrame.identity
        rim.CFrame = bcf * CF(0, -bsize.Y / 2 - 0.06, 0) * axis
        local w = Instance.new("Weld")
        w.Part0, w.Part1, w.C0 = frame, rim, frame.CFrame:ToObjectSpace(rim.CFrame)
        w.Parent = rim
        rim.Parent = src
        table.insert(v.Rim, rim)
        v.Centre = frame.CFrame:ToObjectSpace(bcf) -- (so the gun's middle, not its Frame origin, sits on the drop)
        return v
    end
    local function Build(key: string, item: any): any
        if key == "Gun" then
            local v = GunModel(item)
            if v then return v end
            key = "GunShape"
        end
        local v = New(key)
        ;(B[key] or B.Gem)(v)
        return v
    end
    local function KeyOf(item: any, kind: string): string
        if kind == "Gem" then return "Gem" end
        if kind == "Gear" then
            local s = tostring(item.Slot or "")
            if s:find("Ring") then return "Ring" end
            return B[s] and s or "ChestPiece"
        end
        return "Gun"
    end
    -- paint a (new or pooled) look in its rarity
    local function Paint(v: any, col: Color3)
        for _, p in ipairs(v.Rim) do p.Color = col end
        local soft = col:Lerp(WHITE, 0.4)
        for _, p in ipairs(v.Soft) do p.Color = soft end
        for _, t in ipairs(v.Tint) do
            if t[2] then t[2].Color = t[4]:Lerp(col, 0.16) else t[1].Color = t[3]:Lerp(col, 0.16) end
        end
    end
    -- give drop e its look (from the pool, else built): called by the Step loop, at most 3 a frame
    function Looks.Attach(e: any)
        if not e.Core.Parent then return end
        local key = KeyOf(e.Item, e.Kind)
        local poolKey = (key == "Gun") and ("Gun:" .. tostring(e.Item.BaseId)) or key
        if key == "Gun" and Looks.Guns >= Looks.MAX_GUNS then key, poolKey = "GunShape", "GunShape" end
        local list = Looks.Pool[poolKey]
        local v = list and table.remove(list) or Build(key, e.Item)
        if v.Gun then Looks.Guns += 1 end
        Paint(v, e.Col)
        local tilt = (key == "Gun" or key == "GunShape") and ANG(R(-14), 0, R(6)) or CFrame.identity
        local w = Instance.new("Weld")
        w.Part0, w.Part1 = e.Core, v.Root
        w.C0 = tilt * (v.Centre and v.Centre:Inverse() or CFrame.identity)
        w.Parent = v.Root
        v.Weld = w
        v.Model.Parent = e.Model
        e.Vis, e.VisOn = v, true
        e.Core.Transparency = 1
    end
    -- back to the pool (picked up / cleared)
    function Looks.Release(v: any)
        if v.Weld then v.Weld:Destroy(); v.Weld = nil end
        if v.Gun then Looks.Guns = math.max(0, Looks.Guns - 1) end
        local key = v.Key
        local list = Looks.Pool[key] or {}
        Looks.Pool[key] = list
        if #list < Looks.POOL_MAX then
            v.Model.Parent = nil
            table.insert(list, v)
        else
            v.Model:Destroy()
        end
    end
    -- far LOD: past FAR studs only the beam + tag (hysteresis to NEAR)
    function Looks.Lod(e: any, dist: number)
        local v = e.Vis
        if not v then return end
        if e.VisOn and dist > Looks.FAR then
            v.Model.Parent = nil
            e.VisOn = false
        elseif not e.VisOn and dist < Looks.NEAR then
            v.Model.Parent = e.Model
            e.VisOn = true
        end
    end
end

-- ONE update loop for every drop on the ground (it was a Heartbeat loop per drop, forever)
local live: { [any]: boolean } = {}
local loopConn: RBXScriptConnection? = nil
local frameN = 0
local partsBuf, cfBuf = {}, {}
local function Land(e: any)
    if e.Ring then
        e.Ring.Size = Vector3.new(0.1, 0.5, 0.5)
        e.Ring.Transparency = e.Hidden and 0.85 or 0.05
        local d = e.RingD or 2.2
        TweenService:Create(e.Ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = Vector3.new(0.1, d, d), Transparency = e.Hidden and 0.85 or 0.45 }):Play()
    end
    if e.Ring2 then
        local d = e.Ring2D or 5
        e.Ring2.Size = Vector3.new(0.1, d * 0.4, d * 0.4)
        e.Ring2.Transparency = 0.2
        TweenService:Create(e.Ring2, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, d, d), Transparency = 0.72 }):Play()
    end
    if e.Glyph then
        for _, g in ipairs(e.Glyph) do TweenService:Create(g, TweenInfo.new(0.5), { Transparency = 0.25 }):Play() end
    end
    if not e.Hidden then
        for _, b in ipairs(e.Beams) do b.Enabled = true end
        if e.A1 then
            local ti = TweenInfo.new(e.BeamT, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            TweenService:Create(e.A1, ti, { Position = Vector3.new(0, e.BeamH, 0) }):Play()
            for i = 1, 2 do -- (the Relic shaft rises to 70% of the pillar)
                local s1 = e.Core:FindFirstChild("Shaft1_" .. i)
                if s1 then TweenService:Create(s1, ti, { Position = Vector3.new(0, e.BeamH * 0.7, 0) }):Play() end
            end
            local fl = e.A1:FindFirstChild("LootFlare")
            if fl then fl.Enabled = true end
        end
        if e.Light then e.Light.Enabled = true end
        if e.Sparkle then e.Sparkle.Enabled = true end
        if e.Tag then
            e.Tag.Enabled = true
            e.TagScale.Scale = 0.35
            TweenService:Create(e.TagScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
        if e.Burst then BurstFx(e.Ground, e.Col, e.Burst == "big") end
    end
    if e.OnLand then task.spawn(e.OnLand) end
end
local function Step()
    local now = os.clock()
    frameN += 1
    local q = Looks.Queue
    for _ = 1, 3 do -- (ITEM LOOKS: at most 3 built a frame)
        local e = table.remove(q, 1)
        if not e then break end
        if drops[e.Id] == e then Looks.Attach(e) end
    end
    local cam = Workspace.CurrentCamera
    local cp = cam and cam.CFrame.Position
    local n = 0
    for e in pairs(live) do
        local core = e.Core
        if not core.Parent then
            live[e] = nil
        else
            local cf = nil
            if not e.Landed then
                local u = (now - e.T0) / e.ArcT
                if u >= 1 then
                    e.Landed = true
                    cf = e.Target
                    Land(e)
                else
                    local p = e.S:Lerp(e.Target.Position, u) + Vector3.new(0, e.Apex * 4 * u * (1 - u), 0)
                    cf = CFrame.new(p) * CFrame.Angles(u * 2.2, u * 7, 0) -- (tumbles as it flies)
                end
            elseif not cp or (cp - e.Ground).Magnitude < 140 or (frameN + e.Slot) % 6 == 0 then
                local t = now - e.T0 + e.Phase
                if e.Vis and cp and (frameN + e.Slot) % 10 == 0 then Looks.Lod(e, (cp - e.Ground).Magnitude) end
                cf = e.Target * CFrame.new(0, (e.Vis and 0.15 or 0.25) * math.sin(t * 2), 0) * CFrame.Angles(0, t * (e.Vis and 0.8 or 1.5), 0)
                if e.Glyph then -- (Relic: the ground glyph turns the other way)
                    for i, g in ipairs(e.Glyph) do
                        n += 1
                        partsBuf[n] = g
                        cfBuf[n] = CFrame.new(e.Ground + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, -t * 0.6 + (i - 1) * math.pi / 3, 0)
                    end
                end
                if e.WBase and cp and (frameN + e.Slot) % 8 == 0 then
                    local wk = math.clamp((cp - e.Ground).Magnitude / 40, 1, e.WFar)
                    if math.abs(wk - e.WK) > 0.04 then
                        e.WK = wk
                        for _, w in ipairs(e.WBase) do w[1].Width0, w[1].Width1 = w[2] * wk, w[3] * wk end
                    end
                end
                local pu = e.Pulse
                if pu and pu.Core and now - e.T0 > e.ArcT + 0.5 then -- (Mythic / Relic: the core breathes, the ring with it)
                    local k = 0.5 + 0.5 * math.sin(t * 4.2)
                    local wk = e.WK or 1
                    pu.Core.Width0, pu.Core.Width1 = pu.CW * (1 + 0.35 * k) * wk, pu.CW * 0.6 * (1 + 0.35 * k) * wk
                    pu.Glow.Width0 = pu.GW * (1 + 0.15 * k) * wk
                    if e.Ring then e.Ring.Transparency = 0.3 + 0.25 * (1 - k) end
                end
            end
            if cf then
                n += 1
                partsBuf[n] = core
                cfBuf[n] = cf
            end
        end
    end
    for i = n + 1, #partsBuf do partsBuf[i] = nil; cfBuf[i] = nil end
    if n > 0 then Workspace:BulkMoveTo(partsBuf, cfBuf, Enum.BulkMoveMode.FireCFrameChanged) end
    if next(live) == nil and loopConn then loopConn:Disconnect(); loopConn = nil end
end
local function Track(e: any)
    live[e] = true
    if not loopConn then loopConn = RunService.Heartbeat:Connect(Step) end
end

local slotN = 0
local function Spawn(id: string, item: any, kind: string, pos: Vector3)
    local slot, chestAt = ChestSlot(pos)
    local raw = pos
    pos = FloorBelow(OutOfChests(slot or pos))
    local col = RarityColor(item)
    local rank = ItemData.RarityRank[item.Rarity] or 1
    local relic = item.Exotic ~= nil or item.Rarity == "Relic"
    local mythic = not relic and kind ~= "Gem" and rank >= ItemData.RarityRank.Mythic
    local b = BEAM[item.Rarity] or BEAM.Common -- (light range)
    local sty = StyleFor(item, rank, relic)
    local old = Workspace:GetAttribute("DevLootOldLook") == true -- (Studio A/B: the look before BEAMS v2)
    if old then sty = { H = b.H, Core = b.W, Glow = b.W * 2.2, CoreLE = 1, GlowT = 0.72, Ring = 2.2, Old = true } end
    local st0 = hooks.GetState and hooks.GetState()
    local rule = DropRules.Match(st0 and st0.DropRules, item, kind) -- "Hide" | "Glow" | nil
    if rule == "Glow" then
        local g = table.clone(sty)
        g.H, g.Core, g.Glow = sty.H * 1.5, sty.Core * 1.3, sty.Glow * 1.3
        sty = g
    end
    local hidden = rule == "Hide"
    local model = Instance.new("Model")
    model.Name = "Drop_" .. id
    -- the item: a spinning glowing gem shape (weapons / gear / gems all share it, colored by rarity)
    local core = Instance.new("Part")
    core.Name = "Core"
    core.Size = (kind == "Gem") and Vector3.new(0.9, 0.9, 0.9) or Vector3.new(1.6, 0.5, 0.7)
    if not old and not hidden then -- (ITEM LOOKS: a small spark until the item's own look attaches)
        core.Shape = Enum.PartType.Ball
        core.Size = Vector3.new(0.45, 0.45, 0.45)
    end
    core.Material = Enum.Material.Neon
    core.Color = col
    core.Anchored, core.CanCollide, core.CanTouch = true, false, false
    core.CanQuery = false
    local target = CFrame.new(pos + Vector3.new(0, 1.1, 0))
    -- (where it flies from: out of the chest, else up out of the body, away from you)
    local cam = Workspace.CurrentCamera
    local away = cam and Vector3.new(pos.X - cam.CFrame.Position.X, 0, pos.Z - cam.CFrame.Position.Z) or Vector3.zero
    away = away.Magnitude > 0.1 and away.Unit or Vector3.zAxis
    local start
    if chestAt then
        start = Vector3.new(chestAt.X, math.max(chestAt.Y, pos.Y) + 1.6, chestAt.Z)
    else
        start = pos + Vector3.new(0, math.max(1.6, raw.Y - pos.Y + 1.4), 0) - away * 2.2
    end
    local drop = start.Y - target.Position.Y
    local arcT = (relic and 0.72 or mythic and 0.55 or 0.45) + math.clamp((drop - 3) / 40, 0, 0.3)
    core.CFrame = CFrame.new(start)
    core.Parent = model
    -- ground ring (hidden until the landing pops it out); Mythic / Relic add a thin outer ring
    local function Disc(name: string, d: number, t: number?): Part
        local r = Instance.new("Part")
        r.Name = name
        r.Shape = Enum.PartType.Cylinder
        r.Size = Vector3.new(0.1, d, d)
        r.CFrame = CFrame.new(pos + Vector3.new(0, t or 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
        r.Material = Enum.Material.Neon
        r.Color = col
        r.Transparency = 1
        r.Anchored, r.CanCollide, r.CanTouch, r.CanQuery = true, false, false, false
        r.Parent = model
        return r
    end
    local ring = Disc("Ring", sty.Ring)
    local ring2 = (not hidden and sty.Ring2) and Disc("Ring2", sty.Ring2, 0.05) or nil
    -- Relic ground glyph: three thin neon bars crossing (an asterisk) that turn slowly
    local glyph = nil
    if not hidden and sty.Glyph then
        glyph = {}
        for i = 1, 3 do
            local g = Instance.new("Part")
            g.Name = "Glyph" .. i
            g.Size = Vector3.new(0.28, 0.06, sty.Glyph)
            g.Material = Enum.Material.Neon
            g.Color = col:Lerp(WHITE, 0.2)
            g.Transparency = 1
            g.Anchored, g.CanCollide, g.CanTouch, g.CanQuery = true, false, false, false
            g.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, (i - 1) * math.pi / 3, 0)
            g.Parent = model
            glyph[i] = g
        end
    end
    -- the beam (off in flight, it shoots up on landing): a dark backing beam (Rare+), the core, a soft glow; Relic: a light
    -- shaft of two crossed FLAT beams (they turn with the spinning item) and a flare at the top
    local beams = {}
    local a0, a1, core0, glow0 = nil, nil, nil, nil
    if not hidden then
        local baseY = sty.Old and -1 or 0.9 -- (BEAMS v2: the pillar rises off the top of the item, so the item itself stays in sight)
        -- (BEAMS v2: the beam's own colour is a step deeper for Mythic / Relic -- bloom + lava light washed red to pink and orange to
        -- the Rare's yellow)
        local bc = sty.Old and col or (ItemData.ZenithOf(item) and col) or (relic and col:Lerp(Color3.fromRGB(255, 70, 0), 0.4)) or (mythic and col:Lerp(Color3.fromRGB(200, 0, 20), 0.3)) or col
        a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, baseY, 0); a0.Parent = core
        a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 0.5, 0); a1.Parent = core
        local function MakeBeam(name: string, w0: number, w1: number, c: ColorSequence, t: NumberSequence, le: number, z: number?, at0: Attachment?, at1: Attachment?, faceCam: boolean?, soft: boolean?): Beam
            local beam = Instance.new("Beam")
            beam.Name = name
            beam.Attachment0, beam.Attachment1 = at0 or a0, at1 or a1
            beam.Color = c
            beam.Width0, beam.Width1 = w0, w1
            beam.LightEmission = le
            beam.LightInfluence = 0
            beam.FaceCamera = faceCam ~= false
            beam.Segments = 2
            beam.Transparency = t
            beam.ZOffset = z or 0
            if soft and not sty.Old then beam.Texture, beam.TextureMode, beam.TextureLength = SOFT_BEAM, Enum.TextureMode.Stretch, 1 end
            beam.Enabled = false
            beam.Parent = core
            table.insert(beams, beam)
            return beam
        end
        local function Fade(t0: number, mid: number?): NumberSequence
            return NumberSequence.new({ NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(0.7, math.min(1, t0 + (mid or 0.35))), NumberSequenceKeypoint.new(1, 1) })
        end
        if sty.Back then
            local dark = bc:Lerp(Color3.new(0, 0, 0), 0.8)
            MakeBeam("LootBack", sty.Back, sty.Back * 0.6, ColorSequence.new(dark), Fade(0.15, 0.45), 0, -0.05, nil, nil, nil, true)
        end
        core0 = MakeBeam("LootBeam1", sty.Core, sty.Core * 0.6, ColorSequence.new(bc:Lerp(WHITE, sty.Old and 0.25 or 0.12), bc), Fade(sty.Old and 0.05 or 0, 0.3), sty.CoreLE, 0.05)
        glow0 = MakeBeam("LootBeam2", sty.Glow, sty.Glow * 0.55, ColorSequence.new(bc), Fade(sty.Old and sty.GlowT or sty.GlowT - 0.25), sty.Old and 1 or 0.3, 0, nil, nil, nil, true)
        if sty.Hot then -- (Relic: a white-hot line down the middle of the pillar)
            MakeBeam("LootHot", sty.Hot, sty.Hot * 0.5, ColorSequence.new(WHITE, bc:Lerp(WHITE, 0.5)), Fade(0, 0.4), 1, 0.1)
        end
        if sty.Shaft then
            for i, yaw in ipairs({ 0, 90 }) do
                local s0 = Instance.new("Attachment"); s0.Name = "Shaft0_" .. i; s0.Position = Vector3.new(0, baseY, 0); s0.Orientation = Vector3.new(0, yaw, 0); s0.Parent = core
                local s1 = Instance.new("Attachment"); s1.Name = "Shaft1_" .. i; s1.Position = Vector3.new(0, 0.5, 0); s1.Orientation = Vector3.new(0, yaw, 0); s1.Parent = core
                MakeBeam("LootShaft" .. i, sty.Shaft, sty.Shaft * 0.2, ColorSequence.new(bc:Lerp(WHITE, 0.25), bc), Fade(0.35, 0.35), 0.4, 0.02, s0, s1, false, true)
            end
        end
        if sty.Flare then
            local fl = Instance.new("ParticleEmitter")
            fl.Name = "LootFlare"
            fl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            fl.Color = ColorSequence.new(bc:Lerp(WHITE, 0.5), bc)
            fl.LightEmission, fl.LightInfluence = 1, 0
            fl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(0.4, 6), NumberSequenceKeypoint.new(1, 0) })
            fl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
            fl.Lifetime = NumberRange.new(0.9, 1.3)
            fl.Rate = 3
            fl.Speed = NumberRange.new(0, 0)
            fl.LockedToPart = true
            fl.Enabled = false
            fl.Parent = a1
        end
    end
    -- light: Rare and up only, at most MAX_LIGHTS at once (Mythic / Relic always get one)
    local light = nil
    if not hidden and rank >= ItemData.RarityRank.Rare and (relic or mythic or liveLights < MAX_LIGHTS) then
        light = Instance.new("PointLight")
        light.Color = col
        light.Range = b.Light
        light.Brightness = 2
        light.Shadows = false
        light.Enabled = false
        light.Parent = core
        liveLights += 1
    end
    -- sparkles: Mythic / Relic and a Rare with a top-tier line (the item-level chase), at most MAX_SPARKLES at once
    local sparkle = nil
    if not hidden and (relic or mythic or (kind ~= "Gem" and ItemData.HasTopTierLine(item))) and (relic or mythic or liveSparkles < MAX_SPARKLES) then
        local pe = Instance.new("ParticleEmitter")
        pe.Color = ColorSequence.new(col)
        pe.LightEmission = 1
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
        pe.Lifetime = NumberRange.new(1, 2)
        pe.Rate = (relic or mythic) and 12 or 8
        pe.Speed = NumberRange.new(2, 5)
        pe.Acceleration = Vector3.new(0, 4, 0)
        pe.SpreadAngle = Vector2.new(25, 25)
        pe.Enabled = false
        pe.Parent = a0
        sparkle = pe
        liveSparkles += 1
    end
    -- name tag (pops in on landing)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(220, 22)
    bb.StudsOffset = Vector3.new(0, 1.6, 0)
    bb.MaxDistance = TAG_DIST[item.Rarity] or 70
    bb.AlwaysOnTop = true
    bb.Adornee = core
    bb.Enabled = false
    bb.Parent = model
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1, 1)
    tl.BackgroundTransparency = 1
    tl.Font = Enum.Font.FredokaOne
    tl.TextSize = 15
    tl.TextColor3 = col
    tl.TextStrokeTransparency = 0.3
    tl.Text = (kind == "Gem") and (item.Name or "Gem") or ((item.Exotic and ItemData.DisplayName(item)) or item.Name or "Item")
    if GameSettings.Get("RaritySymbols") ~= false then tl.Text = (kind == "Gem") and (ItemData.ItemGlyph(item) .. " " .. tl.Text) or ItemData.SymbolName(item) end -- (QOL2 I2: the rarity symbol first)
    if not item.Exotic then ItemData.StyleRarityText(tl, item.Rarity) end
    tl.Parent = bb
    local tagScale = Instance.new("UIScale")
    tagScale.Parent = tl
    if hidden then -- (a hidden drop: a dim core + ring only, no beam / light / tag / sound; still picked up as normal)
        core.Transparency = 0.55
        core.Size *= 0.6
    elseif rule == "Glow" then
        local hl = Instance.new("Highlight")
        hl.FillTransparency, hl.OutlineTransparency = 0.6, 0
        hl.FillColor, hl.OutlineColor = DropRules.GLOW, DropRules.GLOW
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.Parent = model -- (the whole drop: the item's look too)
        bb.MaxDistance = 1000
        tl.Text = "★ " .. tl.Text
    end
    -- pickup prompt (the card shows while it's the active prompt)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PickupPrompt"
    prompt.ActionText = "Pick up"
    prompt.ObjectText = item.Name or "Item"
    prompt.KeyboardKeyCode = (hooks.InteractKey and hooks.InteractKey()) or Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonR1 -- (QOL L3: the default ButtonX is Reload on a pad; RB is free)
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Custom -- our own card instead of the default bubble
    prompt.Parent = core
    local sounded = false
    local entry = { Model = model, Item = item, Kind = kind }
    prompt.PromptShown:Connect(function() ShowCard(entry, prompt.KeyboardKeyCode.Name) end)
    prompt.PromptHidden:Connect(function() if card and cardEntry == entry then card.Visible = false end end)
    entry.Pickup = function()
        if not prompt.Enabled then return end
        prompt.Enabled = false
        if card and cardEntry == entry then card.Visible = false end
        local ok = Remotes.GetFunction("PickupLoot"):InvokeServer(id)
        if not ok then prompt.Enabled = true; return end
        -- (2026-10-23: a pickup sound -- quiet for everyday items, "into the bag" for Rare+ / anything that sounded -- and the
        -- bag toast; the big loot card no longer pops for a ground pickup: you saw the card walking up to it)
        if item.Uid then picked[item.Uid] = os.clock() end
        PlayLoot((sounded or relic or rank >= ItemData.RarityRank.Rare) and "PickupGood" or "Pickup")
        -- (the bag line comes from the client's LootAnnounce, which knows whether it's an upgrade)
    end
    prompt.Triggered:Connect(entry.Pickup)
    entry.Prompt = prompt -- (QOL L2: PickupNearby skips one already on its way to the bag)
    model.Parent = Folder()
    drops[id] = entry
    -- the flight + landing (one shared loop)
    slotN += 1
    entry.Core, entry.Ring, entry.Beams, entry.A1, entry.Light, entry.Sparkle = core, ring, beams, a1, light, sparkle
    entry.Tag, entry.TagScale, entry.Hidden, entry.Col, entry.Ground = (not hidden) and bb or nil, tagScale, hidden, col, pos
    entry.Target, entry.S, entry.T0, entry.ArcT, entry.Phase, entry.Slot = target, start, os.clock(), arcT, math.random() * 10, slotN % 6
    entry.Apex = relic and 4 or mythic and 3 or 2.2
    entry.BeamH, entry.BeamT = sty.H, (relic or mythic) and 0.55 or 0.35
    entry.Ring2, entry.Glyph, entry.RingD, entry.Ring2D = ring2, glyph, sty.Ring, sty.Ring2
    entry.Pulse = (not hidden and sty.Pulse) and { Core = core0, Glow = glow0, CW = sty.Core, GW = sty.Glow } or nil
    -- (BEAMS v2 FAR: a Rare+ pillar widens with distance (up to sty.Far x) so it keeps its weight across a big room)
    if not hidden and sty.Far then
        entry.WBase, entry.WFar, entry.WK = {}, sty.Far, 1
        for _, bm in ipairs(beams) do table.insert(entry.WBase, { bm, bm.Width0, bm.Width1 }) end
    end
    entry.Burst = (not hidden) and (relic and "big" or mythic and "small") or nil
    entry.Id = id
    if not old and not hidden then table.insert(Looks.Queue, entry) end
    Track(entry)
    -- sound + callout (0.72: relative to the difficulty -- see DropSound)
    if hidden then drops[id].Hidden = true; return end -- (a hidden drop makes no sound and isn't counted)
    if item.Uid and heard[item.Uid] and os.clock() - heard[item.Uid] < 600 then return end -- (re-sent: BACK PORTAL, rejoin)
    local ex = DropSound(item, arcT)
    if rule == "Glow" and ex <= 0 then QueueSound("Rare", arcT); ex = 1 end
    sounded = ex >= 1
    if item.Uid then heard[item.Uid] = os.clock() end
    -- several items at once (a chest, a boss): say how many, so none get left behind
    local now = os.clock()
    if now - burstT > 0.6 then burst = 0 end
    burst += 1
    burstT = now
    if burst >= 2 and hooks.Toast then
        local n = burst
        task.delay(0.65, function()
            if burst == n and hooks.Toast then hooks.Toast("◆ " .. n .. " ITEMS DROPPED: look for the beams") end
        end)
    end
    if ex == 1 then entry.OnLand = function() GroundLoot.Toast(item, kind, "drop") end end -- (ex 2 = the drop feed's row)
end

local function Remove(id: string)
    local d = drops[id]
    drops[id] = nil
    if d then
        live[d] = nil
        if d.Vis then Looks.Release(d.Vis); d.Vis = nil end
        if d.Light then liveLights = math.max(0, liveLights - 1) end
        if d.Sparkle then liveSparkles = math.max(0, liveSparkles - 1) end
        if d.Model then d.Model:Destroy() end
    end
    if card then card.Visible = false end
end

-- QOL L1 (2026-10-28, owner: loot left on the floor): drops still lying on this floor that you can see (your Drop Rules'
-- hidden ones don't count). LeaveGate(again?) -> true = go; with drops left the first call warns (a toast) and returns false,
-- a second call within LEAVE_WARN_S returns true. Nothing is picked up for you (the economy + LOST LOOT stay as they are).
function GroundLoot.LeftCount(): number
    local n = 0
    for _, d in pairs(drops) do
        if not d.Hidden and d.Model and d.Model.Parent then n += 1 end
    end
    return n
end
local LEAVE_WARN_S, leaveArmT = 6, 0
function GroundLoot.LeaveGate(again: string?): boolean
    local n = GroundLoot.LeftCount()
    if n == 0 then return true end
    if os.clock() - leaveArmT < LEAVE_WARN_S then leaveArmT = 0; return true end
    leaveArmT = os.clock()
    if hooks.Toast then hooks.Toast(n .. (n == 1 and " ITEM" or " ITEMS") .. " STILL ON THE GROUND -- " .. (again or "press again to leave"), true) end
    return false
end

-- QOL L2 (2026-10-28): PICK UP ALL NEARBY (Key_PickupAll, default Z; pad D-pad left). Every drop you can see within
-- PICKUP_ALL_R studs (Drop Rules' hidden ones stay), nearest first, through the server's real pickup path (CombatServer
-- PickupLootMany: distance checked there, stops at a full bag). One sound for the lot; the bag lines come from LootAnnounce.
local PICKUP_ALL_R = 24
local pickingAll = false
function GroundLoot.NearbyCount(): number
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    local here = Vector3.new(root.Position.X, 0, root.Position.Z)
    local n = 0
    for _, d in pairs(drops) do
        if not d.Hidden and d.Core and d.Prompt and d.Prompt.Enabled then
            local p = d.Core.Position
            if (Vector3.new(p.X, 0, p.Z) - here).Magnitude <= PICKUP_ALL_R then n += 1 end
        end
    end
    return n
end
function GroundLoot.PickupNearby()
    if pickingAll then return end
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local here = Vector3.new(root.Position.X, 0, root.Position.Z)
    local list = {}
    for id, d in pairs(drops) do
        if not d.Hidden and d.Core and d.Prompt and d.Prompt.Enabled then
            local p = d.Core.Position
            local dist = (Vector3.new(p.X, 0, p.Z) - here).Magnitude
            if dist <= PICKUP_ALL_R then table.insert(list, { id, dist, d }) end
        end
    end
    if #list == 0 then
        if hooks.Toast then hooks.Toast("Nothing to pick up nearby") end
        return
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    local ids, good = {}, false
    for i, e in ipairs(list) do
        if i > 40 then break end
        ids[i] = e[1]
        local d = e[3]
        d.Prompt.Enabled = false -- (no double pickups while the call travels; LootPicked removes the taken ones)
        if d.Item.Uid then picked[d.Item.Uid] = os.clock() end
        if (ItemData.RarityRank[d.Item.Rarity] or 1) >= ItemData.RarityRank.Rare or d.Item.Exotic then good = true end
    end
    if card then card.Visible = false end
    pickingAll = true
    local ok, n = pcall(function() return Remotes.GetFunction("PickupLootMany"):InvokeServer(ids) end)
    pickingAll = false
    for _, id in ipairs(ids) do -- (left behind -- bag full: pickable again)
        local d = drops[id]
        if d and d.Prompt then d.Prompt.Enabled = true end
    end
    if ok and type(n) == "number" and n > 0 then PlayLoot(good and "PickupGood" or "Pickup") end
end

function GroundLoot.Init(h: any)
    hooks = h or {}
    local ONCE = { PromptVault = true, PromptSupplyChest = true, PromptEvent = true }
    game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
        if who == Players.LocalPlayer and ONCE[prompt.Name] then prompt.Enabled = false end
    end)
    BuildCard(hooks.Parent)
    Remotes.GetEvent("LootDropped").OnClientEvent:Connect(function(id, item, kind, pos)
        if type(id) == "string" and type(item) == "table" and typeof(pos) == "Vector3" then Spawn(id, item, kind or "Weapon", pos) end
    end)
    Remotes.GetEvent("LootPicked").OnClientEvent:Connect(function(id) Remove(id) end)
    Remotes.GetEvent("LootCleared").OnClientEvent:Connect(function()
        for id in pairs(drops) do Remove(id) end
    end)
end

-- (QOL M1 2026-10-28, map builder) the minimap's loot marks: Rare+ drops on the ground that the Drop Rules don't hide ->
-- { { Pos, Col } } (AimRngShared/MiniMap, 10 Hz while it shows; a walk over this table, no scan)
function GroundLoot.MapDrops(): { any }
    local out = {}
    local rare = ItemData.RarityRank.Rare or 3
    for _, e in pairs(drops) do
        local it = e.Item
        if it and not e.Hidden and e.Ground and (it.Exotic or (ItemData.RarityRank[it.Rarity or ""] or 1) >= rare) then
            table.insert(out, { Pos = e.Ground, Col = e.Col or Color3.new(1, 1, 1) })
        end
    end
    return out
end

return GroundLoot
