--!nocheck
-- MUSIC AUDITION (dev only, 2026-10-24; owner on hub music v2: "still very mediocre sounding" -> "Would some sort of chill
-- DNB / Breakcore work here?" -> a free-library audition by ear). F6 admin panel > MUSIC tab (AdminPanel builds it the
-- first time the tab opens; nothing is made or runs before that, and nothing runs while nothing plays).
-- LIST = the candidates from Roblox's licensed library. ROUND 2 (2026-10-24, owner: "put a bunch of underscore songs in
-- the game for me to listen to? Hardstyle / uptempo and stuff is ok too"): APMOfficial UNDERSCORE / no-lead versions
-- (full length, one per track), groups DnB / Hardstyle (uptempo) / Electronic / Chill. Round 1 = git 88f2c38, round 2 = git d234d3c.
-- ROUND 3 (2026-10-25, owner: runs back to DnB + more chill DnB to pick from): 27 APMOfficial chill / liquid DnB full mixes not
-- auditioned before (the Juice Music album the city picks came from, Kamil Mazurek's DNB N Chill full mixes, WORLDWIDE DNB,
-- KPM Liquid Audio, a few classic rollers) + 2 in-game tracks as a REFERENCE row. Trims measured with tools/music_trim.luau (-21.5 dB rule). Trim = the measured Volume that brings the
-- track to the old ~-21.5 dB RMS level (same rule as HubMusic.TRACKS: 10^((-21.5 - RMS) / 20)); it plays at Trim x
-- HubMusic.LEVEL on SoundGroup AimRngMix_Music, so Settings > Audio > Music applies. While it plays HubMusic.Override
-- silences the hub music (fades + pauses like a run); stopping / closing the panel gives it back.
-- KEEP picks: AdminAction "MusicKeep" (id, on) -> AdminService stores them in DataStore DevMusicAudition_v1 / "keeps"
-- (falls back to server memory if Studio has no API access) and prints "MUSIC KEEP: <id> <name>" in the Output.
-- Read them back: F6 > MUSIC (the KEEP ticks + PRINT KEEPS), or art/sounds/preview/music/AUDITION.md.
-- HubMusic.TRACKS is NOT changed by this: the swap happens after the owner picks.
local MusicAudition = {}

MusicAudition.STORE, MusicAudition.KEY = "DevMusicAudition_v1", "keeps"
MusicAudition.GROUPS = { "Juice", "Kamil", "Worldwide", "Liquid", "Classic" }
MusicAudition.GROUP_COLOR = {
    Juice = Color3.fromRGB(48, 226, 255), Kamil = Color3.fromRGB(150, 140, 255), Worldwide = Color3.fromRGB(255, 196, 70),
    Liquid = Color3.fromRGB(110, 230, 160), Classic = Color3.fromRGB(255, 96, 170), Reference = Color3.fromRGB(150, 156, 176),
}
MusicAudition.GROUP_LABEL = { Juice = "Juice Music DnB", Kamil = "DNB N Chill", Worldwide = "Worldwide DnB", Liquid = "Liquid Audio", Classic = "Classic DnB" }

-- { Id, Group, Name, By, Len (s), Trim, Note? }   (generated from the measurements; see AUDITION.md)
-- LIST-BEGIN
MusicAudition.LIST = {
    -- JUICE
    { Id = 9039567217, Group = "Juice", Name = "Breaking Free (a)", By = "Juice Music", Len = 181, Trim = 0.51, Note = "Juice Music 'Drum n Bass' (the album of You and I / Easy Roller / Walking in the Sun); Courageous drum n bass with spirited strings, fuzzy synths, soaring ba" },
    { Id = 9039566355, Group = "Juice", Name = "Sun and Bass (a)", By = "Juice Music", Len = 178, Trim = 0.47, Note = "Juice Music 'Drum n Bass' (the album of You and I / Easy Roller / Walking in the Sun); Beach-party-ready drum n bass with shiny pads, bright keys, sound effe" },
    { Id = 9039568937, Group = "Juice", Name = "Raise It Up (b)", By = "Juice Music", Len = 169, Trim = 0.38, Note = "Juice Music 'Drum n Bass' (the album of You and I / Easy Roller / Walking in the Sun); Sparkling synths introduce animated drum n bass filled with fizzy synt" },
    { Id = 9039566615, Group = "Juice", Name = "Dub Star (a)", By = "Juice Music", Len = 160, Trim = 0.59, Note = "Juice Music 'Drum n Bass' (the album of You and I / Easy Roller / Walking in the Sun); Driving, feel-good drum n bass with dub vibes, featuring sunny offbeat" },
    { Id = 9039568455, Group = "Juice", Name = "Dark and Stormy (b)", By = "Juice Music", Len = 160, Trim = 0.58, Note = "Juice Music 'Drum n Bass' (the album of You and I / Easy Roller / Walking in the Sun); High-energy drum n bass with a dark undertone, featuring menacing wobb" },
    -- KAMIL
    { Id = 100310523012558, Group = "Kamil", Name = "Here I Stand", By = "Kamil Dominik Mazurek", Len = 166, Trim = 0.48, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    { Id = 114921983705231, Group = "Kamil", Name = "Let Me Love", By = "Kamil Dominik Mazurek", Len = 143, Trim = 0.43, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    { Id = 83997818256578, Group = "Kamil", Name = "Free Fall", By = "Kamil Dominik Mazurek", Len = 160, Trim = 0.41, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    { Id = 131050103594724, Group = "Kamil", Name = "In Motion", By = "Kamil Dominik Mazurek", Len = 181, Trim = 0.37, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    { Id = 120984431317324, Group = "Kamil", Name = "Me And You", By = "Kamil Dominik Mazurek", Len = 168, Trim = 0.46, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    { Id = 126427857991924, Group = "Kamil", Name = "Adrenaline Drive", By = "Kamil Dominik Mazurek", Len = 120, Trim = 0.43, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    { Id = 112186346098203, Group = "Kamil", Name = "Moving On", By = "Kamil Dominik Mazurek", Len = 108, Trim = 0.38, Note = "DNB N Chill, full mix (round 2 had the lead-out)" },
    -- WORLDWIDE
    { Id = 1843282312, Group = "Worldwide", Name = "Lokomotiv", By = "Justement Music", Len = 219, Trim = 0.38, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    { Id = 1843282112, Group = "Worldwide", Name = "Tantrik Mandala", By = "Justement Music", Len = 246, Trim = 0.39, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    { Id = 1843282385, Group = "Worldwide", Name = "Western looser", By = "Justement Music", Len = 215, Trim = 0.35, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    { Id = 1843282174, Group = "Worldwide", Name = "Connections", By = "Charles Moreau", Len = 230, Trim = 0.36, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    { Id = 1843282094, Group = "Worldwide", Name = "Go To Uk", By = "Rajaneesh Dwivedi", Len = 227, Trim = 0.26, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    { Id = 1843282469, Group = "Worldwide", Name = "Kick up", By = "Samuel Devauchelle", Len = 222, Trim = 0.30, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    { Id = 1843282233, Group = "Worldwide", Name = "Side Street", By = "Samuel Devauchelle", Len = 230, Trim = 0.40, Note = "WORLDWIDE DNB (the album of Ghostrace)" },
    -- LIQUID
    { Id = 1840546785, Group = "Liquid", Name = "Close To The Heart (A)", By = "KPM Main Series", Len = 212, Trim = 0.82, Note = "KPM Liquid Audio" },
    { Id = 1840546416, Group = "Liquid", Name = "Smooth Accelerator (A)", By = "KPM Main Series", Len = 193, Trim = 1.07, Note = "KPM Liquid Audio" },
    { Id = 1840546932, Group = "Liquid", Name = "Soft Wear (A)", By = "Noiseworks", Len = 203, Trim = 0.70, Note = "KPM Liquid Audio" },
    { Id = 1840546496, Group = "Liquid", Name = "Steel Flame (A)", By = "Noiseworks", Len = 140, Trim = 0.74, Note = "KPM Liquid Audio" },
    -- CLASSIC
    { Id = 1837621712, Group = "Classic", Name = "Supersky", By = "Strategy", Len = 185, Trim = 0.37, Note = "Essential Drum N Bass (classic rollers)" },
    { Id = 1837621659, Group = "Classic", Name = "On The Way", By = "Blak Magik & I", Len = 185, Trim = 0.45, Note = "Essential Drum N Bass (classic rollers)" },
    { Id = 1837621401, Group = "Classic", Name = "Opus", By = "Strategy", Len = 185, Trim = 0.44, Note = "Essential Drum N Bass (classic rollers)" },
    { Id = 1837621503, Group = "Classic", Name = "Underscope", By = "Total Science", Len = 187, Trim = 0.30, Note = "Essential Drum N Bass (classic rollers)" },
    -- REFERENCE
    { Id = 9039566906, Group = "Reference", Name = "You and I (a)", By = "Juice Music", Len = 156, Trim = 0.52, Note = "in the game now (level / feel reference); Dreamy, laid-back drum n bass with reverberant keys, atmospheric pads" },
    { Id = 130097537384597, Group = "Reference", Name = "Star Stream", By = "Kamil Dominik Mazurek", Len = 143, Trim = 0.37, Note = "in the game now (level / feel reference)" },
}
-- LIST-END

MusicAudition.ById = {}
for i, t in ipairs(MusicAudition.LIST) do t.Index = i; MusicAudition.ById[t.Id] = t end

local function Clock(s: number): string
    s = math.max(0, math.floor(s or 0))
    return string.format("%d:%02d", s // 60, s % 60)
end
MusicAudition.Clock = Clock

-- Build(view, api) -> controller { Stop(), Shown(bool) }. view = the admin panel's MUSIC frame;
-- api = { Click(), Toast(msg), Invoke(action, ...) -> AdminAction result, Panel = the admin panel frame }
function MusicAudition.Build(view: Frame, api: any)
    local Shared = script.Parent
    local UIStyle = require(Shared:WaitForChild("UIStyle"))
    local HubMusic = require(Shared:WaitForChild("HubMusic"))
    local SoundService = game:GetService("SoundService")
    local RunService = game:GetService("RunService")
    local C = UIStyle.Colors
    local LIST = MusicAudition.LIST

    local keeps = {}      -- [id] = true
    local cur = nil       -- index into LIST
    local sound: Sound? = nil
    local loop = nil      -- the 0.2 s position loop (only while a track is loaded)
    local rows = {}
    local LOG = {} -- (a short event log for the Studio test hook: State().Log)
    local function L(msg)
        table.insert(LOG, string.format("%.2f %s", os.clock(), msg))
        if #LOG > 40 then table.remove(LOG, 1) end
    end

    -- ===== transport =====
    local top = UIStyle.Card(view, { Name = "NowPlaying", Size = UDim2.new(1, 0, 0, 118), Position = UDim2.fromOffset(0, 0) })
    local nowGroup = UIStyle.Text({ Text = "MUSIC AUDITION", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16), Parent = top })
    local nowName = UIStyle.Text({ Text = "Pick a track below, or press PLAY", TextSize = 20, Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -150, 0, 26), Parent = top })
    nowName.TextTruncate = Enum.TextTruncate.AtEnd
    local nowBy = UIStyle.Text({ Text = #LIST .. " tracks at the in-game level  •  the hub music is muted while one plays", TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub,
        Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -150, 0, 16), Parent = top })
    nowBy.TextTruncate = Enum.TextTruncate.AtEnd
    local timeLbl = UIStyle.Text({ Text = "0:00 / 0:00", TextSize = 16, Font = UIStyle.AccentFont or UIStyle.Font, TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -144, 0, 26), Size = UDim2.fromOffset(130, 22), Parent = top })
    local keptLbl = UIStyle.Text({ Text = "KEPT 0", TextSize = 13, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -144, 0, 50), Size = UDim2.fromOffset(130, 16), Parent = top })
    -- the position bar (click = seek)
    local bar = Instance.new("TextButton")
    bar.Name = "Seek"; bar.Text = ""; bar.AutoButtonColor = false; bar.BorderSizePixel = 0; bar.BackgroundColor3 = C.Well or Color3.fromRGB(14, 14, 24)
    bar.Position = UDim2.fromOffset(14, 72); bar.Size = UDim2.new(1, -28, 0, 6); bar.Parent = top
    local fill = Instance.new("Frame")
    fill.Name = "Fill"; fill.BorderSizePixel = 0; fill.BackgroundColor3 = C.Neon; fill.Size = UDim2.fromScale(0, 1); fill.Parent = bar
    local btnY, bx = 84, 14
    local function TB(text, w, color, name)
        local b = UIStyle.Button(top, text, color or C.Bg2 or Color3.fromRGB(40, 42, 60), UDim2.fromOffset(w, 28), UDim2.fromOffset(bx, btnY), name)
        bx += w + 6
        return b
    end
    local bPrev = TB("◀ PREV", 84, nil, "Prev")
    local bPlay = TB("PLAY", 96, C.Neon, "Play")
    local bNext = TB("NEXT ▶", 84, nil, "Next")
    local b60 = TB("TO 1:00", 80, nil, "To60")
    local b120 = TB("TO 2:00", 80, nil, "To120")
    local bStop = TB("STOP", 70, Color3.fromRGB(200, 80, 80), "Stop")
    local bKeep = TB("KEEP", 90, C.Good, "KeepNow")
    local bPrint = TB("PRINT KEEPS", 110, nil, "PrintKeeps")

    local list = Instance.new("ScrollingFrame")
    list.Name = "Tracks"; list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.Position = UDim2.fromOffset(0, 126)
    list.Size = UDim2.new(1, 0, 1, -126); list.ScrollBarThickness = 8; list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new()
    list.Parent = view
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 3); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list

    local function KeptCount()
        local n = 0
        for _ in pairs(keeps) do n += 1 end
        return n
    end
    local function PaintRows()
        for i, r in pairs(rows) do
            local t = LIST[i]
            local on = keeps[t.Id] == true
            r.Keep.SetText(on and "KEPT ✓" or "KEEP")
            r.Keep.SetColor(on and C.Good or (C.Bg2 or Color3.fromRGB(40, 42, 60)))
            r.Row.BackgroundTransparency = (i == cur) and 0.2 or 0.65
            r.Row.BackgroundColor3 = (i == cur) and Color3.fromRGB(30, 46, 62) or Color3.fromRGB(22, 24, 36)
            r.Num.TextColor3 = (i == cur) and C.Neon or C.Muted
        end
        keptLbl.Text = "KEPT " .. KeptCount()
        local t = cur and LIST[cur]
        local on = t and keeps[t.Id] == true
        bKeep.SetText(on and "KEPT ✓" or "KEEP")
        bKeep.SetEnabled(t ~= nil and t.Group ~= "Reference")
    end

    local function SetKeep(t, on)
        if not t or t.Group == "Reference" then return end
        api.Click()
        local ok, res, msg = pcall(api.Invoke, "MusicKeep", t.Id, on == true)
        if ok and res then
            keeps[t.Id] = on and true or nil
            api.Toast((on and "Kept: " or "Removed: ") .. t.Name)
        else
            api.Toast("Couldn't save the pick: " .. tostring(msg or res))
        end
        PaintRows()
    end

    local escConn = nil   -- (Esc while auditioning = a real close; connected only while a track is loaded)
    local userCloseAt = -1
    local function StopLoop()
        if loop then loop:Disconnect(); loop = nil end
        if escConn then escConn:Disconnect(); escConn = nil end
    end
    local function Stop(why)
        L("Stop " .. tostring(why))
        StopLoop()
        if sound then sound:Destroy(); sound = nil end
        cur = nil
        HubMusic.Override = nil -- (the hub music fades back in where it paused)
        bPlay.SetText("PLAY")
        nowName.Text = "Stopped"
        nowGroup.Text = "MUSIC AUDITION"
        nowBy.Text = "the hub music is back"
        timeLbl.Text = "0:00 / 0:00"
        fill.Size = UDim2.fromScale(0, 1)
        PaintRows()
    end
    local Play
    local function Tick()
        if not sound or not cur then return end
        local len = sound.TimeLength
        if len <= 0 then len = LIST[cur].Len or 0 end
        timeLbl.Text = Clock(sound.TimePosition) .. " / " .. Clock(len)
        fill.Size = UDim2.fromScale(len > 0 and math.clamp(sound.TimePosition / len, 0, 1) or 0, 1)
        bPlay.SetText(sound.IsPlaying and "PAUSE" or "PLAY")
    end
    -- (round 2 fix) every track gets a FRESH Sound, and its Ended only counts when it is still the current Sound and
    -- has played for 2+ s: one reused Sound could report Ended for the SoundId it was switched away from, which
    -- skipped a track (round 1: 1 -> 3) on the next Play.
    local token = 0
    function Play(i)
        if #LIST == 0 then return end
        i = ((i - 1) % #LIST) + 1
        local t = LIST[i]
        cur = i
        token += 1
        local my = token
        L("Play " .. i .. " " .. tostring(t.Id))
        HubMusic.Override = true
        if sound then sound:Destroy() end
        local s = Instance.new("Sound")
        s.Name = "MusicAudition"
        s.Looped = false
        s.SoundGroup = SoundService:FindFirstChild("AimRngMix_Music")
        s.SoundId = "rbxassetid://" .. tostring(t.Id)
        s.Volume = (t.Trim or 1) * (HubMusic.LEVEL or 1)
        s.Parent = SoundService
        sound = s
        local startedAt = os.clock()
        s.Ended:Connect(function()
            local ok = (my == token and s == sound and os.clock() - startedAt > 2)
            L("Ended " .. tostring(t.Id) .. (ok and " -> next" or " (ignored)"))
            if ok then Play(i + 1) end -- (a track ran out: the next one)
        end)
        s:Play()
        if not escConn then
            escConn = game:GetService("UserInputService").InputBegan:Connect(function(input)
                if input.KeyCode == Enum.KeyCode.Escape then userCloseAt = os.clock() end
            end)
        end
        nowGroup.Text = string.upper(MusicAudition.GROUP_LABEL[t.Group] or t.Group) .. "  •  " .. i .. " / " .. #LIST .. "  •  trim " .. string.format("%.2f", t.Trim or 1)
        nowName.Text = t.Name
        nowBy.Text = t.By .. (t.Note and ("  •  " .. t.Note) or "")
        if not loop then
            local acc = 0
            loop = RunService.Heartbeat:Connect(function(dt)
                acc += dt
                if acc < 0.2 then return end
                acc = 0
                Tick()
            end)
        end
        Tick()
        PaintRows()
        -- keep the row in view
        local r = rows[i]
        if r then
            local y = r.Row.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
            if y < list.CanvasPosition.Y or y > list.CanvasPosition.Y + list.AbsoluteSize.Y - 40 then
                list.CanvasPosition = Vector2.new(0, math.max(0, y - 60))
            end
        end
    end
    local function Seek(s)
        if not sound or not cur then return end
        local len = sound.TimeLength
        if len > 0 and s >= len then s = math.max(0, len - 5) end
        sound.TimePosition = s
        if not sound.IsPlaying then sound:Resume() end
        L("Seek " .. tostring(s))
        Tick()
    end

    bPlay.Button.MouseButton1Click:Connect(function()
        api.Click()
        if not sound or not cur then Play(cur or 1) return end
        if sound.IsPlaying then sound:Pause() else sound:Resume() end
        Tick()
    end)
    bPrev.Button.MouseButton1Click:Connect(function() api.Click(); Play((cur or 1) - 1) end)
    bNext.Button.MouseButton1Click:Connect(function() api.Click(); Play((cur or 0) + 1) end)
    b60.Button.MouseButton1Click:Connect(function() api.Click(); Seek(60) end)
    b120.Button.MouseButton1Click:Connect(function() api.Click(); Seek(120) end)
    bStop.Button.MouseButton1Click:Connect(function() api.Click(); Stop("STOP button") end)
    bKeep.Button.MouseButton1Click:Connect(function()
        local t = cur and LIST[cur]
        if t and bKeep.Button.Active then SetKeep(t, not keeps[t.Id]) end
    end)
    bPrint.Button.MouseButton1Click:Connect(function()
        api.Click()
        local ok, res, msg = pcall(api.Invoke, "MusicKeepsPrint")
        api.Toast(ok and tostring(msg or "Printed to the Output.") or "Failed.")
    end)
    bar.MouseButton1Down:Connect(function(x)
        if not sound or not cur then return end
        local len = sound.TimeLength
        if len <= 0 then return end
        Seek(math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1) * len)
    end)

    -- ===== the list =====
    local order, lastGroup = 0, nil
    for i, t in ipairs(LIST) do
        if t.Group ~= lastGroup then
            lastGroup = t.Group
            order += 1
            local h = UIStyle.Text({ Text = string.upper(MusicAudition.GROUP_LABEL[t.Group] or t.Group), TextSize = 14, TextColor3 = MusicAudition.GROUP_COLOR[t.Group] or C.Sub,
                Size = UDim2.new(1, -12, 0, 24), LayoutOrder = order, Parent = list })
            h.TextYAlignment = Enum.TextYAlignment.Bottom
        end
        order += 1
        local row = Instance.new("TextButton")
        row.Name = "T" .. i; row.Text = ""; row.AutoButtonColor = false; row.BorderSizePixel = 0
        row.Size = UDim2.new(1, -12, 0, 34); row.LayoutOrder = order; row.Parent = list
        local stripe = Instance.new("Frame")
        stripe.BorderSizePixel = 0; stripe.Size = UDim2.new(0, 3, 1, -8); stripe.Position = UDim2.fromOffset(0, 4)
        stripe.BackgroundColor3 = MusicAudition.GROUP_COLOR[t.Group] or C.Sub; stripe.Parent = row
        local num = UIStyle.Text({ Text = tostring(i), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(26, 34), Parent = row })
        local nm = UIStyle.Text({ Text = t.Name, TextSize = 15, Position = UDim2.fromOffset(42, 1), Size = UDim2.new(0.5, -40, 0, 20), Parent = row })
        nm.TextTruncate = Enum.TextTruncate.AtEnd
        local by = UIStyle.Text({ Text = t.By .. (t.Note and ("  •  " .. t.Note) or ""), TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub,
            Position = UDim2.fromOffset(42, 19), Size = UDim2.new(1, -250, 0, 14), Parent = row })
        by.TextTruncate = Enum.TextTruncate.AtEnd
        UIStyle.Text({ Text = Clock(t.Len) .. "   x" .. string.format("%.2f", t.Trim or 1), TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub,
            TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -214, 0, 0), Size = UDim2.fromOffset(110, 34), Parent = row })
        local keep = UIStyle.Button(row, "KEEP", C.Bg2 or Color3.fromRGB(40, 42, 60), UDim2.fromOffset(92, 26), UDim2.new(1, -96, 0.5, -13), "Keep")
        if t.Group == "Reference" then keep.SetText("NOW IN GAME"); keep.SetEnabled(false) end
        keep.Button.MouseButton1Click:Connect(function()
            if keep.Button.Active then SetKeep(t, not keeps[t.Id]) end
        end)
        row.MouseButton1Click:Connect(function() api.Click(); Play(i) end)
        rows[i] = { Row = row, Keep = keep, Num = num }
    end

    -- picks saved on the server (survive a Stop / Play)
    local function LoadKeeps()
        local ok, res = pcall(api.Invoke, "MusicKeeps")
        keeps = {}
        if ok and type(res) == "table" then
            for k, v in pairs(res) do if v then keeps[tonumber(k) or k] = true end end
        end
        PaintRows()
    end
    LoadKeeps()

    -- closing the admin panel ends the audition (and gives the hub music back)
    if api.Panel then
        api.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
            -- (round 2 fix) only a real close ends the audition: F6 / the X (AdminPanel marks them) or Esc. A window that
            -- opens on its own (welcome guide, tutorial offer, unlock cards: OpenMenuFrame hides every other window)
            -- used to stop it a few seconds after join; now it keeps playing behind that window.
            L("Panel Visible=" .. tostring(api.Panel.Visible))
            if api.Panel.Visible or not (sound or HubMusic.Override) then return end
            local closedAt = math.max(userCloseAt, api.UserClosedAt and api.UserClosedAt() or -1)
            if os.clock() - closedAt < 0.5 then
                Stop("panel closed")
            else
                L("hidden by another window: still playing")
                api.Toast("Music audition still playing: F6 to come back or stop it")
            end
        end)
    end
    PaintRows()
    return {
        Stop = Stop,
        Reload = LoadKeeps,
        Play = Play, Seek = Seek, -- (Studio test hooks)
        State = function()
            return { Cur = cur, Id = cur and LIST[cur].Id, Pos = sound and sound.TimePosition, Playing = sound and sound.IsPlaying,
                Vol = sound and sound.Volume, Kept = KeptCount(), Log = LOG }
        end,
    }
end

return MusicAudition
