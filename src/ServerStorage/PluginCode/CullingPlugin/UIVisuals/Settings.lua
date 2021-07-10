local module = {
    --[[
    ["Color Frame Intro Properties"] = {
        Time = .5,
        EasingStyle = "Linear",
        Goal = {
            ["BackgroundTransparency"] = 0
        },
    },

    ["Color Frame Exit Properties"] = {
        Time = .5,
        EasingStyle = "Linear",
        Goal = {
            ["BackgroundTransparency"] = 1
        },
    },
    ]]

    ["Color Frame Tween Information"] = TweenInfo.new(
        .5, 
        Enum.EasingStyle.Linear
    ),

    ["Required Settings"] = {
        ["Sound"] = {
            "Name",
            "SoundId",
        },
    },
}

return module