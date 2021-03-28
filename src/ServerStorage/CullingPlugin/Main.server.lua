local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CoreGUI = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

--// Folder definitions
local AnchorPoints = workspace:FindFirstChild("AnchorPoints") --// Folder holding all anchor points
local ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage") --// Stores all models to be culled
local CulledObjects = workspace:FindFirstChild("CulledObjects") --// Stores all current culled objects
local NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects") --// Not used in the context of this plugin, but basically used for ranges

--// GUI definitions
local PluginFolder = script.Parent

local CullingGui = PluginFolder:WaitForChild("CullingGui")

local BackgroundFrame = CullingGui:WaitForChild("BackgroundFrame")
local ContentFrame = BackgroundFrame:WaitForChild("ContentFrame")
local AddToModelStorageButton = ContentFrame:WaitForChild("AddToModelStorageButton")
local CullInButton = ContentFrame:WaitForChild("CullInButton")
local CullOutButton = ContentFrame:WaitForChild("CullOutButton")
local Output = ContentFrame:WaitForChild("Output")
local SetAnchorPointButton = ContentFrame:WaitForChild("SetAnchorPointButton")

local HintFrame = CullingGui:WaitForChild("HintFrame")
local HintLabel = HintFrame:WaitForChild("HintLabel")

--// Basic plugin settings
--// Normally would use modules, but not sure how well that works with plugins :/
local AnchorPointPrefix = "AnchorPoint_"
local AnchorPointPrefixLength = #AnchorPointPrefix
local HintText = {
    ["AddToModelStorageButton"] = "This will add the model to the ModelStorage folder, provided the model does not already exist.  Very useful to use after setting anchor points",
    ["CullInButton"] = "This will cull in all objects located in ReplicatedStorage.ModelStorage to their respective anchor points.  Cloned models will be found in Workspace.CulledObjects.  This is useful for previewing the current state of the map",
    ["CullOutButton"] = "This will cull out all (i.e. destroy in this context) objects located in Workspace.CulledObjects",
    ["SetAnchorPointButton"] = "This will create an anchor point (if one is not created already) for all models currently selected"
}

--// Initial plugin set up
local Toolbar = plugin:CreateToolbar("Culling System")
local OpenGUIButton = Toolbar:CreateButton("Open GUI", "Open the GUI to Control the Culling System", "rbxassetid://23996858")

--// Local functions
local function OutputText(Text: string)
    Output.Text = Text
end

local function InitCheck()
    AnchorPoints = workspace:FindFirstChild("AnchorPoints")
    CulledObjects = workspace:FindFirstChild("CulledObjects")
    ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage")
    NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects")

    if not AnchorPoints then
        OutputText("AnchorPoints (folder) not found in workspace; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not CulledObjects then
        OutputText("CulledObjects (folder) not found in workspace; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not ModelStorage then
        OutputText("ModelStorage (folder) not found in ReplicatedStorage; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not NonCulledObjects then
        OutputText("NonCulledObjects (folder) not found in ReplicatedStorage; Culling plugin failed to initialize.  Please fix this error and try again.")
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

local function SetHint(ButtonName: string)
    if not HintText[ButtonName] then
        return
    end

    HintLabel.Text = HintText[ButtonName]
    HintFrame.Visible = true
end

local function HintCheck()
    if not HintFrame.Visible == false then
        return false
    end

    return true
end


--// Clicking Plugin Button
OpenGUIButton.Click:Connect(function()
    if CullingGui.Parent == CoreGUI then
        CullingGui.Parent = PluginFolder
    else
        CullingGui.Parent = CoreGUI
    end
end)

--// GUI Button Clicks
AddToModelStorageButton.MouseButton1Click:Connect(function()
    if not InitCheck then
        return
    end

    local SelectedObjects = Selection:Get()

    local ErrorString = ""

    for _, Model in pairs (SelectedObjects) do
        if Model:IsA("Model") then
            local ModelAlreadyExists = ModelStorage:FindFirstChild(Model.Name)

            if not ModelAlreadyExists then
                local ModelClone = Model:Clone()
                ModelClone.Parent = ModelStorage
            end
        else
            ErrorString = ErrorString.. Model.Name.. "; "
        end
    end

    if ErrorString == "" then
        OutputText("Success - non-duplicated models were cloned and moved into ModelStorage.")
    else
        OutputText("Partial success - some non-models were selected and the following instances were not moved into ModelStorage: ".. ErrorString)
    end
end)

CullInButton.MouseButton1Click:Connect(function()
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

CullOutButton.MouseButton1Click:Connect(function()
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

SetAnchorPointButton.MouseButton1Click:Connect(function()
    if not InitCheck then
        return
    end

    local SelectedObjects = Selection:Get()

    local ErrorString = ""

    for _, Model in pairs (SelectedObjects) do
        if Model:IsA("Model") then
            SetAnchorPoint(Model)
        else
            ErrorString = ErrorString.. Model.Name.. "; "
        end
    end

    if ErrorString == "" then
        OutputText("Success - anchor points added for all selected models.  They can be found in Workspace.AnchorPoints")
    else
        OutputText("Partial success - some non-models were selected and anchor points were not created for the following instances: ".. ErrorString)
    end
end)

--// Hint hovers (in)
AddToModelStorageButton.MouseEnter:Connect(function()
    if HintCheck then
        SetHint(AddToModelStorageButton.Name)
    end
end)

CullInButton.MouseEnter:Connect(function()
    if HintCheck then
        SetHint(CullInButton.Name)
    end
end)

CullOutButton.MouseEnter:Connect(function()
    if HintCheck then
        SetHint(CullOutButton.Name)
    end
end)

SetAnchorPointButton.MouseEnter:Connect(function()
    if HintCheck then
        SetHint(SetAnchorPointButton.Name)
    end
end)

--// Hint hovers (out)
AddToModelStorageButton.MouseLeave:Connect(function()
    HintFrame.Visible = false
end)

CullInButton.MouseLeave:Connect(function()
    HintFrame.Visible = false
end)

CullOutButton.MouseLeave:Connect(function()
    HintFrame.Visible = false
end)

SetAnchorPointButton.MouseLeave:Connect(function()
    HintFrame.Visible = false
end)