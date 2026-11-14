--!nocheck
-- Custom characters (character creator). Roblox avatars are off (StarterPlayer.LoadCharacterAppearance = false):
-- every character is the plain blocky R15 body, dressed here from the player's saved look (state.Avatar, see
-- AvatarData): body scale, skin / shirt / pants colors, a block head shell with a face, and block-built hair.
-- The creator previews looks live on your real character (AvatarAction "Preview"), then saves ("Save").
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local AvatarData = require(Shared:WaitForChild("AvatarData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AvatarService = {}

local SKIN_PARTS = { "Head", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm" }
local SHIRT_PARTS = { "UpperTorso" }
local PANTS_PARTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }

local function Paint(char: Model, names: { string }, color: Color3, material: Enum.Material?)
    for _, n in ipairs(names) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            p.Color = color
            p.Material = material or Enum.Material.SmoothPlastic
        end
    end
end

local function Weld(a: BasePart, b: BasePart, c0: CFrame)
    local w = Instance.new("Weld")
    w.Part0 = a; w.Part1 = b; w.C0 = c0; w.Parent = b
end

local function Piece(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?, ball: boolean?): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
    if ball then
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Sphere
        m.Parent = p
    end
    p.Parent = parent
    return p
end

-- Dress a character in a look (any look: previews may show locked items).
function AvatarService.Apply(char: Model, look: any)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head") :: BasePart?
    if not (hum and head) then return end
    look = AvatarData.Normalize(look)
    local body = AvatarData.Find("Body", look.Body)
    local skin = AvatarData.Find("Skin", look.Skin)
    local headDef = AvatarData.Find("Head", look.Head)
    local face = AvatarData.Find("Face", look.Face)
    local hair = AvatarData.Find("Hair", look.Hair)
    local hairCol = AvatarData.Find("HairColor", look.HairColor).Color
    local shirt = AvatarData.Find("Shirt", look.Shirt).Color
    local pants = AvatarData.Find("Pants", look.Pants).Color
    local sleeves = look.Sleeves

    -- no Roblox avatar pieces, ever (also covers LoadCharacterAppearance being switched back on)
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("CharacterMesh") or d:IsA("BodyColors") then d:Destroy() end
    end

    -- body proportions (R15 scale values; the rig rescales itself)
    local rescaled = false
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local function SetScale(name: string, v: number)
            local nv = hum:FindFirstChild(name)
            if nv and nv:IsA("NumberValue") and math.abs(nv.Value - v) > 1e-3 then nv.Value = v; rescaled = true end
        end
        SetScale("BodyWidthScale", body.W)
        SetScale("BodyHeightScale", body.H)
        SetScale("BodyDepthScale", body.D)
        SetScale("HeadScale", body.Head)
        SetScale("BodyTypeScale", 0)
        SetScale("BodyProportionScale", 0)
    end
    if rescaled then task.wait(0.1) end -- let the rig resize before measuring the head
    if not head.Parent then return end

    -- colors
    local skinMat = skin.Material == "Metal" and Enum.Material.Metal or nil
    Paint(char, SKIN_PARTS, skin.Color, skinMat)
    Paint(char, SHIRT_PARTS, shirt)
    Paint(char, PANTS_PARTS, pants)
    if sleeves == "Short" or sleeves == "Long" then Paint(char, { "LeftUpperArm", "RightUpperArm" }, shirt) end
    if sleeves == "Long" then Paint(char, { "LeftLowerArm", "RightLowerArm" }, shirt) end

    -- head: every shape is a shell over the (hidden) Roblox head -- the default head is a dynamic head with its face
    -- in the mesh, so a face decal on it would flicker
    local old = char:FindFirstChild("AvatarLook")
    if old then old:Destroy() end
    local folder = Instance.new("Model")
    folder.Name = "AvatarLook"
    local faceDecal = head:FindFirstChildOfClass("Decal")
    local box: Vector3
    local mount: BasePart
    if headDef.Size then
        box = headDef.Size * (body.Head or 1)
        local shell = Piece(folder, "HeadShell", box, skin.Color, skinMat, headDef.Sphere)
        if headDef.ClassicMesh then
            local m = Instance.new("SpecialMesh")
            m.MeshType = Enum.MeshType.Head
            m.Scale = Vector3.one -- (the Head mesh fills the shell's smallest side)
            m.Parent = shell
        end
        -- sits on the neck exactly like the real head (bottoms level)
        Weld(head, shell, CFrame.new(0, (box.Y - head.Size.Y) / 2, 0))
        head.Transparency = 1
        if faceDecal then faceDecal.Transparency = 1 end
        local d = Instance.new("Decal")
        d.Name = "Face"
        d.Face = Enum.NormalId.Front
        d.Texture = face.Texture
        d.Parent = shell
        mount = shell
    else
        box = head.Size
        head.Transparency = 0
        if not faceDecal then
            faceDecal = Instance.new("Decal"); faceDecal.Name = "face"; faceDecal.Face = Enum.NormalId.Front; faceDecal.Parent = head
        end
        faceDecal.Transparency = 0
        faceDecal.Texture = face.Texture
        mount = head
    end
    local mountOffset = (mount == head) and CFrame.new() or CFrame.new(0, (box.Y - head.Size.Y) / 2, 0)

    -- cosmetic pieces (hair + every slot: headwear, top, bottom, ...), each in units of the part it attaches to
    local skinCol = skin.Color
    local named = {
        Hair = hairCol, Skin = skinCol, Shirt = shirt, Pants = pants,
        ShirtDark = shirt:Lerp(Color3.new(0, 0, 0), 0.35), PantsDark = pants:Lerp(Color3.new(0, 0, 0), 0.35),
        Trim = (AvatarData.Find("Trim", look.Trim) or AvatarData.Trim[1]).Color,
    }
    local function AddPieces(tag: string, pieces: { any }, defaultAttach: string, defaultColor: Color3)
        for i, pc in ipairs(pieces) do
            local attachName = pc.Attach or defaultAttach
            local onHead = attachName == "Head"
            local attach = char:FindFirstChild(attachName) :: BasePart?
            if attach and attach:IsA("BasePart") then
                local unit = onHead and box or attach.Size
                local col = (typeof(pc.Color) == "Color3" and pc.Color) or named[pc.Color] or defaultColor
                local mat = pc.Material and Enum.Material[pc.Material] or nil
                local part = Piece(folder, tag .. i, pc.S * unit, col, mat, pc.Ball)
                if pc.Cyl then part.Shape = Enum.PartType.Cylinder end
                if pc.Transparency then part.Transparency = pc.Transparency end
                local r = pc.R or Vector3.zero
                local base = onHead and mountOffset or CFrame.new()
                Weld(attach, part, base * CFrame.new(pc.P * unit) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z)))
            end
        end
    end
    local hidesHair = false
    for _, cat in ipairs(AvatarData.Categories) do
        if cat.Slot then
            local e = AvatarData.Find(cat.Id, look[cat.Id])
            if e and e.HidesHair then hidesHair = true end
        end
    end
    if not hidesHair then AddPieces("Hair", hair.Pieces, "Head", hairCol) end
    for _, cat in ipairs(AvatarData.Categories) do
        if cat.Slot then
            local e = AvatarData.Find(cat.Id, look[cat.Id])
            if e and e.Pieces then AddPieces(cat.Id, e.Pieces, cat.Attach, shirt) end
        end
    end
    folder.Parent = char
    char:SetAttribute("AvatarRev", (char:GetAttribute("AvatarRev") or 0) + 1) -- world gun re-fits to the new body
end

function AvatarService.Init(CombatServer: any)
    -- 2026-10-02 (owner): no character creator -- everyone plays as their own Roblox avatar, forced to R6 like Rivals
    -- (Game Settings > Avatar > R6) so gloves / guns / melees fit the same body. Nothing is dressed here any more: the
    -- world gear just re-fits once the avatar's appearance has loaded (AvatarRev).
    -- (2026-10-13: Studio's Avatar Settings lost the R6 option -> R6Spawner builds every character from the avatar's
    -- HumanoidDescription and bumps AvatarRev itself; CharacterAppearanceLoaded doesn't fire for those, this hook stays
    -- for the R6Spawner fallback, where Roblox spawns characters again.)
    local function Hook(player: Player)
        player.CharacterAppearanceLoaded:Connect(function(char)
            char:SetAttribute("AvatarRev", (char:GetAttribute("AvatarRev") or 0) + 1)
        end)
    end
    Players.PlayerAdded:Connect(Hook)
    for _, p in ipairs(Players:GetPlayers()) do Hook(p) end
    -- (old clients may still ask; nothing to edit now)
    Remotes.GetFunction("AvatarAction").OnServerInvoke = function(player: Player, action: any)
        if action == "Get" then return true end
        return false, "Characters use your Roblox avatar now."
    end
end

return AvatarService
