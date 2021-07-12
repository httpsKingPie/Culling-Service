local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CullingService = require(ReplicatedStorage:WaitForChild("CullingService"))

CullingService.Initialize()

--// !! Used to show how to cull in moving anchor points, delete below this for your game !!
local TweenService = game:GetService("TweenService")
local AnchorPoints = workspace:WaitForChild("AnchorPoints")

local TweenInformation = TweenInfo.new(
    10, 
    Enum.EasingStyle.Linear,
    Enum.EasingDirection.Out,
    math.huge,
    true
)

local function TweenAnchorPoint(AnchorPoint: BasePart)
    local DistanceZ = 40

    local NewCFrame = CFrame.new(Vector3.new(AnchorPoint.CFrame.X, AnchorPoint.CFrame.Y, DistanceZ))

    local Tween = TweenService:Create(AnchorPoint, TweenInformation, {CFrame = NewCFrame})
    Tween:Play()
end

for _, AnchorPoint in pairs (AnchorPoints:GetChildren()) do
    if AnchorPoint.Name == "WeldAnchorPointTest" then
        TweenAnchorPoint(AnchorPoint)
    end
end