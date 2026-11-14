--!nocheck
-- Player settings: the list of every option (tab, label, type, range, default), the current values,
-- change notifications and saving. Client-side only (the server just stores the table it's sent, see
-- SaveService.SanitizeSettings). Values are a flat table of primitives so they save as-is.
--
--   GameSettings.Get(key)                -> current value
--   GameSettings.Set(key, value)         -> clamp/validate, notify, schedule a save
--   GameSettings.OnChanged(key, fn)      -> fn(value) now and on every change ("*" = any key: fn(key, value))
--   GameSettings.Load(savedTable)        -> apply the saved settings from the player's save (once, on join)
--   GameSettings.ResetTab(tabId)         -> defaults for every option on that tab
--   GameSettings.KeyFor(action)          -> Enum.KeyCode bound to a Controls action
local GameSettings = {}

GameSettings.Tabs = {
    { Id = "Gameplay", Label = "Gameplay", IconKey = "g_aim" },
    { Id = "Video", Label = "Video", IconKey = "cat_hud" },
    { Id = "Audio", Label = "Audio", IconKey = "s_audio" },
    { Id = "Interface", Label = "Interface", IconKey = "s_interface" },
    { Id = "Crosshair", Label = "Crosshair", IconKey = "s_crosshair" },
    { Id = "Enemies", Label = "Enemies", IconKey = "s_enemy" },
    { Id = "Social", Label = "Social", IconKey = "g_team" },
    { Id = "Controls", Label = "Controls", IconKey = "s_controls" },
}

-- Crosshair presets fill in the shape sliders; editing any of those switches the preset to "Custom".
GameSettings.CrosshairPresets = {
    Classic = { CrossDot = 4, CrossLength = 6, CrossThickness = 2, CrossGap = 4 },
    Dot = { CrossDot = 5, CrossLength = 0, CrossThickness = 2, CrossGap = 0 },
    ["Large Dot"] = { CrossDot = 8, CrossLength = 0, CrossThickness = 2, CrossGap = 0 },
    ["Small Cross"] = { CrossDot = 0, CrossLength = 5, CrossThickness = 2, CrossGap = 3 },
    ["Large Cross"] = { CrossDot = 0, CrossLength = 10, CrossThickness = 2, CrossGap = 5 },
    ["Large Classic"] = { CrossDot = 4, CrossLength = 10, CrossThickness = 2, CrossGap = 6 },
}
GameSettings.CrosshairColors = {
    Cyan = Color3.fromRGB(0, 255, 255), White = Color3.fromRGB(255, 255, 255), Lime = Color3.fromRGB(80, 255, 80),
    Red = Color3.fromRGB(255, 60, 60), Yellow = Color3.fromRGB(255, 240, 60), Magenta = Color3.fromRGB(255, 80, 230),
    Orange = Color3.fromRGB(255, 150, 40),
}

-- Type: "slider" (Min/Max/Step, Suffix, Scale = display multiplier), "toggle", "choice" (Options),
-- "key" (KeyCode name). Hint = the grey line under the label.
GameSettings.Defs = {
    -- GAMEPLAY
    { Key = "Sensitivity", Tab = "Gameplay", Label = "Mouse Sensitivity", Hint = "Multiplies mouse movement. Same speed on both axes, no acceleration.", Type = "slider", Min = 0.05, Max = 5, Step = 0.01, Default = 1, Decimals = 2, Suffix = "x" },
    { Key = "ADSSensitivity", Tab = "Gameplay", Label = "Aiming Sensitivity", Hint = "Extra multiplier while aiming down sights (on top of the automatic zoom matching).", Type = "slider", Min = 0.1, Max = 2, Step = 0.01, Default = 1, Decimals = 2, Suffix = "x" },
    { Key = "TouchSensitivity", Tab = "Gameplay", Label = "Touch Look Sensitivity", Hint = "Phones / tablets: how far a drag turns your view.", Type = "slider", Min = 0.2, Max = 3, Step = 0.05, Default = 1, Decimals = 2, Suffix = "x" },
    -- (2026-10-13, owner: "Mobile should have ... slight aim assist ... (only in pve)") touch only, never duels / Aim Trials
    { Key = "TouchAimAssist", Tab = "Gameplay", Label = "Aim Assist (touch)", Hint = "Phones / tablets, against bots only: your view slows a little over an enemy and eases toward its body while you aim. Never in duels or Aim Trials.", Type = "choice", Options = { "Off", "Slight", "Normal" }, Default = "Slight" },
    { Key = "StickSensitivity", Tab = "Gameplay", Label = "Controller Look Speed", Hint = "Gamepads: how fast the right stick turns your view.", Type = "slider", Min = 0.2, Max = 3, Step = 0.05, Default = 1, Decimals = 2, Suffix = "x" },
    { Key = "TouchButtonSize", Tab = "Interface", Label = "Touch Button Size", Hint = "Phones / tablets: size of the on-screen fire, aim and movement buttons.", Type = "slider", Min = 70, Max = 140, Step = 5, Default = 100, Suffix = "%" },
    { Key = "InvertY", Tab = "Gameplay", Label = "Invert Vertical Look", Hint = "Moving the mouse up looks down.", Type = "toggle", Default = false },
    { Key = "DropRules", Tab = "Gameplay", Label = "Loot Lens", Hint = "Hide drops you don't want or make the ones you do glow: by kind, rarity and words in the item. The first matching rule wins.", Type = "button", Button = "EDIT", Action = "DropRules" }, -- (UPDATE 7 C9)
    { Key = "ADSMode", Tab = "Gameplay", Label = "Aim Down Sights", Hint = "Hold the aim button (right mouse by default) to aim, or press once to toggle aiming on and off.", Type = "choice", Options = { "Hold", "Toggle" }, Default = "Hold" },

    -- VIDEO
    { Key = "GraphicsQuality", Tab = "Video", Label = "Graphics Quality", Hint = "Auto = Low on phones, tablets or a Roblox graphics slider of 4 or less. Low drops shadows, bloom and extras.", Type = "choice", Options = { "Auto", "High", "Low" }, Default = "Auto" }, -- (UPDATE 4: QualityMode; Auto = optimization pass 2026-10-27)
    { Key = "FOV", Tab = "Video", Label = "Field of View", Hint = "Horizontal view width. Aiming still zooms in from this.", Type = "slider", Min = 70, Max = 103, Step = 1, Default = 90, Suffix = "°" },
    { Key = "ZoomFOV", Tab = "Video", Label = "Zoom FOV", Hint = "Field of view while aiming (rifles; snipers and scopes zoom further, pistols less). Doesn't change with your normal FOV.", Type = "slider", Min = 30, Max = 90, Step = 1, Default = 60, Suffix = "°" },
    { Key = "ViewBob", Tab = "Video", Label = "Weapon Bob", Hint = "How much your gun sways while you move.", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 100, Suffix = "%" },
    { Key = "Shadows", Tab = "Video", Label = "Shadows", Hint = "Turning shadows off can raise FPS on weaker computers.", Type = "toggle", Default = true },
    { Key = "PostFX", Tab = "Video", Label = "Bloom & Color Grading", Hint = "The glow and per-biome color tint. Off gives a flatter, clearer picture.", Type = "toggle", Default = true },
    { Key = "NeonGlow", Tab = "Video", Label = "Neon Glow", Hint = "Reduced: most glowing trims, signs and skin parts are painted instead, the rest glow softer (attack markers and targets always glow). Full: every neon as built.", Type = "choice", Options = { "Reduced", "Full" }, Default = "Reduced" }, -- (0.93 NeonTamer)
    { Key = "Particles", Tab = "Video", Label = "Effects Detail", Hint = "Muzzle smoke, sparks and status-effect particles. Reduced halves them.", Type = "choice", Options = { "Full", "Reduced" }, Default = "Full" },
    { Key = "ShowFPS", Tab = "Video", Label = "Show FPS & Ping", Hint = "Small performance readout in the top-left corner.", Type = "toggle", Default = false },

    -- AUDIO
    { Key = "VolMaster", Tab = "Audio", Label = "Master Volume", Hint = "Everything in the game.", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 100, Suffix = "%" },
    { Key = "VolWeapons", Tab = "Audio", Label = "Weapons", Hint = "Your gunshots, reloads, melee.", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 100, Suffix = "%" },
    { Key = "VolEffects", Tab = "Audio", Label = "Combat & World", Hint = "Enemies, impacts, explosions, bosses, loot.", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 100, Suffix = "%" },
    { Key = "VolUI", Tab = "Audio", Label = "Interface", Hint = "Menu clicks, level-ups, notifications.", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 100, Suffix = "%" },
    { Key = "VolMusic", Tab = "Audio", Label = "Music", Hint = "The city and hideout music (never plays in runs or duels). 0 turns it off.", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 50, Suffix = "%" }, -- (2026-10-23 HubMusic)
    { Key = "HitSound", Tab = "Audio", Label = "Hit Sound", Hint = "The sound when your shot lands on the body (aim-trainer style options).", Type = "choice",
        Options = { "Thock", "Dink", "Tick", "Bell", "Ding", "Pop", "Click", "Cowbell", "Bonk", "Off" }, Default = "Thock" },
    { Key = "HeadHitSound", Tab = "Audio", Label = "Head Hit Sound", Hint = "The sound when you hit a weak spot (head / core). Pick the same as Hit Sound if you like.", Type = "choice",
        Options = { "Thock", "Dink", "Tick", "Bell", "Ding", "Pop", "Click", "Cowbell", "Bonk", "Off" }, Default = "Dink" },
    { Key = "KillSound", Tab = "Audio", Label = "Kill Sound", Hint = "The sound when an enemy dies to you.", Type = "choice",
        Options = { "Pulse", "Thump", "Chime", "Shatter", "Crunch", "Flash", "Classic", "Off" }, Default = "Pulse" },
    { Key = "DeathSound", Tab = "Audio", Label = "Death Sound", Hint = "The sound when you go down.", Type = "choice",
        Options = { "Fade", "Flatline", "Shatter", "Thud", "Off" }, Default = "Fade" },
    { Key = "HitSoundVol", Tab = "Audio", Label = "Hit Sound Volume", Hint = "Hit, weak-spot and kill sounds (loud by default so every hit reads).", Type = "slider",
        Min = 0, Max = 300, Step = 5, Default = 200, Suffix = "%" },

    -- INTERFACE
    -- (Update 5: 90-130. Below 90% the smallest text dropped under ~11 px; above 100% is the accessibility end -- the HUD,
    -- every window, the boss banner, trial + duel HUDs follow it: UIStyle.ScaleGui)
    { Key = "UIScale", Tab = "Interface", Label = "Interface Scale", Hint = "Size of the HUD, menus and on-screen text. Raise it if text is hard to read.", Type = "slider", Min = 90, Max = 130, Step = 5, Default = 100, Suffix = "%" },
    { Key = "DamageNumbers", Tab = "Interface", Label = "Damage Numbers", Hint = "Floating numbers on hits. 'Big hits only' shows weak spots, crits and executes; 'Boss fights only' shows them only on boss floors.", Type = "choice", Options = { "All", "Big hits only", "Boss fights only", "Off" }, Default = "All" },
    { Key = "Minimap", Tab = "Interface", Label = "Minimap", Hint = "The live map of the floor in dungeons. Corner: a small map top-right that turns with you. Large: the same map big in the middle, see-through. The Minimap key (N) cycles them.", Type = "choice", Options = { "Corner", "Large", "Off" }, Default = "Corner" }, -- (QOL M1 2026-10-28: AimRngShared/MiniMap)
    { Key = "MinimapZoom", Tab = "Interface", Label = "Minimap Zoom", Hint = "How much of the floor the minimap shows around you. Near: closer in. Far: more of the floor.", Type = "choice", Options = { "Near", "Normal", "Far" }, Default = "Normal" },
    { Key = "Hitmarker", Tab = "Interface", Label = "Hitmarker", Hint = "The X that flashes on the crosshair when you hit.", Type = "toggle", Default = true },
    { Key = "RaritySymbols", Tab = "Interface", Label = "Rarity Symbols", Hint = "A shape before each item's name in your bag, your stash and on loot on the ground (● Common, ■ Uncommon, ◆ Rare, ◈ Mythic, ★ Relic), so rarity doesn't rely on colour alone.", Type = "toggle", Default = true }, -- (QOL2 I2 2026-10-28)
    { Key = "GlobalDropFeed", Tab = "Interface", Label = "Global Drop Feed", Hint = "The rows on the right edge when anyone in the server finds a top drop. Off: no rows (your own drops still show in your bag lines).", Type = "toggle", Default = true }, -- (QOL L4 2026-10-28)
    { Key = "GoalTracker", Tab = "Interface", Label = "Goal Tracker", Hint = "A small list top-left in runs with up to 3 daily contracts / weekly jobs and their progress. Pick which ones with TRACK in Challenges > WEEKLY.", Type = "toggle", Default = true }, -- (QOL2 R4 2026-10-28)
    { Key = "WelcomeOnJoin", Tab = "Interface", Label = "Welcome Guide on Join", Hint = "Show the game guide when you load into the hub (the GUIDE button in the hub reopens it).", Type = "toggle", Default = true },
    -- (UPDATE 4 wrap-up: the credits window, also on the hub corner + in the guide)
    { Key = "Credits", Tab = "Interface", Label = "Credits", Hint = "The artists whose models, skies, textures and sounds are in Aimbound, with their licences.", Type = "button", Button = "VIEW", Action = "Credits" },
    -- (not shown in the menu: Tab "Hidden" has no page) newest patch notes the player has opened -- drives the NEW badge
    { Key = "SeenPatch", Tab = "Hidden", Label = "Seen Patch", Type = "slider", Min = 0, Max = 100000, Step = 1, Default = 0 },
    -- (Update 6 TUTORIAL) 0 = never started, 1 = the basics, 10+ = the hub / hideout tour step to resume, 100 = done or skipped
    { Key = "TutorialStep", Tab = "Hidden", Label = "Tutorial Step", Type = "slider", Min = 0, Max = 100, Step = 1, Default = 0 },
    -- (Update 6 TUTORIAL) the level-100 maps cards were shown
    { Key = "MapsIntro", Tab = "Hidden", Label = "Maps Intro", Type = "toggle", Default = false },
    -- (UPDATE 7 UNLOCK CARDS) bit i = Tutorial.UNLOCKS[i]'s cards were shown. Max = all 32 bits (was 65535: the 17th card,
    -- LEVEL 22 Quarry, could never be marked seen and popped up every time)
    { Key = "UnlockCards", Tab = "Hidden", Label = "Unlock Cards", Type = "slider", Min = 0, Max = 4294967295, Step = 1, Default = 0 },

    -- CROSSHAIR
    { Key = "CrossPreset", Tab = "Crosshair", Label = "Preset", Hint = "Pick a starting shape, then fine-tune it below.", Type = "choice", Options = { "Classic", "Dot", "Large Dot", "Small Cross", "Large Cross", "Large Classic", "Custom" }, Default = "Classic" },
    { Key = "CrossColor", Tab = "Crosshair", Label = "Color", Hint = "", Type = "choice", Options = { "Cyan", "White", "Lime", "Red", "Yellow", "Magenta", "Orange" }, Default = "Cyan" },
    { Key = "CrossDot", Tab = "Crosshair", Label = "Center Dot", Hint = "Dot size in pixels (0 = no dot).", Type = "slider", Min = 0, Max = 12, Step = 1, Default = 4, Suffix = "px" },
    { Key = "CrossLength", Tab = "Crosshair", Label = "Line Length", Hint = "0 = no lines.", Type = "slider", Min = 0, Max = 24, Step = 1, Default = 6, Suffix = "px" },
    { Key = "CrossThickness", Tab = "Crosshair", Label = "Line Thickness", Hint = "", Type = "slider", Min = 1, Max = 6, Step = 1, Default = 2, Suffix = "px" },
    { Key = "CrossGap", Tab = "Crosshair", Label = "Center Gap", Hint = "Space between the center and each line.", Type = "slider", Min = 0, Max = 20, Step = 1, Default = 4, Suffix = "px" },
    { Key = "CrossOutline", Tab = "Crosshair", Label = "Outline", Hint = "Thin dark border so it reads on bright and dark backgrounds.", Type = "toggle", Default = true },
    { Key = "CrossOpacity", Tab = "Crosshair", Label = "Opacity", Hint = "", Type = "slider", Min = 10, Max = 100, Step = 5, Default = 100, Suffix = "%" },

    -- ENEMIES
    { Key = "EnemyOutline", Tab = "Enemies", Label = "Outlines", Hint = "Draws an outline around enemies so they stand out from the room.", Type = "toggle", Default = true },
    -- (0.61c, owner: "The enemy visibility is a bit low in some of the biomes": new keys so everyone gets the new defaults --
    -- the old White outline vanished on Ice / Dream floors. Contrast = a colour picked against the biome, elites / bosses
    -- in their tier colour.)
    { Key = "EnemyOutlineColor2", Tab = "Enemies", Label = "Outline Color", Hint = "Contrast picks a colour that stands out in each biome. Auto uses each enemy's own color.", Type = "choice", Options = { "Contrast", "Auto", "Red", "White", "Yellow", "Magenta", "Cyan" }, Default = "Contrast" },
    { Key = "EnemyThroughWalls", Tab = "Enemies", Label = "Outline Through Walls", Hint = "Show enemy outlines even when they're behind cover.", Type = "toggle", Default = true },
    { Key = "EnemyFill2", Tab = "Enemies", Label = "Body Tint", Hint = "Tints enemy bodies with the outline color for extra visibility.", Type = "choice", Options = { "Off", "Subtle", "Strong" }, Default = "Subtle" },
    { Key = "EnemyBrightness", Tab = "Enemies", Label = "Brightness", Hint = "How bright enemy bodies look.", Type = "choice", Options = { "Normal", "Dim", "Bright" }, Default = "Normal" },
    { Key = "EnemyWeakSpotGlow", Tab = "Enemies", Label = "Weak-Spot Glow", Hint = "Heads and cores glow softly.", Type = "toggle", Default = true },
    { Key = "EnemyBarStyle", Tab = "Enemies", Label = "Health Bar Style", Hint = "Cosmetic looks for enemy health bars (wings, skulls, flames...), opens your Cosmetics.", Type = "button", Button = "CHOOSE", Action = "BarStyles" },
    { Key = "EnemyHealthBars", Tab = "Enemies", Label = "Health Bars", Hint = "Health bars over enemies you hit or aim at (bosses get a big bar at the top).", Type = "toggle", Default = true },

    -- SOCIAL (0.55: trading + hideouts). The server reads these from your saved Settings (TradeService / Hideouts).
    { Key = "AllowDuelRequests", Tab = "Social", Label = "Duel Challenges", Hint = "Let other players challenge you to duels. Off: nobody can challenge you.", Type = "toggle", Default = true },
    { Key = "AllowSpectate", Tab = "Social", Label = "Allow Spectators", Hint = "Let players in the city watch your runs through your eyes. Off: nobody can spectate you.", Type = "toggle", Default = true },
    { Key = "AllowTradeRequests", Tab = "Social", Label = "Trade Requests", Hint = "Let other players send you trade requests. Off: nobody can ask you to trade.", Type = "toggle", Default = true },
    { Key = "AllowVisitRequests", Tab = "Social", Label = "Hideout Visit Requests", Hint = "Let players who aren't your friends or party ask to visit your hideout (only while you're in it). Friends and party can always visit.", Type = "toggle", Default = true },

    -- CONTROLS (KeyCode names, or MouseButton1/2/3 -- playtester 2026-10-02: "can't rebind mouse buttons").
    -- (Roblox doesn't report the side mouse buttons, so left / right / middle are the ones that can be bound.)
    { Key = "Key_Fire", Tab = "Controls", Label = "Shoot / Light Attack", Type = "key", Default = "MouseButton1", Action = "Fire" },
    { Key = "Key_Aim", Tab = "Controls", Label = "Aim / Melee Dash-Strike", Type = "key", Default = "MouseButton2", Action = "Aim" },
    { Key = "Key_Reload", Tab = "Controls", Label = "Reload", Type = "key", Default = "R", Action = "Reload" },
    { Key = "Key_Melee", Tab = "Controls", Label = "Quick Melee", Type = "key", Default = "V", Action = "Melee" },
    { Key = "Key_SlotGun", Tab = "Controls", Label = "Gun (weapon slot 1)", Type = "key", Default = "One", Action = "SlotGun" },
    { Key = "Key_SlotMelee", Tab = "Controls", Label = "Melee (weapon slot 3)", Type = "key", Default = "Three", Action = "SlotMelee" },
    { Key = "Key_SwapWeapon", Tab = "Controls", Label = "Swap Gun / Melee", Type = "key", Default = "Q", Action = "SwapWeapon" },
    { Key = "Key_Inspect", Tab = "Controls", Label = "Inspect Weapon", Type = "key", Default = "T", Action = "Inspect" },
    { Key = "Key_Interact", Tab = "Controls", Label = "Interact / Accept Weapon", Type = "key", Default = "E", Action = "Interact" },
    { Key = "Key_PickupAll", Tab = "Controls", Label = "Pick Up All Nearby (pad: D-pad left)", Type = "key", Default = "Z", Action = "PickupAll" }, -- (QOL L2 2026-10-28: GroundLoot.PickupNearby)
    { Key = "Key_Dismiss", Tab = "Controls", Label = "Dismiss Weapon Offer", Type = "key", Default = "X", Action = "Dismiss" },
    { Key = "Key_ExitRun", Tab = "Controls", Label = "Back to Hub (double tap)", Type = "key", Default = "J", Action = "ExitRun" },
    { Key = "Key_FreeCursor", Tab = "Controls", Label = "Free Cursor", Type = "key", Default = "LeftAlt", Action = "FreeCursor" },
    -- (the other menus open at their stations in the hub -- the Teleport menu takes you to any of them)
    { Key = "Key_Inventory", Tab = "Controls", Label = "Stash / Arsenal", Type = "key", Default = "Tab", Action = "Inventory" },
    { Key = "Key_Tree", Tab = "Controls", Label = "Skill Tree", Type = "key", Default = "P", Action = "Tree" }, -- (0.93: no running to the monolith)
    { Key = "Key_Cosmetics", Tab = "Controls", Label = "My Cosmetics (hub)", Type = "key", Default = "H", Action = "Cosmetics" },
    { Key = "Key_Store", Tab = "Controls", Label = "Store (hub)", Type = "key", Default = "B", Action = "Store" },
    { Key = "Key_Teleport", Tab = "Controls", Label = "Teleport (hub areas)", Type = "key", Default = "G", Action = "Teleport" },
    { Key = "Key_Trade", Tab = "Controls", Label = "Trade (hub)", Type = "key", Default = "Y", Action = "Trade" },
    { Key = "Key_Duel", Tab = "Controls", Label = "Duel (hub)", Type = "key", Default = "K", Action = "Duel" },
    { Key = "Key_Hideout", Tab = "Controls", Label = "Hideout (hub)", Type = "key", Default = "U", Action = "Hideout" },
    { Key = "Key_Dungeons", Tab = "Controls", Label = "Dungeons (hub)", Type = "key", Default = "O", Action = "Dungeons" }, -- (QOL F2 2026-10-28: the Dungeons window from anywhere in the hub)
    { Key = "Key_Forge", Tab = "Controls", Label = "Forge (hub + hideout)", Type = "key", Default = "I", Action = "ForgeWin" }, -- (QOL F3 2026-10-28: the Forge window; "Forge" was the old daily-roll action)
    { Key = "Key_Settings", Tab = "Controls", Label = "Settings", Type = "key", Default = "M", Action = "Settings" },
    { Key = "Key_Menu", Tab = "Controls", Label = "Menu (every window)", Type = "key", Default = "L", Action = "Menu" }, -- (2026-10-20: the MENU window)
    { Key = "Key_ShiftLock", Tab = "Controls", Label = "Shift Lock (hub)", Type = "key", Default = "CapsLock", Action = "ShiftLock" }, -- (was Shift -- Dash works in the hub now)
    -- movement tech (not in the hub hall)
    { Key = "Key_Dash", Tab = "Controls", Label = "Dash", Type = "key", Default = "LeftShift", Action = "Dash" },
    { Key = "Key_Slide", Tab = "Controls", Label = "Slide (hold; Ctrl also works)", Type = "key", Default = "C", Action = "Slide" },
    { Key = "Key_Ability", Tab = "Controls", Label = "Duel Ability", Type = "key", Default = "F", Action = "Ability" }, -- (2026-10-15 duel abilities)
    { Key = "Key_Map", Tab = "Controls", Label = "Minimap: corner / large / off (pad: D-pad right)", Type = "key", Default = "N", Action = "Map" }, -- (QOL M1 2026-10-28: AimRngShared/MiniMap)
}

-- Mouse buttons a Controls action can be bound to (stored by their UserInputType name).
GameSettings.MouseBinds = { MouseButton1 = true, MouseButton2 = true, MouseButton3 = true }
-- Keys that can't be rebound to (they're fixed: Escape closes menus, F8/F9/F12 are Studio/Roblox).
GameSettings.ReservedKeys = { Escape = true, F8 = true, F9 = true, F12 = true, Unknown = true }

local defsByKey = {}
for i, d in ipairs(GameSettings.Defs) do
    d.Order = i
    defsByKey[d.Key] = d
end
GameSettings.DefsByKey = defsByKey

local values = {}
for _, d in ipairs(GameSettings.Defs) do values[d.Key] = d.Default end

local listeners = {} -- key -> { fn }
local anyListeners = {}
local saveScheduled = false
local loaded = false

local function Round(v: number, step: number): number
    return math.floor(v / step + 0.5) * step
end

-- Validate a value for a def; returns the cleaned value or nil if unusable.
local function Clean(d, v)
    if d.Type == "slider" then
        if type(v) ~= "number" or v ~= v then return nil end
        v = math.clamp(Round(v, d.Step or 1), d.Min, d.Max)
        if d.Decimals then v = tonumber(string.format("%." .. d.Decimals .. "f", v)) end
        return v
    elseif d.Type == "toggle" then
        if type(v) == "boolean" then return v end
        return nil
    elseif d.Type == "choice" then
        return (type(v) == "string" and table.find(d.Options, v)) and v or nil
    elseif d.Type == "key" then
        if type(v) ~= "string" or GameSettings.ReservedKeys[v] then return nil end
        if GameSettings.MouseBinds[v] then return v end
        local ok = pcall(function() return Enum.KeyCode[v] end)
        return ok and v or nil
    end
    return nil
end

local function Notify(key: string, v: any)
    for _, fn in ipairs(listeners[key] or {}) do task.spawn(fn, v) end
    for _, fn in ipairs(anyListeners) do task.spawn(fn, key, v) end
end

local function ScheduleSave()
    if not loaded or saveScheduled then return end
    saveScheduled = true
    task.delay(1.5, function()
        saveScheduled = false
        local Remotes = require(script.Parent:WaitForChild("Remotes"))
        Remotes.GetEvent("SaveSettings"):FireServer(values)
    end)
end

-- (0.83 SPECTATE MIRROR, owner: "show their exact settings (FOV, skin, crosshair, UI, damage numbers kill effects etc)"):
-- while you watch someone, THEIR visual settings stand in for yours (never saved; your own come back when you stop).
GameSettings.MIRROR_KEYS = {
    FOV = true, ZoomFOV = true, ViewBob = true, DamageNumbers = true, Hitmarker = true,
    HitSound = true, HeadHitSound = true, KillSound = true, HitSoundVol = true,
    CrossPreset = true, CrossColor = true, CrossDot = true, CrossLength = true, CrossThickness = true, CrossGap = true,
    CrossOutline = true, CrossOpacity = true,
    EnemyOutline = true, EnemyOutlineColor2 = true, EnemyThroughWalls = true, EnemyFill2 = true, EnemyBrightness = true,
    EnemyWeakSpotGlow = true, EnemyHealthBars = true,
}
local mirror: { [string]: any }? = nil
GameSettings.MirrorChanging = false -- (true while a mirror swap notifies: listeners that preview sounds skip it)

function GameSettings.Get(key: string): any
    if mirror and mirror[key] ~= nil then return mirror[key] end
    return values[key]
end

function GameSettings.Mirroring(): boolean return mirror ~= nil end

function GameSettings.Default(key: string): any
    local d = defsByKey[key]
    return d and d.Default
end

-- QOL2 H1 (2026-10-28, audit: binding a used key left two actions on it, ActionFor took the first): a rebind SWAPS (the other
-- action takes your old key, Set above) and says so; on Load any old duplicate (a saved custom key that a newer default now
-- shares, e.g. a saved "Z" vs Pick Up All) is solved the same way: the action still on its default moves (to its default if
-- free, else the first FREE_KEYS key nobody uses). Listeners: GameSettings.OnBindMoved(fn(def, keyName)) -> the client toasts.
local FREE_KEYS = { "CapsLock", "Comma", "Semicolon", "Quote", "Slash", "Backquote", "Eight", "Nine", "Zero", "Home", "End",
    "Insert", "F2", "F3", "F4", "F7" } -- (letters are all taken by defaults; Two / Four-Seven / brackets are hard-wired elsewhere)
local movedListeners = {}
local movedQueue = {} -- (moves before anyone listens, e.g. on Load: handed to the first listener)
local function MovedBind(d: any, keyName: string)
    if #movedListeners == 0 then table.insert(movedQueue, { d, keyName }); return end
    for _, fn in ipairs(movedListeners) do task.spawn(fn, d, keyName) end
end
function GameSettings.OnBindMoved(fn: (any, string) -> ())
    table.insert(movedListeners, fn)
    local q = movedQueue
    movedQueue = {}
    for _, m in ipairs(q) do task.spawn(fn, m[1], m[2]) end
end

-- A key no Controls action uses (prefer first if it's free); nil if every fallback is taken.
function GameSettings.FreeKey(prefer: string?): string?
    local used = {}
    for _, d in ipairs(GameSettings.Defs) do
        if d.Type == "key" and values[d.Key] ~= nil then used[values[d.Key]] = true end
    end
    if prefer and not used[prefer] and not GameSettings.ReservedKeys[prefer] then return prefer end
    for _, k in ipairs(FREE_KEYS) do
        if not used[k] then return k end
    end
    return nil
end

-- Two actions (same Context) on one key -> move one of them. Returns how many moved.
local function ResolveClashes(): number
    local n = 0
    for _ = 1, 40 do
        local owner, a, b = {}, nil, nil
        for _, d in ipairs(GameSettings.Defs) do
            local v = d.Type == "key" and values[d.Key]
            if v then
                local slot = tostring(d.Context or "") .. "|" .. v
                if owner[slot] then a, b = owner[slot], d; break end
                owner[slot] = d
            end
        end
        if not a then break end
        -- the one the player didn't pick moves (still on its default); otherwise the later one in the list
        local mover = (values[a.Key] == a.Default and values[b.Key] ~= b.Default) and a or b
        local nk = GameSettings.FreeKey(mover.Default)
        if not nk then break end
        values[mover.Key] = nk
        Notify(mover.Key, nk)
        MovedBind(mover, nk)
        n += 1
    end
    return n
end

-- Returns true if the stored value changed.
function GameSettings.Set(key: string, v: any, silentPreset: boolean?): boolean
    local d = defsByKey[key]
    if not d then return false end
    v = Clean(d, v)
    if v == nil or values[key] == v then return false end

    -- Rebinding a key that another action already uses: the other action takes this action's old key.
    -- (Actions used in different places -- Context, e.g. "Hub" -- may share a key.)
    if d.Type == "key" then
        for _, o in ipairs(GameSettings.Defs) do
            if o.Type == "key" and o.Key ~= key and values[o.Key] == v and o.Context == d.Context then
                values[o.Key] = values[key]
                Notify(o.Key, values[o.Key])
                MovedBind(o, values[o.Key]) -- (QOL2 H1: "X MOVED TO <key>")
            end
        end
    end

    values[key] = v
    if not (mirror and mirror[key] ~= nil) then Notify(key, v) end -- (0.83: while mirroring, your change waits)

    -- Crosshair: picking a preset fills the shape sliders; hand-editing a shape slider means "Custom".
    if key == "CrossPreset" and GameSettings.CrosshairPresets[v] then
        for k, pv in pairs(GameSettings.CrosshairPresets[v]) do
            if values[k] ~= pv then values[k] = pv; Notify(k, pv) end
        end
    elseif not silentPreset and (key == "CrossDot" or key == "CrossLength" or key == "CrossThickness" or key == "CrossGap") then
        if values.CrossPreset ~= "Custom" then values.CrossPreset = "Custom"; Notify("CrossPreset", "Custom") end
    end

    ScheduleSave()
    return true
end

-- m = the watched player's saved settings (or nil to stop): only MIRROR_KEYS, cleaned like your own
function GameSettings.SetMirror(m: any)
    local old = {}
    for k in pairs(GameSettings.MIRROR_KEYS) do old[k] = GameSettings.Get(k) end
    if type(m) == "table" then
        local clean = {}
        for k, v in pairs(m) do
            local d = GameSettings.MIRROR_KEYS[k] and defsByKey[k]
            local c = d and Clean(d, v)
            if c ~= nil then clean[k] = c end
        end
        mirror = clean
    else
        mirror = nil
    end
    GameSettings.MirrorChanging = true
    for k in pairs(GameSettings.MIRROR_KEYS) do
        local v = GameSettings.Get(k)
        if v ~= old[k] then Notify(k, v) end
    end
    GameSettings.MirrorChanging = false
end

function GameSettings.OnChanged(key: string, fn: (...any) -> ())
    if key == "*" then
        table.insert(anyListeners, fn)
        return
    end
    listeners[key] = listeners[key] or {}
    table.insert(listeners[key], fn)
    task.spawn(fn, values[key])
end

function GameSettings.Load(saved: any)
    if type(saved) == "table" then
        for key, v in pairs(saved) do
            local d = defsByKey[key]
            local c = d and Clean(d, v)
            if c ~= nil and values[key] ~= c then
                values[key] = c
                Notify(key, c)
            end
        end
    end
    -- (2026-10-02: Dash works in the hub now, so a Shift Lock still sharing the Dash key moves to Caps Lock)
    -- (QOL2 H1: the old fallback "Z" clashed with Pick Up All -> any free key)
    if values.Key_ShiftLock == values.Key_Dash then
        values.Key_ShiftLock = GameSettings.FreeKey("CapsLock") or "CapsLock"
        Notify("Key_ShiftLock", values.Key_ShiftLock)
        MovedBind(defsByKey.Key_ShiftLock, values.Key_ShiftLock)
    end
    local moved = ResolveClashes() -- (QOL2 H1: old duplicates)
    loaded = true
    if moved > 0 then ScheduleSave() end
end

function GameSettings.ResetTab(tabId: string)
    for _, d in ipairs(GameSettings.Defs) do
        if d.Tab == tabId and values[d.Key] ~= d.Default then
            values[d.Key] = d.Default
            Notify(d.Key, d.Default)
        end
    end
    ScheduleSave()
end

-- Is the player typing? A focused TextBox (GetFocusedTextBox) OR the Roblox chat bar -- the TextChatService chat
-- input lives in CoreGui, which GetFocusedTextBox doesn't report, so hotkeys used to fire while chatting
-- (playtester 2026-10-02: "fix the menus opening while typing"). Every hotkey handler checks this first.
function GameSettings.IsTyping(): boolean
    if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
    local ok, focused = pcall(function()
        local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
        return cfg ~= nil and cfg.IsFocused
    end)
    return ok and focused == true
end

-- A phone / tablet with no keyboard (owner 2026-10-02: "mobile is horribly messed up ... fully implement mobile"):
-- key hints are hidden and hover / right-click / mouse-drag UI gets a tap version. In Studio the DevTouch player
-- attribute fakes it (PlatformControls shows the touch buttons with it too).
function GameSettings.TouchOnly(): boolean
    local UIS = game:GetService("UserInputService")
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then return true end
    if game:GetService("RunService"):IsStudio() then
        local lp = game:GetService("Players").LocalPlayer
        return lp ~= nil and lp:GetAttribute("DevTouch") == true
    end
    return false
end

function GameSettings.KeyFor(action: string): Enum.KeyCode?
    for _, d in ipairs(GameSettings.Defs) do
        if d.Action == action then
            local ok, kc = pcall(function() return Enum.KeyCode[values[d.Key]] end)
            return ok and kc or nil
        end
    end
    return nil
end

-- The stored name of an input: its KeyCode name, or MouseButton1/2/3 for a mouse button (nil for anything else).
function GameSettings.InputName(input: InputObject): string?
    local t = input.UserInputType.Name
    if GameSettings.MouseBinds[t] then return t end
    if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode.Name end
    return nil
end

-- Is this input the one bound to `action` (key or mouse button)?
function GameSettings.InputIs(input: InputObject, action: string): boolean
    local name = GameSettings.InputName(input)
    return name ~= nil and name == GameSettings.BindName(action)
end

-- The stored binding of an action ("R", "MouseButton2", ...).
function GameSettings.BindName(action: string): string?
    for _, d in ipairs(GameSettings.Defs) do
        if d.Action == action then return values[d.Key] end
    end
    return nil
end

-- Input -> action name (keys and mouse buttons).
function GameSettings.ActionForInput(input: InputObject): string?
    local name = GameSettings.InputName(input)
    return name and GameSettings.ActionFor(name) or nil
end

-- KeyCode (or stored input name) -> action name (nil if unbound). Rebuilt on demand; there are only a few bindings.
function GameSettings.ActionFor(keyCode: any): string?
    local name = (typeof(keyCode) == "EnumItem") and keyCode.Name or keyCode
    for _, d in ipairs(GameSettings.Defs) do
        if d.Action and values[d.Key] == name then return d.Action end
    end
    return nil
end

-- Pretty key names for the Controls tab.
local PRETTY = {
    LeftAlt = "L-Alt", RightAlt = "R-Alt", LeftShift = "L-Shift", RightShift = "R-Shift", LeftControl = "L-Ctrl",
    RightControl = "R-Ctrl", Return = "Enter", Backquote = "`", One = "1", Two = "2", Three = "3", Four = "4",
    Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0", CapsLock = "Caps",
    MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB",
    -- (QOL2 H2: punctuation as the symbol -- the free-key fallbacks of H1 land on these)
    Comma = ",", Period = ".", Semicolon = ";", Quote = "'", Slash = "/", BackSlash = "\\", LeftBracket = "[", RightBracket = "]",
    Minus = "-", Equals = "=",
}
function GameSettings.KeyLabel(name: string?): string
    if not name then return "-" end
    return PRETTY[name] or name
end

-- Format a value for display.
function GameSettings.Format(key: string, v: any): string
    local d = defsByKey[key]
    if not d then return tostring(v) end
    if d.Type == "slider" then
        local s = d.Decimals and string.format("%." .. d.Decimals .. "f", v) or tostring(math.floor(v + 0.5))
        return s .. (d.Suffix or "")
    elseif d.Type == "toggle" then
        return v and "On" or "Off"
    elseif d.Type == "key" then
        return GameSettings.KeyLabel(v)
    end
    return tostring(v)
end

return GameSettings
