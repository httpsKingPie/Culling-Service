local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OTAM = require(ReplicatedStorage:WaitForChild("OT&AM"))

local CullingService = script.Parent
local Settings = require(CullingService:WaitForChild("Settings"))

local AnchorPoints = workspace:WaitForChild("AnchorPoints")
local CullingRegions = workspace:WaitForChild("CullingRegions")

--[[
    Regions indexes are formatted like "XX.XX.XX"
    Each XX is a number, dots are just for separating numbers
    Numbering starts at 0
    Any region with a 0 means that it is the first of the row (so it probably doesn't have any neighbors)
    The actual value of the table includes all anchor points within the region

    If UseParts is true it looks like

    [XX.XX.XX] = {
        ["Region Part"] = Region Part,
        ["Anchor Points"] = {} simple table,
    }

    If UseParts is false it looks like

    [XX.XX.XX] = {
        ["Region Size"] = Vector3,
        ["Region CFrame"] = CFrame,
        ["Anchor Points"] = {} simple table,
    }
]]

local module = {
    ["Current Region"] = nil, --// Later populated, this will be the Region Index (XX.XX.XX format)
    ["Tracked Regions"] = {}, --// Simple table of all region names that are being tracked
    ["Tracked Anchor Points"] = {}, --// Simple table of all anchor points which need to actually be tracked
    ["Regions"] = {}, --// Formatting info is up above
}

--// Credits to XAXA (this function is soooooo useful) 
--// (https://devforum.roblox.com/t/how-does-roblox-calculate-the-bounding-boxes-on-models-getextentssize/216581/8)
local function GetBoundingBox(Model: Model)
    local ModelDescendants = Model:GetDescendants()

	local Orientation = CFrame.new()
	
	local abs = math.abs
	local Infinity = math.huge

	local MinimumX, MinimumY, MinimumZ = Infinity, Infinity, Infinity
	local MaximumX, MaximumY, MaximumZ = -Infinity, -Infinity, -Infinity

	for _, BasePart in pairs(ModelDescendants) do
		if BasePart:IsA("BasePart") and not BasePart:IsA("Terrain") then
			local BasePartCFrame = BasePart.CFrame
			BasePartCFrame = Orientation:ToObjectSpace(BasePartCFrame)

			local Size = BasePart.Size
			local SizeX, SizeY, SizeZ = Size.X, Size.Y, Size.Z

			local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = BasePartCFrame:GetComponents()

			local WorldSpaceX = 0.5 * (abs(R00) * SizeX + abs(R01) * SizeY + abs(R02) * SizeZ)
			local WorldSpaceY = 0.5 * (abs(R10) * SizeX + abs(R11) * SizeY + abs(R12) * SizeZ)
			local WorldSpaceZ = 0.5 * (abs(R20) * SizeX + abs(R21) * SizeY + abs(R22) * SizeZ)

			if MinimumX > X - WorldSpaceX then
				MinimumX = X - WorldSpaceX
			end

			if MinimumY > Y - WorldSpaceY then
				MinimumY = Y - WorldSpaceY
			end

			if MinimumZ > Z - WorldSpaceZ then
				MinimumZ = Z - WorldSpaceZ
			end

			if MaximumX < X + WorldSpaceX then
				MaximumX = X + WorldSpaceX
			end

			if MaximumY < Y + WorldSpaceY then
				MaximumY = Y + WorldSpaceY
			end

			if MaximumZ < Z + WorldSpaceZ then
				MaximumZ = Z + WorldSpaceZ
			end
		end
	end

	local ObjectMinimum, ObjectMaximum = Vector3.new(MinimumX, MinimumY, MinimumZ), Vector3.new(MaximumX, MaximumY, MaximumZ)
	local ObjectMiddle = (ObjectMaximum+ObjectMinimum)/2
	local WorldCFrame = Orientation - Orientation.p + Orientation:PointToWorldSpace(ObjectMiddle)
	local Size = (ObjectMaximum-ObjectMinimum)

	return WorldCFrame, Size
end

--// Credits https://devforum.roblox.com/t/how-do-i-get-a-player-from-a-zone/464473/7
local function CheckInsideRegion(PositionToCheck, BoundingBoxCFrame, BoundingBoxSize)
	local BBVector3 = BoundingBoxCFrame:PointToObjectSpace(PositionToCheck)
	return (math.abs(BBVector3.X) <= BoundingBoxSize.X / 2)
		and (math.abs(BBVector3.Y) <= BoundingBoxSize.Y / 2)
		and (math.abs(BBVector3.Z) <= BoundingBoxSize.Z / 2)
end

local function QuickPart(PartSize: Vector3, PartCFrame: CFrame)
    local Part = Instance.new("Part")
    Part.Anchored = true
    Part.CanCollide = false
    Part.Transparency = 1
    Part.Size = PartSize
    Part.CFrame = PartCFrame

    Part.Parent = CullingRegions
        
    return Part
end

local function SortAnchorPointsIntoRegions()
    local AnchorPointsToCheck = {}

    --// Create a quick copy of the table
    for _, AnchorPoint in pairs (AnchorPoints:GetChildren()) do
        table.insert(AnchorPointsToCheck, AnchorPoint)
    end

    --// Optimize this later, just not sure if there's a better method
    for _, RegionData in pairs (module["Regions"]) do
        for Index, AnchorPoint in pairs (AnchorPointsToCheck) do
            local InsideRegion: boolean

            if Settings["Use Parts"] == true then
                InsideRegion = CheckInsideRegion(AnchorPoint.Position, RegionData["Region Part"].CFrame, RegionData["Region Part"].Size)
            elseif Settings["Use Parts"] == false then
                InsideRegion = CheckInsideRegion(AnchorPoint.Position, RegionData["Region CFrame"], RegionData["Region Size"])
            end

            if InsideRegion then
                --// Theoretically, it will get faster and faster as it loops through, since less entries
                table.insert(RegionData["Anchor Points"], AnchorPoint)
                table.remove(AnchorPointsToCheck, Index)
            end
        end
    end
end

local function ReturnRegionsToTrack()
    if not module["Current Region"] then
        return warn("No current region - unable to create regions to track")
    end

    local SplitString: table = string.split(module["Current Region"], ".")

    --// Coordinate number values
    local XValue = tonumber(SplitString[1])
    local YValue = tonumber(SplitString[2])
    local ZValue = tonumber(SplitString[3])

    local RegionsToTrack = {}
    
    --// If you have a basic index like 5.5.5, have modifiers of (0, 1, 1) this will give you an adjacent region index of 5.6.6
    local function AddAdjacentRegion(XModifier: number, YModifier: number, ZModifier: number)
        local AdjacentRegionName = tostring(XValue + XModifier) .. "." .. tostring(YValue + YModifier) .. "." .. tostring(ZValue + ZModifier)

        --// It's okay if the region doesn't exist, because some regions (especially in the y direction won't often have stuff)
        if module["Regions"][AdjacentRegionName] then
            table.insert(RegionsToTrack, AdjacentRegionName)
        end
    end

    --// Get adjacent regions in 3D space

    --// At same Y value
    AddAdjacentRegion(0, 0, -1)
    AddAdjacentRegion(0, 0, 0)
    AddAdjacentRegion(0, 0, 1)
    AddAdjacentRegion(1, 0, -1)
    AddAdjacentRegion(1, 0, 0)
    AddAdjacentRegion(1, 0, 1)
    AddAdjacentRegion(-1, 0, -1)
    AddAdjacentRegion(-1, 0, 0)
    AddAdjacentRegion(-1, 0, 1)

    --// At Y value below
    AddAdjacentRegion(0, -1, -1)
    AddAdjacentRegion(0, -1, 0)
    AddAdjacentRegion(0, -1, 1)
    AddAdjacentRegion(1, -1, -1)
    AddAdjacentRegion(1, -1, 0)
    AddAdjacentRegion(1, -1, 1)
    AddAdjacentRegion(-1, -1, -1)
    AddAdjacentRegion(-1, -1, 0)
    AddAdjacentRegion(-1, -1, 1)

    --// At Y value above
    AddAdjacentRegion(0, 1, -1)
    AddAdjacentRegion(0, 1, 0)
    AddAdjacentRegion(0, 1, 1)
    AddAdjacentRegion(1, 1, -1)
    AddAdjacentRegion(1, 1, 0)
    AddAdjacentRegion(1, 1, 1)
    AddAdjacentRegion(-1, 1, -1)
    AddAdjacentRegion(-1, 1, 0)
    AddAdjacentRegion(-1, 1, 1)

    return RegionsToTrack
end

local function ReturnAnchorPointsToTrack()
    if not module["Tracked Regions"] then
        warn("Not currently in a region - cannot track anchor points")
        return
    end

    local AnchorPointsToTrack = {}

    for _, RegionIndexName in pairs (module["Tracked Regions"]) do
        local RegionData = module["Regions"][RegionIndexName]

        for _, AnchorPoint in pairs (RegionData["Anchor Points"]) do
            table.insert(AnchorPointsToTrack, AnchorPoint)
        end
    end

    return AnchorPointsToTrack
end

function module:GenerateInternalRegions()
    --// Basic data about the BoundingBox of the workspace
    local BoundingBoxCFrame, BoundingBoxSize = GetBoundingBox(workspace)
    
    --// Store the edge position so that regions can be sequentially created
    local EdgePosition = BoundingBoxCFrame.Position - Vector3.new(((BoundingBoxSize.X)/2), (BoundingBoxSize.Y)/2, (BoundingBoxSize.Z)/2)

    --// Booleans which determine if a row has been fully checked
    local CheckedAllX = false
    local CheckedAllY = false
    local CheckedAllZ = false

    --// Store current iteration
    local CurrentXIteration = 0
    local CurrentYIteration = 0
    local CurrentZIteration = 0
    
    --// Number values (filled in later) which save the amount of moves needed to fill the BoundingBox
    local MovesX
    local MovesZ

    --// Generate the part for the region and store it
    local function GenerateRegion(RegionSize: Vector3, RegionCFrame: CFrame)
        local IndexName = tostring(CurrentXIteration) .. "." .. tostring(CurrentYIteration) .. "." .. tostring(CurrentZIteration)

        if Settings["Use Parts"] == true then
            local Region = QuickPart(RegionSize, RegionCFrame)

            module["Regions"][IndexName] = {}
            module["Regions"][IndexName]["Region Part"] = Region
            module["Regions"][IndexName]["Anchor Points"] = {}
    
            Region.Name = IndexName
        elseif Settings["Use Parts"] == false then
            module["Regions"][IndexName] = {}
            module["Regions"][IndexName]["Region Size"] = RegionSize
            module["Regions"][IndexName]["Region CFrame"] = RegionCFrame
            module["Regions"][IndexName]["Anchor Points"] = {}
        end
        
    end
    
    local function ParseAlongX()
        local NewPositionX
        
        local function FinalParseX()
            GenerateRegion(Vector3.new(Settings["Region Length"], Settings["Region Length"], Settings["Region Length"]), NewPositionX)
            CheckedAllX = true --// Ends the loop, for now
            CurrentXIteration = 0
        end
        
        while not CheckedAllX do
            NewPositionX = CFrame.new(EdgePosition + Vector3.new(Settings["Region Length"] * CurrentXIteration, Settings["Region Length"] * CurrentYIteration, Settings["Region Length"] * CurrentZIteration))
    
            GenerateRegion(Vector3.new(Settings["Region Length"], Settings["Region Length"], Settings["Region Length"]), NewPositionX)
    
            CurrentXIteration = CurrentXIteration + 1 --// Also representative of the amount of times parsed
            
            if not MovesX then
                --// Assign the amount of times that this should move (since it moves along a box, we don't need to calculate every time)
                
                if not CheckInsideRegion(NewPositionX.Position, BoundingBoxCFrame, BoundingBoxSize) then
                    MovesX = CurrentXIteration
                    FinalParseX()
                end
            else
                if MovesX <= CurrentXIteration then
                    FinalParseX()
                end
            end
        end
    end
    
    local function OrientAlongZ()
        while not CheckedAllZ do
            --// Parse along the x dimension
            ParseAlongX()
    
            --// Align to a new Z
            CurrentZIteration = CurrentZIteration + 1
            local NewPositionZ = EdgePosition + Vector3.new(0, 0, Settings["Region Length"] * CurrentZIteration)
    
            CheckedAllX = false --// Parse along x for the new z variable
            
            if not MovesZ then
                if not CheckInsideRegion(NewPositionZ, BoundingBoxCFrame, BoundingBoxSize) then
                    MovesZ = CurrentZIteration
                    
                    ParseAlongX()
                    
                    CheckedAllZ = true
                    CurrentZIteration = 0
                end
            else
                if MovesZ <= CurrentZIteration then
                    ParseAlongX()
                    
                    CheckedAllZ = true
                    CurrentZIteration = 0
                end
            end
        end
    end
    
    local function GenerateBoxRegions()
        --// Parse along the y dimension
        while not CheckedAllY do
            OrientAlongZ()
            
            CurrentYIteration = CurrentYIteration + 1
            local NewPositionY = EdgePosition + Vector3.new(0, Settings["Region Length"] * CurrentYIteration, 0)
            
            CheckedAllX = false
            CheckedAllZ = false
            
            if not CheckInsideRegion(NewPositionY, BoundingBoxCFrame, BoundingBoxSize) then
                CheckedAllY = true
                
                OrientAlongZ()
                
                CurrentYIteration = 0
            end
        end
    end

    --// Generate internal regions
    GenerateBoxRegions()

    --// Place anchor points within each region
    SortAnchorPointsIntoRegions()
end

function module:TrackRegionChanges()
    --// Set up events to log region changes
    for RegionName, RegionData in pairs (module["Regions"]) do
        local TrackedRegion

        if Settings["Use Parts"] == true then
            TrackedRegion = OTAM.addArea(RegionName, RegionData["Region Part"])
        elseif Settings["Use Parts"] == false then
            TrackedRegion = OTAM.addArea(RegionName, RegionData["Region CFrame"], RegionData["Region Size"])
        end

        TrackedRegion.onEnter:Connect(function()
            module["Current Region"] = RegionName

            --// Update the Tracked Regions
            module["Tracked Regions"] = ReturnRegionsToTrack()
            module["Tracked Anchor Points"] = ReturnAnchorPointsToTrack()
        end)
    end
end

function module:ReturnTrackedRegions()
    return module["Tracked Regions"]
end

function module:ReturnTrackedAnchorPoints()
    return module["Tracked Anchor Points"]
end

return module