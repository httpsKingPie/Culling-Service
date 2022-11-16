--[[
    This runs exclusively on the client

    Run it with CullingService.Initialize()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ModelStorage = ReplicatedStorage:WaitForChild("ModelStorage")
local NonCulledObjects = ReplicatedStorage:WaitForChild("NonCulledObjects")

local CulledObjects = workspace:WaitForChild("CulledObjects")

local AnimationPackages = script:WaitForChild("AnimationPackages")

local RegionHandling = require(script:WaitForChild("RegionHandling"))
local Settings = require(script:WaitForChild("Settings"))
local Signal = require(script:WaitForChild("Signal"))

local LocalPlayer = Players.LocalPlayer

local HumanoidRootPart --// Used to determine whether the player is alive - we don't want to have culling change when the player dies (ex: imagine if the player's rootpart gets flung really fast)

local Initialized = false

local module = {
    ["Paused"] = false, --// Whether Culling is paused or not (defaults to false, since culling may want to be done manually at the beginning for cutscnees, etc.)
    
    ["AnchorPointModelCorrelations"] = {}, --// A dictionary of [AnchorPoint] = Model
    ["CurrentCulledInModels"] = {}, --// Numeric table holding all currently culled in models (indexes correlated to CurrentCulledInRanges)
    ["CurrentCulledInRanges"] = {}, --// Numeric table holding all currently culled in ranges (indexes correlated to CurrentCulledInModels)
    ["ModelAnchorPointCorrelations"] = {}, --// Inverse of AnchorPointModelCorrelations, dictionary format is [Model] = AnchorPoint
    ["NonCulledObjectCorrelations"] = {}, --// A dictionary of [Model] = Folder of Other Ranges

    --// Models to track for Signals
    ["ModelNamesAssociatedWithSignals"] = {
        ["CullIn"] = {}, --// Dictionary [ModelName] = Signal
        ["CullOut"] = {}, --// Dictionary [ModelName] = Signal
    },

    ["RangeAssociatedWithSignals"] = {
        ["CullIn"] = {}, --// Dictionary [ModelName] = {[RangeName] = Signal}
        ["CullOut"] = {}, --// Dictionary [ModelName] = {[RangeName] = Signal}
    },
}

local function CharacterAdded(Player, BoundFunction, ...)
	local Args = {...}
	
	if type(Player) ~= "userdata" or Player:IsA("Player") == false or Player.Parent == nil then
		warn("Invalid player instance provided as first argument")
		return
	end
	
	if type(BoundFunction) ~= "function" then
		warn("Pass a function as the second argument")
		return
	end
	
	if Player.Character then
		BoundFunction(Player.Character, table.unpack(Args))
		
		Player.CharacterAdded:Connect(function(Character)
			BoundFunction(Character, table.unpack(Args))
		end)
	end
	
	Player.CharacterAdded:Connect(function(Character)
		BoundFunction(Character, table.unpack(Args))
	end)
end

local function CreateWeld(Part1, Part2)
    local Weld = Instance.new("WeldConstraint")
    Weld.Parent = Part1
    Weld.Part0 = Part1
    Weld.Part1 = Part2
end

local function ReturnModelValues(AnchorPoint: BasePart)
    local Model: Model = module["AnchorPointModelCorrelations"][AnchorPoint]
    local ModelNonCulledObjects: Folder = module["NonCulledObjectCorrelations"][Model]
    local Index: number = table.find(module["CurrentCulledInModels"], Model)
    local RangeTable: table = module["CurrentCulledInRanges"][Index]

    if not Model then
        --warn("Unable to return Model for value", AnchorPoint.Name)

        return nil, nil, nil
    end

    if not ModelNonCulledObjects then
        --warn("Unable to return ModelNonCulledObjects for value", AnchorPoint.Name)

        return nil, nil, nil
    end

    if not RangeTable then
        --warn("Unable to return RangeTable for value", AnchorPoint.Name)

        return nil, nil, nil
    end

    return Model, ModelNonCulledObjects, RangeTable
end

--// Returns all anchor points in relevant regions and their distance from the origin position (table format is {[AnchorPoint: BasePart] = Distance: number})
local function GetAnchorPointsInRange(OriginPosition: Vector3)
    local AnchorPointDistances = {}

    local AllTrackedAnchorPoints = RegionHandling:ReturnTrackedAnchorPoints()

    for _, AnchorPoint in pairs (AllTrackedAnchorPoints) do
        local Distance = (OriginPosition - AnchorPoint.Position).Magnitude
        
        AnchorPointDistances[AnchorPoint] = Distance
    end

    return AnchorPointDistances
end

--[[
    Check functions

    Validating stuff xp
]]

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

    --[[
        This sometimes 'errors' (doesn't find a RangeTable, but it functions correctly.)
    ]]
    if not Model then
        return
    end

    if table.find(RangeTable, RangeName) then
        return true
    end

    return false
end

--// Returns whether something is in distance
local function InDistance(ComaprisonNumber, MaximumBound)
    if ComaprisonNumber <= MaximumBound then
        return true
    end

    return false
end

local function HandleAnimation(ObjectToAnimate: Model | BasePart, InOrOut: string)
    local AnimationPackageName = Settings["Animation Package"]

    if not AnimationPackageName then
        return
    end

    local AnimationPackageFound = AnimationPackages:FindFirstChild(AnimationPackageName)

    if not AnimationPackageFound then
        warn("Animation package", AnimationPackageName, "not found - check for typo")

        return
    end

    local AnimationFunction = require(AnimationPackageFound)

    AnimationFunction(ObjectToAnimate, InOrOut)
end

--// ParameterDictionary = {["Model"] = Model, ["Type"] = string ("CullIn" or "CullOut"), ["ModelName"] = string, ["RangeName"] = string? (optional)}
local function HandleSignals(ParameterDictionary: table)
    local Model: Model = ParameterDictionary["Model"]
    local ModelName: string = ParameterDictionary["ModelName"]
    local RangeName: string = ParameterDictionary["RangeName"]
    local Type: string = ParameterDictionary["Type"]

    --// Handle for only range
    if RangeName then
        local RangeTableExistsForModel: table = module["RangeAssociatedWithSignals"][Type][ModelName]

        if not RangeTableExistsForModel then
            return
        end

        local RangeSignal: RBXScriptSignal = RangeTableExistsForModel[RangeName]

        if RangeSignal then
            RangeSignal:Fire(Model)
        end

        return
    end

    --// Handle for only models
    local SignalForModel: RBXScriptSignal = module["ModelNamesAssociatedWithSignals"][Type][ModelName]

    if SignalForModel then
        SignalForModel:Fire(Model)
    end
end

--[[
    Tool functions:

    These are the tools of the CullingService.  Based on what the brain functions determine is the best choice, one of these functions are used to make it actually happen

    CullIn: Used when Culling something in for the first thing
    CullOut: Used when culling out an object completely
    CullUpdate: Used when updating ranges
]]

--// Used when Culling something in for the first thing
local function CullIn(AnchorPoint: BasePart)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    local AlreadyCreated = CheckIfAlreadyCulledIn(Model)

    if AlreadyCreated then --// For models that have already been streamed in once and are being reset
        for _, Folder in pairs(ModelNonCulledObjects:GetChildren()) do
            local Range = Folder.Name

            if table.find(RangeTable, Range) then
                Folder.Parent = Model

                HandleAnimation(Folder, "CullIn")

                HandleSignals({
                    ["Model"] = Model,
                    ["Type"] = "CullIn",
                    ["ModelName"] = Model.Name,
                    ["Range"] = Range
                })
            end
        end
    else
        Model:PivotTo(AnchorPoint.CFrame)

        for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into relevant distance folders (ex: "Short", "Medium", "Long") [these must correlate with Settings.Distances]
            local Range = Folder.Name
            
            if not table.find(RangeTable, Range) then --// Current range is not being culled in
                Folder.Parent = ModelNonCulledObjects
            else
                HandleSignals({
                    ["Model"] = Model,
                    ["Type"] = "CullIn",
                    ["ModelName"] = Model.Name,
                    ["Range"] = Range,
                })
            end
        end

        Model.Parent = CulledObjects

        HandleAnimation(Model, "CullIn")

        HandleSignals({
            ["Model"] = Model,
            ["Type"] = "CullIn",
            ["ModelName"] = Model.Name,
        })
    end
end

--// Used when culling out an object completely
local function CullOut(AnchorPoint: BasePart)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    if not Model then --// Warning bundled in
        return
    end

    --// Clear internal tracking
    module["AnchorPointModelCorrelations"][AnchorPoint] = nil
    module["NonCulledObjectCorrelations"][Model] = nil

    local Index = table.find(module["CurrentCulledInModels"], Model)

    table.remove(module["CurrentCulledInModels"], Index)
    table.remove(module["CurrentCulledInRanges"], Index)

    --// Destroy the NonCulledObjects folder for this model
    ModelNonCulledObjects:Destroy()

    if not Model:IsDescendantOf(workspace) then
        warn("Attempted to cull out a model that does not exist in workspace")
        return
    end

    local AnchorPoint = module["ModelAnchorPointCorrelations"][Model]

    module.AnchorPointModelCorrelations[AnchorPoint] = nil
    module.ModelAnchorPointCorrelations[Model] = nil

    --// This is wrapped in a spawn function, because some animations may have yield functions (to prevent being destroyed before the animation is complete, but that can hang the whole script)
    task.spawn(function()
        HandleAnimation(Model, "CullOut") --// The animation should have built in yielding

        Model:Destroy()

        HandleSignals({
            ["Model"] = Model,
            ["Type"] = "CullOut",
            ["ModelName"] = Model.Name,
        })
    end)

    --// Clean up the welds which are stored in the anchor point (because they are created each time)
    local WeldAnchorPoints = table.find(Settings["Welded Anchor Points"], AnchorPoint.Name)

    if WeldAnchorPoints then
        for _, Child: WeldConstraint in pairs (AnchorPoint:GetChildren()) do
            if not Child:IsA("WeldConstraint") then
                continue
            end

            if not Child.Part1 or Child.Part1.Parent == nil then
                Child:Destroy()
            end
        end
    end
end

--// Used when updating ranges
local function CullUpdate(AnchorPoint: BasePart)
    local Model, ModelNonCulledObjects, RangeTable = ReturnModelValues(AnchorPoint)

    if not Model then --// Warning bundled in
        return
    end

    for _, Folder in pairs (ModelNonCulledObjects:GetChildren()) do
        local Range = Folder.Name

        if table.find(RangeTable, Range) then
            Folder.Parent = Model

            HandleAnimation(Folder, "CullIn")

            HandleSignals({
                ["Model"] = Model,
                ["Type"] = "CullIn",
                ["ModelName"] = Model.Name,
                ["Range"] = Range,
            })
        end
    end

    for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into relevant distance folders (ex: "Short", "Medium", "Long") [these must correlate with Settings.Distances]
        local Range = Folder.Name
        
        if not table.find(RangeTable, Range) then --// Current range is not being culled in
            Folder.Parent = ModelNonCulledObjects

            HandleAnimation(Folder, "CullOut")

            HandleSignals({
                ["Model"] = Model,
                ["Type"] = "CullOut",
                ["ModelName"] = Model.Name,
                ["Range"] = Range,
            })
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

        local WeldAnchorPoints = table.find(Settings["Welded Anchor Points"], Model.Name)

        if WeldAnchorPoints then
            for _, Descendant in pairs (Model:GetDescendants()) do
                if Descendant:IsA("BasePart") then
                    CreateWeld(AnchorPoint, Descendant)
                    Descendant.Anchored = false
                end
            end
        end

        --// Set up Anchor Point Model Correlations
        module["AnchorPointModelCorrelations"][AnchorPoint] = Model
        module["ModelAnchorPointCorrelations"][Model] = AnchorPoint

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

    if not Model then --// Warning bundled in
        return
    end

    local RangesCulledIn = #RangeTable --// If this is 1, then that means removing this range will result in removing the whole model.  This should never be 0

    if RangesCulledIn > 1 then --// Means we are updating the model (culling out a range), not culling out the whole model
        local RangeIndex = table.find(RangeTable, DistanceFolder.Name)
        table.remove(RangeTable, RangeIndex)
        
        CullUpdate(AnchorPoint) --// Determine whether to cull out or cull in
    else --// Removing this range will mean effectively removing the model so we completely cull it out
        CullOut(AnchorPoint) --// Determine whether to cull out or cull in
    end
end

local function BackupCheck(HumanoidRootPart: BasePart)
    local FurthestDistance = 0

    --// Get the furthest distance (earlier versions were less modularized)
    for DistanceName: string, Distance: number in pairs (Settings["Distances"]) do
        if Distance > FurthestDistance then
            FurthestDistance = Distance
        end
    end

    for AnchorPoint: BasePart, AssociatedModel: Model in pairs (module["AnchorPointModelCorrelations"]) do
        local Distance = (HumanoidRootPart.Position - AnchorPoint.Position).Magnitude

        if Distance < FurthestDistance then
            continue
        end

        CullOut(AnchorPoint)
    end
end

--// What actually handles the culling
local function CoreLoop()
    while true do
        task.wait(Settings["Wait Time"]) --// This doesn't have to be super specific, so I'm just using the basic Roblox wait function
        
        if not Settings["Paused"] and HumanoidRootPart then --// If not paused and the player is alive and they are currently in a culling region
            --// Search for all nodes at the furthest distances (long)
            local AnchorPointDictionary = GetAnchorPointsInRange(HumanoidRootPart.Position)

            for AnchorPoint: BasePart, AnchorPointDistance: number in pairs (AnchorPointDictionary) do
                --// Model that will be cloned if it is being culled in
                local ReferenceModel = ModelStorage:FindFirstChild(AnchorPoint.Name)

                if not ReferenceModel then
                    warn("No reference model found for AnchorPoint", AnchorPoint.Name)

                    continue
                end

                --// Return distance folders
                local DistanceFolderDictionary = {} --// looks like {[DistanceFolder: Folder] = InDistanceToCull: boolean}

                for _, Folder: Folder in pairs (ReferenceModel:GetChildren()) do
                    if not Folder:IsA("Folder") then
                        continue
                    end

                    local DistanceAssociatedWithFolder = Settings["Distances"][Folder.Name]

                    if not DistanceAssociatedWithFolder then
                        warn("Distance Folder [", Folder.Name, "] in Model [", ReferenceModel.Name, "] does not have a distance associated with it")

                        continue
                    end

                    local IsInDistance = InDistance(AnchorPointDistance, DistanceAssociatedWithFolder)

                    DistanceFolderDictionary[Folder] = IsInDistance
                end

                --// Tells whether the model is culled in
                local ModelCulledIn = CheckIfModelIsAlreadyCulledIn(AnchorPoint)
                
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
                    --// 1.
                    if not DistanceFolder then
                        return
                    end

                    local RangeCulledIn = CheckIfRangeIsCulledIn(AnchorPoint, DistanceFolder.Name)

                    --// 2.
                    if not IsInDistance and RangeCulledIn then
                        ProcessCullOut(DistanceFolder, AnchorPoint)
                        return
                    end
                end

                for DistanceFolder: Folder, IsInDistance: boolean in pairs (DistanceFolderDictionary) do
                    DetermineCullIn(DistanceFolder, IsInDistance)

                    if ModelCulledIn then
                        DetermineCullOut(DistanceFolder, IsInDistance)
                    end
                end
            end

            BackupCheck(HumanoidRootPart)
        end
    end
end

--[[
    Culling Service functions

    I.e. the ones designed to be called
]]

--// Returns a Signal which is fired every time a model with the name provided is culled in.  When the Signal is fired, it provides the model as the first parameter
function module:CreateSignalForModelCullIn(ModelName: string)
    module["ModelNamesAssociatedWithSignals"]["CullIn"][ModelName] = Signal.new()

    return module["ModelNamesAssociatedWithSignals"]["CullIn"][ModelName]
end

--// Returns a Signal which is fired every time a model with the name provided is culled out.  When the Signal is fired, it provides the model (in this case nil) as the first parameter
function module:CreateSignalForModelCullOut(ModelName: string)
    module["ModelNamesAssociatedWithSignals"]["CullOut"][ModelName] = Signal.new()

    return module["ModelNamesAssociatedWithSignals"]["CullOut"][ModelName]
end

--// Returns a Signal which is fired every time a model with the name provided is culled in.  When the Signal is fired, it provides the model as the first parameter
function module:CreateSignalForModelCullInAtRange(ModelName: string, RangeName: string)
    if not module["RangeAssociatedWithSignals"]["CullIn"][ModelName] then
        module["RangeAssociatedWithSignals"]["CullIn"][ModelName] = {}
    end

    module["RangeAssociatedWithSignals"]["CullIn"][ModelName][RangeName] = Signal.new()

    return module["RangeAssociatedWithSignals"]["CullIn"][ModelName][RangeName]
end

--// Returns a Signal which is fired every time a model with the name provided is culled out.  When the Signal is fired, it provides the model as the first parameter
function module:CreateSignalForModelCullOutAtRange(ModelName: string, RangeName: string)
    if not module["RangeAssociatedWithSignals"]["CullOut"][ModelName] then
        module["RangeAssociatedWithSignals"]["CullOut"][ModelName] = {}
    end

    module["RangeAssociatedWithSignals"]["CullOut"][ModelName][RangeName] = Signal.new()

    return module["RangeAssociatedWithSignals"]["CullOut"][ModelName][RangeName]
end

--// Resumes CullingService
function module:Resume()
    module["Paused"] = false
end

--// Pauses CullingService
function module:Pause()
    module["Paused"] = true
end

--// Initializes and runs CullingService
function module.Initialize()
    --// Validate this is being run on the client
    if not RunService:IsClient() then
        warn("Run CullingService from the client, not the server")
        return
    end

    if Initialized then
        return
    end

    Initialized = true

    --// Handle deaths
    CharacterAdded(LocalPlayer, function(Character)
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

        local Humanoid = Character:WaitForChild("Humanoid")
        
        local Connection

        Connection = Humanoid.Died:Connect(function()
            HumanoidRootPart = nil
            Connection:Disconnect()
        end)

        --GetCurrentRegion(HumanoidRootPart)
    end)

    --// Divide up the map into internal regions
    RegionHandling:GenerateInternalRegions()

    --// Track the player entering regions
    RegionHandling:TrackRegionChanges()

    --// Actual culling portion (the core loop)
    coroutine.wrap(CoreLoop)()
end

return module