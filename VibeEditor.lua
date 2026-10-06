-- The Vibration tab, laid out like the Touchpad tab: the events down the
-- left by group (Combat: critical hit, taken; Progress: level up), the selected one big in the
-- middle with its pattern, and the patterns down the right (Off and Easy
-- Controller's seven) as slices of a ring around it. Choosing a pattern
-- sets it and plays it; Triangle plays the event's one again. (Vibration
-- on / off and its strength: the Home tab.)
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local V = IC.Vibe

local PANEL_W, PICKER_TOP, PICKER_ROWS = 340, 236, 8
local ARC = 300
local function ArcX(dy)
    return math.sqrt(math.max(0, ARC * ARC - dy * dy))
end

local E = { zone = "rail", index = 1 }
V.Editor = E

function E:Event()
    return V.EVENTS[self.index]
end

-- The left side's lines: each group's name, then its events
local function Lines()
    local lines = {}
    for _, group in ipairs(V.GROUPS) do
        lines[#lines + 1] = { header = group.label }
        for i, event in ipairs(V.EVENTS) do
            if event.group == group.key then lines[#lines + 1] = { index = i } end
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
        ring = { anchor = f, theta = 0.34 },
    })
    self.picker:SetPoint("TOPLEFT", f, "CENTER", 30, PICKER_TOP)
    self.picker:SetHeight(400)
    self.picker:Open({
        lists = { { key = "patterns", label = "Vibration", entries = function()
            local entries = { { action = "off", name = "Off", icon = V.OFF_ICON } }
            for _, p in ipairs(V.PATTERNS) do
                entries[#entries + 1] = { action = p.key, name = p.label, icon = p.icon }
            end
            return entries
        end } },
        rows = PICKER_ROWS, chooseVerb = "Set",
        onChoose = function(e) E:Set(e) end,
        onBack = function()
            E.zone = "rail"
            menu.Render()
        end,
    })
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
    self.picker.def.current = V.EventPattern(self:Event().key) or "off"
    self.picker:LoadList()
    menu.Render()
end

function E:Set(e)
    local event = self:Event()
    V.SetEventPattern(event.key, e.action)
    if e.action ~= "off" then V.Play(e.action) end
    menu.Toast(event.label .. ": " .. e.name)
    menu.Render()
end

-- Triangle: feel the event's pattern again
function E:Try()
    local pattern = V.EventPattern(self:Event().key)
    if not pattern then
        menu.Toast(self:Event().label .. " is off", true)
    elseif not V.Settings().enabled then
        menu.Toast("Vibration is off (Home tab)", true)
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
        self.index = math.max(1, math.min(#V.EVENTS, self.index + (name == "UP" and -1 or 1)))
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
    hints[#hints + 1] = H({ "Y" }, "Try it", "Y")
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, self.zone == "picker" and "Events" or "Close", "B")
    return hints
end

function E:Crumb()
    return "Vibration › " .. self:Event().label
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
    local lines = Lines()
    local n = #lines
    for i, r in ipairs(f.rows) do
        local line = lines[i]
        local theta = math.pi - ((n + 1) / 2 - i) * K.SEG.STEP
        r.seg:Place(f, theta)
        r.index = line.index
        if line.header then
            r.seg:SetShown(false)
            r.seg:SetFocus(false)
            r.label:SetText(line.header:upper())
            r.label:SetTextColor(unpack(KC.dimGold))
        else
            local event = V.EVENTS[line.index]
            local isSel = line.index == self.index
            r.seg:SetShown(true)
            r.seg:SetFocus(isSel and self.zone == "rail")
            r.label:SetText(event.label .. (V.EventPattern(event.key) and "" or "  |cffff7a5cOff|r"))
            r.label:SetTextColor(unpack(isSel and KC.focus or KC.rail))
        end
        K.Rotate(r.label, K.ReadingAngle(theta))
    end
    -- The selected event, its pattern under it
    local event = self:Event()
    local pattern = V.Pattern(V.EventPattern(event.key))
    f.big:SetLook({ icon = event.icon, discColor = KC.iconBg, hatch = not pattern,
        dash = true })
    f.big:SetAlpha((settings.enabled and pattern) and 1 or 0.45)
    f.pattern:SetText(pattern and pattern.label or "|cffff7a5cOff|r")
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
end)
