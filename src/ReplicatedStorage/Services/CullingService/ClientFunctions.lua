local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HelpfulModules = ReplicatedStorage:WaitForChild("HelpfulModules")
local Services = ReplicatedStorage:WaitForChild("Services")
local ReplicaServiceClient = Services:WaitForChild("ReplicaServiceClient")

local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local ReplicaController = require(ReplicaServiceClient:WaitForChild("ReplicaController"))

local module = {
    ["CullingReplica"] = nil, --// Becomes the CullingReplica specific to this client
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
    --[[
        Demo version will check the whole map, broadly searching every check period for whatever is within streaming distance
        Final version should incorporate smarter check methods (ex: take note of where the player is, like what "zone" the player is, and then only search within that zone for better performance)
    ]]

    
end

function module.EndCulling()

end

function module.InitializePlayer(Player: Player)
    if not Player then
        warn("Player arguemnt not passed, unable to initialize culling")
        return

        ReplicaController.ReplicaOfClassCreated("CullingReplica_"..tostring(Player.UserId), function(Replica)
        
        end)
    end

    PieAPI.CharacterAdded(Player, function(Character)
        
    end)
end

return module