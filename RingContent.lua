-- What goes on each ring. Every builder returns a list of entries:
--   { label, icon, count?, type = "spell"|"item"|"macro", value }
-- A wheel's slots hold actions: "spell:<id>", "item:<id>", "macro:<name>"
-- or "emote:<token>"; Buffs and Emotes keep theirs here, the player's own
-- wheels in MyWheels.lua, Consumables fills itself from the bags.
local _, IC = ...

local MAX_SLOTS = 24 -- three pages of eight
IC.MAX_SLOTS = MAX_SLOTS

local CLASS_BUFFS = {
    WARRIOR = { "Battle Shout", "Commanding Shout" },
    MAGE = {
        "Arcane Intellect", "Arcane Brilliance", "Frost Armor", "Ice Armor", "Mage Armor", "Molten Armor",
        "Dampen Magic", "Amplify Magic", "Ice Barrier", "Mana Shield",
    },
    PRIEST = {
        "Power Word: Fortitude", "Prayer of Fortitude", "Divine Spirit", "Prayer of Spirit",
        "Shadow Protection", "Prayer of Shadow Protection", "Inner Fire", "Fear Ward", "Power Word: Shield",
    },
    DRUID = { "Mark of the Wild", "Gift of the Wild", "Thorns", "Omen of Clarity" },
    PALADIN = {
        "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation",
        "Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Might", "Greater Blessing of Wisdom",
        "Greater Blessing of Kings", "Righteous Fury",
    },
    WARLOCK = { "Demon Armor", "Demon Skin", "Fel Armor", "Unending Breath", "Detect Invisibility", "Soul Link" },
    SHAMAN = { "Lightning Shield", "Water Shield", "Water Breathing", "Water Walking" },
    HUNTER = {
        "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack",
        "Aspect of the Wild", "Trueshot Aura",
    },
    ROGUE = {},
}

-- Emotes a slot can take (the slash command is "/" .. token)
IC.EMOTES = {
    { "wave", "Wave" }, { "hello", "Hello" }, { "thank", "Thank" }, { "cheer", "Cheer" },
    { "dance", "Dance" }, { "laugh", "Laugh" }, { "bow", "Bow" }, { "roar", "Roar" },
    { "bye", "Bye" }, { "clap", "Clap" }, { "cry", "Cry" }, { "flex", "Flex" },
    { "kiss", "Kiss" }, { "kneel", "Kneel" }, { "lol", "Lol" }, { "no", "No" },
    { "yes", "Yes" }, { "point", "Point" }, { "rude", "Rude" }, { "salute", "Salute" },
    { "sit", "Sit" }, { "sleep", "Sleep" }, { "shy", "Shy" }, { "train", "Train" },
    { "chicken", "Chicken" }, { "thanks", "Thanks" }, { "followme", "Follow me" }, { "charge", "Charge" },
    { "attacktarget", "Attack target" }, { "healme", "Heal me" }, { "oom", "Out of mana" }, { "flee", "Flee" },
}
local EMOTE_NAME = {}
for _, emote in ipairs(IC.EMOTES) do
    EMOTE_NAME[emote[1]] = emote[2]
end
IC.EMOTE_ICON = "Interface\\GossipFrame\\GossipGossipIcon"
local DEFAULT_EMOTES = { "wave", "hello", "thank", "cheer", "dance", "laugh", "bow", "roar" }

local function SpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info then return info.name, info.iconID, info.spellID end
        return nil
    end
    if GetSpellInfo then
        local name, _, icon, _, _, _, spellID = GetSpellInfo(spell)
        return name, icon, spellID
    end
end

local function ItemNameByID(id)
    local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    return getName and getName(id)
end

local function ItemIconByID(id)
    local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return getIcon and getIcon(id)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function Parse(action)
    return (action or ""):match("^(%a+):(.+)$")
end

-- An action's name and icon (nil for one that no longer exists)
function IC.ActionInfo(action)
    local kind, value = Parse(action)
    if kind == "spell" then
        local name, icon = SpellInfo(tonumber(value))
        return name, icon
    elseif kind == "item" then
        local id = tonumber(value)
        return ItemNameByID(id) or ("item:" .. value), ItemIconByID(id)
    elseif kind == "macro" then
        local name, icon = GetMacroInfo(value)
        return name, icon
    elseif kind == "emote" then
        return EMOTE_NAME[value] or value, IC.EMOTE_ICON
    end
end

-- An action as a ring entry, or nil (a macro deleted...)
function IC.ActionEntry(action)
    local kind, value = Parse(action)
    local name, icon = IC.ActionInfo(action)
    if not name then
        return nil
    end
    if kind == "spell" then
        return { label = name, icon = icon, type = "spell", value = name, spellID = tonumber(value) }
    elseif kind == "item" then
        return { label = name, icon = icon, type = "item", value = "item:" .. value }
    elseif kind == "macro" then
        local _, _, body = GetMacroInfo(value)
        return body and { label = name, icon = icon, type = "macro", value = body }
    elseif kind == "emote" then
        return { label = name, icon = icon, type = "macro", value = "/" .. value }
    end
end

-- A wheel's slots (holes allowed) as ring entries, in slot order
function IC.SlotEntries(slots, max)
    local entries = {}
    for i = 1, max do
        local entry = slots[i] and IC.ActionEntry(slots[i])
        if entry then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

---------------------------------------------------------------------------
-- Buffs (per character) and Emotes (account) slots
---------------------------------------------------------------------------

-- The buff spells the class starts with, as slots
local function DefaultBuffSlots()
    local _, class = UnitClass("player")
    local slots = {}
    for _, name in ipairs(CLASS_BUFFS[class] or {}) do
        local _, _, spellID = SpellInfo(name)
        if spellID and #slots < MAX_SLOTS then
            slots[#slots + 1] = "spell:" .. spellID
        end
    end
    return slots
end

function IC.GetBuffSlots()
    local db = IC.charDB
    if not db.buffSlots then
        -- An earlier version kept a list of spell names
        if db.buffs then
            db.buffSlots = {}
            for i, name in ipairs(db.buffs) do
                local _, _, spellID = SpellInfo(name)
                if spellID then db.buffSlots[i] = "spell:" .. spellID end
            end
            db.buffs = nil
        else
            db.buffSlots = DefaultBuffSlots()
        end
    end
    return db.buffSlots
end

function IC.ResetBuffSlots()
    IC.charDB.buffSlots = DefaultBuffSlots()
end

function IC.GetEmoteSlots()
    if not IC.db.emoteSlots then
        IC.ResetEmoteSlots()
    end
    return IC.db.emoteSlots
end

function IC.ResetEmoteSlots()
    local slots = {}
    for i, token in ipairs(DEFAULT_EMOTES) do
        slots[i] = "emote:" .. token
    end
    IC.db.emoteSlots = slots
end

local function BuildBuffs()
    return IC.SlotEntries(IC.GetBuffSlots(), MAX_SLOTS)
end

-- Every active spell in the spellbook, once per name, in book order:
--   { name, icon, tab, spellID }
function IC.GetSpellbookSpells()
    local spells, seen = {}, {}
    local function add(name, icon, tab, spellID)
        if name and not seen[name] then
            seen[name] = true
            spells[#spells + 1] = { name = name, icon = icon, tab = tab, spellID = spellID }
        end
    end
    if GetNumSpellTabs and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() or 0 do
            local tabName, _, offset, numSlots = GetSpellTabInfo(tab)
            for index = (offset or 0) + 1, (offset or 0) + (numSlots or 0) do
                local itemType, spellID = GetSpellBookItemInfo(index, "spell")
                if itemType == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(index, "spell")) then
                    add(GetSpellBookItemName(index, "spell"), GetSpellBookItemTexture(index, "spell"), tabName, spellID)
                end
            end
        end
    elseif C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.offSpecID then
                for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                    if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isPassive then
                        add(item.name, item.iconID, info.name, item.spellID)
                    end
                end
            end
        end
    end
    return spells
end

-- Consumable subclasses (item class 0) in display order; others go last.
local SUBCLASS_ORDER = { [1] = 1, [5] = 2, [7] = 3, [2] = 4, [3] = 5, [4] = 6 }

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function ContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

local function ItemInstant(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if getInfo then
        local _, _, _, _, icon, classID, subclassID = getInfo(itemID)
        return icon, classID, subclassID
    end
end

local function ItemName(itemID)
    local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    return getName and getName(itemID) or ("item:" .. itemID)
end

local function ItemCount(itemID)
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    return getCount and getCount(itemID) or 0
end

local function BuildConsumables()
    local seen, items = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ContainerSlots(bag) do
            local itemID = ContainerItemID(bag, slot)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                local icon, classID, subclassID = ItemInstant(itemID)
                if classID == 0 then
                    table.insert(items, {
                        label = ItemName(itemID),
                        icon = icon,
                        count = ItemCount(itemID),
                        type = "item",
                        value = "item:" .. itemID,
                        order = SUBCLASS_ORDER[subclassID] or 99,
                    })
                end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.label < b.label
    end)
    for i = #items, MAX_SLOTS + 1, -1 do
        items[i] = nil
    end
    return items
end

local function BuildEmotes()
    return IC.SlotEntries(IC.GetEmoteSlots(), 8)
end

IC.BuildConsumables = BuildConsumables

IC.RingBuilders = {
    buffs = BuildBuffs,
    consumables = BuildConsumables,
    emotes = BuildEmotes,
}
