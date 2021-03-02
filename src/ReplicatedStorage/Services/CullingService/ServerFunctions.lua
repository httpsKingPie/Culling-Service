local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HelpfulModules = ReplicatedStorage.HelpfulModules
local OctreeModule = require(script.Parent.Octree)
local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaService = require(ServerScriptService.ReplicaServiceServer.ReplicaService)

local Settings = require(script.Parent.Settings)

local ModelStorage = ReplicatedStorage.ModelTest

local module = {
    ["Octree"] = OctreeModule.new(), --// Generates a new octree to be referenced
    ["Player Information"] = {},  --// Store all Player replicas, currently streamed in objects and not currently streamed in objects
}

function module.InitializePlayer(Player: Player)
     --// Generate a specific replica for each player
    local CullingReplica = ReplicaService.NewReplica({
        ClassToken = ReplicaService.NewClassToken("CullingReplica_"..tostring(Player.UserId)),
        Data = {
            ActiveModels = {}, --// No data yet (this will be filled with models or BaseParts)
            --[[
                ActiveModels looks like = {
                    [1] = Model1,
                    [2] = Model2,
                    etc... and these are actual instances, not strings
                }
            ]]
            ActiveRanges = {}, --// Shares the same index as each model, but this is a table of strings (ex: short, medium, and long)
            --[[
                ActiveRanges looks like = {
                    [1] = {"Long"},
                    [2] = {"Long", "Medium"},
                    etc... the indexes correspond to the model indexes in ActiveModels
                }
            ]]
        },
        Replication = Player,
    })

    --// Store it for access later and create some variables for the player
    module["Player Information"][Player.Name] = {}
    module["Player Information"][Player.Name]["Culled Models"] = {}
    module["Player Information"][Player.Name]["Culling Replica"] = CullingReplica
end

--[[
local function CheckObject(Object)
    local Short = Object:FindFirstChild("Short")
    local Medium = Object:FindFirstChild("Medium")
    local Long = Object:FindFirstChild("Long")

    if not Short or not Medium or not Long then --// If no Short, Medium, or Long folder is detected, we keep searching in the 
        if Object:IsA("Model") or Object:IsA("Folder") then --// If Ahlvie doesn't use folders to organize things, then we'll cut this last argument
            for _, Child in pairs (Object:GetChildren()) do
                CheckObject(Child)
            end

            return
        end
    end
end
]]

local function InDistance(ModelDistance: number, MaximumDistance: number)
    if ModelDistance <= MaximumDistance then
        return true
    else
        return false
    end
end

local function CheckModelIsReadyToBeCulled(Model: Model)
    if Model.PrimaryPart then
        return
    end

    local Primary_Part = Instance.new("Part")
    Primary_Part.Anchored = true
    Primary_Part.Size = Vector3.new(.1, .1, .1)
    Primary_Part.CFrame = Model:GetModelCFrame() --// Yes, it's deprecated - yes this is the best thing to use in this case, because it puts it exactly where the node is
    Primary_Part.Parent = Model
    Model.PrimaryPart = Primary_Part
end

local function CullIn(DistanceFolder: Folder, CullingReplica) --// Can Cull in a full model or cull in specific ranges
    local Model = DistanceFolder.Parent

    CheckModelIsReadyToBeCulled(Model)

    local Index = table.find(module.GetCulledModels(CullingReplica), Model)
    local RangeTable = module.GetCulledRanges(CullingReplica, Model) or {}

    table.insert(RangeTable, DistanceFolder.Name)

    if Index then --// Means the model exists, which means the active ranges also exist
        CullingReplica:ArraySet({"ActiveRanges"}, Index, RangeTable)
    else --// Need to replicate the model and the range
        CullingReplica:ArrayInsert({"ActiveModels"}, Model)
        CullingReplica:ArrayInsert({"ActiveRanges"}, RangeTable)
    end

    --// Gets the index of the Model or adds the Model as an active model

    --// Gets the range table or generates a blank table (the latter happens when the model is being added as an active model for the first time)
end

local function CullOut(DistanceFolder: Folder, CullingReplica) --// Culls out specific ranges, and forwards any models needing to completely culled out to CompleteCullOut
    print("Cull out was called")
    local Model = DistanceFolder.Parent

    --// Don't need to check if it is ready to be culled, since it will be already in workspace

    local Index = table.find(module.GetCulledModels(CullingReplica), Model)
    local RangeTable = module.GetCulledRanges(CullingReplica, Model)

    local RangesCulledIn = #RangeTable --// If this is 1, then that means removing this range will result in removing the whole model.  This should never be 0

    if RangesCulledIn > 1 then --// Means we are updating the model, not removing the model
        local RangeIndex = table.find(RangeTable, DistanceFolder.Name)
        table.remove(RangeTable, RangeIndex)

        CullingReplica:ArraySet({"ActiveRanges"}, Index, RangeTable)
    else --// Removing this range will mean effectively removing the model so we completely cull it out
        CullingReplica:ArrayRemove({"ActiveModels"}, Index)
        CullingReplica:ArrayRemove({"ActiveRanges"}, Index)
    end
end

function module.GetPlayerReplica(Player)
    if not module["Player Information"][Player.Name] then
        warn("Played not initialized - unable to load culling replica")
        return
    end

    return module["Player Information"][Player.Name]["Culling Replica"]
end

function module.InitializeOctree()
    for _, Model in pairs (ModelStorage:GetChildren()) do
        if Model:IsA("Model") then
            --// GetModelCFrame is a deprecated function, but it's the only way to effectively and reliably find the center of a model (even though Roblox contests it isn't)
            
            module["Octree"]:CreateNode(Model:GetModelCFrame().Position, Model)
        end
    end
end

function module.ModelCulledIn(CullingReplica, Model: Model)
    local CulledModels = module.GetCulledModels(CullingReplica)

    if table.find(CulledModels, Model) then
        return true
    else
        return false
    end
end

function module.RangeCulledIn(CullingReplica, Model: Model, RangeName: String) --// Returns if the range is currently culled in
    local CulledRanges = module.GetCulledRanges(CullingReplica, Model)

    if CulledRanges and table.find(CulledRanges, RangeName) then
        return true
    end

    return false
end

function module.GetCulledModels(CullingReplica) --// Returns models that are currently loaded in
    return CullingReplica.Data.ActiveModels
end

function module.GetCulledRanges(CullingReplica, Model: Model)
    local TableIndex = table.find(CullingReplica.Data.ActiveModels, Model)

    if not TableIndex then --// The model is not currently culled in
        return
    else
        return CullingReplica.Data.ActiveRanges[TableIndex]
    end
end

function module.Initialize()
    module.InitializeOctree() --// Creates Octress for fast searching

    PieAPI.PlayerAdded(function(Player)
        module.InitializePlayer(Player) --// Set up the basic player information in the module

        local CullingReplica = module.GetPlayerReplica(Player) --// Assign a replica to the player

        local HumanoidRootPart

        PieAPI.CharacterAdded(Player, function(Character) --// Handle deaths
            HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

            local Humanoid = Character:WaitForChild("Humanoid")

            Humanoid.Died:Connect(function()
                HumanoidRootPart = nil
            end)
        end)

        while true do --// Handle culling (server side)
            wait(Settings["Wait Time"])
            
            if HumanoidRootPart then --// I.e. if the player is alive
                print("Scanning")
                local ModelsInRadius, DistancesSquared = module["Octree"]:RadiusSearch(HumanoidRootPart.Position, Settings["Distances"]["Search Radius"]) --// Search for all nodes at the furthest distances (long)

                for Index, Model in ipairs (ModelsInRadius) do
                    local ShortDistanceFolder = Model:FindFirstChild("Short") --// Returns a distance folder (Short)
                    local MediumDistanceFolder = Model:FindFirstChild("Medium") --// Returns a distance folder (Medium)
                    local LongDistanceFolder = Model:FindFirstChild("Long") --// Returns a distance folder (Long)

                    local ModelCulledIn = module.ModelCulledIn(CullingReplica, Model) --// Tells whether the model is culled in

                    local InShortDistance = InDistance(math.sqrt(DistancesSquared[Index]), Settings["Distances"]["Short"])
                    local InMediumDistance = InDistance(math.sqrt(DistancesSquared[Index]), Settings["Distances"]["Medium"])
                    local InLongDistance = InDistance(math.sqrt(DistancesSquared[Index]), Settings["Distances"]["Long"])
                    
                    --[[
                        Check for:
                            * Folder exists
                            * Is in distance to be culled
                            * Model is not already culled in AND the range for that model is not already culled in
                    ]]

                    local function DetermineCullIn(DistanceFolder: Folder, InDistance: boolean)
                        if not DistanceFolder then
                            return
                        end

                        if not InDistance then
                            return
                        end

                        if ModelCulledIn and module.RangeCulledIn(CullingReplica, Model, DistanceFolder.Name) then
                            return
                        end

                        CullIn(DistanceFolder, CullingReplica)
                    end

                    local function CheckForUpdate(DistanceFolder: Folder, InDistance: boolean)
                        local RangeCulledIn = module.RangeCulledIn(CullingReplica, Model, DistanceFolder.Name)

                        if not DistanceFolder then
                            return
                        end

                        if not InDistance and RangeCulledIn then
                            CullOut(DistanceFolder, CullingReplica)
                            return
                        end
                    end

                    DetermineCullIn(ShortDistanceFolder, InShortDistance)
                    DetermineCullIn(MediumDistanceFolder, InMediumDistance)
                    DetermineCullIn(LongDistanceFolder, InLongDistance)

                    if ModelCulledIn then
                        CheckForUpdate(ShortDistanceFolder, InShortDistance)
                        CheckForUpdate(MediumDistanceFolder, InMediumDistance)
                        CheckForUpdate(LongDistanceFolder, InLongDistance)
                    end

                    --[[

                    if ShortDistanceFolder and InShortDistance and not (ModelCulledIn and module.RangeCulledIn(CullingReplica, Model, "Short")) then
                        print("Short in distance")
                        CullIn(ShortDistanceFolder, CullingReplica)
                    end

                    if MediumDistanceFolder and InMediumDistance and not (ModelCulledIn and module.RangeCulledIn(CullingReplica, Model, "Medium")) then
                        print("Medium in distance")
                        CullIn(MediumDistanceFolder, CullingReplica)
                    end

                    if LongDistanceFolder and InLongDistance and not (ModelCulledIn and module.RangeCulledIn(CullingReplica, Model, "Long")) then
                        print("Long in distance")
                        CullIn(LongDistanceFolder, CullingReplica)
                    end
                    
                    ]]
                end
            end
        end
    end)
    
end

return module