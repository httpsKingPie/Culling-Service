--// Minimized version of GuiService - containing only the essentials

local TweenService = game:GetService("TweenService")

local module = {}

function module:BindInputEndedMouseButton1(TableOfInstances: table, BoundFunction, ...)
    local Arguments = {...}

    for _, GuiElement in pairs (TableOfInstances) do
        GuiElement.InputEnded:Connect(function(Input: InputObject)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                BoundFunction(table.unpack(Arguments))
            end
        end)
    end
end

function module:BindMouseButton1Click(TableOfInstances: table, BoundFunction, ...)
    local Arguments = {...}

    for _, GuiButton: GuiButton in pairs (TableOfInstances) do
        if GuiButton:IsA("GuiButton") then
            GuiButton.MouseButton1Click:Connect(function()
                if GuiButton.Visible == false then --// If it is invisible, this will not fire
                    return
                end
                
                BoundFunction(table.unpack(Arguments))
            end)
        else
            warn("Unable to bind mouse button 1 click function to", GuiButton.Name, "because it is not a GuiButton")
        end
    end
end

function module:BindMouseLeave(TableOfInstances: table, BoundFunction, ...)
    local Arguments = {...}

    for _, GuiButton: GuiButton in pairs (TableOfInstances) do
        if GuiButton:IsA("GuiButton") then
            GuiButton.MouseLeave:Connect(function()
                if GuiButton.Visible == false then --// If it is invisible, this will not fire
                    return
                end
                
                BoundFunction(table.unpack(Arguments))
            end)
        else
            warn("Unable to bind mouse leave function to", GuiButton.Name, "because it is not a GuiButton")
        end
    end
end

function module:BindMouseEnter(TableOfInstances: table, BoundFunction, ...)
    local Arguments = {...}

    for _, GuiButton: GuiButton in pairs (TableOfInstances) do
        if GuiButton:IsA("GuiButton") then
            GuiButton.MouseEnter:Connect(function()
                if GuiButton.Visible == false then --// If it is invisible, this will not fire
                    return
                end
                
                BoundFunction(table.unpack(Arguments))
            end)
        else
            warn("Unable to bind mouse enter function to", GuiButton.Name, "because it is not a GuiButton")
        end
    end
end

function module:ClearGuiObjectChildren(TableOfInstances: table)
    for _, GuiElement in pairs (TableOfInstances) do
        for _, GuiObject in pairs (GuiElement:GetChildren()) do
            if GuiObject:IsA("GuiObject") then
                GuiObject:Destroy()
            end
        end
    end
end

function module:HandlePrefixAndSuffix(OriginalText: string, PrefixSuffixTable: table)
    if OriginalText == nil then
        OriginalText = ""
    end
    
    local NewText = OriginalText

    if PrefixSuffixTable["Prefix"] then
        NewText = PrefixSuffixTable["Prefix"] .. NewText
    end

    if PrefixSuffixTable["Suffix"] then
        NewText = NewText.. PrefixSuffixTable["Suffix"]
    end

    return NewText
end

--// Automatically size a scrolling frame based on Y size
function module:ResizeScrollingFrameCanvasYSize(ScrollingFrame: ScrollingFrame, AbsoluteYSize: number, OptionalBufferSize: number)
	if OptionalBufferSize then
		AbsoluteYSize = AbsoluteYSize + OptionalBufferSize
	end

	ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, AbsoluteYSize)
end

function module:ResizeYOffsetForTextFit(GuiObject: GuiObject, OffsetIncrement: number)
	if GuiObject.TextFits ~= nil then
		while GuiObject.TextFits == false do
			GuiObject.Size = GuiObject.Size + UDim2.new(0, 0, 0, OffsetIncrement)
		end
	else
		warn("TextFits is not a valid property of ".. tostring(GuiObject.Name))
	end
end

function module:ConvertScaleSizeToOffset(GuiObject: GuiObject)
    local AbsoluteSize: Vector2 = GuiObject.AbsoluteSize

    GuiObject.Size = UDim2.new(0, AbsoluteSize.X, 0, AbsoluteSize.Y)
end

function module:ChangeVisibility(TableOfInstances: table, VisibibilityState: boolean)
    for _, GuiObject: GuiObject in pairs (TableOfInstances) do
        GuiObject.Visible = VisibibilityState
    end
end

return module