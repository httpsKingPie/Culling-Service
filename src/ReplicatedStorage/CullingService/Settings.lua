local module = {
    ["Distances"] = {
        --// Distances for culling things in
        ["Short"] = 20,
        ["Medium"] = 50,
        ["Long"] = 100,
    },

    ["Paused"] = false, --// Whether the CullingService is paused, defaults to false.  This setting can be changed via the :Pause and :Resume functions

    ["Region Length"] = 100, --// This is an invisible cube length.  Make sure this value is at least a third of the search radius.  Customize to your liking
    
    ["Wait Time"] = .5, --// Determines how often CullingService checks to cull things in or out

    --[[
        Put the names of AnchorPoints/their models (should have the same name) here that you want to be welded together.
        Useful for moving stuff
        Format like {"ModelName1", "WhateverThisModelIsCalled", etc. and so on}
    ]]
    
    ["Welded Anchor Points"] = {"WeldAnchorPointTest"}, --// What is currently here is just a dummy value, feel free to remove it
}

return module