-- The Touchpad tab, laid out like the Wheels tab: the four corners by name
-- down the left, the selected corner's slot big in the middle, and the
-- picker (Spells, Items, Macros, Interface; L2 / R2) down the right, the
-- lists as slices of a ring around it. A corner is picked from the list,
-- by clicking the touchpad (the corner under the finger) or by pointing
-- the right stick; a choice in the picker binds it. Triangle clears a
-- corner, held turns it off. (Turning the touchpad click on / off: the Home
-- tab.)
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local touch = IC.Touch
local MW = IC.MyWheels

local PANEL_W, PICKER_TOP, PICKER_ROWS = 340, 236, 7
local ARC = 300
local function ArcX(dy)
    return math.sqrt(math.max(0, ARC * ARC - dy * dy))
end

-- The corners, row by row as on the pad
local GRID = {
    { "upleft", "upright" },
    { "downleft", "downright" },
}

local function Settings()
    return touch.GetSettings()
end

local T = { zone = "rail", row = 1, col = 1 }

function T:SelectRegion(region)
    for r, row in ipairs(GRID) do
        for c, name in ipairs(row) do
            if name == region then self.row, self.col = r, c end
        end
    end
end
touch.Editor = T

function T:Region()
    return GRID[self.row][self.col]
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function T:Build(parent)
    -- The whole screen, as the Wheels tab (the panel's frame, not its body)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- The middle: one big slot, the selected corner's
    local big = K.Slot(f, 150, 108)
    big:SetPoint("CENTER", f, "CENTER", 0, 0)
    big:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            T:Clear()
        else
            T:Aim()
        end
    end)
    f.big = big
    -- Under it, what the corner runs (as the Vibration tab shows its pattern)
    f.bound = K.Text(f, 16, KC.title)
    f.bound:SetPoint("TOP", big, "BOTTOM", 0, -40)
    f.bound:SetJustifyH("CENTER")

    -- Left: the corners by name, slices down the ring's left side
    f.rows = {}
    for i, region in ipairs(touch.REGIONS) do
        local r = K.NewFrame("Button", nil, f)
        r:SetSize(200, 34)
        r.seg = K.Segment(r)
        r.label = K.Text(r, 14, KC.rail, "OVERLAY")
        r.label:SetJustifyH("CENTER")
        r.label:SetPoint("CENTER")
        r:SetScript("OnClick", function()
            T:SelectRegion(region)
            T.zone = "rail"
            menu.Render()
        end)
        f.rows[i] = r
    end

    -- Right: the picker of what a slot runs
    local lists = {}
    for _, list in ipairs(MW.CATALOG) do
        if list.key ~= "emotes" then lists[#lists + 1] = list end
    end
    lists[#lists + 1] = { key = "interface", label = "Interface", entries = touch.InterfaceEntries }
    self.picker = K.Picker(f, PANEL_W, menu.Render, {
        bare = true, rowHeight = 38,
        arc = function(y) return ArcX(PICKER_TOP + y) end,
        ring = { anchor = f, theta = 0.34 },
    })
    self.picker:SetPoint("TOPLEFT", f, "CENTER", 30, PICKER_TOP)
    self.picker:SetHeight(400)
    self.picker:Open({
        kicker = function() return "Slot · " .. touch.REGION_LABELS[T:Region()] end,
        title = function()
            local key = Settings().regions[T:Region()]
            return touch.IsBound(key) and touch.ActionLabel(key) or "Empty"
        end,
        lists = lists, rows = PICKER_ROWS, chooseVerb = "Bind",
        marked = function(e)
            for _, key in pairs(Settings().regions) do
                if key == e.action then return true end
            end
            return false
        end,
        onChoose = function(e) T:Bind(e) end,
        onBack = function()
            T.zone = "rail"
            menu.Render()
        end,
    })
end

function T:Show()
    self.zone = "rail"
    self.frame:Show()
end

function T:Hide()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Picking, binding
---------------------------------------------------------------------------
-- The picker on the slot's action (its list, its entry)
function T:Target()
    local def = self.picker.def
    local key = Settings().regions[self:Region()]
    def.current = key
    local kind = touch.IsBound(key) and (key:match("^(%a+):") or "interface")
    for i, list in ipairs(def.lists) do
        if kind and (list.key == kind or list.key == kind .. "s") then
            if i ~= self.picker.list then self.picker.list = i end
            break
        end
    end
    self.picker:LoadList()
end

function T:Aim()
    self.zone = "picker"
    self:Target()
    menu.Render()
end

function T:Bind(e)
    touch.SetAction(self:Region(), e.action)
    menu.Toast(touch.REGION_LABELS[self:Region()] .. ": " .. (e.name or ""))
    menu.Render()
end

-- Triangle: a press clears the slot, held (0.6 s) turns it off / on
local HOLD = 0.6

function T:Triangle()
    if self.holding then return end
    local region, started = self:Region(), GetTime()
    self.holding = region
    menu.Render()
    self.holdTicker = C_Timer.NewTicker(0.05, function(ticker)
        local held = IsKeyDown and IsKeyDown("PAD4")
        if held and GetTime() - started >= HOLD then
            ticker:Cancel()
            T.holding = nil
            local off = touch.ToggleOff(region)
            menu.Toast(touch.REGION_LABELS[region] .. (off and " turned off" or " turned on")
                .. (off and touch.CORNERS[region] and " (its sides take its area)" or ""))
            menu.Render()
        elseif not held then
            ticker:Cancel()
            T.holding = nil
            T:Clear(region)
        end
    end)
end

function T:Clear(region)
    region = region or self:Region()
    if touch.IsBound(Settings().regions[region]) then
        touch.SetAction(region, "none")
        menu.Toast(touch.REGION_LABELS[region] .. " cleared")
    end
    menu.Render()
end


-- A touchpad click while the tab is up: the slot under the finger (in the
-- picker: the slot it binds)
function T:OnTouch()
    local x, y = touch.FingerPosition()
    if not x then return end
    local region = touch.RegionAt(x, y)
    for r, row in ipairs(GRID) do
        for c, name in ipairs(row) do
            if name == region then self.row, self.col = r, c end
        end
    end
    -- Picking a slot edits it: the picker takes the focus
    self.zone = "picker"
    self:Target()
    menu.Render()
end

-- The right stick points at a corner (its quarter), as on the Wheels tab

function T:OnStick(stick, x, y, len)
    if stick ~= "Right" and stick ~= "Camera" then return end
    if (len or 0) < 0.5 then return end
    local region = (y > 0 and "up" or "down") .. (x > 0 and "right" or "left")
    if region == self:Region() and self.zone == "picker" then return end
    for r, row in ipairs(GRID) do
        for c, name in ipairs(row) do
            if name == region then self.row, self.col = r, c end
        end
    end
    self.zone = "picker"
    self:Target()
    menu.Render()
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
-- Left / right move between the corners (left) and the picker (right);
-- up / down move inside them. A touchpad click or the right stick picks a
-- corner too, and gives the picker the focus.
function T:Press(name)
    if name == "LB" or name == "RB" then return false end
    if name == "Y" then
        self:Triangle()
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
    -- The corners
    local index = 1
    for i, region in ipairs(touch.REGIONS) do
        if region == self:Region() then index = i end
    end
    if name == "UP" or name == "DOWN" then
        index = math.max(1, math.min(#touch.REGIONS, index + (name == "UP" and -1 or 1)))
        self:SelectRegion(touch.REGIONS[index])
    elseif name == "RIGHT" or name == "A" then
        self.zone = "picker"
        self:Target()
    else
        -- Circle closes the panel
        return false
    end
    menu.Render()
    return true
end

function T:Help()
    local H = K.H
    local hints = { H({ "TOUCHPAD" }, "Slot"), H({ "RS" }, "Slot") }
    if self.zone == "picker" then
        hints[#hints + 1] = H({ "DPAD" }, "Move")
        hints[#hints + 1] = H({ "A" }, "Bind", "A")
        hints[#hints + 1] = H({ "LT", "RT" }, "List", "RT")
    else
        hints[#hints + 1] = H({ "DPAD" }, "Pick corner")
        hints[#hints + 1] = H({ "A" }, "Edit", "A")
    end
    hints[#hints + 1] = H({ "Y" }, "Clear (hold: off)", "Y")
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, self.zone == "picker" and "Corners" or "Close", "B")
    return hints
end

function T:Crumb()
    return "Touchpad › " .. touch.REGION_LABELS[self:Region()]
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function T:Render()
    local f = self.frame
    if not f then return end
    if self.zone ~= "picker" then self.zone = "rail" end
    local settings = Settings()
    local on = settings.enabled ~= false
    local selected = self:Region()
    -- The corners down the ring's left side, centred on it, each name along
    -- its slice (dimmed when turned off)
    local n = #f.rows
    for i, r in ipairs(f.rows) do
        local region = touch.REGIONS[i]
        local theta = math.pi - ((n + 1) / 2 - i) * K.SEG.STEP
        r.seg:Place(f, theta)
        local isSel = region == selected
        r.seg:SetFocus(isSel and self.zone == "rail")
        r.label:SetText(touch.REGION_LABELS[region] .. (touch.IsOff(region) and "  |cffff7a5cOff|r" or ""))
        r.label:SetTextColor(unpack(isSel and KC.focus or KC.rail))
        K.Rotate(r.label, K.ReadingAngle(theta))
    end
    -- The big slot: what the selected corner holds
    local key = settings.regions[selected]
    local bound = touch.IsBound(key)
    local off = touch.IsOff(selected)
    f.big:SetLook({ icon = bound and (touch.ActionIcon(key) or 134400) or nil, discColor = bound and KC.iconBg or nil,
        plus = not bound and not off, hatch = off, dash = true })
    f.big:SetAlpha((on and not off) and 1 or 0.45)
    f.bound:SetText(off and "|cffff7a5cOff|r" or (bound and touch.ActionLabel(key) or "|cff9d917aEmpty|r"))
    self.picker:Show()
    self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
    self.picker:Render()
end

---------------------------------------------------------------------------
-- The Touchpad tab (Menu.lua) uses this page
---------------------------------------------------------------------------
for _, def in ipairs(menu.TABS) do
    if def.key == "touchpad" then
        def.page = function() return T end
    end
end

-- The panel kept the touchpad click while it was open; give it back
hooksecurefunc(menu, "Close", function()
    T.zone = "rail"
    if not IC.InCombat() then touch.Apply() end
end)
