-- STUDIO ONLY (owner 2026-10-11: agents' play tests kept moving the owner's mouse). An agent sets workspace attribute
-- DevNoMouseLock = true (Edit, before starting play) and the first-person mouse lock never grabs / recentres the real
-- cursor; the game still runs (tests drive it through DevAct / DevFire / DevCmd, not the mouse). Agents clear the
-- attribute before releasing the studio lock, so the owner's own play tests lock the mouse as usual.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    return
end
local UserInputService = game:GetService("UserInputService")
RunService:BindToRenderStep("DevNoMouseLock", Enum.RenderPriority.Last.Value + 10, function()
    if workspace:GetAttribute("DevNoMouseLock") and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)
