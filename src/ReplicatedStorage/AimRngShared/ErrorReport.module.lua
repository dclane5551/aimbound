--!nocheck
-- Client half of the LIVE ERROR LOG (ServerScriptService ErrorLog): forwards this player's script errors to the server.
-- The same message is sent at most once a minute; the server also rate-limits each player.
local ScriptContext = game:GetService("ScriptContext")
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local ErrorReport = {}
local sentAt = {}

function ErrorReport.Start()
    if ErrorReport._on then return end
    ErrorReport._on = true
    local ev = Remotes.GetEvent("ReportError")
    ScriptContext.Error:Connect(function(msg, trace)
        local key = tostring(msg):sub(1, 120)
        local now = os.clock()
        if sentAt[key] and now - sentAt[key] < 60 then return end
        sentAt[key] = now
        ev:FireServer(tostring(msg):sub(1, 300), tostring(trace):sub(1, 600))
    end)
end

return ErrorReport
