local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HelpfulModules = ReplicatedStorage.HelpfulModules
local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaService = require(ServerScriptService.ReplicaServiceServer.ReplicaService)

local Settings = require(script.Parent.Settings)

local module = {
    ["Player Information"] = {},  --// Store all Player replicas and what zone they are in here
    ["Zones"] =  {}
}

function module.InitializePlayer(Player: Player)
     --// Generate a specific replica for each player
    local CullingReplica = ReplicaService.NewClassToken({
        ClassToken = ReplicaService.NewClassToken("CullingReplica_"..tostring(Player.UserId)),
        Data = {  --// No data yet
            ["Short Range"] = {},
            ["Medium Range"] = {},
            ["Long Range"] = {},
        },
        Replication = Player,
    })

    --// Store it for access later and create some variables for the player
    module["Player Information"][Player.Name] = {}
    module["Player Information"][Player.Name]["Current Zone"] = ""
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

local function InitializeZones()

end

function module.Initialize()
    InitializeZones() --// Creates the zones to make searching more efficient
    while true do
        wait(Settings["Wait Time"])
    end
end

return module