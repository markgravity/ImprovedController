-- Improved Forever: Gather. Names beside the minimap's dots (NodeScan.lua,
-- Gather.lua), set up in its tab (GatherEditor.lua).
local IF = ImprovedForever

IF.AddModule({ key = "gather", label = "Gather", icon = IF.TEX .. "ic_mod_gather", addon = ... })

-- /if nodes: list what the minimap shows (step / debug tune it)
IF.AddCommand("nodes", function(args) IF.Gather.Command(args[1], args[2]) end, "[step|debug]: what the minimap shows")

BINDING_HEADER_IMPROVEDFOREVER_GATHER = "Improved Forever: Gather"
