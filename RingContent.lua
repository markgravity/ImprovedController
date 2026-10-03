-- What goes on each ring. Every builder returns a list of entries:
--   { label, icon, count?, type = "spell"|"item"|"macro", value }
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

local EMOTES = {
    { "Wave", "/wave" }, { "Hello", "/hello" }, { "Thank", "/thank" }, { "Cheer", "/cheer" },
    { "Dance", "/dance" }, { "Laugh", "/laugh" }, { "Bow", "/bow" }, { "Roar", "/roar" },
}
local EMOTE_ICON = "Interface\\GossipFrame\\GossipGossipIcon"

-- Name lookups only resolve spells that are in the player's spellbook.
local function KnownSpell(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if info then
            return info.name, info.iconID
        end
        return nil
    end
    if GetSpellInfo then
        local spellName, _, icon = GetSpellInfo(name)
        return spellName, icon
    end
end

-- The buff spells the class starts with, before the player picks their own.
function IC.DefaultBuffs()
    local _, class = UnitClass("player")
    local list = {}
    for _, name in ipairs(CLASS_BUFFS[class] or {}) do
        if KnownSpell(name) then
            list[#list + 1] = name
        end
    end
    return list
end

-- The player's pick (per character), else the class defaults.
function IC.GetBuffList()
    return IC.charDB.buffs or IC.DefaultBuffs()
end

-- Every active spell in the spellbook, once per name, in book order:
--   { name, icon, tab }
function IC.GetSpellbookSpells()
    local spells, seen = {}, {}
    local function add(name, icon, tab)
        if name and not seen[name] then
            seen[name] = true
            spells[#spells + 1] = { name = name, icon = icon, tab = tab }
        end
    end
    if GetNumSpellTabs and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() or 0 do
            local tabName, _, offset, numSlots = GetSpellTabInfo(tab)
            for index = (offset or 0) + 1, (offset or 0) + (numSlots or 0) do
                local itemType = GetSpellBookItemInfo(index, "spell")
                if itemType == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(index, "spell")) then
                    add(GetSpellBookItemName(index, "spell"), GetSpellBookItemTexture(index, "spell"), tabName)
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
                        add(item.name, item.iconID, info.name)
                    end
                end
            end
        end
    end
    return spells
end

local function BuildBuffs()
    local entries = {}
    for _, name in ipairs(IC.GetBuffList()) do
        local spellName, icon = KnownSpell(name)
        if spellName and #entries < MAX_SLOTS then
            table.insert(entries, { label = spellName, icon = icon, type = "spell", value = spellName })
        end
    end
    return entries
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
    local entries = {}
    for _, emote in ipairs(EMOTES) do
        table.insert(entries, { label = emote[1], icon = EMOTE_ICON, type = "macro", value = emote[2] })
    end
    return entries
end

IC.RingBuilders = {
    buffs = BuildBuffs,
    consumables = BuildConsumables,
    emotes = BuildEmotes,
}
