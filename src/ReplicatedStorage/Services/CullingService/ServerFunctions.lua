local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HelpfulModules = ReplicatedStorage.HelpfulModules
local OctreeModule = require(script.Parent.Octree)
local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaService = require(ServerScriptService.ReplicaServiceServer.ReplicaService)

local Settings = require(script.Parent.Settings)

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

local function InDistance(ModelDistance: number, MaximumDistance: number)
    if ModelDistance <= MaximumDistance then
        return true
    else
        return false
    end
end

local function CullIn(DistanceFolder: Folder)

end

function module.GetPlayerReplica(Player)
    if not module["Player Information"][Player.Name] then
        warn("Played not initialized - unable to load culling replica")
        return
    end

    return module["Player Information"][Player.Name]["Culling Replica"]
end

function module.InitializeOctree()
    for _, Model in pairs (workspace:GetChildren()) do
        if Model:IsA("Model") then
            --// GetModelCFrame is a deprecated function, but it's the only way to effectively and reliably find the center of a model (even though Roblox contests it isn't)
            
            module["Octree"]:CreateNode(Model:GetModelCFrame().Position, Model)
        end
    end
end

function module.GetCulledModels(CullingReplica) --// Returns models that are currently loaded in
    return CullingReplica.Data.ActiveObjects
end

function module.GetCulledRanges(CullingReplica, Model: Model)
    local TableIndex = table.find(CullingReplica.Data.ActiveObjects, Model)

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

                local CulledObjects = module.GetCulledModels(CullingReplica)

                local ModelsInRadius, DistancesSquared = module["Octree"]:RadiusSearch(HumanoidRootPart.Position, Settings["Distances"]["Long"]) --// Search for all nodes at the furthest distances (long)

                for Index, Model in ipairs (ModelsInRadius) do
                    local ShortDistanceFolder = Model:FindFirstChild("Short")
                    local MediumDistanceFolder = Model:FindFirstChild("Medium")
                    local LongDistanceFolder = Model:FindFirstChild("Long")

                    --[[
                        Check for:
                            * Model not already culled in
                            * Model is in d
                    ]]

                    if not (CulledObjects[Model] ) and ShortDistanceFolder and InDistance(math.sqrt(DistancesSquared[Index]), Settings["Distances"]["Short"]) then
                        print("Short in distance")
                    end

                    if not CulledObjects[Model] and MediumDistanceFolder and InDistance(math.sqrt(DistancesSquared[Index]), Settings["Distances"]["Medium"]) then
                        print("Medium in distance")
                    end

                    if not CulledObjects[Model] and LongDistanceFolder and InDistance(math.sqrt(DistancesSquared[Index]), Settings["Distances"]["Long"]) then
                        print("Long in distance")
                    end
                end
            end
        end
    end)
    
end

return module