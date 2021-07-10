local Culling = require(script.Parent.Culling)

local module = {
    ["Buttons"] = {

    {
        ["Text"] = "Add Selection to Model Storage",
        ["Bound Function"] = Culling.AddSelectionToModelStorage,
        ["Hint Text"] = [[
This will add the model to the ModelStorage folder, provided the model does not already exist.
Very useful to use after setting anchor points
]]
    },
    {
        ["Text"] = "Cull In Entire Map",
        ["Bound Function"] = Culling.CullInEntireMap,
        ["Hint Text"] = [[
This will cull in all objects located in ReplicatedStorage.ModelStorage to their respective anchor points.
Cloned models will be found in Workspace.CulledObjects.
This is useful for previewing the current state of the map
]]
    },
        {
        ["Text"] = "Cull Out Entire Map",
        ["Bound Function"] = Culling.CullOutEntireMap,
        ["Hint Text"] = [[
This will cull out all (i.e. destroy in this context) objects located in Workspace.CulledObjects
]]
    },
    {
        ["Text"] = "Generate Anchor Points for Selection",
        ["Bound Function"] = Culling.GenerateAnchorPointsForSelection,
        ["Hint Text"] = [[
This will create an anchor point (if one is not created already) for all models currently selected
]]
    },
    {
        ["Text"] = "Visualize Internal Regions",
        ["Bound Function"] = Culling.VisualizeInternalRegions,
        ["Hint Text"] = [[
The map is divided into various sub-regions to optimize culling
This gives a live preview of how this looks
This will allow you to use the "Cull In Internal Regions" and "Cull Out Internal Regions" button
]]
    },
},
    ["Buffer Size"] = 10,
}

return module