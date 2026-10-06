-- The wheels, adapted from Easy Controller - Forever's MyWheels (moust4ki,
-- MIT License, see LICENSE-EasyController.md): the built-in ones
-- (Buffs, Consumables, Emotes) and up to 8 of the player's own per
-- character, 8 slots each, holding the spells, items, macros and emotes
-- they pick. Each is a ring ("buffs", "my<id>"...), opened by an R3 combo
-- or its own key binding. Configured in the panel's Wheels tab
-- (WheelEditor.lua), which works on the descriptions MW.Wheels() returns.
local _, IC = ...

local MW = {}
IC.MyWheels = MW

MW.SLOTS = 8
MW.MAX = 8
MW.POSITIONS = { "Top", "Top right", "Right", "Bottom right", "Bottom", "Bottom left", "Left", "Top left" }

-- The built-in rings; the wheels are added after them
local BUILT_IN = { "native", "buffs", "consumables", "emotes" }
-- The built-in wheels, shown before the player's own
MW.BUILT_IN_WHEELS = { "buffs", "consumables", "emotes" }

---------------------------------------------------------------------------
-- The wheels: charDB.wheels = { { id = 1-8, name, slots = { [1-8] = "spell:133" } } }
---------------------------------------------------------------------------
function MW.List()
    IC.charDB.wheels = IC.charDB.wheels or {}
    return IC.charDB.wheels
end

function MW.Get(id)
    for _, w in ipairs(MW.List()) do
        if w.id == id then return w end
    end
end

function MW.Count(w)
    local n = 0
    for i = 1, MW.SLOTS do
        if w.slots[i] then n = n + 1 end
    end
    return n
end

function MW.RingKey(id)
    return "my" .. id
end

function MW.ActionName(action)
    return (IC.ActionInfo(action))
end

function MW.ActionIcon(action)
    return select(2, IC.ActionInfo(action))
end

local function ItemName(id)
    return (IC.ActionInfo("item:" .. id))
end

local function ItemIcon(id)
    return select(2, IC.ActionInfo("item:" .. id))
end

---------------------------------------------------------------------------
-- What a slot can take (the picker's lists): spells by spellbook tab,
-- usable items in the bags and equipped, macros, emotes
---------------------------------------------------------------------------
local function SpellEntries()
    local entries, lastTab = {}, nil
    for _, spell in ipairs(IC.GetSpellbookSpells()) do
        if spell.spellID then
            if spell.tab ~= lastTab then
                entries[#entries + 1] = { header = spell.tab or "Spells" }
                lastTab = spell.tab
            end
            entries[#entries + 1] = { action = "spell:" .. spell.spellID, name = spell.name, icon = spell.icon }
        end
    end
    return entries
end

local function ItemSpell(id)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    return getSpell and getSpell(id)
end

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function ContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then return C_Container.GetContainerItemID(bag, slot) end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

local function ItemEntries()
    local entries, seen = {}, {}
    local function add(id)
        if id and not seen[id] and ItemSpell(id) then
            seen[id] = true
            entries[#entries + 1] = { action = "item:" .. id, name = ItemName(id) or ("item:" .. id), icon = ItemIcon(id) }
        end
    end
    entries[#entries + 1] = { header = "Equipped" }
    for slot = 1, 19 do
        add(GetInventoryItemID("player", slot))
    end
    if #entries == 1 then entries[1] = nil end
    local before = #entries
    entries[#entries + 1] = { header = "Bags" }
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ContainerSlots(bag) do
            add(ContainerItemID(bag, slot))
        end
    end
    if #entries == before + 1 then entries[#entries] = nil end
    return entries
end

local function MacroEntries()
    local entries = {}
    local global, perChar = GetNumMacros()
    local groups = {
        { "General macros", 1, global },
        { "Character macros", (MAX_ACCOUNT_MACROS or 120) + 1, (MAX_ACCOUNT_MACROS or 120) + perChar },
    }
    for _, group in ipairs(groups) do
        if group[3] >= group[2] then
            entries[#entries + 1] = { header = group[1] }
            for index = group[2], group[3] do
                local name, icon = GetMacroInfo(index)
                if name then
                    entries[#entries + 1] = { action = "macro:" .. name, name = name, icon = icon }
                end
            end
        end
    end
    return entries
end

local function EmoteEntries()
    local entries = {}
    for _, emote in ipairs(IC.EMOTES) do
        entries[#entries + 1] = { action = "emote:" .. emote[1], name = emote[2], icon = emote[3] or IC.EMOTE_ICON, sub = "/" .. emote[1] }
    end
    return entries
end

local SPELLS = { key = "spells", label = "Spells", entries = SpellEntries }
local ITEMS = { key = "items", label = "Items", entries = ItemEntries }
local MACROS = { key = "macros", label = "Macros", entries = MacroEntries }
local EMOTES = { key = "emotes", label = "Emotes", entries = EmoteEntries }
MW.CATALOG = { SPELLS, ITEMS, MACROS, EMOTES }

-- As a ring: the filled slots in order
local function Builder(id)
    return function()
        local w = MW.Get(id)
        return w and IC.SlotEntries(w.slots, MW.SLOTS) or {}
    end
end

-- IC.RINGS / RING_LABELS / RingBuilders: the built-in rings, then the wheels
function MW.Register()
    local rings = {}
    for _, key in ipairs(BUILT_IN) do rings[#rings + 1] = key end
    for key in pairs(IC.RING_LABELS) do
        if key:find("^my%d") then IC.RING_LABELS[key], IC.RingBuilders[key] = nil, nil end
    end
    for _, w in ipairs(MW.List()) do
        local key = MW.RingKey(w.id)
        rings[#rings + 1] = key
        IC.RING_LABELS[key] = w.name
        IC.RingBuilders[key] = Builder(w.id)
    end
    IC.RINGS = rings
    -- Each wheel's line in the game's Key Bindings (AddOns)
    for _, key in ipairs(IC.WHEEL_BINDING_KEYS or {}) do
        _G["BINDING_NAME_CLICK ImprovedControllerWheel_" .. key .. ":LeftButton"] = "Open wheel: "
            .. (IC.RING_LABELS[key] or ("Wheel " .. key:gsub("^my", "")))
    end
    -- A combo on a wheel that is gone: back to the game's own R3
    for combo, ring in pairs(IC.db.combos) do
        if not IC.RING_LABELS[ring] then
            IC.db.combos[combo] = "native"
        end
    end
end

local function Changed()
    MW.Register()
    -- A recorded button on a wheel that is gone: let go
    local keys = MW.WheelKeys()
    for button, key in pairs(keys) do
        if not IC.RING_LABELS[key] then keys[button] = nil end
    end
    IC.RefreshRings()
    if IC.ApplyRingBindings then IC.ApplyRingBindings() end
    MW.ApplyWheelKeys()
end
MW.Changed = Changed

function MW.Create()
    local used = {}
    for _, w in ipairs(MW.List()) do used[w.id] = true end
    for id = 1, MW.MAX do
        if not used[id] then
            table.insert(MW.List(), { id = id, name = "Wheel " .. id, slots = {} })
            Changed()
            return id
        end
    end
end

function MW.Delete(id)
    local list = MW.List()
    for i, w in ipairs(list) do
        if w.id == id then
            table.remove(list, i)
            break
        end
    end
    Changed()
end

function MW.SetSlot(id, slot, action)
    local w = MW.Get(id)
    if not w then return end
    w.slots[slot] = action
    Changed()
end

function MW.Rename(id, name)
    local w = MW.Get(id)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if not w or name == "" then return end
    w.name = name:sub(1, 40)
    Changed()
end

---------------------------------------------------------------------------
-- Every wheel, described for the editor: { key, label, builtin, slots
-- (nil: fills itself), max (slots: 8 per page), lists (the picker's),
-- info, reset, id (own wheels: rename / delete) }
---------------------------------------------------------------------------
function MW.Wheels()
    local wheels = {
        { key = "buffs", label = IC.RING_LABELS.buffs, builtin = true, slots = IC.GetBuffSlots(),
            max = IC.MAX_SLOTS, lists = { SPELLS, ITEMS, MACROS },
            info = "Your class buffs to start with: change any slot. Three pages of eight.",
            reset = IC.ResetBuffSlots, resetLabel = "Class defaults" },
        { key = "consumables", label = IC.RING_LABELS.consumables, builtin = true, max = IC.MAX_SLOTS,
            info = "Fills itself from your bags: potions, food and drink, bandages, elixirs, flasks and scrolls,"
                .. " best kinds first. Nothing to set here but its hotkey." },
        { key = "emotes", label = IC.RING_LABELS.emotes, builtin = true, slots = IC.GetEmoteSlots(), max = 8,
            lists = { EMOTES, MACROS },
            info = "Emotes to play with a flick of the stick. Change any slot.",
            reset = IC.ResetEmoteSlots, resetLabel = "Default emotes" },
    }
    for _, w in ipairs(MW.List()) do
        wheels[#wheels + 1] = { key = MW.RingKey(w.id), label = w.name, id = w.id, slots = w.slots, max = MW.SLOTS,
            lists = MW.CATALOG, info = "A wheel of your own: spells, items, macros or emotes in any slot." }
    end
    return wheels
end

-- What a self-filling wheel holds right now, as actions by slot
function MW.LiveSlots(wheel)
    local slots = {}
    for i, entry in ipairs(IC.RingBuilders[wheel.key]()) do
        slots[i] = entry.value
    end
    return slots
end

function MW.SetWheelSlot(wheel, slot, action)
    if not wheel.slots then return end
    wheel.slots[slot] = action
    MW.Changed()
end

function MW.ResetWheel(wheel)
    if wheel.reset then
        wheel.reset()
        MW.Changed()
    end
end

---------------------------------------------------------------------------
-- Hotkeys: an R3 combo (L1 / L2 / R1 / R2 + R3, or R3), a recorded
-- controller button, or the wheel's line in the game's Key Bindings
---------------------------------------------------------------------------
-- The combos that open a ring ("L1 + R3, R2 + R3"), or nil
function MW.CombosText(ringKey)
    local parts = {}
    for _, combo in ipairs(IC.COMBOS) do
        if IC.GetComboRing(combo) == ringKey then parts[#parts + 1] = IC.COMBO_LABELS[combo] end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- The key bound to it in the game's Key Bindings, or nil
function MW.BindingText(ringKey)
    local key = GetBindingKey("CLICK ImprovedControllerWheel_" .. ringKey .. ":LeftButton")
    return key and (GetBindingText and GetBindingText(key) or key) or nil
end

---------------------------------------------------------------------------
-- Recorded hotkeys: any controller button opens a wheel (IC.db.wheelKeys =
-- { [button] = ringKey }), bound with priority over the game's and
-- Forever's own action for it, under every modifier a held trigger may add
---------------------------------------------------------------------------
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
-- Held with R3: the R3 combos (Ring.lua reads which is held on the press)
MW.COMBO_HOLD = { PADLSHOULDER = "L1", PADLTRIGGER = "L2", PADRSHOULDER = "R1", PADRTRIGGER = "R2" }

-- A button's name as printed on the pad in hand (Pad.lua)
function MW.ButtonName(button)
    return IC.ButtonName(button)
end

function MW.WheelKeys()
    IC.db.wheelKeys = IC.db.wheelKeys or {}
    return IC.db.wheelKeys
end

local keyOwner = CreateFrame("Frame", "ImprovedControllerWheelKeys")
local keysPending = false

function MW.ApplyWheelKeys()
    if IC.InCombat() then
        keysPending = true
        return
    end
    keysPending = false
    ClearOverrideBindings(keyOwner)
    for button, ringKey in pairs(MW.WheelKeys()) do
        if IC.RING_LABELS[ringKey] then
            for _, prefix in ipairs(PREFIXES) do
                SetOverrideBindingClick(keyOwner, true, prefix .. button, "ImprovedControllerWheel_" .. ringKey, "LeftButton")
            end
        end
    end
end

keyOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
keyOwner:RegisterEvent("PLAYER_ENTERING_WORLD")
keyOwner:SetScript("OnEvent", function(_, event)
    if IC.db and (keysPending or event == "PLAYER_ENTERING_WORLD") then MW.ApplyWheelKeys() end
end)

-- The recorded buttons that open a ring ("Triangle, D-pad Up"), or nil
function MW.KeysText(ringKey)
    local parts = {}
    for button, key in pairs(MW.WheelKeys()) do
        if key == ringKey then parts[#parts + 1] = MW.ButtonName(button) end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- What opens it, as glyph keys for a GlyphRow (ConfigKit): an R3 combo
-- ("LB", "RS"), else a bound button, else its game key binding's name; nil
-- when nothing does
local COMBO_GLYPHS = {
    R3 = { "RS" }, L1 = { "LB", "+", "RS" }, L2 = { "LT", "+", "RS" }, R1 = { "RB", "+", "RS" }, R2 = { "RT", "+", "RS" },
}

function MW.BindGlyphs(ringKey)
    for _, combo in ipairs(IC.COMBOS) do
        if IC.GetComboRing(combo) == ringKey then return COMBO_GLYPHS[combo] end
    end
    for button, key in pairs(MW.WheelKeys()) do
        if key == ringKey then return { IC.PAD_KEY[button] or button } end
    end
    local binding = MW.BindingText(ringKey)
    return binding and { binding } or nil
end

-- Everything that opens it, or nil
function MW.HotkeyText(ringKey)
    local parts = {}
    for _, text in ipairs({ MW.CombosText(ringKey), MW.KeysText(ringKey), MW.BindingText(ringKey) }) do
        if text then parts[#parts + 1] = text end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

-- A recorded press as a hotkey: { combo = "L1" } (held + R3, or "R3"
-- alone) or { button = "PAD4" }; nil if it can't be one
function MW.HotkeySpec(held, pressed)
    if pressed == "PADRSTICK" then
        local combo = held and MW.COMBO_HOLD[held]
        if held and not combo then return nil end
        return { combo = combo or "R3" }
    end
    if held then return nil end
    return { button = pressed }
end

function MW.SpecText(spec)
    if spec.combo then return IC.COMBO_LABELS[spec.combo] end
    return MW.ButtonName(spec.button)
end

-- What the hotkey takes over, for the confirmation
function MW.SpecReplaces(spec, ringKey)
    if spec.combo then
        local current = IC.GetComboRing(spec.combo)
        if current == ringKey then return "nothing (already this wheel)" end
        if current ~= "native" then return "the " .. (IC.RING_LABELS[current] or current) .. " wheel" end
        return spec.combo == "R3" and "the game's " .. IC.ButtonName("RS") .. " (Look Here)" or "nothing"
    end
    local key = MW.WheelKeys()[spec.button]
    if key == ringKey then return "nothing (already this wheel)" end
    if key then return "the " .. (IC.RING_LABELS[key] or key) .. " wheel" end
    local action = GetBindingAction(spec.button, true)
    if not action or action == "" then return "nothing" end
    local name = GetBindingName and GetBindingName(action)
    if action:find("^CLICK InputFunctionBindingButton") then
        return "Forever's own action for " .. MW.ButtonName(spec.button)
    end
    return (name and name ~= action) and name or action
end

-- No more hotkeys for this wheel
function MW.ClearHotkey(ringKey)
    for _, combo in ipairs(IC.COMBOS) do
        if IC.GetComboRing(combo) == ringKey then IC.db.combos[combo] = "native" end
    end
    local keys = MW.WheelKeys()
    for button, key in pairs(keys) do
        if key == ringKey then keys[button] = nil end
    end
    if IC.ApplyRingBindings then IC.ApplyRingBindings() end
    MW.ApplyWheelKeys()
end

-- Saves a recorded hotkey: the wheel's old one goes, and the press is
-- taken from whatever had it
function MW.SetHotkey(ringKey, spec)
    MW.ClearHotkey(ringKey)
    if spec.combo then
        IC.db.combos[spec.combo] = ringKey
    else
        MW.WheelKeys()[spec.button] = ringKey
    end
    if IC.ApplyRingBindings then IC.ApplyRingBindings() end
    MW.ApplyWheelKeys()
end

-- Before the rings are built (Ring.lua's login runs after this file's)
IC.OnLogin(MW.Register)
