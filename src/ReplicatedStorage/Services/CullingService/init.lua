--[[
    This runs exclusively on the client

    Run it with CullingService:Initialize()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UtilityModules = ReplicatedStorage:WaitForChild("UtilityModules")
local PieAPI = require(UtilityModules:WaitForChild("PieAPI"))

local ModelStorage = ReplicatedStorage:WaitForChild("ModelStorage")
local NonCulledObjects = ReplicatedStorage:WaitForChild("NonCulledObjects")

local AnchorPoints = workspace:WaitForChild("AnchorPoints")
local CulledObjects = workspace:WaitForChild("CulledObjects")

local Settings = require(script.Settings)

local LocalPlayer = Players.LocalPlayer

local Initialized = false

--[[
    Demo version will check the whole map, broadly searching every check period for whatever is within streaming distance
    Final version should incorporate smarter check methods (ex: take note of where the player is, like what "zone" the player is, and then only search within that zone for better performance)
]]

local module = {
    ["Paused"] = false, --// Whether Culling is paused or not (defaults to false, since culling may want to be done manually at the beginning for cutscnees, etc.)
    
    ["AnchorPointModelCorrelations"] = {}, --// A dictionary of [AnchorPoint] = Model
    ["CurrentCulledInModels"] = {}, --// Numeric table holding all currently culled in models (indexes correlated to CurrentCulledInRanges)
    ["CurrentCulledInRanges"] = {}, --// Numeric table holding all currently culled in ranges (indexes correlated to CurrentCulledInModels)
    ["NonCulledObjectCorrelations"] = {}, --// A dictionary of [Model] = Folder of Other Ranges

    ["Regions"] = {},
}

--// Region shaping
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

--[[
    Process is to do this with an actual part, and then remove the part and do this invisible with just numbers

    Don't need to actually make this super complex (with division), just loop and cut a sliver of it
    Imagine a lawnmower.  Imagine a lawn that is the shape of a cube.  You mow it going down until you hit the end.  You do the same thing over and over again.  Since it's 3D space, go up once you finish each bit.  Yay for loops.
]]
local function DivideBoundingBox()

end

local function GenerateCullingRegions()
    local Part = Instance.new("Part")

    local PartCFrame, PartSize = GetBoundingBox(workspace)

    Part.CFrame = PartCFrame
    Part.Size = PartSize

    Part.Parent = workspace
end

--// Return functions

--[[
    For a given anchor point, returns the Model, NonCulledObjects for that model, and table containing the current culled in ranges for that point

    * Only use after a model has been fully processed with ProcessCullIn
]]

local function ReturnModelValues(AnchorPoint: BasePart)
    local Model: Model = module["AnchorPointModelCorrelations"][AnchorPoint]
    local ModelNonCulledObjects: Folder = module["NonCulledObjectCorrelations"][Model]
    local Index: number = table.find(module["CurrentCulledInModels"], Model)
    local RangeTable: table = module["CurrentCulledInRanges"][Index]

    return Model, ModelNonCulledObjects, RangeTable
end

--// Returns all anchor points in range and their distance from the origin position
local function GetAnchorPointsInRange(OriginPosition: Vector3, SearchRadius: number)
    local AllAnchorPoints = AnchorPoints:GetChildren()

    local AnchorPointsInRange = {}
    local AnchorPointDistances = {}

    for _, AnchorPoint in pairs (AllAnchorPoints) do
        local Distance = (OriginPosition - AnchorPoint.Position).Magnitude

        if Distance <= SearchRadius then
            table.insert(AnchorPointsInRange, AnchorPoint)
            table.insert(AnchorPointDistances, Distance)
        end
    end

    return AnchorPointsInRange, AnchorPointDistances
end

--// End return functions

--// Check functions

--// Checks if a model has a PrimaryPart (i.e. is ready to be culled)
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

--// Checks if a model is already culled in for a given anchor point
local function CheckIfModelIsAlreadyCulledIn(AnchorPoint: BasePart)
    if module["AnchorPointModelCorrelations"][AnchorPoint] then
        return true
    end

    return false
end

--// Returns whether a model is already culled in for a given model
local function CheckIfAlreadyCulledIn(Model: Model)
    if Model.Parent == CulledObjects then
        return true
    end

    return false
end

--// Checks if a range is already culled in
local function CheckIfRangeIsCulledIn(AnchorPoint: BasePart, RangeName: string)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    if table.find(RangeTable, RangeName) then
        return true
    end

    return false
end

--// End check functions

--// Returns whether something is in distance
local function InDistance(ComaprisonNumber, MaximumBound)
    if ComaprisonNumber <= MaximumBound then
        return true
    end

    return false
end

--[[
    Tool functions:

    These are the tools of the CullingService.  Based on what the brain functions determine is the best choice, one of these functions are used to make it actually happen

    CullIn: Used when Culling something in for the first thing
    Cullout: Used when culling out an object completely
    CullUpdate: Used when updating ranges
]]

--// Used when Culling something in for the first thing
local function CullIn(AnchorPoint: BasePart)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    local AlreadyCreated = CheckIfAlreadyCulledIn(Model)

    if AlreadyCreated then --// For models that have already been streamed in once and are being rest
        print("Already created")
        for _, Folder in pairs(ModelNonCulledObjects:GetChildren()) do
            if table.find(RangeTable, Folder.Name) then
                Folder.Parent = Model
            end
        end
    else
        print("Not already created")
        Model:SetPrimaryPartCFrame(AnchorPoint.CFrame)

        for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into the "Short", "Medium", and "Long" sub-folders
            if not table.find(RangeTable, Folder.Name) then --// Current range is not being culled in
                Folder.Parent = ModelNonCulledObjects
            end
        end

        Model.Parent = CulledObjects
    end
end

--// Used when culling out an object completely
local function CullOut(Model: Model)
    if not Model:IsDescendantOf(workspace) then
        warn("Attempted to cull out a model that does not exist in workspace")
        return
    end

    Model:Destroy()
end

--// Used when updating ranges
local function CullUpdate(AnchorPoint: BasePart)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    for _, Folder in pairs (ModelNonCulledObjects:GetChildren()) do
        if table.find(RangeTable, Folder.Name) then
            Folder.Parent = Model
        end
    end

    for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into the "Short", "Medium", and "Long" sub-folders
        if not table.find(RangeTable, Folder.Name) then --// Current range is not being culled in
            Folder.Parent = ModelNonCulledObjects
        end
    end
end

--// End tool functions

--[[
    Brain functions:

    These are the brains of the CullingService, determing which function (CullIn, CullOut, or CullUpdate) is best
]]

--// Does the backend work short of actually streaming the change
local function ProcessCullIn(DistanceFolder: Folder, AnchorPoint: BasePart) 
    local ReferenceModel = DistanceFolder.Parent

    CheckForPrimaryPart(ReferenceModel) --// Ensures that there is a PrimaryPart so that appropirate changes can be made (if one doesn't exist, one is created)

    local ModelAlreadyCulledIn = CheckIfModelIsAlreadyCulledIn(AnchorPoint)

    local Index

    if ModelAlreadyCulledIn then --// Means we are updating ranges
        local Model =  module["AnchorPointModelCorrelations"][AnchorPoint]

        Index = table.find(module["CurrentCulledInModels"], Model) --// Gets the index of the model so that we can appropriate access ranges
        local RangeTable = module["CurrentCulledInRanges"][Index] --// Gets the currently streamed in ranges

        table.insert(RangeTable, DistanceFolder.Name) --// Adds the range we are processing

        CullUpdate(AnchorPoint) --// Determine whether to cull out or cull in
    else --// Means we are loading in a model from scratch
        local Model = ReferenceModel:Clone()

        --// Set up Anchor Point Model Correlations
        module["AnchorPointModelCorrelations"][AnchorPoint] = Model

        --// Set up Non Culled Object Correlations
        local NonCulledObjectStorageFolder = Instance.new("Folder")
        NonCulledObjectStorageFolder.Name = Model.Name
        NonCulledObjectStorageFolder.Parent = NonCulledObjects
        
        module["NonCulledObjectCorrelations"][Model] = NonCulledObjectStorageFolder

        --// Handling CulledIn Models
        table.insert(module["CurrentCulledInModels"], Model) --/ Adds the model to the CurrentCuleldInModels for tracking/association purposes
        Index = table.find(module["CurrentCulledInModels"], Model)

        --// Handling CulledInRanges
        local RangeTable = {}
        table.insert(RangeTable, DistanceFolder.Name) --// Adds the range we are processing

        module["CurrentCulledInRanges"][Index] = RangeTable --// Adds the current ranges to CurrentCulledInRanges

        CullIn(AnchorPoint) --// Determine whether to cull out or cull in
    end
end

--// Culls out specific ranges, and forwards any models needing to completely culled out to CompleteCullOut
local function ProcessCullOut(DistanceFolder: Folder, AnchorPoint: BasePart)
    --// Don't need to check if it is ready to be culled, since it will be already in workspace
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    local RangesCulledIn = #RangeTable --// If this is 1, then that means removing this range will result in removing the whole model.  This should never be 0

    if RangesCulledIn > 1 then --// Means we are updating the model (culling out a range), not culling out the whole model
        local RangeIndex = table.find(RangeTable, DistanceFolder.Name)
        table.remove(RangeTable, RangeIndex)
        
        CullUpdate(AnchorPoint) --// Determine whether to cull out or cull in
    else --// Removing this range will mean effectively removing the model so we completely cull it out
        --// Clear internal tracking
        module["AnchorPointModelCorrelations"][AnchorPoint] = nil
        module["NonCulledObjectCorrelations"][Model] = nil

        local Index = table.find(module["CurrentCulledInModels"], Model)

        table.remove(module["CurrentCulledInModels"], Index)
        table.remove(module["CurrentCulledInRanges"], Index)

        --// Destroy the NonCulledObjects folder for this model
        ModelNonCulledObjects:Destroy()
            
        CullOut(Model) --// Determine whether to cull out or cull in
    end
end

--// End Brain Functions

--// CullingService functions (super basic)

function module:Resume()
    module["Paused"] = false
end

function module:Pause()
    module["Paused"] = true
end

function module:Initialize()
    if not Initialized then

        --// Validate this is being run on the client
        if not PieAPI:ValidateCurrentRuntimeEnvironment("Client") then
            return
        end

        if not LocalPlayer then
            warn("LocalPlayer not found")
            return
        end

        Initialized = true

        local HumanoidRootPart --// Used to determine whether the player is alive - we don't want to have culling change when the player dies (ex: imagine if the player's rootpart gets flung really fast)

        --// Handle deaths
        PieAPI.CharacterAdded(LocalPlayer, function(Character)
            HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

            local Humanoid = Character:WaitForChild("Humanoid")

            Humanoid.Died:Connect(function()
                HumanoidRootPart = nil
            end)
        end)

        --// Actual culling portion
        while true do
            wait(Settings["WaitTime"])
            
            if not Settings["Paused"] and HumanoidRootPart then --// If not paused and the player is alive
                print("Scanning")

                --// Search for all nodes at the furthest distances (long)
                local AnchorPointsInRadius, Distances = GetAnchorPointsInRange(HumanoidRootPart.Position, Settings["Distances"]["Search Radius"])

                for Index, AnchorPoint in ipairs (AnchorPointsInRadius) do
                    --// Model that will be cloned if it is being culled in
                    local ReferenceModel = ModelStorage:FindFirstChild(AnchorPoint.Name)

                    --// Return distance folders (for short, medium, and/or long)
                    local ShortDistanceFolder = ReferenceModel:FindFirstChild("Short")
                    local MediumDistanceFolder = ReferenceModel:FindFirstChild("Medium")
                    local LongDistanceFolder = ReferenceModel:FindFirstChild("Long")

                    --// Tells whether the model is culled in
                    local ModelCulledIn = module["AnchorPointModelCorrelations"][AnchorPoint]

                    --// Return whether the model is in distance for the short, medium, or long range to be culled in
                    local InShortDistance = InDistance(Distances[Index], Settings["Distances"]["Short"])
                    local InMediumDistance = InDistance(Distances[Index], Settings["Distances"]["Medium"])
                    local InLongDistance = InDistance(Distances[Index], Settings["Distances"]["Long"])
                    
                    --[[
                        Evaluating whether to cull something in

                        Check for:
                            1. Folder exists
                            2. Is in distance to be culled
                            3. Model is not already culled in AND the range for that model is not already culled in
                    ]]
                    local function DetermineCullIn(DistanceFolder: Folder, IsInDistance: boolean)
                        --// 1.
                        if not DistanceFolder then
                            return
                        end

                        --// 2.
                        if not IsInDistance then
                            return
                        end

                        --// 3.
                        if ModelCulledIn and CheckIfRangeIsCulledIn(AnchorPoint, DistanceFolder.Name) then
                            return
                        end

                        ProcessCullIn(DistanceFolder, AnchorPoint) --// Cull it in
                    end

                    --[[
                        Evaluating whether to remove a range

                        Check for:
                            1. Folder exists
                            2. Is not in distance to be culled AND the range for that model is already culled
                    ]]

                    local function DetermineCullOut(DistanceFolder: Folder, IsInDistance: boolean)
                        local RangeCulledIn = CheckIfRangeIsCulledIn(AnchorPoint, DistanceFolder.Name)

                        --// 1.
                        if not DistanceFolder then
                            return
                        end

                        --// 2.
                        if not IsInDistance and RangeCulledIn then
                            ProcessCullOut(DistanceFolder, AnchorPoint)
                            return
                        end
                    end

                    --// Determines whether to Cull in short, medium, and long ranges
                    DetermineCullIn(ShortDistanceFolder, InShortDistance)
                    DetermineCullIn(MediumDistanceFolder, InMediumDistance)
                    DetermineCullIn(LongDistanceFolder, InLongDistance)

                    --// Determines whether to cull out short, medium, and long ranges
                    if ModelCulledIn then
                        DetermineCullOut(ShortDistanceFolder, InShortDistance)
                        DetermineCullOut(MediumDistanceFolder, InMediumDistance)
                        DetermineCullOut(LongDistanceFolder, InLongDistance)
                    end
                end
            end
        end
    end
end

return module