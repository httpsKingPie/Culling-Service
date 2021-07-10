--// Handles button code, primarily

--// Don't forget to put Gui as a child of the plugin folder/sibling of the Main script
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Folder definitions
local AnchorPoints = workspace:FindFirstChild("AnchorPoints") --// Folder holding all anchor points
local ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage") --// Stores all models to be culled
local CulledObjects = workspace:FindFirstChild("CulledObjects") --// Stores all current culled objects
local NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects") --// Not used in the context of this plugin, but basically used for ranges

--// GUI definitions
local PluginFolder = script.Parent

local CullingGui = PluginFolder:WaitForChild("CullingGui")

local BackgroundFrame:Frame = CullingGui:WaitForChild("BackgroundFrame")
local ScrollingFrame: ScrollingFrame = BackgroundFrame:WaitForChild("ScrollingFrame")
local Output: TextLabel = BackgroundFrame:WaitForChild("Output")
local RegionSizeInput: TextBox = BackgroundFrame:WaitForChild("RegionSizeInput")
local RegionSizeTitle: TextLabel = BackgroundFrame:WaitForChild("RegionSizeTitle")

local UIListLayout: UIListLayout = ScrollingFrame:WaitForChild("UIListLayout")
local ButtonTemplate: TextButton = ScrollingFrame:WaitForChild("ButtonTemplate")

local HintFrame: Frame = CullingGui:WaitForChild("HintFrame")
local HintLabel: TextLabel = HintFrame:WaitForChild("HintLabel")

--// Basic plugin settings
--// Normally would use modules, but not sure how well that works with plugins :/

--// Initial plugin set up
local Toolbar = plugin:CreateToolbar("Culling System")
local OpenGUIButton = Toolbar:CreateButton("Toggle GUI", "Control the Culling System", "rbxassetid://6520368338")

local Culling = require(script:WaitForChild("Culling"))
local InternalSettings = require(script:WaitForChild("InternalSettings"))
local Settings = require(script:WaitForChild("Settings"))
local UIVisuals = require(script:WaitForChild("UIVisuals"))

local function InitCheck()
    AnchorPoints = workspace:FindFirstChild("AnchorPoints")
    CulledObjects = workspace:FindFirstChild("CulledObjects")
    ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage")
    NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects")

    if not AnchorPoints then
        Culling.OutputText("AnchorPoints (folder) not found in workspace; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not CulledObjects then
        Culling.OutputText("CulledObjects (folder) not found in workspace; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not ModelStorage then
        Culling.OutputText("ModelStorage (folder) not found in ReplicatedStorage; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not NonCulledObjects then
        Culling.OutputText("NonCulledObjects (folder) not found in ReplicatedStorage; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    return true
end

local function SetHint(HintText: string)
    HintLabel.Text = HintText
    HintFrame.Visible = true
end

local function ClearHint(HintText: string)
    wait(.05)

    --// This means that the text was changed (i.e. another hint is being displayed) so we don't clear
    if HintText ~= HintLabel.Text then
        return
    end

    HintFrame.Visible = false
end

local function GenerateButtons()
    UIVisuals:ClearGuiObjectChildren({ScrollingFrame})

    for _, ButtonData in ipairs (InternalSettings["Buttons"]) do
        local Button = ButtonTemplate:Clone()

        Button.Name = ButtonData["Text"]
        Button.Text = ButtonData["Text"]

        Button.Parent = ScrollingFrame
        Button.Visible = true

        UIVisuals:BindMouseButton1Click({Button}, ButtonData["Bound Function"])
        UIVisuals:BindMouseEnter({Button}, SetHint, ButtonData["Hint Text"])
        UIVisuals:BindMouseLeave({Button}, ClearHint, ButtonData["Hint Text"])
    end

    UIVisuals:ResizeScrollingFrameCanvasYSize(ScrollingFrame, UIListLayout.AbsoluteContentSize.Y, InternalSettings["Buffer Size"])

    RegionSizeInput.Visible = true
    RegionSizeTitle.Visible = true
end

local function GenerateInitializationButton()
    local Button = ButtonTemplate:Clone()

    Button.Text = "Initialize plugin"
    Button.Parent = ScrollingFrame
    Button.Visible = true

    UIVisuals:BindMouseButton1Click({Button}, function()
        if not InitCheck then
            warn("Errors initializing - check output box in Culling Plugin")
            return
        end

        GenerateButtons()
    end)
end

local function HandleRegionSizeChange()
    local function SetPlaceholderTextToCurrentSize()
        RegionSizeInput.PlaceholderText = "Current size: ".. tostring(Settings["Culling Region Size"])
    end
    
    SetPlaceholderTextToCurrentSize()

    RegionSizeInput.FocusLost:Connect(function()
        if not tonumber(RegionSizeInput.Text) then
            RegionSizeInput.Text = "Please enter a number!"
            wait(1)
            RegionSizeInput.Text = ""

            return
        end

        Settings["Culling Region Size"] = tonumber(RegionSizeInput.Text)

        RegionSizeInput.PlaceholderText = "Current size: ".. tostring(Settings["Culling Region Size"])
        RegionSizeInput.Text = ""
    end)
end

local function Initialize()
    UIVisuals:ConvertScaleSizeToOffset(ButtonTemplate)

    ButtonTemplate.Visible = false
    ButtonTemplate.Parent = PluginFolder

    RegionSizeTitle.Visible = false
    RegionSizeInput.Visible = false

    --// Generate button to manually initialize
    GenerateInitializationButton()
    HandleRegionSizeChange()

    Culling.OutputText("")
    CullingGui.Enabled = true

    --// Clicking Plugin Button
    OpenGUIButton.Click:Connect(function()
        if CullingGui.Parent == CoreGui then
            CullingGui.Parent = PluginFolder
        else
            CullingGui.Parent = CoreGui
        end
    end)

    --// Delete the old culling gui if it is still there (i.e. updating and forgetting to close it)
    local OldCullingGui = CoreGui:FindFirstChild("CullingGui")

    if OldCullingGui then
        OldCullingGui:Destroy()
    end
end

Initialize()