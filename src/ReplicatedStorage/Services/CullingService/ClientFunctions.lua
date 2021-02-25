local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HelpfulModules = ReplicatedStorage:WaitForChild("HelpfulModules")
local Services = ReplicatedStorage:WaitForChild("Services")
local ReplicaServiceClient = Services:WaitForChild("ReplicaServiceClient")

local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaController = require(ReplicaServiceClient:WaitForChild("ReplicaController"))

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

    if Model:IsDescendantOf(ReplicatedStorage) then --// Model has not yet been culled or is currently called out
        --// Attributes don't yet support object values *sigh*

        --local NonCulledObjects = Model:GetAttribute("NonCulledObjects")

        if not NonCulledObjects then
            NonCulledObjects = Instance.new("Folder")
            NonCulledObjects.Parent = ReplicatedStorage.NonCulledObjects
            NonCulledObjects.Name = "NonCulledObjects_".. Model.Name
            
            --Model:SetAttribute("NonCulledObjects", NonCulledObjects)
            module["Non Culled Objects"][Model] = NonCulledObjects
        end

        for _, Folder in pairs (Model:GetChildren()) do --// Each model should be sorted into the "Short", "Medium", and "Long" sub-folders
            if not table.find(RangeTable, Folder.Name) then --// Current range is not being culled in
                Folder.Parent = NonCulledObjects
            end
        end

        Model.Parent = workspace

    elseif Model.Parent == workspace then --// Model is currently culled in, and needs a range updated
        
    end
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

function module.CullOut(Object) --// An array of objects or individual BaseParts can be added as arguments
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
end

function module.CullOutWorkspace()
    for _, Model in pairs (workspace:GetChildren()) do
        if Model:IsA("Model") then
            module.CullOut(Model:GetChildren())
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

        Replica:ListenToArraySet({"ActiveRanges"}, function(RangeIndex, RangeTable) --// Listen to the different ranges being streamed in
            if module["Paused"] then
                module.CullUpdate(RangeIndex, RangeTable) --// Determine whether to cull out or cull in
            end
        end)

        Replica:ListenToArrayInsert({"ActiveRanges"}, function(RangeIndex, RangeTable) --// Listen to the different ranges being streamed in
            if module["Paused"] then
                module.CullIn(RangeIndex, RangeTable) --// Determine whether to cull out or cull in
            end
        end)

        Replica:ListenToArrayRemove({"ActiveModels"}, function(Models) --// Listens to stuff removed from the active objects
            if module["Paused"] then
                module.CullOut(Models)
            end
        end)

    end)

    PieAPI.CharacterAdded(Player, function(Character)
        
    end)
end

return module