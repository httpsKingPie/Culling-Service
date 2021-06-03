local GroupService = game:GetService("GroupService") --// Apparently less prone to errors per https://devforum.roblox.com/t/player-getrankingroup-is-inaccurate-causing-anti-cheat-to-call-false-positives/742456/4?u=https_kingpie
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local module = {}

local RemoteCooldown = {}

function module:CheckNumber(Input)
	if tonumber(Input) ~= nil then
		return true
	else
		return false
	end
end

function module:ValidateCurrentRuntimeEnvironment(RunEnvironment: string)
    if RunEnvironment == "Client" then
        if RunService:IsClient() then
            return true
        end

        warn("Attempted to access Client Runtime from the Server")
        return false
    elseif RunEnvironment == "Server" then
        if RunService:IsServer() then
            return true
        end

        warn("Attempted to access Server Runtime from the Client")
        return false
    end
end

function module:Round(Number,NumberOfDecimalPlaces)
	local Multiple = 10^(NumberOfDecimalPlaces or 0)
	return math.floor(Number * Multiple + 0.5) / Multiple
end

function module:RemoveNumbers(String: string)
	return string.gsub(String, "[^a-zA-Z]", "") 
end

function module:RemoteCooldownTimer(RemoteName, PlayerName, Time)
	if RemoteCooldown[RemoteName] == nil then
		RemoteCooldown[RemoteName] = {}
	end
	
	if RemoteCooldown[RemoteName][PlayerName] == nil then
		RemoteCooldown[RemoteName][PlayerName] = tick()
		return true
	else
		if (tick() - RemoteCooldown[RemoteName][PlayerName]) > Time then
			RemoteCooldown[RemoteName][PlayerName] = tick()
			return true
		else
			return false
		end
	end
end

function module:WaitForAllChildren(Model, WaitTime)
	local Children = Model:GetChildren()
	
	while #Children == 0 do --// Sometimes the children returned is 0 for some reason, so this rechecks
		Children = Model:GetChildren()
		wait(WaitTime)
	end
end

function module:ResizeYOffsetForTextFit(GuiObject, OffsetIncrement)
	if GuiObject.TextFits ~= nil then
		while GuiObject.TextFits == false do
			GuiObject.Size = GuiObject.Size + UDim2.new(0, 0, 0, OffsetIncrement)
		end
	else
		warn("TextFits is not a valid property of ".. tostring(GuiObject.Name))
	end
end

function module:ResizeScrollingFrameCanvasYSize(ScrollingFrame, AbsoluteSizeInstance, OptionalBufferSize)
	if OptionalBufferSize == nil then
		ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, AbsoluteSizeInstance.AbsoluteContentSize.Y)
	else
		ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, AbsoluteSizeInstance.AbsoluteContentSize.Y + OptionalBufferSize)
	end
end

function module:Weld(Part1, Part2)
	local Weld = Instance.new("WeldConstraint")
	Weld.Parent = Part1
	Weld.Part0 = Part1
	Weld.Part1 = Part2
end

--// Less error prone method of detecting if player is in a group
function module.PlayerIsInGroup(Player: Player, GroupId: number)
	local PlayerGroups

    local Success, ErrorMessage = pcall(function()
        PlayerGroups = GroupService:GetGroupsAsync(Player.UserId)
    end)

	if not Success then
		warn("HTTP error loading player groups")
		return
	end

	for _, GroupInformation in pairs (PlayerGroups) do
        if GroupInformation.Id == GroupId then
            return true
        end
    end

	return false
end

--// Less error prone way of getting a player's rank in a group
function module:PlayerGetRankInGroup(Player: Player, GroupId: number)
	local PlayerGroups

    local Success, ErrorMessage = pcall(function()
        PlayerGroups = GroupService:GetGroupsAsync(Player.UserId)
    end)

	if not Success then
		warn("HTTP error loading player groups")
		return
	end

	for _, GroupInformation in pairs (PlayerGroups) do
        if GroupInformation.Id == GroupId then
            return GroupInformation.Rank
        end
    end

	return 0
end

--// Less error prone way of getting a player's role in a group
function module:PlayerGetRoleInGroup(Player: Player, GroupId: number)
	local PlayerGroups

    local Success, ErrorMessage = pcall(function()
        PlayerGroups = GroupService:GetGroupsAsync(Player.UserId)
    end)

	if not Success then
		warn("HTTP error loading player groups")
		return
	end

	for _, GroupInformation in pairs (PlayerGroups) do
        if GroupInformation.Id == GroupId then
            return GroupInformation.Role
        end
    end

	return "Guest"
end

--// Alternative to PlayerAdded the affects players already in the game
function module.PlayerAdded(BoundFunction, ...)
	local Args = {...}
	
	if type(BoundFunction) ~= "function" then
		warn("Pass a function as the first argument")
		return
	end
	
	Players.PlayerAdded:Connect(function(Player)
		BoundFunction(Player, table.unpack(Args))
	end)
	
	local AllPlayers = Players:GetPlayers()
	
	for i = 1, #AllPlayers do
		BoundFunction(AllPlayers[i], table.unpack(Args))
	end
end

--// Alternative to Player.CharacterAdded which affects characters already loaded in
function module.CharacterAdded(Player, BoundFunction, ...)
	local Args = {...}
	
	if type(Player) ~= "userdata" or Player:IsA("Player") == false or Player.Parent == nil then
		warn("Invalid player instance provided as first argument")
		return
	end
	
	if type(BoundFunction) ~= "function" then
		warn("Pass a function as the second argument")
		return
	end
	
	if Player.Character then
		BoundFunction(Player.Character, table.unpack(Args))
		
		Player.CharacterAdded:Connect(function(Character)
			BoundFunction(Character, table.unpack(Args))
		end)
	end
	
	Player.CharacterAdded:Connect(function(Character)
		BoundFunction(Character, table.unpack(Args))
	end)
end

return module