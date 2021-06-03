local module = {
    ["AnchorPointPrefix"] = "AnchorPoint_",

    ["Distances"] = {
        ["Short"] = 20,
        ["Medium"] = 50,
        ["Long"] = 100,
        ["Search Radius"] = 200, --// We search for models this far, since we may have to cull some out
    },

    ["Paused"] = false, --// Whether the CullingService is paused, defaults to false.  This setting can be changed via the :Pause and :Resume functions

    ["Region Length"] = 300, --// This is an invisible cube
    
    ["WaitTime"] = .5,
}

return module