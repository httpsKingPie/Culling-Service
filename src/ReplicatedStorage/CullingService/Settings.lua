local module = {
    ["Animation Package"] = nil, --// Defaults to nil for backwards compatability

    ["AutoStart"] = true, --// Whether CullingService automatically starts once initialized. Defaults to true for backwards compatability.

    ["Backup Regularity"] = 5, --// This means that the backup check runs every (x) times that the core loop activates.  To visualize this in time, multiply this value by the Wait Time value, and that is how often the backup check runs

    ["Distances"] = {
        --// Distances for culling things in (you are able to add more!)
        ["Short"] = 20,
        ["Medium"] = 50,
        ["Long"] = 100,
    },

    ["Ignore Y Dimension"] = true, --// Whether to ignore the Y dimension (utilize default .Magnitude calculation) or calculate magnitude manually excluding the Y dimension

    ["Region Length"] = 100, --// This is an invisible cube length.  This is how big the invisble regions in IE are (bigger regions = more streamed parts at once).  A good rule of thumb: the actual streaming distance will be decided by the smaller of the two figures: (1.) the designated streaming distance (ex: 100 studs) or (2.) the region length * 2
    
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