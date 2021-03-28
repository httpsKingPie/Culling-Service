local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local module = {}

if RunService:IsClient() then
    local Handler = require(script.Handler)

    local LocalPlayer = Players.LocalPlayer

    Handler.InitializePlayer(LocalPlayer)
else
    warn("CullingService attempted to run on the server - please run this on the client")
end

return module