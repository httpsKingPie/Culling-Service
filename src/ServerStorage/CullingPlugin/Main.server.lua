--// Don't forget to put Gui as a child of the plugin folder/sibling of the Main script

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CoreGui = game:GetService("CoreGui")
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

local HintText = {
    ["AddToModelStorageButton"] = "This will add the model to the ModelStorage folder, provided the model does not already exist.  Very useful to use after setting anchor points",
    ["CullInButton"] = "This will cull in all objects located in ReplicatedStorage.ModelStorage to their respective anchor points.  Cloned models will be found in Workspace.CulledObjects.  This is useful for previewing the current state of the map",
    ["CullOutButton"] = "This will cull out all (i.e. destroy in this context) objects located in Workspace.CulledObjects",
    ["SetAnchorPointButton"] = "This will create an anchor point (if one is not created already) for all models currently selected"
}

--// Initial plugin set up
local Toolbar = plugin:CreateToolbar("Culling System")
local OpenGUIButton = Toolbar:CreateButton("Toggle GUI", "Control the Culling System", "rbxassetid://6520368338")

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

local function CheckForPrimaryPart(Model: Model)
    if Model.PrimaryPart then
        return
    end

    local Primary_Part = Instance.new("Part")
    Primary_Part.Anchored = true
    Primary_Part.Name = "ModelPrimaryPart"
    Primary_Part.Size = Vector3.new(.1, .1, .1)
    Primary_Part.CFrame = Model:GetModelCFrame() --// Yes, it's deprecated - yes this is the best thing to use in this case, because it puts it exactly where the node is
    Primary_Part.Parent = Model
    Model.PrimaryPart = Primary_Part
end

local function SetAnchorPoint(Model: Model)
    local AnchorPoint = Instance.new("Part")
    AnchorPoint.Size = Vector3.new(.05, .05, .05)
    AnchorPoint.Transparency = 1
    AnchorPoint.Anchored = true
    AnchorPoint.Name = Model.Name
    AnchorPoint.Parent = AnchorPoints

    CheckForPrimaryPart(Model)

    AnchorPoint.CFrame = Model.PrimaryPart.CFrame
end

--// Clicking Plugin Button
OpenGUIButton.Click:Connect(function()
    if CullingGui.Parent == CoreGui then
        CullingGui.Parent = PluginFolder
    else
        CullingGui.Parent = CoreGui
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
                
                CheckForPrimaryPart(ModelClone)
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

    ChangeHistoryService:SetWaypoint("Added models to ModelStorage")
end)

CullInButton.MouseButton1Click:Connect(function()
    if not InitCheck then
        return
    end

    for _, AnchorPoint in pairs (AnchorPoints:GetChildren()) do
        local AssociatedModelName = AnchorPoint.Name

        local Model = ModelStorage:FindFirstChild(AssociatedModelName)

        if Model then
            CheckForPrimaryPart(Model)
            
            local ModelToCull: Model = Model:Clone()--// For handy syntax autocomplete

            ModelToCull:SetPrimaryPartCFrame(AnchorPoint.CFrame)
            ModelToCull.Parent = CulledObjects
        end
    end

    ChangeHistoryService:SetWaypoint("Culled in all objects that had models in ModelStorage")
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

    ChangeHistoryService:SetWaypoint("Culled out all objects that had models in ModelStorage")
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

    ChangeHistoryService:SetWaypoint("Added anchor points")
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

--// Start up code in case I forgot to enable or the old one is still there
CullingGui.Enabled = true

local OldCullingGui = CoreGui:FindFirstChild("CullingGui")

if OldCullingGui then
    OldCullingGui:Destroy()
    print("Silly goose - don't forget to untoggle the gui when updating it!")
end