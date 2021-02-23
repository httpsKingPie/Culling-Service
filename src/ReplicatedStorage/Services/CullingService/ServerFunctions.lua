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
    local CullingReplica = ReplicaService.NewClassToken({
        ClassToken = ReplicaService.NewClassToken("CullingReplica_"..tostring(Player.UserId)),
        Data = {
            ActiveObjects = {} --// No data yet
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
            --// Deprecated function, but it's the only way to effectively and reliably find the center of a model (even though Roblox contests it isn't)
            module["Octree"]:CreateNode(Model:GetModelCFrame().Position, Model)
        end
    end
end

function module.GetCulledModels(CullingReplica) --// Returns models that are currently loaded in
    return CullingReplica.Data.ActiveObjects
end

function module.Initialize()
    module.InitializeOctree() --// Creates Octress for fast searching

    PieAPI.PlayerAdded(function(Player)
        module.InitializePlayer(Player)

        local CullingReplica = module.GetPlayerReplica(Player)
        local HumanoidRootPart

        PieAPI.CharacterAdded(Player, function(Character)
            HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

            local Humanoid = Character:WaitForChild("Humanoid")

            Humanoid.Died:Connect(function()
                HumanoidRootPart = nil
            end)
        end)

        while true do
            wait(Settings["Wait Time"])
            
            local CulledObjects = module.GetCulledModels(CullingReplica)

            if HumanoidRootPart then
                local SearchTable = {
                    ["Short"] = module["Octree"]:RadiusSearch(HumanoidRootPart.Position, Settings["Distances"]["Short"]),
                    ["Medium"] = module["Octree"]:RadiusSearch(HumanoidRootPart.Position, Settings["Distances"]["Medium"]),
                    ["Long"] = module["Octree"]:RadiusSearch(HumanoidRootPart.Position, Settings["Distances"]["Long"])
                }

                for DistanceType, RadiusSearch in pairs (SearchTable) do
                    for _, Model in ipairs (RadiusSearch) do
                        local IsInTable = table.find(module["Player Information"][Player.Name]["Culled Models"])

                        if not IsInTable then
                            table.insert()
                        end
                    end
                end
            end
        end
    end)
    
end

return module