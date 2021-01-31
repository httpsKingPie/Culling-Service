local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HelpfulModules = ReplicatedStorage.HelpfulModules
local PieAPI = require(HelpfulModules:WaitForChild("PieAPI"))

local Settings = require(script.Settings)

local module = {}

if RunService:IsClient() then
    local ClientFunctions = require(script.ClientFunctions)

    local LocalPlayer = Players.LocalPlayer

    ClientFunctions.InitializePlayer(LocalPlayer)
end

if RunService:IsServer() then
    local ServerFunctions = require(script.ServerFunctions)

    
end

return module