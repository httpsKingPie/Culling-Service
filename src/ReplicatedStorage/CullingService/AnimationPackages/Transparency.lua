local TweenService = game:GetService("TweenService")

local TweenInformation = TweenInfo.new(
    1,
    Enum.EasingStyle.Linear
)

local function CullInAnimation(BasePart: BasePart)
    local OriginalTransparency = BasePart.Transparency

    --// Reduce redundancy
    if OriginalTransparency == 1 then
        return
    end

    BasePart.Transparency = 1

    local Tween = TweenService:Create(BasePart, TweenInformation, {["Transparency"] = OriginalTransparency})

    Tween:Play()

    Tween.Completed:Connect(function()
        Tween:Destroy()
    end)
end

local function CullOutAnimation(BasePart: BasePart)
    local function RecursiveFindTrueParent(InstanceToCheck)
        local InstanceParent = InstanceToCheck.Parent

        if InstanceParent:IsA("Folder") then
            return InstanceParent
        else
            local Parent = RecursiveFindTrueParent(InstanceParent)

            if Parent then
                return Parent
            end
        end
    end

    local TrueParent = RecursiveFindTrueParent(BasePart)

    local OriginalTransparency = BasePart.Transparency

    --// Reduce redundancy
    if OriginalTransparency == 1 then
        return
    end

    local Tween = TweenService:Create(BasePart, TweenInformation, {["Transparency"] = 1})

    Tween:Play()

    Tween.Completed:Once(function()
        Tween:Destroy()
    end)

    --// Reset to the original transparency
    local ParentChanged: RBXScriptSignal = TrueParent:GetPropertyChangedSignal("Parent")

    ParentChanged:Connect(function()
        if BasePart then
            BasePart.Transparency = OriginalTransparency
        end
    end)
end

local CullTypeFunctions = {
    ["CullIn"] = CullInAnimation,
    ["CullOut"] = CullOutAnimation,
}

--// CullType == "CullIn", "CullOut", or "CullUpdate" and sequences to CullIn or CullOut
return function(ObjectToAnimate: Model | BasePart | Folder, CullType: string)
    local CullTypeFunction = CullTypeFunctions[CullType]

    if not CullTypeFunction then
        warn("No CullTypeFunction found for", CullType)

        return
    end

    if ObjectToAnimate:IsA("BasePart") then
        CullTypeFunction(ObjectToAnimate)
    end

    for _, Descendant: BasePart in pairs (ObjectToAnimate: GetDescendants()) do
        if not Descendant:IsA("BasePart") then
            continue
        end

        CullTypeFunction(Descendant)
    end

    --// This is to make the thread yield until all the tweens are done (to prevent it from being destryed to before the animations finish
    if CullType == "CullOut" then
        task.wait(TweenInformation.Time + .1)
    end
end