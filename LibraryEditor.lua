-- The Library tab, a tab of settings (IC.SettingsPage, SettingsPage.lua): R3
-- held on an item opens its page, and where its data comes from (QuestieDB,
-- the recipes known). Library.lua does the work.
local _, IC = ...

local menu = IC.Menu
local LB = IC.Library
local Item, OnOff = IC.SettingsItem, IC.SettingsOnOff

local ICON = "Interface\\Icons\\"

local function S()
    return LB.Settings()
end

local QUESTIE = {
    found = "Installed: its data is read (the newest).",
    bundled = "Not installed (or its version doesn't fit): the copy of its data that comes with the addon is read.",
    missing = "|cffff7a5cNo data|r: neither QuestieDB nor the addon's copy of it is there.",
}

local ITEMS = {
    Item({
        key = "enabled", group = "library", label = "Library",
        icon = ICON .. "INV_Misc_Book_09",
        tip = "R3 held on an item (in the bags, the loot window or the auction window) opens its page: what it is,"
            .. " what drops it, who sells it, the recipes that make it or use it, its quests and auction prices."
            .. " It reads as a traveller's notes: Cross on an entry under them opens that list, then another"
            .. " item's page or a waypoint; L2 / R2 turn the page, Circle goes back."
            .. " A short R3 press still shows or hides the tooltip.",
    }, OnOff(function() return S().enabled end, function(on) S().enabled = on end, "Library")),
    Item({
        key = "questie", group = "sources", label = "QuestieDB",
        icon = ICON .. "INV_Misc_Map_01",
        tip = "Drops, vendors and quests come from QuestieDB's data (by the Questie team): the QuestieDB addon when"
            .. " installed, else the copy that comes with this addon.",
        text = function()
            local q = LB.Q()
            return QUESTIE[LB.QStatus()] .. (q and q.bundled and q.source and ("|n" .. q.source) or "")
        end,
    }),
    Item({
        key = "recipes", group = "sources", label = "Recipes",
        icon = ICON .. "Trade_Engineering",
        tip = "Every profession's recipes come with the addon; the ones a profession window shows are added as you"
            .. " open it (recipes only Forever has).",
        text = function()
            local bundled, seen = 0, 0
            for _ in pairs(IC.LibraryRecipes and IC.LibraryRecipes.recipes or {}) do bundled = bundled + 1 end
            for _ in pairs(S().recipes) do seen = seen + 1 end
            return bundled .. " known, " .. seen .. " seen in your profession windows"
        end,
    }),
}

local GROUPS = {
    { key = "library", label = "Library" },
    { key = "sources", label = "Sources" },
}

menu.AddTab({ key = "library", label = "Library", sections = {} }, "vibration")
IC.LibraryEditor = IC.SettingsPage("library", "Library", GROUPS, ITEMS)
