local Players = game:GetService("Players")

local module = {}

local RemoteCooldown = {}

function module:CheckNumber(Input)
	if tonumber(Input) ~= nil then
		return true
	else
		return false
	end
end

function module:Round(Number,NumberOfDecimalPlaces)
	local Multiple = 10^(NumberOfDecimalPlaces or 0)
	return math.floor(Number * Multiple + 0.5) / Multiple
end

function module:RemoveNumbers(String)
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

--// Just use regular PlayerRemoving - there's no way to really improve that one (that I know of atm)

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