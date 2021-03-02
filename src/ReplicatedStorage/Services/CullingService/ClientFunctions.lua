local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HelpfulModules = ReplicatedStorage:WaitForChild("HelpfulModules")
local Services = ReplicatedStorage:WaitForChild("Services")
local ReplicaServiceClient = Services:WaitForChild("ReplicaServiceClient")

local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaController = require(ReplicaServiceClient:WaitForChild("ReplicaController"))

local ModelStorage = ReplicatedStorage:WaitForChild("ModelTest")

--[[
    Demo version will check the whole map, broadly searching every check period for whatever is within streaming distance
    Final version should incorporate smarter check methods (ex: take note of where the player is, like what "zone" the player is, and then only search within that zone for better performance)
]]

local module = {
    ["CullingReplica"] = nil, --// Becomes the CullingReplica specific to this client
    ["Non Culled Objects"] = {}, --// A dictionary of [Model] = Folder to non-culled objects
    ["Paused"] = true, --// Whether Culling is paused or not (defaults to true, since culling may want to be done manually at the beginning for cutscnees, etc.)
}

function module.ReturnHumanoidRootPart(Character: Model) --// Set up for R15
    if not Character then
        warn("No character sent to function")
        return
    end

    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

    if not HumanoidRootPart then
        warn("HumanoidRootPart not found")
    end

    return HumanoidRootPart
end

function module.StartCulling(HumanoidRootPart)
    module["Paused"] = false
end

function module.PauseCulling()
    module["Paused"] = true
end

function module.CullIn(RangeIndex, RangeTable)
    local Model = module["CullingReplica"].Data.ActiveModels[RangeIndex]
    local NonCulledObjects = module["Non Culled Objects"][Model]

    local AlreadyCreated = true

    if not Model:IsDescendantOf(ReplicatedStorage) then
        warn("Attempted to cull in a model that already exists in Workspace")
        return
    end

    --// Model has not yet been culled or is currently called out
    --// Attributes don't yet support object values *sigh*

    --local NonCulledObjects = Model:GetAttribute("NonCulledObjects")

    if not NonCulledObjects then
        NonCulledObjects = Instance.new("Folder")
        NonCulledObjects.Parent = ReplicatedStorage.NonCulledObjects
        NonCulledObjects.Name = "NonCulledObjects_".. Model.Name
        
        --Model:SetAttribute("NonCulledObjects", NonCulledObjects)
        module["Non Culled Objects"][Model] = NonCulledObjects

        AlreadyCreated = false
    end

    --[[
        Some models will have already been streamed in once and will already have their NonCulledObjects folder created
        If that's the case, then the Short, Medium, and Long folders will actually be there instead
        Thus, we check that location and reparent any folders that need to be streamed in directly there

        If it has not already been created, we do the opposite: leaving any models that are supposed to be streamed in within the model and reparenting those not being streamed to the NonCulledObjects folder
    ]]
    if AlreadyCreated then --// For models that have already been streamed in once and are being rest
        for _, Folder in pairs(NonCulledObjects:GetChildren()) do
            if table.find(RangeTable, Folder.Name) then
                Folder.Parent = Model
            end
        end
    else
        for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into the "Short", "Medium", and "Long" sub-folders
            if not table.find(RangeTable, Folder.Name) then --// Current range is not being culled in
                Folder.Parent = NonCulledObjects
            end
        end
    end

    Model.Parent = workspace
end

function module.CullOut(Model: Model) --// An array of objects or individual BaseParts can be added as arguments
    print("Calling Cull Out for ".. Model.Name)
    local NonCulledObjects = module["Non Culled Objects"][Model]
    
    if not Model:IsDescendantOf(workspace) then
        warn("Attempted to cull out a model that does not exist in workspace")
        return
    end

    for _, Folder in pairs (Model:GetChildren()) do
        Folder.Parent = NonCulledObjects
    end

    Model.Parent = ModelStorage
    --[[

    if type(Object) == "table" then --// If an array is passed, the children are recyclced into the function
        for _, Child in pairs (Object) do
            module.CullOut(Child)
        end

        return
    end

    if Object:IsA("Model") or Object:IsA("Folder") then
        module.CullOut(Object:GetChildren())
        return
    end

    if not Object:IsA("BasePart") then
        return
    end

    Object:Destroy()
    ]]
end

function module.ClearModelChildren(Object)
    if type(Object) == "table" then --// If an array is passed, the children are recyclced into the function
        for _, Child in pairs (Object) do
            module.ClearModelChildren(Child)
        end

        return
    end

    if Object:IsA("Model") or Object:IsA("Folder") then
        module.ClearModelChildren(Object:GetChildren())
        return
    end

    if not Object:IsA("BasePart") then
        return
    end

    Object:Destroy()
end

function module.CullUpdate(RangeIndex, RangeTable)
    local Model = module["CullingReplica"].Data.ActiveModels[RangeIndex]
    local NonCulledObjects = module["Non Culled Objects"][Model]

    for _, Folder in pairs (NonCulledObjects:GetChildren()) do
        if table.find(RangeTable, Folder.Name) then
            Folder.Parent = Model
        end
    end

    for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into the "Short", "Medium", and "Long" sub-folders
        if not table.find(RangeTable, Folder.Name) then --// Current range is not being culled in
            Folder.Parent = NonCulledObjects
        end
    end
end

function module.CullOutWorkspace()
    for _, Model in pairs (workspace:GetChildren()) do
        if Model:IsA("Model") then
            module.ClearModelChildren(Model:GetChildren())
        end
    end
end

function module.InitializePlayer(Player: Player) --// This gets called once and is what handles the basic "listening"
    if not Player then
        warn("Player arguemnt not passed, unable to initialize culling")
        return
    end

    ReplicaController.ReplicaOfClassCreated("CullingReplica_"..tostring(Player.UserId), function(Replica)
        module["CullingReplica"] = Replica

        --// Array is added when a model is streamed in for the first time
        Replica:ListenToArrayInsert({"ActiveRanges"}, function(RangeIndex, RangeTable) --// Listen to the different ranges being streamed in
            if module["Paused"] then
                module.CullIn(RangeIndex, RangeTable) --// Determine whether to cull out or cull in
            end
        end)

        --// Array is set when the ranges are being changed
        Replica:ListenToArraySet({"ActiveRanges"}, function(RangeIndex, RangeTable) --// Listen to the different ranges being streamed in
            if module["Paused"] then
                module.CullUpdate(RangeIndex, RangeTable) --// Determine whether to cull out or cull in
            end
        end)

        --// Array is removed when 
        Replica:ListenToArrayRemove({"ActiveModels"}, function(OldIndex, Model) --// Listens to stuff removed from the active objects
            if module["Paused"] then
                module.CullOut(Model)
            end
        end)

    end)

    PieAPI.CharacterAdded(Player, function(Character)
        
    end)
end

return module