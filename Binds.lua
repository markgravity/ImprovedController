-- Every controller press the addon answers, in one place: the wheels' R3
-- combos, bag clean-up, the Destroy / Swap panel, the minimap labels' hotkey,
-- the touchpad click, the actions put on presses (Override.lua) and the
-- menu's double press.
-- Each feature keeps its own setting; this file reads and writes them
-- through one shape, so the General tab (BindEditor.lua) can show them all
-- on the controller and every tab can tell what a new binding replaces.
--
-- A press is a spec: "PADRSTICK" (pressed), "PADLSHOULDER+PADRSTICK" (one
-- held, one pressed), "PADLSTICK:double" (pressed twice quickly).
-- Two bindings on the same spec clash only where they work at the same
-- time: one for the game and one for the bags share a press (a wheel and
-- bag clean-up on L3), each answering where the focus is.
--
-- Where each works (the gamepad's focus): "world" bindings only while the
-- game has it (B.InGame: no window of Forever's gamepad UI holds it, as
-- bags or the map do); "bags" ones only while a bag is open. A window
-- taking the focus takes our world bindings off its buttons until it lets
-- go (B.FocusChanged re-applies them).
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
    -- (a press of Forever's crossbar: its slot holds what it runs, Native.lua)
    if IC.Native and IC.Native.SlotOf(spec) then return nil end
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
-- context ("world": while the game has the gamepad's focus, or "bags":
-- while a bag is open), accepts(spec), specs() (what it is bound to now), set(spec)
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
            icon = TEX .. "ic_event_wheel", context = "world",
            tip = "Opens the wheel (pressed again: closes it). On " .. IC.ButtonName("RS")
                .. " or a shoulder / trigger + " .. IC.ButtonName("RS") .. ", " .. IC.ButtonName("RS")
                .. " twice uses its last action again.",
            -- R3 combos (Ring.lua), a crossbar slot (Native.lua: a macro of
            -- ours that opens it), or any press an override binding can go on
            accepts = function(spec)
                local _, _, double = B.Parse(spec)
                return B.SpecCombo(spec) ~= nil or IC.Native.SlotOf(spec) ~= nil
                    or (not double and B.KeyOf(spec) ~= nil)
            end,
            specs = function()
                local specs = {}
                for _, combo in ipairs(IC.COMBOS) do
                    if IC.GetComboRing(combo) == key then specs[#specs + 1] = B.ComboSpec(combo) end
                end
                for spec, ring in pairs(MW.WheelKeys()) do
                    if ring == key then specs[#specs + 1] = spec end
                end
                for _, bound in ipairs(IC.Native.Bound()) do
                    if bound.action == "wheel:" .. key then specs[#specs + 1] = bound.spec end
                end
                return specs
            end,
            -- (one press per wheel: setting one takes it off the others)
            set = function(spec)
                MW.ClearHotkey(key)
                for _, bound in ipairs(IC.Native.Bound()) do
                    if bound.action == "wheel:" .. key and bound.spec ~= spec then IC.Native.Clear(bound.spec) end
                end
                if not spec then return end
                if IC.Native.SlotOf(spec) then
                    IC.Native.Set(spec, "wheel:" .. key, wheel.label)
                    return
                end
                local combo = B.SpecCombo(spec)
                MW.SetHotkey(key, combo and { combo = combo } or { button = spec })
            end,
            unbind = function(spec)
                local combo = B.SpecCombo(spec)
                if IC.Native.SlotOf(spec) then
                    if IC.Native.Get(spec) == "wheel:" .. key then IC.Native.Clear(spec) end
                elseif combo then
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
    icon = 133633, context = "bags",
    tip = "Sorts your bags. Only while a bag is open: the button does its own job again once they close.",
    accepts = Single,
    specs = function() return IC.db.bagSort ~= false and One(IC.BagSortKey()) or {} end,
    set = function(spec)
        IC.db.bagSort = spec ~= nil
        if spec then IC.SetBagSortKey(spec) else IC.UpdateBagBinding() end
    end,
})

Add({
    id = "destroy", label = "Destroy", group = "Bags", tab = "general",
    icon = TEX .. "ic_emote_no", context = "bags",
    -- Watched, not taken; on an R3 combo the wheels leave it to the panel
    -- while the bags are open (Swap.lua)
    tip = "Opens the panel of what is safe to throw away. Only while a bag is open. With the bags full,"
        .. " the top face button (Triangle / Y) opens it from the loot window too: there each destroy"
        .. " loots the item that didn't fit in the junk's place.",
    accepts = NotDouble,
    specs = function() return IC.Swap.Enabled() and One(IC.Swap.OpenKey()) or {} end,
    set = function(spec)
        IC.db.bagClean = spec ~= nil
        if spec then IC.Swap.SetOpenKey(spec) end
    end,
})

Add({
    id = "gather", label = "Minimap labels", group = "Other", tab = "gather",
    icon = ICON .. "INV_Misc_Flower_02", context = "world",
    tip = "Shows / hides the names beside the minimap's dots. Watched only: the buttons keep their own"
        .. " actions too.",
    accepts = NotDouble,
    specs = function() return One(IC.Gather.Key()) end,
    set = function(spec) IC.Gather.SetKey(spec) end,
})

Add({
    id = "touch", label = "Touchpad corners", group = "Other", tab = "general",
    icon = "gamepad-ps-touchpad-normal", context = "world",
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
    icon = ICON .. "INV_Misc_Gear_02", context = "world",
    tip = "Pressed twice quickly, opens this panel. Once still opens the game's own menu.",
    accepts = function(spec) return spec == "PADFORWARD:double" end,
    specs = function() return IC.db.menuDouble ~= false and { "PADFORWARD:double" } or {} end,
    set = function(spec) IC.db.menuDouble = spec ~= nil end,
})

-- A spell, item, macro, emote or window can go on the press: in its
-- crossbar slot (Native.lua), or as an override binding (Override.lua)
function B.ActionFits(spec)
    return IC.Native.SlotOf(spec) ~= nil or IC.Override.Supports(spec)
end

-- The action on a press (a crossbar slot's, not a wheel's; else the
-- override's), or nil
function B.ActionOn(spec)
    if IC.Native.SlotOf(spec) then
        local action = IC.Native.Get(spec)
        return action and not action:find("^wheel:") and action or nil
    end
    return IC.Override.Get(spec)
end

-- Puts an action on a press (nil: takes it off). Out of combat.
function B.SetAction(spec, action, label, icon)
    if IC.Native.SlotOf(spec) then
        if action then return IC.Native.Set(spec, action, label, icon) end
        return IC.Native.Clear(spec)
    end
    IC.Override.Set(spec, action)
end

-- An action on a press: a spell, an item, a macro, an emote or a window.
-- One per press, made for any press asked about.
function B.ActionDef(spec)
    local O = IC.Override
    local action = B.ActionOn(spec)
    return {
        id = "action:" .. spec, kind = "action", group = "Action", context = "world",
        label = action and ("Action: " .. (O.ActionLabel(action) or action)) or "An action",
        icon = O.ActionIcon(action) or ICON .. "INV_Misc_QuestionMark",
        tip = "Runs a spell, an item, a macro, an emote or opens a window, in combat too.",
        accepts = function(s) return s == spec and B.ActionFits(s) end,
        specs = function() return B.ActionOn(spec) and { spec } or {} end,
        set = function(s) if not s then B.SetAction(spec, nil) end end,
    }
end

local function Actions()
    local list = {}
    local O = IC.Override
    if not (O and IC.db) then return list end
    local specs, seen = {}, {}
    for spec in pairs(O.Settings()) do
        if B.ActionOn(spec) then specs[#specs + 1], seen[spec] = spec, true end
    end
    -- (and what the crossbar's slots hold)
    for _, bound in ipairs(IC.Native.Bound()) do
        if not seen[bound.spec] and not bound.action:find("^wheel:") then specs[#specs + 1] = bound.spec end
    end
    table.sort(specs)
    for _, spec in ipairs(specs) do list[#list + 1] = B.ActionDef(spec) end
    return list
end

---------------------------------------------------------------------------
-- The gamepad's focus: in the game, or on a window (Forever's binding stack,
-- GamepadSharedUtility.InputBindingManager), read every 0.1 s: never a
-- callback of ours in its lists, which would taint its secure work.
-- Bindings can only change out of combat: as combat starts ours go on
-- (PLAYER_REGEN_DISABLED comes just before the lockdown), so they work
-- through it whatever has the focus.
---------------------------------------------------------------------------
local inCombat = false

function B.InGame()
    if inCombat then return true end
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    if not (manager and manager.IsOnlyCoreBindingSetActive) then return true end
    return manager:IsOnlyCoreBindingSetActive() and true or false
end

-- The focus moved: every world binding re-applied (each one checks B.InGame)
function B.FocusChanged()
    if IC.InCombat() or not IC.db then return end
    if IC.ApplyRingBindings then IC.ApplyRingBindings() end
    if IC.MyWheels then IC.MyWheels.ApplyWheelKeys() end
    if IC.Override then IC.Override.Apply() end
    if IC.Touch then IC.Touch.Apply() end
end

local focus = CreateFrame("Frame")
focus:RegisterEvent("PLAYER_REGEN_DISABLED")
focus:RegisterEvent("PLAYER_REGEN_ENABLED")
focus:SetScript("OnEvent", function(_, event)
    inCombat = event == "PLAYER_REGEN_DISABLED"
    if inCombat then
        B.FocusChanged()
    else
        -- (after the features' own catch-up on PLAYER_REGEN_ENABLED)
        C_Timer.After(0, B.FocusChanged)
    end
end)

local lastInGame, wait = nil, 0
focus:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 or not IC.db then return end
    wait = 0.1
    local now = B.InGame()
    if now ~= lastInGame then
        lastInGame = now
        B.FocusChanged()
    end
end)

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

-- Two bindings on one press: do they get in each other's way? Only where
-- they work at the same time (the same focus)
function B.Clash(a, b)
    return a.id ~= b.id and a.context == b.context
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
