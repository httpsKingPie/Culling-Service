local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HelpfulModules = ReplicatedStorage.HelpfulModules
local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaService = require(ServerScriptService.ReplicaServiceServer.ReplicaService)

local module = {} --// Store all Player replicas here

function module.InitializePlayer(Player: Player)
     --// Generate a specific replica for each player
    local CullingReplica = ReplicaService.NewClassToken({
        ClassToken = ReplicaService.NewClassToken("CullingReplica_"..tostring(Player.UserId)),
        Data = {}, --// No data yet
        Replication = Player,
    })

    --// Store it for access later and create some variables for the player
    module[Player.Name] = {}
    module[Player.Name] = CullingReplica

end

return module