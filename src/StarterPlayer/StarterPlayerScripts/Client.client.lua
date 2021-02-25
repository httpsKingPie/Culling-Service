local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = ReplicatedStorage:WaitForChild("Services")

local CullingService = require(Services:WaitForChild("CullingService"))

local ReplicaServiceClient = Services:WaitForChild("ReplicaServiceClient")
local ReplicaController = require(ReplicaServiceClient:WaitForChild("ReplicaController"))

ReplicaController.RequestData()