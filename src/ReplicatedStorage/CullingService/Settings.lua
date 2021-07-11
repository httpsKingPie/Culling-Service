local module = {
    ["Distances"] = {
        --// Distances for culling things in
        ["Short"] = 20,
        ["Medium"] = 50,
        ["Long"] = 100,
        ["Search Radius"] = 200, --// We search for models this far, since we may have to cull some out
    },

    ["Paused"] = false, --// Whether the CullingService is paused, defaults to false.  This setting can be changed via the :Pause and :Resume functions

    ["Region Length"] = 100, --// This is an invisible cube length.  Make sure this value is at least a third of the search radius.  Customize to your liking
    
    ["WaitTime"] = .5,
}

return module