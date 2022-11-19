local TweenService = game:GetService("TweenService")

local TweenInInformation = TweenInfo.new(
    2,
    Enum.EasingStyle.Quart,
    Enum.EasingDirection.Out
)

local TweenOutInformation = TweenInfo.new(
    2,
    Enum.EasingStyle.Quart,
    Enum.EasingDirection.In
)

local FlyHeight = 300

local function CullInAnimation(BasePart: BasePart)
    local AdjustedPosition = BasePart.Position + (Vector3.new(0, FlyHeight, 0))
    local TargetPosition = BasePart.Position

    BasePart.Position = AdjustedPosition

    local Tween = TweenService:Create(BasePart, TweenInInformation, {["Position"] = TargetPosition})

    Tween:Play()

    Tween.Completed:Connect(function()
        Tween:Destroy()
    end)
end

local function CullOutAnimation(BasePart: BasePart)
    local TargetPosition = BasePart.Position + (Vector3.new(0, FlyHeight, 0))

    local Tween = TweenService:Create(BasePart, TweenOutInformation, {["Position"] = TargetPosition})

    Tween:Play()

    Tween.Completed:Connect(function()
        Tween:Destroy()
    end)
end

local CullTypeFunctions = {
    ["CullIn"] = CullInAnimation,
    ["CullOut"] = CullOutAnimation,
}

--// CullType == "CullIn", "CullOut", or "CullUpdate" and sequences to CullIn or CullOut
return function(ObjectToAnimate: Model, CullType: string)
    if not ObjectToAnimate:IsA("Model") then
        return
    end

    local CullTypeFunction = CullTypeFunctions[CullType]

    if not CullTypeFunction then
        warn("No CullTypeFunction found for", CullType)

        return
    end

    for _, Descendant: BasePart in pairs (ObjectToAnimate: GetDescendants()) do
        if not Descendant:IsA("BasePart") then
            continue
        end

        CullTypeFunction(Descendant)
    end

    --// This is to make the thread yield until all the tweens are done (to prevent it from being destryed to before the animations finish
    if CullType == "CullOut" then
        task.wait(TweenOutInformation.Time + .1)
    end
end