local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local AnchorPoints = workspace:FindFirstChild("AnchorPoints")
local ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage")
local CulledObjects = workspace:FindFirstChild("CulledObjects")
local NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects")

local Toolbar = plugin:CreateToolbar("Culling System")

local CullInButton = Toolbar:CreateButton("Cull In", "Cull in all buildings", "rbxassetid://6520368358")
local CullOutButton = Toolbar:CreateButton("Cull Out", "Cull out all buidlings", "rbxassetid://6520368730")
local SetAnchorPointButton = Toolbar:CreateButton("Generate Anchor Points", "Generate anchor points for currently culled in objects", "rbxassetid://6520369215")

local AnchorPointPrefix = "AnchorPoint_"
local AnchorPointPrefixLength = #AnchorPointPrefix

local function InitCheck()
    AnchorPoints = workspace:FindFirstChild("AnchorPoints")
    CulledObjects = workspace:FindFirstChild("CulledObjects")
    ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage")

    if not AnchorPoints then
        warn("AnchorPoints not found in workspace; Culling plugin failed to initialize")
        return
    end

    if not CulledObjects then
        warn("CulledObjects not found in workspace; Culling plugin failed to initialize")
        return
    end

    if not ModelStorage then
        warn("ModelStorage not found in ReplicatedStorage; Culling plugin failed to initialize")
        return
    end

    if not NonCulledObjects then
        warn("NonCulledObjects not found in ReplicatedStorage; Culling plugin failed to initialize")
        return
    end

    return true
end

local function SetAnchorPoint(Model: Model)
    local AnchorPoint = Instance.new("Part")
    AnchorPoint.Size = Vector3.new(.05, .05, .05)
    AnchorPoint.Transparency = 1
    AnchorPoint.Anchored = true
    AnchorPoint.Name = "AnchorPoint_".. Model.Name
    AnchorPoint.Parent = AnchorPoints

    local PrimaryPart = Model.PrimaryPart

    if not PrimaryPart then
        PrimaryPart = Instance.new("Part")
        PrimaryPart.Size = Vector3.new(.05, .05, .05)
        PrimaryPart.Transparency = 1
        PrimaryPart.Anchored = true
        PrimaryPart.CFrame = Model:GetModelCFrame() --// Yeah, I know it's deprectated :/
        PrimaryPart.Name = "PrimaryPart"
    end

    AnchorPoint.CFrame = PrimaryPart.CFrame
end

local function GetTrueName(Name: string)
    return string.sub(Name, AnchorPointPrefixLength + 1)
end

CullInButton.Click:Connect(function()
    if not InitCheck then
        return
    end

    for _, AnchorPoint in pairs (workspace:GetChildren()) do
        if string.sub(AnchorPoint.Name, 1, AnchorPointPrefixLength) == AnchorPointPrefix then
            local AssociatedModelName = GetTrueName(AnchorPoint.Name)

            local Model = ModelStorage:FindFirstChild(AssociatedModelName)

            if Model then
                local ModelToCull: Model --// For handy syntax autocomplete
                ModelToCull = Model:Clone()

                ModelToCull:SetPrimaryPartCFrame(AnchorPoint.CFrame)
            end
        end
    end
end)

CullOutButton.Click:Connect(function()
    if not InitCheck then
        return
    end

    local AllCulledObjects = CulledObjects:GetChildren()

    for _, Model in pairs (AllCulledObjects) do
        local AlreadyInModelStorage = ModelStorage:FindFirstChild(Model.Name)

        if AlreadyInModelStorage then
            Model:Destroy()
        else
            Model.Parent = ModelStorage
        end
    end
end)

SetAnchorPointButton.Click:Connect(function()
    if not InitCheck then
        return
    end

    local SelectedObjects = Selection:Get()

    for _, Model in pairs (SelectedObjects) do
        if Model:IsA("Model") then
            SetAnchorPoint(Model)
        else
            warn("Unable to attach an anchor point to a non-model")
        end
    end
end)