--!nocheck
-- HUB MUSIC (2026-10-23, owner: "We need some sort of music for the game"). Client only: HubMusic.Start(hooks) from AimRngClient.
-- TWO PLAYLISTS (2026-10-24, owner: "lets do the dnb tracks in the city, and then in game we'll do underscore"):
--   TRACKS     = the city / market / range / hideout (the owner's chill DnB picks: APM Music, Roblox's licensed library)
--   RUN_TRACKS = every run floor, bosses too: the same DnB picks, RUN_TRIM (~4.4 dB) under the city level (2026-10-25; the
--                Underscore run list of 2026-10-24 was "too much")
-- Two Sounds (A / B) on SoundGroup AimRngMix_Music (volume = Master x Music, Settings > Audio > Music): each list has its
-- own shuffle bag (no track twice in a row) and crossfades XFADE s before a track ends. Moving between the city and a run
-- crossfades the lists over SWITCH s; each list remembers its track + position, so the city resumes its DnB track mid-way.
-- SILENT (fades out over FADE s + pauses, resumes where it was): duels (footsteps / shots), the tutorial hall / try range,
-- try-ons, Aim Trials, spectating, HubMusic.Override (the dev MUSIC AUDITION) and a playing hideout jukebox ("HideoutMusic").
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local HubMusic = {}

-- { Id, Name, By, Volume } -- Volume = per-track trim to the old tracks' level (~-21.5 dB RMS measured with an AudioAnalyzer;
-- the library masters are 3-10 dB hotter). v2 (2026-10-23, owner: the CC0 tracks "sound cheesy and AI generated"): Roblox's
-- licensed music library (creator APMOfficial = APM Music, free in any experience, no per-id access grant). Shortlist +
-- the old ids: art/sounds/preview/music/README.md.
HubMusic.TRACKS = { -- (2026-10-24 v3 chill DnB: the owner's 8 picks from the F6 MUSIC audition; Volume = measured trim)
    { Id = 9039566906, Name = "You and I", By = "Juice Music", Volume = 0.52 },
    { Id = 9039568053, Name = "Easy Roller", By = "Juice Music", Volume = 0.57 },
    { Id = 9039567438, Name = "Walking in the Sun", By = "Juice Music", Volume = 0.60 },
    { Id = 9042183916, Name = "All Right", By = "KPM Main Series", Volume = 0.60 },
    { Id = 130097537384597, Name = "Star Stream", By = "Kamil Dominik Mazurek", Volume = 0.37 },
    { Id = 74889756421416, Name = "With You (Underscore)", By = "Kamil Dominik Mazurek", Volume = 0.46 },
    { Id = 127557053729116, Name = "Right By Your Side (Underscore)", By = "Kamil Dominik Mazurek", Volume = 0.44 },
    { Id = 1843282365, Name = "Ghostrace", By = "Justement Music", Volume = 0.43 },
}
-- RUN_TRACKS (2026-10-25, owner: runs back to DnB, the Underscore run list was "too much"): the same DnB picks as the city,
-- RUN_TRIM under the city level (the old run list's ~-26 dB target: music sits under the fight). Its own shuffle bag + memory,
-- so walking into a run still crossfades to another track and the city resumes its own mid-way.
HubMusic.RUN_TRIM = 0.6
HubMusic.RUN_TRACKS = {}
for i, t in ipairs(HubMusic.TRACKS) do
    HubMusic.RUN_TRACKS[i] = { Id = t.Id, Name = t.Name, By = t.By, Volume = t.Volume * HubMusic.RUN_TRIM }
end
HubMusic.FADE = 1.5      -- s to fade out / in when the music goes silent / comes back
HubMusic.SWITCH = 1.8    -- s of crossfade between the city list and the run list
HubMusic.XFADE = 4       -- s of crossfade between two tracks
HubMusic.LEVEL = 1.0     -- Sound.Volume at full (the group carries Master x Music: 50% = -6 dB -> ~-26 LUFS, a gunshot is ~-11)
HubMusic.ZONES = { city = true, market = true, range = true, hideout = true }
HubMusic.Override = nil -- (2026-10-24) true = silenced by something else playing (the dev MUSIC AUDITION panel); fades + pauses

local started = false
function HubMusic.Start(hooks: any)
    if started or not RunService:IsClient() then return end
    started = true
    hooks = hooks or {}
    local GameSettings = hooks.GameSettings
    local Zones = hooks.Zones
    local lp = Players.LocalPlayer

    local group = SoundService:FindFirstChild("AimRngMix_Music") or Instance.new("SoundGroup")
    group.Name = "AimRngMix_Music"
    group.Parent = SoundService
    local function ApplyVol()
        local m = (tonumber(GameSettings and GameSettings.Get("VolMaster")) or 100) / 100
        local v = (tonumber(GameSettings and GameSettings.Get("VolMusic")) or 50) / 100
        group.Volume = m * v
    end
    ApplyVol()
    if GameSettings then
        GameSettings.OnChanged("VolMaster", ApplyVol)
        GameSettings.OnChanged("VolMusic", ApplyVol)
    end

    local function NewSound(name: string): Sound
        local s = Instance.new("Sound")
        s.Name = name
        s.Looped = false
        s.Volume = 0
        s.SoundGroup = group
        s.Parent = SoundService
        s.Ended:Connect(function() s:SetAttribute("Done", true) end)
        return s
    end
    local A, B = NewSound("HubMusicA"), NewSound("HubMusicB")
    local LISTS = { city = HubMusic.TRACKS, run = HubMusic.RUN_TRACKS }
    local cur, nxt = A, B          -- cur = the track you hear, nxt = the one fading in during a crossfade
    local info = { [A] = {}, [B] = {} } -- [sound] = { List, Track, Trim }
    local curList = nil            -- the list cur belongs to ("city" | "run")
    local bags, lastIdx = { city = {}, run = {} }, {}
    local mem = {}                 -- [list] = { Track, Pos }: where a list was when the other list took over
    local fade = 0                 -- 0..1 presence (silent places / the jukebox)
    local xf, xfDur = nil, HubMusic.XFADE -- crossfade progress 0..1 while nxt fades in (a track change or a list switch)

    local function NextTrack(list: string): any
        local tracks = LISTS[list] or {}
        local n = #tracks
        if n == 0 then return nil end
        local bag = bags[list]
        if #bag == 0 then
            for i = 1, n do bag[i] = i end
            for i = n, 2, -1 do local j = math.random(i); bag[i], bag[j] = bag[j], bag[i] end
            if n > 1 and bag[#bag] == lastIdx[list] then bag[1], bag[#bag] = bag[#bag], bag[1] end
        end
        local i = table.remove(bag)
        lastIdx[list] = i
        return tracks[i]
    end
    -- put the list's next track into s (or the track it left off on, from that spot)
    local function Load(s: Sound, list: string)
        local m = mem[list]
        mem[list] = nil
        local t = m and m.Track or NextTrack(list)
        info[s] = { List = list, Track = t, Trim = t and t.Volume or 1 }
        if not t then s.SoundId = ""; return end
        s.SoundId = "rbxassetid://" .. tostring(t.Id)
        s.TimePosition = m and m.Pos or 0
        s:SetAttribute("Done", nil)
    end
    local function Remember(s: Sound)
        local inf = info[s]
        if inf and inf.Track and not s:GetAttribute("Done") then
            mem[inf.List] = { Track = inf.Track, Pos = s.TimePosition }
        end
    end

    -- the jukebox: a Sound named HideoutMusic (HideoutShowcase) somewhere in the workspace
    local juke: Sound? = nil
    workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Sound") and d.Name == "HideoutMusic" then juke = d end
    end)
    local function JukeOn(): boolean
        if juke and (not juke.Parent or not juke:IsDescendantOf(workspace)) then juke = nil end
        -- (JUKEBOX v2: attr Station = a station is on, also while its next track loads)
        return juke ~= nil and (juke.IsPlaying or juke:GetAttribute("Station") ~= nil)
    end

    -- the list that should play here: "city" | "run" | nil (silent)
    local function Mode(): string?
        if HubMusic.Override then return nil end
        if hooks.Blocked and hooks.Blocked() then return nil end
        if lp:GetAttribute("PvpDuel") or lp:GetAttribute("TryOnFP") then return nil end
        if lp:GetAttribute("RunId") then return (#HubMusic.RUN_TRACKS > 0) and "run" or nil end -- (party floors)
        local ch = lp.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root or not Zones then return nil end
        local kind = Zones.Kind(root.Position)
        if kind == "dungeon" then return (#HubMusic.RUN_TRACKS > 0) and "run" or nil end -- (solo floors have no RunId)
        if not HubMusic.ZONES[kind] then return nil end
        if JukeOn() then return nil end
        return (#HubMusic.TRACKS > 0) and "city" or nil
    end

    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.1 then return end
        local step = acc
        acc = 0
        local mode = Mode()
        fade = math.clamp(fade + (mode and 1 or -1) * step / HubMusic.FADE, 0, 1)
        if not mode then
            if fade <= 0 then
                if cur.IsPlaying then cur:Pause() end
                if nxt.IsPlaying then nxt:Pause() end
                return
            end
        elseif mode ~= curList then
            if not curList or fade <= 0.2 or not (cur.IsPlaying or nxt.IsPlaying) then
                -- nothing (much) audible: swap lists in place (the old list's spot is remembered)
                if curList then Remember(cur) end
                if xf then nxt:Stop(); xf = nil end
                cur:Stop()
                Load(cur, mode)
                curList = mode
                cur:Play()
            else
                -- CITY <-> RUN: crossfade the lists over SWITCH s
                if xf then -- (a track crossfade was running: keep the newer track as this list's spot)
                    cur:Stop()
                    cur, nxt = nxt, cur
                end
                Remember(cur)
                Load(nxt, mode)
                nxt.Volume = 0
                nxt:Play()
                curList = mode
                xf, xfDur = 0, HubMusic.SWITCH
            end
        end
        if mode and mode == curList then
            if not cur.IsPlaying then
                if xf and cur:GetAttribute("Done") then
                    if not nxt.IsPlaying then nxt:Resume() end -- (the old track ran out mid-crossfade)
                elseif not xf and (cur.SoundId == "" or cur:GetAttribute("Done")) then
                    Load(cur, curList) -- (a track ran out without a crossfade: short / not loaded)
                    cur:Play()
                elseif not (xf and xfDur == HubMusic.SWITCH) then
                    cur:Resume()   -- back from a silent place: carry on where it paused
                end
            end
            if xf and not nxt.IsPlaying and not nxt:GetAttribute("Done") then nxt:Resume() end
            -- crossfade into this list's next track near the end of this one
            local len = cur.TimeLength
            if not xf and len > HubMusic.XFADE * 2 and cur.TimePosition >= len - HubMusic.XFADE then
                Load(nxt, curList)
                nxt.Volume = 0
                nxt:Play()
                xf, xfDur = 0, HubMusic.XFADE
            end
        end
        if xf then
            xf = math.min(1, xf + step / xfDur)
            if xf >= 1 then
                cur:Stop()
                cur, nxt = nxt, cur
                xf = nil
            end
        end
        local base = HubMusic.LEVEL * fade
        cur.Volume = base * ((info[cur] or {}).Trim or 1) * (xf and math.cos(xf * math.pi / 2) or 1)
        if xf then nxt.Volume = base * ((info[nxt] or {}).Trim or 1) * math.sin(xf * math.pi / 2) end
    end)

    HubMusic.Debug = function()
        local ci = info[cur] or {}
        return string.format("list %s fade %.2f cur %s pos %.1f/%.1f vol %.2f playing %s xf %s group %.2f track %s juke %s",
            tostring(curList), fade, cur.Name, cur.TimePosition, cur.TimeLength, cur.Volume, tostring(cur.IsPlaying), tostring(xf),
            group.Volume, ci.Track and ci.Track.Name or "-", tostring(JukeOn()))
    end
end

return HubMusic
