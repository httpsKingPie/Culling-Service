local module = {
    ["Animation Package"] = nil, --// Defaults to nil for backwards compatability

    ["Distances"] = {
        --// Distances for culling things in (you are able to add more!)
        ["Short"] = 20,
        ["Medium"] = 50,
        ["Long"] = 100,
    },

    ["Paused"] = false, --// Whether the CullingService is paused, defaults to false.  This setting can be changed via the :Pause and :Resume functions

    ["Region Length"] = 100, --// This is an invisible cube length.  Make sure this is *at least* one-thirds the length of your largest value in ["Distances"] (recommend to exceed that, otherwise you may get streaming issues)  Customize to your liking
    
    ["Use Parts"] = false, --// Whether CullingService creates a physical part that the player walks into to work or just uses CFrame positions

    ["Wait Time"] = .5, --// Determines how often CullingService checks to cull things in or out

    --[[
        Put the names of AnchorPoints/their models (should have the same name) here that you want to be welded together.
        Useful for moving stuff
        Format like {"ModelName1", "WhateverThisModelIsCalled", etc. and so on}
    ]]
    
    ["Welded Anchor Points"] = {"WeldAnchorPointTest"}, --// What is currently here is just a dummy value, feel free to remove it
}

return module