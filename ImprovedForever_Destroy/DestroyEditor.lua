-- The Destroy tab, a tab of settings (IF.SettingsPage, SettingsPage.lua):
-- on / off, and the press that opens the panel while a bag is open.
local IF = ImprovedForever

local DS = IF.Destroy
local B = IF.Binds
local Item, OnOff = IF.SettingsItem, IF.SettingsOnOff

local ITEMS = {
    Item({
        key = "enabled", group = "destroy", label = "Destroy panel",
        tip = "The panel of what is safe to throw away, opened while a bag is open. With the bags full, the top"
            .. " face button (Triangle / Y) opens it from the loot window too: there each destroy loots the item"
            .. " that didn't fit in the junk's place.",
    }, OnOff(function() return DS.Enabled() end, function(on)
        -- (its own press back, without taking it from anything)
        B.Get("destroy").set(on and DS.OpenKey() or nil)
    end, "Destroy panel")),
    {
        key = "key", group = "destroy", label = "Opens with",
        tip = "The press that opens the panel while a bag is open: one button, or hold one and press another."
            .. " Watched, not taken: the button keeps its own action outside the bags.",
        bindable = true, chord = true, bindId = "destroy",
        binding = function() return DS.OpenKey() end,
        keyText = function(size) return DS.OpenKeyText(size) end,
        disabled = function() return not DS.Enabled() end,
    },
}

local GROUPS = {
    { key = "destroy", label = "Destroy" },
}

IF.DestroyEditor = IF.SettingsPage({ key = "destroy", label = "Destroy", module = "destroy", order = 55 }, GROUPS, ITEMS)
