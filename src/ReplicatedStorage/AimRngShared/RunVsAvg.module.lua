--!nocheck
-- "VS YOUR AVERAGE" (QOL PASS 2 R3, 2026-10-28): under ACCURACY / WEAK SPOT / DPS on the RUN SUMMARY, how this run compares with
-- your average before it (server RunStats.Averages over the AIM PROFILE's run log: me.AvgAcc / me.AvgWeak / me.AvgDps; nil =
-- not enough runs logged yet -> no line). Accuracy + weak spot in percentage points, DPS in percent. Green better, red worse,
-- grey within half a point. Called once per Render (no per-frame work).
--
--   RunVsAvg.Decorate(grid, me) -- grid = the summary's tile grid (tiles by LayoutOrder: 4 ACCURACY, 6 WEAK SPOT, 9 DPS)
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))

local RunVsAvg = {}
local C = UIStyle.Colors
RunVsAvg.TILES = { { 4, "Accuracy", "AvgAcc", "pts" }, { 6, "WeakPct", "AvgWeak", "pts" }, { 9, "DPS", "AvgDps", "rel" } }
RunVsAvg.FLAT = 0.5 -- (within this many points / percent = grey)

-- the line for one stat: text + colour, or nil
function RunVsAvg.Line(v: number?, avg: number?, kind: string): (string?, Color3?)
    if type(v) ~= "number" or type(avg) ~= "number" or v ~= v or avg ~= avg then return nil end
    local d
    if kind == "rel" then
        if avg <= 0 or v <= 0 then return nil end
        d = (v / avg - 1) * 100
    else
        d = (v - avg) * 100
    end
    local col = (d >= RunVsAvg.FLAT and C.Good) or (d <= -RunVsAvg.FLAT and C.Bad) or C.Sub
    local txt = (math.abs(d) < 0.05) and "= avg" or string.format("%s%.1f%% vs avg", d > 0 and "+" or "-", math.abs(d))
    return txt, col
end

function RunVsAvg.Decorate(grid: Instance, me: any)
    if type(me) ~= "table" then return end
    for _, t in ipairs(RunVsAvg.TILES) do
        local tile
        -- (UI CLEAN R-C: the summary names its tiles by stat key -- found by name first, the old LayoutOrder as the fallback)
        tile = grid:FindFirstChild(t[2])
        if not tile and not grid:FindFirstChild("Time") then
            for _, c in ipairs(grid:GetChildren()) do if c:IsA("Frame") and c.LayoutOrder == t[1] then tile = c break end end
        end
        local v = me[t[2]]
        if t[2] ~= "DPS" and (tonumber(me.Shots) or 0) <= 0 then v = nil end -- (no shots this run: nothing to compare)
        local txt, col = RunVsAvg.Line(v, me[t[3]], t[4])
        if tile and txt then
            local l = Instance.new("TextLabel")
            l.Name = "VsAvg"; l.BackgroundTransparency = 1; l.Font = UIStyle.BodyFont; l.TextSize = 13; l.TextColor3 = col
            l:SetAttribute("TextRole", "Meta")
            l.Text = txt; l.TextXAlignment = Enum.TextXAlignment.Right
            l.Position = UDim2.fromOffset(10, 28); l.Size = UDim2.new(1, -20, 0, 22)
            l.Parent = tile
        end
    end
end

return RunVsAvg
