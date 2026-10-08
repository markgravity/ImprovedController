-- Every controller press the addon answers, in one place: the wheels' R3
-- combos, bag clean-up, the bag clean-up panel, the minimap labels' hotkey,
-- the touchpad click, the actions put on presses (Override.lua) and the
-- menu's double press.
-- Each feature keeps its own setting; this file reads and writes them
-- through one shape, so the General tab (BindEditor.lua) can show them all
-- on the controller and every tab can tell what a new binding replaces.
--
-- A press is a spec: "PADRSTICK" (pressed), "PADLSHOULDER+PADRSTICK" (one
-- held, one pressed), "PADLSTICK:double" (pressed twice quickly).
-- Two bindings on the same spec clash, unless one only works while the
-- bags are open and takes the button from the other meanwhile (bag
-- clean-up on L3 shares it with L3's override action that way).
local _, IC = ...

local B = {}
IC.Binds = B

-- Buttons that can be held for a second one
B.HOLDS = { "PADLSHOULDER", "PADLTRIGGER", "PADRSHOULDER", "PADRTRIGGER" }

-- The held button of each R3 combo, and back
local COMBO_HOLD = { L1 = "PADLSHOULDER", L2 = "PADLTRIGGER", R1 = "PADRSHOULDER", R2 = "PADRTRIGGER" }
local HOLD_COMBO = {}
for combo, key in pairs(COMBO_HOLD) do HOLD_COMBO[key] = combo end

---------------------------------------------------------------------------
-- Specs
---------------------------------------------------------------------------
-- held (or nil), pressed, double
function B.Parse(spec)
    if not spec then return nil end
    local pressed, double = spec:match("^(.-):double$")
    pressed = pressed or spec
    local held, rest = pressed:match("^(.-)%+(.+)$")
    if held then return held, rest, double ~= nil end
    return nil, pressed, double ~= nil
end

function B.Spec(held, pressed, double)
    return (held and (held .. "+") or "") .. pressed .. (double and ":double" or "")
end

-- "L1 + R3", "L3 twice"; with size, each button's glyph before its name
function B.Text(spec, size)
    if not spec then return "Not bound" end
    local held, pressed, double = B.Parse(spec)
    local function one(key)
        return (size and (IC.GlyphText(key, size) .. " ") or "") .. IC.ButtonName(key)
    end
    return (held and (one(held) .. " + ") or "") .. one(pressed) .. (double and " twice" or "")
end

-- Glyph keys for a GlyphRow (ConfigKit): { "LB", "+", "RS" }
function B.Glyphs(spec)
    local held, pressed = B.Parse(spec)
    if not pressed then return nil end
    local keys = {}
    if held then
        keys[1] = IC.PAD_KEY[held] or held
        keys[2] = "+"
    end
    keys[#keys + 1] = IC.PAD_KEY[pressed] or pressed
    return keys
end

-- An R3 combo ("L1", "R3") as a spec, and a spec as one (or nil)
function B.ComboSpec(combo)
    if combo == "R3" then return "PADRSTICK" end
    return COMBO_HOLD[combo] .. "+PADRSTICK"
end

function B.SpecCombo(spec)
    local held, pressed, double = B.Parse(spec)
    if pressed ~= "PADRSTICK" or double then return nil end
    if not held then return "R3" end
    return HOLD_COMBO[held]
end

-- The modifier a held button gives (the game's GamePadEmulate* CVars), or nil
local EMULATE = { { "GamePadEmulateShift", "SHIFT-" }, { "GamePadEmulateCtrl", "CTRL-" }, { "GamePadEmulateAlt", "ALT-" } }

local function ModifierOf(button)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    for _, m in ipairs(EMULATE) do
        if get and get(m[1]) == button then return m[2] end
    end
end

-- The key an override binding for a press goes on ("PADLSTICK",
-- "SHIFT-PAD1"; a press twice: its button's), or nil when it can't have
-- one: R3 (the wheels' combos, Ring.lua), a PlayStation touchpad (its
-- corners), a button the game makes a modifier, or one held that it doesn't
function B.KeyOf(spec)
    local held, pressed = B.Parse(spec)
    if not pressed or pressed == "PADRSTICK" or ModifierOf(pressed) then return nil end
    if pressed == "PADBACK" and IC.PadStyle() == "Shapes" then return nil end
    if not held then return pressed end
    local modifier = ModifierOf(held)
    return modifier and (modifier .. pressed) or nil
end

-- The ways a button can be pressed: alone, twice (where something takes
-- that), with each of the shoulders / triggers held
function B.Variants(key)
    local list = { key }
    local double = key .. ":double"
    for _, def in ipairs(B.All()) do
        if def.accepts(double) or IC.Override.Supports(double) then
            list[#list + 1] = double
            break
        end
    end
    for _, held in ipairs(B.HOLDS) do
        if held ~= key then list[#list + 1] = held .. "+" .. key end
    end
    return list
end

---------------------------------------------------------------------------
-- The bindings: { id, label, icon, group, tab (where else it is set),
-- context ("world", or "bags": only while a bag is open), takes (bool or
-- function(spec): it takes the button from the game and from others while
-- it works), accepts(spec), specs() (what it is bound to now), set(spec)
-- (nil: unbound), unbind(spec) (optional: just that one) }
---------------------------------------------------------------------------
local TEX = "Interface\\AddOns\\ImprovedController\\textures\\"
local ICON = "Interface\\Icons\\"

local function Single(spec)
    local held, _, double = B.Parse(spec)
    return spec ~= nil and not held and not double
end

local function NotDouble(spec)
    local _, _, double = B.Parse(spec)
    return spec ~= nil and not double
end

local function One(spec)
    return spec and { spec } or {}
end

local fixed = {}

local function Add(def)
    fixed[#fixed + 1] = def
    return def
end

-- The wheels: an R3 combo each (Ring.lua opens them)
local function Wheels()
    local list = {}
    local MW = IC.MyWheels
    if not (MW and IC.db) then return list end
    for _, wheel in ipairs(MW.Wheels()) do
        local key = wheel.key
        list[#list + 1] = {
            id = "wheel:" .. key, label = wheel.label .. " wheel", group = "Wheels", tab = "wheels",
            icon = TEX .. "ic_event_wheel", context = "world", takes = true,
            tip = "Opens the wheel (pressed again: closes it). On " .. IC.ButtonName("RS")
                .. " or a shoulder / trigger + " .. IC.ButtonName("RS") .. ", " .. IC.ButtonName("RS")
                .. " twice uses its last action again.",
            -- R3 combos (Ring.lua), or any press an override binding can go on
            accepts = function(spec)
                local _, _, double = B.Parse(spec)
                return B.SpecCombo(spec) ~= nil or (not double and B.KeyOf(spec) ~= nil)
            end,
            specs = function()
                local specs = {}
                for _, combo in ipairs(IC.COMBOS) do
                    if IC.GetComboRing(combo) == key then specs[#specs + 1] = B.ComboSpec(combo) end
                end
                for spec, ring in pairs(MW.WheelKeys()) do
                    if ring == key then specs[#specs + 1] = spec end
                end
                return specs
            end,
            set = function(spec)
                if not spec then return MW.ClearHotkey(key) end
                local combo = B.SpecCombo(spec)
                MW.SetHotkey(key, combo and { combo = combo } or { button = spec })
            end,
            unbind = function(spec)
                local combo = B.SpecCombo(spec)
                if combo then
                    if IC.GetComboRing(combo) == key then IC.SetComboRing(combo, "native") end
                elseif MW.WheelKeys()[spec] == key then
                    MW.WheelKeys()[spec] = nil
                    MW.ApplyWheelKeys()
                end
            end,
        }
    end
    return list
end

Add({
    id = "bagsort", label = "Bag clean-up", group = "Bags", tab = "general",
    icon = 133633, context = "bags", takes = true,
    tip = "Sorts your bags. Only while a bag is open: the button does its own job again once they close.",
    accepts = Single,
    specs = function() return IC.db.bagSort ~= false and One(IC.BagSortKey()) or {} end,
    set = function(spec)
        IC.db.bagSort = spec ~= nil
        if spec then IC.SetBagSortKey(spec) else IC.UpdateBagBinding() end
    end,
})

Add({
    id = "bagclean", label = "Bag clean-up panel", group = "Bags", tab = "general",
    icon = TEX .. "ic_emote_no", context = "bags",
    -- Watched, not taken; on an R3 combo the wheels leave it to the panel
    -- while the bags are open (BagCleaner.lua)
    takes = function(spec) return B.SpecCombo(spec) ~= nil end,
    tip = "Opens the panel of what is safe to throw away. Only while a bag is open.",
    accepts = NotDouble,
    specs = function() return IC.BagCleaner.Enabled() and One(IC.BagCleaner.OpenKey()) or {} end,
    set = function(spec)
        IC.db.bagClean = spec ~= nil
        if spec then IC.BagCleaner.SetOpenKey(spec) end
    end,
})

Add({
    id = "gather", label = "Minimap labels", group = "Other", tab = "gather",
    icon = ICON .. "INV_Misc_Flower_02", context = "world", takes = false,
    tip = "Shows / hides the names beside the minimap's dots. Watched only: the buttons keep their own"
        .. " actions too.",
    accepts = NotDouble,
    specs = function() return One(IC.Gather.Key()) end,
    set = function(spec) IC.Gather.SetKey(spec) end,
})

Add({
    id = "touch", label = "Touchpad corners", group = "Other", tab = "general",
    icon = "gamepad-ps-touchpad-normal", context = "world", takes = true,
    tip = "Clicking the touchpad runs what its corner holds (set on its corners here). PlayStation controllers only.",
    accepts = function(spec) return spec == "PADBACK" and IC.PadStyle() == "Shapes" end,
    specs = function()
        local on = IC.Touch.GetSettings().enabled ~= false and IC.PadStyle() == "Shapes"
        return on and { "PADBACK" } or {}
    end,
    set = function(spec)
        IC.Touch.GetSettings().enabled = spec ~= nil
        IC.Touch.Apply()
    end,
})

Add({
    id = "menu", label = "Improved Controller menu", group = "Other",
    icon = ICON .. "INV_Misc_Gear_02", context = "world", takes = false,
    tip = "Pressed twice quickly, opens this panel. Once still opens the game's own menu.",
    accepts = function(spec) return spec == "PADFORWARD:double" end,
    specs = function() return IC.db.menuDouble ~= false and { "PADFORWARD:double" } or {} end,
    set = function(spec) IC.db.menuDouble = spec ~= nil end,
})

-- An action on a press (Override.lua): a spell, an item, a macro, an emote
-- or a window. One per press, made for any press asked about.
function B.ActionDef(spec)
    local O = IC.Override
    local action = O.Get(spec)
    return {
        id = "action:" .. spec, kind = "action", group = "Action", context = "world", takes = true,
        label = action and ("Action: " .. (O.ActionLabel(action) or action)) or "An action",
        icon = O.ActionIcon(action) or ICON .. "INV_Misc_QuestionMark",
        tip = "Runs a spell, an item, a macro, an emote or opens a window, in combat too.",
        accepts = function(s) return s == spec and O.Supports(s) end,
        specs = function() return O.Get(spec) and { spec } or {} end,
        set = function(s) if not s then O.Set(spec, nil) end end,
    }
end

local function Actions()
    local list = {}
    local O = IC.Override
    if not (O and IC.db) then return list end
    local specs = {}
    for spec in pairs(O.Settings()) do specs[#specs + 1] = spec end
    table.sort(specs)
    for _, spec in ipairs(specs) do list[#list + 1] = B.ActionDef(spec) end
    return list
end

-- Every binding, in the order the General tab lists them
function B.All()
    local list = {}
    for _, def in ipairs(Wheels()) do list[#list + 1] = def end
    for _, def in ipairs(fixed) do list[#list + 1] = def end
    for _, def in ipairs(Actions()) do list[#list + 1] = def end
    return list
end

function B.Get(id)
    local spec = id:match("^action:(.+)$")
    if spec then return B.ActionDef(spec) end
    for _, def in ipairs(B.All()) do
        if def.id == id then return def end
    end
end

local function Has(def, spec)
    for _, s in ipairs(def.specs()) do
        if s == spec then return true end
    end
    return false
end
B.Has = Has

-- What is bound to a press, world bindings first
function B.Bound(spec)
    local list = {}
    for _, def in ipairs(B.All()) do
        if Has(def, spec) then list[#list + 1] = def end
    end
    table.sort(list, function(a, b) return (a.context == "world" and 0 or 1) < (b.context == "world" and 0 or 1) end)
    return list
end

local function Takes(def, spec)
    if type(def.takes) == "function" then return def.takes(spec) end
    return def.takes and true or false
end

-- Two bindings on one press: do they get in each other's way?
function B.Clash(a, b, spec)
    if a.id == b.id then return false end
    if a.context == b.context then return true end
    local bags = a.context == "bags" and a or b
    return not Takes(bags, spec)
end

-- What would have to give way for id on spec
function B.Conflicts(id, spec)
    local def = B.Get(id)
    local list = {}
    if not def or not spec then return list end
    for _, other in ipairs(B.Bound(spec)) do
        if B.Clash(def, other, spec) then list[#list + 1] = other end
    end
    return list
end

-- Bindings that clash on a press right now (two or more), or nil
function B.Clashing(spec)
    local bound = B.Bound(spec)
    for i = 1, #bound do
        for j = i + 1, #bound do
            if B.Clash(bound[i], bound[j], spec) then return bound end
        end
    end
    return nil
end

-- What a binding clashes with where it is bound now
function B.ClashesOf(id)
    local def = B.Get(id)
    local list = {}
    if not def then return list end
    for _, spec in ipairs(def.specs()) do
        for _, other in ipairs(B.Conflicts(id, spec)) do list[#list + 1] = other end
    end
    return list
end

-- "the Buffs wheel and Minimap labels"
function B.Names(defs)
    local names = {}
    for _, def in ipairs(defs) do names[#names + 1] = def.label end
    if #names <= 1 then return names[1] or "" end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

local function Unbind(def, spec)
    if def.unbind then def.unbind(spec) else def.set(nil) end
end

-- Frees a press for id: whatever clashes with it there is unbound. Returns
-- what was.
function B.Take(id, spec)
    local gone = B.Conflicts(id, spec)
    for _, other in ipairs(gone) do Unbind(other, spec) end
    return gone
end

-- Binds id to spec (nil: unbinds it), taking the press from what clashes
-- with it. Returns what was unbound. Out of combat.
function B.Assign(id, spec)
    local def = B.Get(id)
    if not def then return {} end
    if not spec then
        def.set(nil)
        return {}
    end
    local gone = B.Take(id, spec)
    def.set(spec)
    return gone
end

-- Nothing of ours on a press any more; returns what was there
function B.Clear(spec)
    local gone = B.Bound(spec)
    for _, def in ipairs(gone) do Unbind(def, spec) end
    return gone
end
