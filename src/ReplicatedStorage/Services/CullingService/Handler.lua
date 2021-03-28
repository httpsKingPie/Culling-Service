local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HelpfulModules = ReplicatedStorage:WaitForChild("HelpfulModules")
local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ModelStorage = ReplicatedStorage:WaitForChild("ModelStorage")
local NonCulledObjects = ReplicatedStorage:WaitForChild("NonCulledObjects")

local AnchorPoints = workspace:WaitForChild("AnchorPoints")
local CulledObjects = workspace:WaitForChild("CulledObjects")

local Settings = require(script.Parent.Settings)

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
}

function module:Resume()
    module["Paused"] = false
end

function module:Pause()
    module["Paused"] = true
end

local function CheckIfAlreadyCulledIn(Model: Model)
    if Model.Parent == CulledObjects then
        return true
    end

    return false
end

local function ReturnModelValues(AnchorPoint: BasePart) --// Only use after a model has been fully processed with ProcessCullIn
    local Model: Model = module["AnchorPointModelCorrelations"][AnchorPoint]
    local ModelNonCulledObjects: Folder = module["NonCulledObjectCorrelations"][Model]
    local Index: number = table.find(module["CurrentCulledInModels"], Model)
    local RangeTable: table = module["CurrentCulledInRanges"][Index]

    return Model, ModelNonCulledObjects, RangeTable
end

--[[
    These are akin to the tools used by the ProcessCullIn and ProcessCullOut functions.
    Those ones are the brains, deciding which function is actually most appropriate 
    (i.e. complete CullOut or CullIn or when its just CullUpdate where ranges are changing)

    CullIn: Used when Culling something in for the first thing
    Cullout: Used when culling out an object completely
    CullUpdate: Used when updating ranges
]]
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

local function CullOut(Model: Model)
    if not Model:IsDescendantOf(workspace) then
        warn("Attempted to cull out a model that does not exist in workspace")
        return
    end

    Model:Destroy()
end

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

local function CheckModelIsReadyToBeCulled(Model: Model)
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

local function CheckIfModelIsAlreadyCulledIn(AnchorPoint)
    if module["AnchorPointModelCorrelations"][AnchorPoint] then
        return true
    end

    return false
end

local function CheckIfRangeIsCulledIn(AnchorPoint: BasePart, RangeName: string)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    if table.find(RangeTable, RangeName) then
        return true
    end

    return false
end

local function ProcessCullIn(DistanceFolder: Folder, AnchorPoint: BasePart) --// Does the backend work short of actually streaming the change
    local ReferenceModel = DistanceFolder.Parent

    CheckModelIsReadyToBeCulled(ReferenceModel) --// Ensures that there is a PrimaryPart so that appropirate changes can be made (if one doesn't exist, one is created)

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

local function ProcessCullOut(DistanceFolder: Folder, AnchorPoint: BasePart) --// Culls out specific ranges, and forwards any models needing to completely culled out to CompleteCullOut
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

local function CullOutWorkspace()
    for _, Model in pairs (workspace:GetChildren()) do
        if Model:IsA("Model") then
            Model:Destroy()
        end
    end
end

local function InitCheck()
    AnchorPoints = workspace:FindFirstChild("AnchorPoints")
    CulledObjects = workspace:FindFirstChild("CulledObjects")
    ModelStorage = ReplicatedStorage:FindFirstChild("ModelStorage")
    NonCulledObjects = ReplicatedStorage:FindFirstChild("NonCulledObjects")

    if not AnchorPoints then
        warn("AnchorPoints (folder) not found in workspace; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not CulledObjects then
        warn("CulledObjects (folder) not found in workspace; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not ModelStorage then
        warn("ModelStorage (folder) not found in ReplicatedStorage; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    if not NonCulledObjects then
        warn("NonCulledObjects (folder) not found in ReplicatedStorage; Culling plugin failed to initialize.  Please fix this error and try again.")
        return
    end

    return true
end

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

local function GetTrueName(Name: string)
    return string.sub(Name, #(Settings["AnchorPointPrefix"]) + 1)
end

local function InDistance(ComaprisonNumber, MaximumBound)
    if ComaprisonNumber <= MaximumBound then
        return true
    end

    return false
end

function module.InitializePlayer(Player: Player) --// This gets called once and is what handles the basic "listening"
    if not Player then
        warn("Player arguemnt not passed, unable to initialize culling")
        return
    end

    if not InitCheck then
        return
    end

    if Settings["InitiallyCullOutWorkspace"] then
        CullOutWorkspace()
    end

    local HumanoidRootPart

    PieAPI.CharacterAdded(Player, function(Character) --// Handle deaths
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

        local Humanoid = Character:WaitForChild("Humanoid")

        Humanoid.Died:Connect(function()
            HumanoidRootPart = nil
        end)
    end)

    while true do --// Handle culling (server side)
        wait(Settings["WaitTime"])
        
        if not Settings["Paused"] and HumanoidRootPart then --// If not pasused and the player is alive
            print("Scanning")
            local AnchorPointsInRadius, Distances = GetAnchorPointsInRange(HumanoidRootPart.Position, Settings["Distances"]["Search Radius"]) --// Search for all nodes at the furthest distances (long)

            for Index, AnchorPoint in ipairs (AnchorPointsInRadius) do
                local ReferenceModel = ModelStorage:FindFirstChild(GetTrueName(AnchorPoint.Name))

                local ShortDistanceFolder = ReferenceModel:FindFirstChild("Short") --// Returns a distance folder (Short)
                local MediumDistanceFolder = ReferenceModel:FindFirstChild("Medium") --// Returns a distance folder (Medium)
                local LongDistanceFolder = ReferenceModel:FindFirstChild("Long") --// Returns a distance folder (Long)

                local ModelCulledIn = module["AnchorPointModelCorrelations"][AnchorPoint] --// Tells whether the model is culled in

                local InShortDistance = InDistance(Distances[Index], Settings["Distances"]["Short"])
                local InMediumDistance = InDistance(Distances[Index], Settings["Distances"]["Medium"])
                local InLongDistance = InDistance(Distances[Index], Settings["Distances"]["Long"])
                
                --[[
                    Check for:
                        * Folder exists
                        * Is in distance to be culled
                        * Model is not already culled in AND the range for that model is not already culled in
                ]]

                local function DetermineCullIn(DistanceFolder: Folder, IsInDistance: boolean)
                    if not DistanceFolder then
                        return
                    end

                    if not IsInDistance then
                        return
                    end

                    if ModelCulledIn and CheckIfRangeIsCulledIn(AnchorPoint, DistanceFolder.Name) then
                        return
                    end

                    ProcessCullIn(DistanceFolder, AnchorPoint)
                end

                local function CheckForUpdate(DistanceFolder: Folder, IsInDistance: boolean)
                    local RangeCulledIn = CheckIfRangeIsCulledIn(AnchorPoint, DistanceFolder.Name)

                    if not DistanceFolder then
                        return
                    end

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
                    CheckForUpdate(ShortDistanceFolder, InShortDistance)
                    CheckForUpdate(MediumDistanceFolder, InMediumDistance)
                    CheckForUpdate(LongDistanceFolder, InLongDistance)
                end
            end
        end
    end
end

return module