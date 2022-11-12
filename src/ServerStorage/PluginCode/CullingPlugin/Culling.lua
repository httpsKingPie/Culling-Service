--// Handles actually culling

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

--// Folder definitions
local AnchorPoints = workspace:FindFirstChild("AnchorPoints") --// Folder holding all anchor points
local ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage") --// Stores all models to be culled
local CulledObjects = workspace:FindFirstChild("CulledObjects") --// Stores all current culled objects
local NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects") --// Not used in the context of this plugin, but basically used for ranges

local VisualizedRegions = workspace:FindFirstChild("VisualizedRegions") --// Non-required folder - this one will be created if it isn't there

local MainScript = script.Parent
local PluginFolder = MainScript.Parent

local CullingGui = PluginFolder:WaitForChild("CullingGui")

local BackgroundFrame:Frame = CullingGui:WaitForChild("BackgroundFrame")
local Output:TextLabel = BackgroundFrame:WaitForChild("Output")

local Settings = require(MainScript:WaitForChild("Settings"))

local module = {
    ["Total Visualized Parts"] = 0
}

local function CheckInsideRegion(PositionToCheck, BoundingBoxCFrame, BoundingBoxSize) --// Credits https://devforum.roblox.com/t/how-do-i-get-a-player-from-a-zone/464473/7
	local BBVector3 = BoundingBoxCFrame:PointToObjectSpace(PositionToCheck)
	return (math.abs(BBVector3.X) <= BoundingBoxSize.X / 2)
		and (math.abs(BBVector3.Y) <= BoundingBoxSize.Y / 2)
		and (math.abs(BBVector3.Z) <= BoundingBoxSize.Z / 2)
end

local function GetBoundingBox(Model: Model) --// Credits to XAXA (this function is soooooo useful) (https://devforum.roblox.com/t/how-does-roblox-calculate-the-bounding-boxes-on-models-getextentssize/216581/8)
    local ModelDescendants = Model:GetDescendants()

	local Orientation = CFrame.new()
	
	local abs = math.abs
	local Infinity = math.huge

	local MinimumX, MinimumY, MinimumZ = Infinity, Infinity, Infinity
	local MaximumX, MaximumY, MaximumZ = -Infinity, -Infinity, -Infinity

	for _, BasePart in pairs(ModelDescendants) do
		if BasePart:IsA("BasePart") and not BasePart:IsA("Terrain") then
			local BasePartCFrame = BasePart.CFrame
			BasePartCFrame = Orientation:ToObjectSpace(BasePartCFrame)

			local Size = BasePart.Size
			local SizeX, SizeY, SizeZ = Size.X, Size.Y, Size.Z

			local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = BasePartCFrame:GetComponents()

			local WorldSpaceX = 0.5 * (abs(R00) * SizeX + abs(R01) * SizeY + abs(R02) * SizeZ)
			local WorldSpaceY = 0.5 * (abs(R10) * SizeX + abs(R11) * SizeY + abs(R12) * SizeZ)
			local WorldSpaceZ = 0.5 * (abs(R20) * SizeX + abs(R21) * SizeY + abs(R22) * SizeZ)

			if MinimumX > X - WorldSpaceX then
				MinimumX = X - WorldSpaceX
			end

			if MinimumY > Y - WorldSpaceY then
				MinimumY = Y - WorldSpaceY
			end

			if MinimumZ > Z - WorldSpaceZ then
				MinimumZ = Z - WorldSpaceZ
			end

			if MaximumX < X + WorldSpaceX then
				MaximumX = X + WorldSpaceX
			end

			if MaximumY < Y + WorldSpaceY then
				MaximumY = Y + WorldSpaceY
			end

			if MaximumZ < Z + WorldSpaceZ then
				MaximumZ = Z + WorldSpaceZ
			end
		end
	end

	local ObjectMinimum, ObjectMaximum = Vector3.new(MinimumX, MinimumY, MinimumZ), Vector3.new(MaximumX, MaximumY, MaximumZ)
	local ObjectMiddle = (ObjectMaximum+ObjectMinimum)/2
	local WorldCFrame = Orientation - Orientation.p + Orientation:PointToWorldSpace(ObjectMiddle)
	local Size = (ObjectMaximum-ObjectMinimum)

	return WorldCFrame, Size
end

local function CheckForPrimaryPart(Model: Model)
    if Model.PrimaryPart then
        return
    end

    local Primary_Part = Instance.new("Part")
    Primary_Part.Anchored = true
    Primary_Part.Name = "ModelPrimaryPart"
    Primary_Part.Transparency = 1
    Primary_Part.Size = Vector3.new(.1, .1, .1)
    Primary_Part.CFrame = Model:GetModelCFrame() --// Yes, it's deprecated - yes this is the best thing to use in this case, because it puts it exactly where the node is
    Primary_Part.Parent = Model
    Model.PrimaryPart = Primary_Part
end

local function SetAnchorPoint(Model: Model)
    local AnchorPoint = Instance.new("Part")
    AnchorPoint.Size = Vector3.new(.05, .05, .05)
    AnchorPoint.Transparency = 1
    AnchorPoint.CanTouch = false
    AnchorPoint.Anchored = true
    AnchorPoint.Name = Model.Name
    AnchorPoint.Parent = AnchorPoints

    CheckForPrimaryPart(Model)

    AnchorPoint.CFrame = Model.PrimaryPart.CFrame
end

function module.OutputText(TextToOutput: string)
    Output.Text = TextToOutput
end

function module.AddSelectionToModelStorage()
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
        module.OutputText("Success - non-duplicated models were cloned and moved into ModelStorage.")
    else
        module.OutputText("Partial success - some non-models were selected and the following instances were not moved into ModelStorage: ".. ErrorString)
    end

    ChangeHistoryService:SetWaypoint("Added models to ModelStorage")
end

function module.CullInEntireMap()
    for _, AnchorPoint in pairs (AnchorPoints:GetChildren()) do
        local AssociatedModelName = AnchorPoint.Name

        local Model = ModelStorage:FindFirstChild(AssociatedModelName)

        if Model then
            CheckForPrimaryPart(Model)
            
            local ModelToCull: Model = Model:Clone()--// For handy syntax autocomplete

            ModelToCull:PivotTo(AnchorPoint.CFrame)
            ModelToCull.Parent = CulledObjects
        end
    end

    ChangeHistoryService:SetWaypoint("Culled in all objects that had models in ModelStorage")
end

function module.CullOutEntireMap()
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
end

function module.CullInSelection()
    local SelectedObjects = Selection:Get()

    local ErrorString = ""

    for _, AnchorPoint in pairs (SelectedObjects) do
        if AnchorPoint.Parent == AnchorPoints then
            local Model = ModelStorage:FindFirstChild(AnchorPoint.Name)

            if Model then
                CheckForPrimaryPart(Model)

                local ModelToCull: Model = Model:Clone()

                ModelToCull:PivotTo(AnchorPoint.CFrame)
                ModelToCull.Parent = CulledObjects
            end
        else
            ErrorString = ErrorString.. AnchorPoint.Name.. ";"
        end
    end

    if ErrorString == "" then
        module.OutputText("Success - culled in all objects for anchor points")
    else
        module.OutputText("Partial success - some non-anchor points were selected or models were not found for the following instances: ".. ErrorString)
    end

    ChangeHistoryService:SetWaypoint("Culled in for selection")
end

function module.CullOutSelection()
    local SelectedObjects = Selection:Get()

    for _, Model in pairs (SelectedObjects) do
        local AlreadyInModelStorage = ModelStorage:FindFirstChild(Model.Name)

        if AlreadyInModelStorage then
            Model:Destroy()
        else
            Model.Parent = ModelStorage
        end
    end

    ChangeHistoryService:SetWaypoint("Culled out all objects that had models in ModelStorage")
end

function module.GenerateAnchorPointsForSelection()
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
        module.OutputText("Success - anchor points added for all selected models.  They can be found in Workspace.AnchorPoints")
    else
        module.OutputText("Partial success - some non-models were selected and anchor points were not created for the following instances: ".. ErrorString)
    end

    ChangeHistoryService:SetWaypoint("Added anchor points for selection")
end

function module.AutoMode()
    module.GenerateAnchorPointsForSelection()
    module.AddSelectionToModelStorage()
    module.CullOutSelection()
end

function module.VisualizeInternalRegions()
    local CurrentXIteration = 0
    local CurrentYIteration = 0
    local CurrentZIteration = 0

    local function QuickPart(PartSize: Vector3, PartCFrame: CFrame, OptionalPosition: Vector3)
        local QP = Instance.new("Part")
        QP.Anchored = true
        QP.Transparency = 1
        QP.Color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
        QP.Size = PartSize
        QP.CFrame = PartCFrame
        
        module["Total Visualized Parts"] = module["Total Visualized Parts"] + 1
        QP.Name = "[".. tostring(CurrentXIteration).. "][" .. tostring(CurrentYIteration).. "][".. tostring(CurrentZIteration).."]"
        
        QP.Parent = VisualizedRegions
        
        if OptionalPosition then
            QP.Position = OptionalPosition
        end
        
        return QP
    end

    if not VisualizedRegions then
        VisualizedRegions = Instance.new("Folder")
        VisualizedRegions.Name = "VisualizedRegions"
        VisualizedRegions.Parent = workspace
    else
        for _, OldRegion in pairs (VisualizedRegions:GetChildren()) do
            OldRegion:Destroy()
        end
    end

    local BoundingBoxCFrame, BoundingBoxSize = GetBoundingBox(workspace)
    
    local BoundingBox = QuickPart(BoundingBoxSize, BoundingBoxCFrame)
    local BBPosition = BoundingBox.Position
    local BBSize = BoundingBox.Size
    
    local EdgePosition = BoundingBoxCFrame.Position - Vector3.new(((BBSize.X)/2) - Settings["Culling Region Size"]/2, (BBSize.Y)/2 - Settings["Culling Region Size"]/2, (BBSize.Z)/2 - Settings["Culling Region Size"]/2)
    
    local CheckedAllX = false
    local CheckedAllY = false
    local CheckedAllZ = false
    
    local MovesX
    local MovesZ
    
    local function ParseAlongX()
        local NewPositionX
        
        local function FinalParseX()
            QuickPart(Vector3.new(Settings["Culling Region Size"], Settings["Culling Region Size"], Settings["Culling Region Size"]), BoundingBoxCFrame, NewPositionX)
            CheckedAllX = true --// Ends the loop, for now
            CurrentXIteration = 0
        end
        
        while not CheckedAllX do
            NewPositionX = EdgePosition + Vector3.new(Settings["Culling Region Size"] * CurrentXIteration, Settings["Culling Region Size"] * CurrentYIteration, Settings["Culling Region Size"] * CurrentZIteration)
    
            QuickPart(Vector3.new(Settings["Culling Region Size"], Settings["Culling Region Size"], Settings["Culling Region Size"]), BoundingBoxCFrame, NewPositionX)
    
            CurrentXIteration = CurrentXIteration + 1 --// Also representative of the amount of times parsed
            
            if not MovesX then
                --// Assign the amount of times that this should move (since it moves along a box, we don't need to calculate every time)
                
                if not CheckInsideRegion(NewPositionX, BoundingBoxCFrame, BoundingBoxSize) then
                    MovesX = CurrentXIteration
                    FinalParseX()
                end
            else
                if MovesX <= CurrentXIteration then
                    FinalParseX()
                end
            end
        end
    end
    
    local function OrientAlongZ()
        while not CheckedAllZ do
            --// Parse along the x dimension
            ParseAlongX()
    
            --// Align to a new Z
            CurrentZIteration = CurrentZIteration + 1
            local NewPositionZ = EdgePosition + Vector3.new(0, 0, Settings["Culling Region Size"] * CurrentZIteration)
    
            CheckedAllX = false --// Parse along x for the new z variable
            
            if not MovesZ then
                if not CheckInsideRegion(NewPositionZ, BoundingBoxCFrame, BoundingBoxSize) then
                    MovesZ = CurrentZIteration
                    
                    ParseAlongX()
                    
                    CheckedAllZ = true
                    CurrentZIteration = 0
                end
            else
                if MovesZ <= CurrentZIteration then
                    ParseAlongX()
                    
                    CheckedAllZ = true
                    CurrentZIteration = 0
                end
            end
        end
    end
    
    local function GenerateBoxRegions()
        --// Parse along the y dimension
        while not CheckedAllY do
            OrientAlongZ()
            
            CurrentYIteration = CurrentYIteration + 1
            local NewPositionY = EdgePosition + Vector3.new(0, Settings["Culling Region Size"] * CurrentYIteration, 0)
            
            CheckedAllX = false
            CheckedAllZ = false
            
            if not CheckInsideRegion(NewPositionY, BoundingBoxCFrame, BoundingBoxSize) then
                CheckedAllY = true
                
                OrientAlongZ()
                
                CurrentYIteration = 0
            end
        end

        module.OutputText(module["Total Visualized Parts"].. " regions generated; Region size is ".. tostring(Settings["Culling Region Size"]) .."x".. tostring(Settings["Culling Region Size"]))
    end

    GenerateBoxRegions()
end

return module