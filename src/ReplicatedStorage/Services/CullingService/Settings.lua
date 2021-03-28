local module = {
    ["AnchorPointPrefix"] = "AnchorPoint_",

    ["Distances"] = {
        ["Short"] = 20,
        ["Medium"] = 50,
        ["Long"] = 100,
        ["Search Radius"] = 200, --// We search for models this far, since we may have to cull some out
    },

    ["InitiallyCullOutWorkspace"] = true, --// This will destroy all models in the Workspace if enabled

    ["Paused"] = false, --// Whether the CullingService is paused, defaults to false.  This setting can be changed via the :Pause and :Resume functions
    
    ["WaitTime"] = .5,
}

return module