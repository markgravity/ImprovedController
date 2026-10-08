-- The Vibration tab, laid out like the Gather tab: the events down the
-- left by group (Combat; Casting: spell, gathering, crafting; Wheel;
-- Progress), the selected one big in the middle with its pattern, and its
-- choices down the right as slices of a ring around it: an event's
-- patterns, or for a kind of cast the ready-made sets for its four moments
-- (casting, interrupted, cancelled, pushed back). Choosing one sets it and
-- plays it; Triangle plays it again. First, under Settings: vibration on /
-- off and its strength.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local V = IC.Vibe

local PANEL_W, PICKER_TOP, PICKER_ROWS = 340, 236, 8
local RAIL_ROWS = 8                 -- lines on the left at once (as the picker); the rest scroll
local ARC = 300
local function ArcX(dy)
    return math.sqrt(math.max(0, ARC * ARC - dy * dy))
end

local E = { zone = "rail", index = 1 }
V.Editor = E

---------------------------------------------------------------------------
-- The settings, at the top of the rail: { setting = { value, text,
-- options, choose } } in place of an event's subs
---------------------------------------------------------------------------
local TEX = "Interface\\AddOns\\ImprovedController\\textures\\"

table.insert(V.GROUPS, 1, { key = "settings", label = "Settings" })
table.insert(V.RAIL, 1, {
    key = "vibe_on", group = "settings", label = "Vibration", icon = TEX .. "ic_vibe_pulse", subs = {},
    setting = {
        value = function() return V.Settings().enabled and "on" or "off" end,
        text = function() return V.Settings().enabled and "On" or "|cffff7a5cOff|r" end,
        options = function()
            return { { action = "on", name = "On", icon = TEX .. "ic_emote_yes" },
                { action = "off", name = "Off", icon = TEX .. "ic_emote_no" } }
        end,
        choose = function(action)
            V.Settings().enabled = action == "on"
            if action == "on" then V.Play("pulse") else V.Stop() end
            menu.Toast("Vibration: " .. action)
        end,
    },
})
table.insert(V.RAIL, 2, {
    key = "vibe_strength", group = "settings", label = "Strength", icon = TEX .. "ic_vibe_rise", subs = {},
    setting = {
        value = function() return tostring(math.floor(V.Settings().intensity * 10 + 0.5)) end,
        text = function() return math.floor(V.Settings().intensity * 100 + 0.5) .. "%" end,
        options = function()
            local list = {}
            for n = 1, 10 do list[#list + 1] = { action = tostring(n), name = (n * 10) .. "%", icon = TEX .. "ic_vibe_pulse" } end
            return list
        end,
        choose = function(action)
            V.Settings().intensity = tonumber(action) / 10
            V.Play("pulse")
            menu.Toast("Vibration strength: " .. (tonumber(action) * 10) .. "%")
        end,
    },
})

-- The selected line on the left (V.RAIL: an event, or a kind of cast)
function E:Item()
    return V.RAIL[self.index]
end

local function Patterns()
    local entries = { { action = "off", name = "Off", icon = V.OFF_ICON } }
    -- (the actions' own patterns only come with Match the action)
    for _, p in ipairs(V.PATTERNS) do
        if not p.action then entries[#entries + 1] = { action = p.key, name = p.label, icon = p.icon } end
    end
    return entries
end

-- The picker on the selected line: one list of patterns per event in it
-- (a kind of cast: the ready-made sets)
function E:SyncPicker()
    local item = self:Item()
    if self.pickerFor == item.key then return end
    self.pickerFor = item.key
    -- A setting: its choices
    if item.setting then
        self.picker:Open({
            lists = { { key = item.key, label = item.label, entries = item.setting.options } },
            rows = PICKER_ROWS, chooseVerb = "Set",
            current = function() return item.setting.value() end,
            onChoose = function(e) E:Set(e) end,
            onBack = function()
                E.zone = "rail"
                menu.Render()
            end,
        })
        return
    end
    -- A kind of cast: one list, the ready-made sets
    if item.castKind then
        self.picker:Open({
            lists = { { key = item.key, label = "Vibration", entries = function()
                -- Off, Match the action, then the general sets (each action's
                -- own set only comes with Match the action)
                local entries = {}
                for _, p in ipairs(V.CAST_PRESETS) do
                    if not p.action then
                        entries[#entries + 1] = { action = p.key, name = p.label, icon = p.auto and item.icon or p.icon }
                    end
                end
                return entries
            end } },
            rows = PICKER_ROWS, chooseVerb = "Set",
            current = function() return V.CastPreset(item.castKind) end,
            onChoose = function(e) E:Set(e) end,
            onBack = function()
                E.zone = "rail"
                menu.Render()
            end,
        })
        return
    end
    local lists = {}
    for _, sub in ipairs(item.subs) do
        lists[#lists + 1] = { key = sub.key, label = #item.subs > 1 and sub.label or "Vibration", sub = sub,
            entries = Patterns }
    end
    self.picker:Open({
        lists = lists, rows = PICKER_ROWS, chooseVerb = "Set",
        current = function(list) return V.EventPattern(list.sub.key) or "off" end,
        onChoose = function(e) E:Set(e) end,
        onBack = function()
            E.zone = "rail"
            menu.Render()
        end,
    })
end

-- The event being set: the selected line's, its list in the picker
function E:Event()
    local item = self:Item()
    self:SyncPicker()
    return item.subs[self.picker.list] or item.subs[1]
end

-- The left side's lines: each group's name, then its events
local function Lines()
    local lines = {}
    for _, group in ipairs(V.GROUPS) do
        lines[#lines + 1] = { header = group.label }
        for i, item in ipairs(V.RAIL) do
            if item.group == group.key then lines[#lines + 1] = { index = i } end
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function E:Build(parent)
    -- The whole screen, as the other tabs with a ring
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- The middle: the selected event, big, and its pattern under it
    local big = K.Slot(f, 150, 108)
    big:SetPoint("CENTER", f, "CENTER", 0, 10)
    big:SetScript("OnClick", function() E:Aim() end)
    f.big = big
    f.pattern = K.Text(f, 16, KC.title)
    f.pattern:SetPoint("TOP", big, "BOTTOM", 0, -40)
    f.pattern:SetJustifyH("CENTER")

    -- Left: the groups' names and their events, slices down the ring's left
    -- side (a name: just its text, in its slice's place)
    f.rows = {}
    f.railUp, f.railDown = K.MoreArrows(f)
    for i in ipairs(Lines()) do
        local r = K.NewFrame("Button", nil, f)
        r:SetSize(200, 34)
        r.seg = K.Segment(r)
        r.label = K.Text(r, 14, KC.rail, "OVERLAY")
        r.label:SetJustifyH("CENTER")
        r.label:SetPoint("CENTER")
        r:SetScript("OnClick", function(self)
            if not self.index then return end
            E.index, E.zone = self.index, "rail"
            menu.Render()
        end)
        f.rows[i] = r
    end

    -- Right: the patterns
    self.picker = K.Picker(f, PANEL_W, menu.Render, {
        bare = true, rowHeight = 38,
        arc = function(y) return ArcX(PICKER_TOP + y) end,
        ring = { anchor = f, theta = 0.34, x = -K.NEAR },
    })
    self.picker:SetPoint("TOPLEFT", f, "CENTER", 30 - K.NEAR, PICKER_TOP)
    self.picker:SetHeight(400)
    self:SyncPicker()
end

function E:Show()
    self.zone = "rail"
    self.frame:Show()
end

function E:Hide()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Setting
---------------------------------------------------------------------------
-- The picker on the event's pattern
function E:Aim()
    self.zone = "picker"
    self:SyncPicker()
    self.picker:LoadList()
    menu.Render()
end

function E:Set(e)
    local item = self:Item()
    if item.setting then
        item.setting.choose(e.action)
        self.picker:LoadList()
        menu.Render()
        return
    end
    if item.castKind then
        V.SetCastPreset(item.castKind, e.action)
        menu.Toast(item.label .. ": " .. e.name)
        -- Felt as a cast would go with it
        if e.action ~= "off" then self:Try() end
        menu.Render()
        return
    end
    local event = self:Event()
    V.SetEventPattern(event.key, e.action)
    if e.action ~= "off" then V.Play(e.action) end
    menu.Toast(event.label .. ": " .. e.name)
    menu.Render()
end

-- Triangle: feel the event's pattern again (a kind of cast: a whole cast
-- played out, each of its four where it would come; a critical hit: a
-- combo of them)
function E:Try()
    if not V.Settings().enabled then
        menu.Toast("Vibration is off (Settings, at the top)", true)
        return
    end
    local item = self:Item()
    if item.setting then return V.Play("pulse") end
    if item.castKind then
        if V.CastPreset(item.castKind) == "off" then
            menu.Toast(item.label .. " is off", true)
            return
        end
        V.SimulateCast(function(label)
            if label then menu.Toast(item.label .. ": " .. label) end
        end, item.castKind)
        return
    end
    local event = self:Event()
    local pattern = V.EventPattern(event.key)
    if not pattern then
        menu.Toast(event.label .. " is off", true)
    elseif event.loop then
        -- Plays on, as it would while the state lasts
        if V.SimulateLoop(event.key, 6) then
            menu.Toast(event.label .. ": playing (" .. IC.ButtonName("Y") .. " stops)")
        else
            menu.Toast(event.label .. ": stopped")
        end
    elseif event.combo then
        -- A run of crits, each hit varied as in a real combo
        V.SimulateCombo(event.key, function(n)
            menu.Toast(event.label .. (n > 1 and " x" .. n or ""))
        end)
    else
        V.Play(pattern)
    end
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
-- Left / right move between the events (left) and the patterns (right);
-- up / down move inside them.
function E:Press(name)
    if name == "LB" or name == "RB" then return false end
    -- L2 / R2: an item's lists, from either side
    if name == "LT" or name == "RT" then
        self:SyncPicker()
        self.picker:Press(name)
        menu.Render()
        return true
    end
    if name == "Y" then
        self:Try()
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
        self.index = math.max(1, math.min(#V.RAIL, self.index + (name == "UP" and -1 or 1)))
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

function E:Help()
    local H = K.H
    local hints = {}
    if self.zone == "picker" then
        hints[#hints + 1] = H({ "DPAD" }, "Move")
        hints[#hints + 1] = H({ "A" }, "Set", "A")
    else
        hints[#hints + 1] = H({ "DPAD" }, "Pick event")
        hints[#hints + 1] = H({ "A" }, "Edit", "A")
    end
    if #self:Item().subs > 1 then hints[#hints + 1] = H({ "LT", "RT" }, "Event", "RT") end
    hints[#hints + 1] = H({ "Y" }, "Try it", "Y")
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, self.zone == "picker" and "Events" or "Close", "B")
    return hints
end

function E:Crumb()
    return "Vibration › " .. (self:Item().setting and self:Item().label or self:Event().label)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function E:Render()
    local f = self.frame
    if not f then return end
    if self.zone ~= "picker" then self.zone = "rail" end
    local settings = V.Settings()
    -- The groups and their events down the ring's left side, centred on it,
    -- each name along its slice; a group's name in gold without a slice
    -- Only RAIL_ROWS lines at once, scrolled to keep the selected one in
    -- view, arrows past the ends when there are more
    local lines = Lines()
    local shown, thetaAt
    self.railTop, shown, thetaAt = K.RailWindow(lines, self.index, self.railTop, RAIL_ROWS)
    K.RingArrow(f.railUp, f, thetaAt(0.25), true, K.NEAR)
    f.railUp:SetShown(self.railTop > 1)
    K.RingArrow(f.railDown, f, thetaAt(shown + 0.75), false, K.NEAR)
    f.railDown:SetShown(self.railTop + shown - 1 < #lines)
    for i, r in ipairs(f.rows) do
        local line = lines[i]
        local slot = i - self.railTop + 1
        r:SetShown(line ~= nil and slot >= 1 and slot <= shown)
        if r:IsShown() then
            local theta = thetaAt(slot)
            r.seg:Place(f, theta, K.NEAR)
            r.index = line.index
            if line.header then
                r.seg:SetShown(false)
                r.seg:SetFocus(false)
                r.label:SetText(line.header:upper())
                r.label:SetTextColor(unpack(KC.dimGold))
            else
                -- Off: none of its events vibrates
                local item = V.RAIL[line.index]
                local on = false
                if item.setting then
                    on = item.setting.value() ~= "off"
                elseif item.castKind then
                    on = V.CastPreset(item.castKind) ~= "off"
                else
                    for _, sub in ipairs(item.subs) do
                        if V.EventPattern(sub.key) then on = true end
                    end
                end
                local isSel = line.index == self.index
                r.seg:SetShown(true)
                r.seg:SetFocus(isSel and self.zone == "rail")
                r.label:SetText(item.label .. (on and "" or "  |cffff7a5cOff|r"))
                r.label:SetTextColor(unpack(isSel and KC.focus or KC.rail))
            end
            K.Rotate(r.label, K.ReadingAngle(theta))
        end
    end
    local item = self:Item()
    -- A setting: its value
    if item.setting then
        local off = item.setting.value() == "off"
        f.big:SetLook({ icon = item.icon, discColor = KC.iconBg, hatch = off, dash = true })
        f.big:SetAlpha(off and 0.45 or 1)
        f.pattern:SetText(item.setting.text())
        self.picker:Show()
        self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
        self.picker:Render()
        return
    end
    -- A kind of cast: its set, and what each moment plays
    if item.castKind then
        local preset = V.Preset(V.CastPreset(item.castKind))
        local on = preset and preset.key ~= "off"
        f.big:SetLook({ icon = item.icon, discColor = KC.iconBg, hatch = not on, dash = true })
        f.big:SetAlpha((settings.enabled and on) and 1 or 0.45)
        local text = on and preset.label or "|cffff7a5cOff|r"
        if on and preset.auto then
            text = text .. "|n|cffb9ab8cEach action its own feel|r"
        elseif on then
            local parts = {}
            for _, phase in ipairs(V.CAST_PHASES) do
                local pattern = V.Pattern(preset[phase])
                local label = phase == "cast" and "Casting" or (phase:sub(1, 1):upper() .. phase:sub(2))
                if phase == "pushback" then label = "Pushed back" end
                parts[#parts + 1] = label .. ": " .. (pattern and pattern.label or "—")
            end
            text = text .. "|n|cffb9ab8c" .. table.concat(parts, "|n") .. "|r"
        end
        f.pattern:SetText(text)
        self.picker:Show()
        self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
        self.picker:Render()
        return
    end
    -- The selected event, its pattern under it
    local event = self:Event()
    local pattern = V.Pattern(V.EventPattern(event.key))
    f.big:SetLook({ icon = event.icon, discColor = KC.iconBg, hatch = not pattern,
        dash = true })
    f.big:SetAlpha((settings.enabled and pattern) and 1 or 0.45)
    local name = #self:Item().subs > 1 and event.label .. ": " or ""
    f.pattern:SetText(name .. (pattern and pattern.label or "|cffff7a5cOff|r"))
    self.picker:Show()
    self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
    self.picker:Render()
end

---------------------------------------------------------------------------
-- The Vibration tab (Menu.lua) uses this page
---------------------------------------------------------------------------
for _, def in ipairs(menu.TABS) do
    if def.key == "vibration" then
        def.page = function() return E end
    end
end

hooksecurefunc(menu, "Close", function()
    E.zone = "rail"
    V.StopSimulation()
end)
