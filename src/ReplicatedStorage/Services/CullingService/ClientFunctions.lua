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

function module.CullIn(Object)

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

        ReplicaController.ReplicaOfClassCreated("CullingReplica_"..tostring(Player.UserId), function(Replica)

            Replica:ListenToArrayInsert({"ActiveObjects"}, function(Objects) --// Listens to stuff added to the active objects
                if module["Paused"] then
                    module.CullIn(Objects)
                end
            end)

            Replica:ListenToArrayRemove({"ActiveObjects"}, function(Models) --// Listens to stuff removed from the active objects
                if module["Paused"] then
                    module.CullOut(Models)
                end
            end)

        end)
    end

    PieAPI.CharacterAdded(Player, function(Character)
        
    end)
end

return module