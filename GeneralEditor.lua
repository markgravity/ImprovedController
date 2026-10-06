-- The General tab, laid out like the Vibration tab: the settings down the
-- left by group (Controller, Features, Misc, About), the selected one big in
-- the middle with its value, and its choices down the right as slices of a
-- ring around it. A Misc item runs on a button: Square records another one
-- for it (Circle cancels).
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu

local PANEL_W, PICKER_TOP, PICKER_ROWS = 340, 236, 8
local ARC = 300
local function ArcX(dy)
    return math.sqrt(math.max(0, ARC * ARC - dy * dy))
end

local TEX = "Interface\\AddOns\\ImprovedController\\textures\\"
local ON_ICON, OFF_ICON = TEX .. "ic_emote_yes", TEX .. "ic_emote_no"

local function OnOff(get, set, label)
    return {
        value = function() return get() and "on" or "off" end,
        text = function() return get() and "On" or "|cffff7a5cOff|r" end,
        options = function()
            return {
                { action = "on", name = "On", icon = ON_ICON },
                { action = "off", name = "Off", icon = OFF_ICON },
            }
        end,
        choose = function(action)
            set(action == "on")
            menu.Toast(label .. ": " .. (action == "on" and "on" or "off"))
        end,
    }
end

local function Item(def, behaviour)
    for k, v in pairs(behaviour or {}) do def[k] = v end
    return def
end

---------------------------------------------------------------------------
-- The settings
---------------------------------------------------------------------------
local GROUPS = {
    { key = "controller", label = "Controller" },
    { key = "features", label = "Features" },
    { key = "misc", label = "Misc" },
    { key = "about", label = "About" },
}

local ITEMS = {
    Item({
        key = "padStyle", group = "controller", label = "Buttons shown",
        icon = function() return IC.GlyphAtlas("A") or 134400 end,
        tip = "Which controller's buttons the menus and wheels show. Automatic follows the controller in"
            .. " use, as the game's own prompts do.",
        value = function() return IC.db.padStyle or "auto" end,
        text = function()
            local set = IC.db.padStyle
            if not set then return "Auto: " .. IC.PAD_STYLE_LABELS[IC.DetectedPadStyle()] end
            return IC.PAD_STYLE_LABELS[set]
        end,
        options = function()
            local list = {}
            for _, style in ipairs(IC.PAD_STYLES) do
                local glyph = IC.PAD_ATLAS[style == "auto" and IC.DetectedPadStyle() or style].A[1]
                list[#list + 1] = {
                    action = style,
                    name = style == "auto" and ("Automatic (" .. IC.PAD_STYLE_LABELS[IC.DetectedPadStyle()] .. ")")
                        or IC.PAD_STYLE_LABELS[style],
                    icon = IC.HasAtlas(glyph) and glyph or 134400,
                }
            end
            return list
        end,
        choose = function(action)
            IC.SetPadStyle(action)
            menu.Toast("Buttons shown: " .. IC.PAD_STYLE_LABELS[action])
        end,
    }),
    Item({
        key = "touch", group = "features", label = "Touchpad click",
        icon = "gamepad-ps-touchpad-normal",
        tip = "Clicking the touchpad runs what its corner holds (Touchpad tab). Works in combat.",
        note = function()
            if IC.PadStyle() ~= "Shapes" then
                return "Needs a PlayStation controller (a touchpad)."
            end
        end,
    }, OnOff(function() return IC.Touch.GetSettings().enabled ~= false end, function(on)
        IC.Touch.GetSettings().enabled = on
        IC.Touch.Apply()
    end, "Touchpad click")),
    Item({
        key = "vibe", group = "features", label = "Vibration",
        icon = TEX .. "ic_vibe_pulse",
        tip = "The controller vibrates on the events set in the Vibration tab.",
    }, OnOff(function() return IC.Vibe.Settings().enabled end, function(on)
        IC.Vibe.Settings().enabled = on
        if on then IC.Vibe.Play("pulse") else IC.Vibe.Stop() end
    end, "Vibration")),
    Item({
        key = "vibeStrength", group = "features", label = "Vibration strength",
        icon = TEX .. "ic_vibe_rise",
        tip = "How strong every vibration is. Choosing one plays a pulse so you can feel it.",
        value = function() return tostring(math.floor(IC.Vibe.Settings().intensity * 10 + 0.5)) end,
        text = function() return math.floor(IC.Vibe.Settings().intensity * 100 + 0.5) .. "%" end,
        options = function()
            local list = {}
            for n = 1, 10 do
                list[#list + 1] = { action = tostring(n), name = (n * 10) .. "%", icon = TEX .. "ic_vibe_pulse" }
            end
            return list
        end,
        choose = function(action)
            IC.Vibe.Settings().intensity = tonumber(action) / 10
            IC.Vibe.Play("pulse")
            menu.Toast("Vibration strength: " .. (tonumber(action) * 10) .. "%")
        end,
    }),
    Item({
        key = "bags", group = "misc", label = "Bag clean-up",
        icon = 133633,
        tip = "While any bag is open, its button sorts your bags. The button does its usual job again once"
            .. " the bags close.",
        bindable = true,
        binding = function() return IC.BagSortKey() end,
        bind = function(key) IC.SetBagSortKey(key) end,
    }, OnOff(function() return IC.db.bagSort ~= false end, function(on)
        IC.db.bagSort = on
        IC.UpdateBagBinding()
    end, "Bag clean-up")),
    Item({
        key = "about", group = "about", label = "Improved Controller",
        icon = TEX .. "ic_event_wheel",
        tip = "Quality of life for WoW Forever with a controller.",
        text = function() return "" end,
        note = function()
            return IC.PadText("Wheels (buffs, consumables, emotes and your own), touchpad clicks, vibration and bag"
                .. " clean-up. {LB} / {RB} switch tabs; open this panel with /ic or a key binding (Key Bindings >"
                .. " AddOns). Panel design adapted from Easy Controller - Forever by moust4ki (MIT License).")
        end,
    }),
}

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local G = { zone = "rail", index = 1 }
IC.GeneralEditor = G

function G:Item()
    return ITEMS[self.index]
end

local function Resolve(v)
    if type(v) == "function" then return v() end
    return v
end

-- The left side's lines: each group's name, then its items
local function Lines()
    local lines = {}
    for _, group in ipairs(GROUPS) do
        lines[#lines + 1] = { header = group.label }
        for i, item in ipairs(ITEMS) do
            if item.group == group.key then lines[#lines + 1] = { index = i } end
        end
    end
    return lines
end

function G:Build(parent)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- The middle: the selected setting, big, its value and a note under it
    local big = K.Slot(f, 150, 108)
    big:SetPoint("CENTER", f, "CENTER", 0, 10)
    big:SetScript("OnClick", function() G:Aim() end)
    f.big = big
    f.value = K.Text(f, 16, KC.title)
    f.value:SetPoint("TOP", big, "BOTTOM", 0, -40)
    f.value:SetJustifyH("CENTER")
    f.note = K.Text(f, 12, KC.help)
    f.note:SetPoint("TOP", f.value, "BOTTOM", 0, -8)
    f.note:SetWidth(300)
    f.note:SetJustifyH("CENTER")
    f.note:SetWordWrap(true)

    -- Left: the groups' names and their settings
    f.rows = {}
    for i in ipairs(Lines()) do
        local r = K.NewFrame("Button", nil, f)
        r:SetSize(200, 34)
        r.seg = K.Segment(r)
        r.label = K.Text(r, 14, KC.rail, "OVERLAY")
        r.label:SetJustifyH("CENTER")
        r.label:SetPoint("CENTER")
        r:SetScript("OnClick", function(self)
            if not self.index then return end
            G.index, G.zone = self.index, "rail"
            menu.Render()
        end)
        f.rows[i] = r
    end

    -- Right: the selected setting's choices
    self.picker = K.Picker(f, PANEL_W, menu.Render, {
        bare = true, rowHeight = 38,
        arc = function(y) return ArcX(PICKER_TOP + y) end,
        ring = { anchor = f, theta = 0.34, x = -K.NEAR },
    })
    self.picker:SetPoint("TOPLEFT", f, "CENTER", 30 - K.NEAR, PICKER_TOP)
    self.picker:SetHeight(400)

    -- Takes the next controller button while one is being recorded
    local capture = K.NewFrame("Frame", nil, UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetSize(1, 1)
    capture:SetPoint("CENTER")
    capture:Hide()
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then G:StopCapture() end
    end)
    if capture.EnableGamePadButton then
        -- A button pressed and let go while recording (Square's own release,
        -- from starting it, doesn't count)
        capture:SetScript("OnGamePadButtonDown", function(self, button) self.held = button end)
        capture:SetScript("OnGamePadButtonUp", function(self, button)
            if button == self.held then G:Recorded(button) end
        end)
    end
    self.capture = capture
    self:SyncPicker(true)
end

function G:SyncPicker(force)
    local item = self:Item()
    if self.pickerFor == item.key and not force then return end
    self.pickerFor = item.key
    self.picker:Open({
        lists = { { key = item.key, label = item.label, entries = function()
            return item.options and item.options() or {}
        end } },
        rows = PICKER_ROWS, chooseVerb = "Set",
        current = function() return item.value and item.value() end,
        onChoose = function(e)
            item.choose(e.action)
            G.picker:LoadList()
            menu.Render()
        end,
        onBack = function()
            G.zone = "rail"
            menu.Render()
        end,
    })
end

function G:Show()
    self.zone = "rail"
    self.frame:Show()
end

function G:Hide()
    self:StopCapture()
    self.frame:Hide()
end

function G:Aim()
    if not self:Item().options then return end
    self.zone = "picker"
    self:SyncPicker()
    self.picker:LoadList()
    menu.Render()
end

---------------------------------------------------------------------------
-- Binding a Misc item to another button
---------------------------------------------------------------------------
function G:StartCapture()
    local item = self:Item()
    if not item.bindable or IC.InCombat() then return end
    self.zone = "capture"
    local c = self.capture
    c.held = nil
    c:Show()
    c:EnableKeyboard(true)
    c:SetPropagateKeyboardInput(false)
    if c.EnableGamePadButton then c:EnableGamePadButton(true) end
    menu.Toast(IC.PadText(item.label .. ": press a button for it ({B} cancels)"))
    self.captureToken = (self.captureToken or 0) + 1
    local token = self.captureToken
    C_Timer.After(10, function()
        if G.captureToken == token and G.zone == "capture" then G:StopCapture() end
    end)
    menu.Render()
end

function G:StopCapture()
    local c = self.capture
    if c and c:IsShown() then
        c:Hide()
        if not IC.InCombat() then
            c:EnableKeyboard(false)
            if c.EnableGamePadButton then c:EnableGamePadButton(false) end
        end
    end
    if self.zone == "capture" then self.zone = "rail" end
end

function G:Recorded(button)
    if self.zone ~= "capture" then return end
    local item = self:Item()
    -- (on the next frame: the press that ended it is still being handled)
    C_Timer.After(0, function()
        G:StopCapture()
        if button == "PAD2" then
            menu.Toast(item.label .. ": unchanged")
        elseif not IC.InCombat() then
            item.bind(button)
            menu.Toast(item.label .. ": " .. IC.ButtonName(button))
        end
        menu.Render()
    end)
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
function G:Press(name)
    if self.zone == "capture" then return true end
    if name == "LB" or name == "RB" then return false end
    if name == "X" then
        if self:Item().bindable then self:StartCapture() end
        return true
    end
    if self.zone == "picker" then
        if name == "LEFT" or name == "B" then
            self.zone = "rail"
        elseif name ~= "RIGHT" then
            self.picker:Press(name)
        end
        menu.Render()
        return true
    end
    if name == "UP" or name == "DOWN" then
        self.index = math.max(1, math.min(#ITEMS, self.index + (name == "UP" and -1 or 1)))
    elseif name == "RIGHT" or name == "A" then
        self:Aim()
        return true
    else
        -- Circle closes the panel
        return false
    end
    menu.Render()
    return true
end

function G:Help()
    local H = K.H
    if self.zone == "capture" then
        return { H({ "B" }, "Cancel", "B") }
    end
    local hints = {}
    if self.zone == "picker" then
        hints[#hints + 1] = H({ "DPAD" }, "Move")
        hints[#hints + 1] = H({ "A" }, "Set", "A")
    else
        hints[#hints + 1] = H({ "DPAD" }, "Pick")
        if self:Item().options then hints[#hints + 1] = H({ "A" }, "Edit", "A") end
    end
    if self:Item().bindable then hints[#hints + 1] = H({ "X" }, "Bind", "X") end
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, self.zone == "picker" and "Back" or "Close", "B")
    return hints
end

function G:Crumb()
    return "General › " .. self:Item().label
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function G:Render()
    local f = self.frame
    if not f then return end
    if self.zone ~= "picker" and self.zone ~= "capture" then self.zone = "rail" end
    self:SyncPicker()
    local lines = Lines()
    local n = #lines
    for i, r in ipairs(f.rows) do
        local line = lines[i]
        local theta = math.pi - ((n + 1) / 2 - i) * K.SEG.STEP
        r.seg:Place(f, theta, K.NEAR)
        r.index = line.index
        if line.header then
            r.seg:SetShown(false)
            r.seg:SetFocus(false)
            r.label:SetText(line.header:upper())
            r.label:SetTextColor(unpack(KC.dimGold))
        else
            local item = ITEMS[line.index]
            local isSel = line.index == self.index
            r.seg:SetShown(true)
            r.seg:SetFocus(isSel and self.zone == "rail")
            r.label:SetText(item.label)
            r.label:SetTextColor(unpack(isSel and KC.focus or KC.rail))
        end
        K.Rotate(r.label, K.ReadingAngle(theta))
    end
    -- The selected setting: its icon, its value, what it is bound to
    local item = self:Item()
    local off = item.value and item.value() == "off"
    f.big:SetLook({ icon = Resolve(item.icon), discColor = KC.iconBg, hatch = off, dash = true })
    f.big:SetAlpha(off and 0.45 or 1)
    local text = item.text and item.text() or ""
    if item.bindable then
        local key = item.binding()
        text = text .. "|n|cffd8ccb0" .. (self.zone == "capture" and "Press a button..."
            or ("Button: " .. IC.GlyphText(key, 20) .. " " .. IC.ButtonName(key))) .. "|r"
    end
    f.value:SetText(text)
    f.note:SetText(Resolve(item.note) or item.tip or "")
    self.picker:SetShown(item.options ~= nil)
    self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
    if item.options then self.picker:Render() end
end

---------------------------------------------------------------------------
-- The General tab (Menu.lua) uses this page
---------------------------------------------------------------------------
for _, def in ipairs(menu.TABS) do
    if def.key == "general" then
        def.page = function() return G end
    end
end

hooksecurefunc(menu, "Close", function()
    G:StopCapture()
    G.zone = "rail"
end)
