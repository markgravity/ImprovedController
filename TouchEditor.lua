-- The Touchpad tab, one screen: on the left the pad drawn with its nine
-- regions as slots (corners, sides, centre) like the wheel editor's, its
-- settings under it; on the right the picker (Spells, Items, Macros,
-- Interface; L2 / R2). A slot is picked with the D-pad or by clicking the
-- touchpad itself (the slot under the finger lights up); Cross aims the
-- picker at it, a choice binds it, Triangle clears it.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local touch = IC.Touch
local MW = IC.MyWheels

local BODY_W, BODY_H, PANEL_W, GAP = 964, 424, 400, 12
local AREA_W = BODY_W - PANEL_W - GAP
local PAD_W, PAD_H, PAD_TOP = 390, 222, 42
local SLOT_SIZE, ICON_SIZE = 46, 32
local INSET, MAP_COLS, MAP_ROWS = 4, 39, 22
local ROW_H, ROWS_TOP = 36, PAD_TOP + PAD_H + 12

-- The slots, row by row as on the pad
local GRID = {
    { "upleft", "up", "upright" },
    { "left", "centre", "right" },
    { "downleft", "down", "downright" },
}
local COLS = { 70, 195, 320 }
local ROWS = { 38, 108, 178 }

local function Settings()
    return touch.GetSettings()
end

local function Percent(v)
    return math.floor(v * 100 + 0.5) .. "%"
end

-- The settings under the pad: { label, value(), step(delta) }
local SETTINGS = {
    {
        label = "Touchpad click",
        value = function() return Settings().enabled ~= false and "On" or "Off" end,
        step = function()
            Settings().enabled = Settings().enabled == false
            touch.Apply()
        end,
    },
    {
        label = "Centre size",
        value = function() return Percent(Settings().centre) end,
        step = function(delta) touch.SetCentre(Settings().centre + delta * 0.05) end,
    },
    {
        label = "Corner reach",
        value = function() return Percent(Settings().corner) end,
        step = function(delta) touch.SetCorner(Settings().corner + delta * 0.05) end,
    },
}

local T = { zone = "grid", row = 1, col = 2, setting = 1 }
touch.Editor = T

function T:Region()
    return GRID[self.row][self.col]
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function SettingRow(parent, i)
    local r = K.NewFrame("Button", nil, parent)
    r:SetSize(PAD_W, ROW_H - 2)
    r.sel = K.NineSlice(r, "ck_select", 128, 32, 10, 10, "ARTWORK")
    r.label = K.Text(r, 15, KC.cream)
    r.label:SetPoint("LEFT", 14, 0)
    r.value = K.Text(r, 15, KC.cream)
    r.value:SetPoint("RIGHT", -34, 0)
    r.value:SetJustifyH("CENTER")
    r.value:SetWidth(70)
    r.left = K.Text(r, 14, KC.dimGold)
    r.left:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    r.left:SetText("<")
    r.right = K.Text(r, 14, KC.dimGold)
    r.right:SetPoint("LEFT", r.value, "RIGHT", 4, 0)
    r.right:SetText(">")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(_, button)
        T.zone, T.setting = "settings", i
        SETTINGS[i].step(button == "RightButton" and -1 or 1)
        menu.Render()
    end)
    return r
end

function T:Build(parent)
    local f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()
    self.frame = f

    local area = K.NewFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT")
    area:SetSize(AREA_W, BODY_H)
    f.title = K.Text(area, 18, KC.title)
    f.title:SetPoint("TOP", area, "TOP", 0, -2)
    f.title:SetText("Touchpad")
    f.kicker = K.ChatText(area, 13, KC.grey)
    f.kicker:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    f.kicker:SetText("Click the pad: the slot under your finger runs its action")

    -- The pad: a rounded box the shape of the DualSense's touchpad
    local pad = K.NewFrame("Frame", nil, area)
    pad:SetSize(PAD_W, PAD_H)
    pad:SetPoint("TOP", area, "TOP", 0, -PAD_TOP)
    pad.box = K.Box(pad, 4, 2, "BACKGROUND")
    pad.box:SetPoints(pad)
    pad.box:SetColors(KC.boxBg, 0.9, KC.control, 1)
    -- The regions as the click sees them: the pad cut in cells, each
    -- coloured by touch.RegionAt at its middle, with a line where two
    -- regions meet (so a slot turned off shows its area going to its
    -- neighbours)
    f.cells = {}
    local cw, ch = (PAD_W - 2 * INSET) / MAP_COLS, (PAD_H - 2 * INSET) / MAP_ROWS
    for row = 1, MAP_ROWS do
        f.cells[row] = {}
        for col = 1, MAP_COLS do
            local x, y = INSET + (col - 1) * cw, -(INSET + (row - 1) * ch)
            local cell = pad:CreateTexture(nil, "BACKGROUND", nil, 3)
            cell:SetPoint("TOPLEFT", pad, "TOPLEFT", x, y)
            cell:SetSize(cw, ch)
            local right = pad:CreateTexture(nil, "BORDER", nil, 1)
            right:SetPoint("TOPRIGHT", cell, "TOPRIGHT")
            right:SetSize(1, ch)
            right:SetColorTexture(KC.line1[1], KC.line1[2], KC.line1[3], 1)
            local bottom = pad:CreateTexture(nil, "BORDER", nil, 1)
            bottom:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT")
            bottom:SetSize(cw, 1)
            bottom:SetColorTexture(KC.line1[1], KC.line1[2], KC.line1[3], 1)
            f.cells[row][col] = { tex = cell, right = right, bottom = bottom,
                x = -1 + (col - 0.5) * 2 / MAP_COLS, y = 1 - (row - 0.5) * 2 / MAP_ROWS }
        end
    end
    -- Where the finger is, live (above the zones and the slots)
    local top = K.NewFrame("Frame", nil, pad)
    top:SetAllPoints()
    top:SetFrameLevel(pad:GetFrameLevel() + 20)
    f.finger = top:CreateTexture(nil, "OVERLAY", nil, 6)
    f.finger:SetTexture(K.TEX .. "ck_dot")
    f.finger:SetSize(16, 16)
    f.finger:SetVertexColor(1, 1, 1)
    f.finger:Hide()
    f:SetScript("OnUpdate", function() T:UpdateFinger() end)
    f.slots, f.labels = {}, {}
    for r, row in ipairs(GRID) do
        for c, region in ipairs(row) do
            local s = K.Slot(pad, SLOT_SIZE, ICON_SIZE)
            s:SetPoint("CENTER", pad, "TOPLEFT", COLS[c], -(ROWS[r] - 6))
            s:SetScript("OnClick", function(_, button)
                T.row, T.col = r, c
                if button == "RightButton" and IsShiftKeyDown() then
                    touch.ToggleOff(region)
                    menu.Render()
                elseif button == "RightButton" then
                    T:Clear()
                else
                    T:Aim()
                end
            end)
            f.slots[region] = s
            local label = K.Text(pad, 11, KC.grey)
            label:SetPoint("TOP", s, "BOTTOM", 0, -1)
            label:SetWidth(118)
            label:SetJustifyH("CENTER")
            f.labels[region] = label
        end
    end

    -- The settings
    f.rows = {}
    for i in ipairs(SETTINGS) do
        local r = SettingRow(area, i)
        r:SetPoint("TOP", area, "TOP", 0, -(ROWS_TOP + (i - 1) * ROW_H))
        f.rows[i] = r
    end

    -- Right: the picker of what a slot runs
    local lists = {}
    for _, list in ipairs(MW.CATALOG) do
        if list.key ~= "emotes" then lists[#lists + 1] = list end
    end
    lists[#lists + 1] = { key = "interface", label = "Interface", entries = touch.InterfaceEntries }
    self.picker = K.Picker(f, PANEL_W, menu.Render)
    self.picker:SetPoint("TOPRIGHT")
    self.picker:SetHeight(BODY_H)
    self.picker:Open({
        kicker = function() return "Slot · " .. touch.REGION_LABELS[T:Region()] end,
        title = function()
            local key = Settings().regions[T:Region()]
            return touch.IsBound(key) and touch.ActionLabel(key) or "Empty"
        end,
        lists = lists, rows = 9, chooseVerb = "Bind",
        marked = function(e)
            for _, key in pairs(Settings().regions) do
                if key == e.action then return true end
            end
            return false
        end,
        onChoose = function(e) T:Bind(e) end,
        onBack = function()
            T.zone = "grid"
            menu.Render()
        end,
    })
end

function T:Show()
    self.zone = "grid"
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
    self.zone = "grid"
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
    if self.zone == "picker" then
        self:Target()
    else
        self.zone = "grid"
    end
    menu.Render()
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
function T:Press(name)
    if self.zone == "picker" then
        if name == "LB" or name == "RB" then return false end
        if name == "Y" then
            self:Triangle()
            return true
        end
        self.picker:Press(name)
        menu.Render()
        return true
    end
    if self.zone == "settings" then
        local setting = SETTINGS[self.setting]
        if name == "UP" then
            if self.setting == 1 then
                self.zone, self.row = "grid", 3
            else
                self.setting = self.setting - 1
            end
        elseif name == "DOWN" then
            self.setting = math.min(#SETTINGS, self.setting + 1)
        elseif name == "LEFT" or name == "RIGHT" then
            setting.step(name == "LEFT" and -1 or 1)
        elseif name == "A" then
            setting.step(1)
        elseif name == "B" then
            self.zone = "grid"
        else
            return false
        end
        menu.Render()
        return true
    end
    -- On the slots
    if name == "UP" then
        self.row = math.max(1, self.row - 1)
    elseif name == "DOWN" then
        if self.row == 3 then
            self.zone, self.setting = "settings", 1
        else
            self.row = self.row + 1
        end
    elseif name == "LEFT" then
        self.col = math.max(1, self.col - 1)
    elseif name == "RIGHT" then
        self.col = math.min(3, self.col + 1)
    elseif name == "A" then
        self:Aim()
        return true
    elseif name == "Y" then
        self:Triangle()
        return true
    elseif name == "LT" or name == "RT" then
        self.picker:Press(name)
    else
        -- L1 / R1 switch tabs, Circle closes
        return false
    end
    menu.Render()
    return true
end

function T:Help()
    local H = K.H
    if self.zone == "picker" then
        local hints = self.picker:Hints()
        table.insert(hints, #hints, H({ "Y" }, "Clear (hold: off)", "Y"))
        table.insert(hints, #hints, H({ "Touchpad" }, "Slot"))
        return hints
    end
    if self.zone == "settings" then
        return { H({ "DPAD_LR" }, "Change", "RIGHT"), H({ "DPAD" }, "Move"), H({ "LB", "RB" }, "Tab", "RB"),
            H({ "B" }, "Back", "B") }
    end
    return { H({ "DPAD" }, "Slot"), H({ "Touchpad" }, "Slot"), H({ "A" }, "Choose", "A"), H({ "Y" }, "Clear (hold: off)", "Y"),
        H({ "LB", "RB" }, "Tab", "RB"), H({ "B" }, "Close", "B") }
end

function T:Crumb()
    return "Touchpad › " .. touch.REGION_LABELS[self:Region()]
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- Pad coordinates (-1..1, up and right positive) to pixels in the pad
local function PadPoint(x, y)
    return INSET + (x + 1) / 2 * (PAD_W - 2 * INSET), -(INSET + (1 - y) / 2 * (PAD_H - 2 * INSET))
end

-- Each region's colour on the map: the centre gold, the sides bronze, the
-- corners cyan (no two neighbours alike)
local REGION_COLOR = {
    centre = KC.slot, up = KC.fill, down = KC.fill, left = KC.fill, right = KC.fill,
    upleft = KC.info, upright = KC.info, downleft = KC.info, downright = KC.info,
}

function T:DrawZones()
    local f = self.frame
    local selected = self:Region()
    -- Brighter while its setting has the focus
    local centreFocus = self.zone == "settings" and self.setting == 2
    local cornerFocus = self.zone == "settings" and self.setting == 3
    local regions = {}
    for row = 1, MAP_ROWS do
        regions[row] = {}
        for col = 1, MAP_COLS do
            local cell = f.cells[row][col]
            regions[row][col] = touch.RegionAt(cell.x, cell.y) or false
        end
    end
    for row = 1, MAP_ROWS do
        for col = 1, MAP_COLS do
            local cell, region = f.cells[row][col], regions[row][col]
            local color = region and REGION_COLOR[region]
            if color then
                local alpha = 0.1
                if region == selected and self.zone ~= "settings" then alpha = 0.28 end
                if (centreFocus and region == "centre") or (cornerFocus and touch.CORNERS[region]) then alpha = 0.32 end
                cell.tex:SetColorTexture(color[1], color[2], color[3], alpha)
            else
                cell.tex:SetColorTexture(0, 0, 0, 0)
            end
            cell.right:SetShown(col < MAP_COLS and regions[row][col + 1] ~= region)
            cell.bottom:SetShown(row < MAP_ROWS and regions[row + 1][col] ~= region)
        end
    end
end

-- The finger dot, and the region under it lit, while touching
function T:UpdateFinger()
    local f = self.frame
    local x, y = touch.FingerPosition()
    local touching = x and (x ~= 0 or y ~= 0)
    f.finger:SetShown(touching or false)
    if touching then
        local px, py = PadPoint(math.max(-1, math.min(1, x)), math.max(-1, math.min(1, y)))
        f.finger:ClearAllPoints()
        f.finger:SetPoint("CENTER", f.pad, "TOPLEFT", px, py)
    end
    local region = touching and touch.RegionAt(x, y) or nil
    if region ~= self.fingerRegion then
        self.fingerRegion = region
        for name, label in pairs(f.labels) do
            label:SetAlpha((not region or name == region) and 1 or 0.55)
        end
    end
end

function T:Render()
    local f = self.frame
    if not f then return end
    if self.zone == "list" or self.zone == "rail" then self.zone = "grid" end
    local settings = Settings()
    local on = settings.enabled ~= false
    local selected = self:Region()
    for region, s in pairs(f.slots) do
        local key = settings.regions[region]
        local bound = touch.IsBound(key)
        local isSel = region == selected
        local off = touch.IsOff(region)
        s:SetLook({ icon = bound and (touch.ActionIcon(key) or 134400) or nil, discColor = bound and KC.iconBg or nil,
            plus = not bound and not off, hatch = off, glow = self.zone == "grid" and isSel,
            dash = self.zone == "picker" and isSel })
        s:SetAlpha((on and not off) and 1 or 0.45)
        if self.holding == region then s:SetAlpha(0.7) end
        local label = f.labels[region]
        label:SetText(off and (touch.REGION_LABELS[region] .. " · Off")
            or (bound and touch.ActionLabel(key) or touch.REGION_LABELS[region]))
        label:SetTextColor(unpack(isSel and self.zone ~= "settings" and KC.focus or (bound and KC.cream or KC.grey)))
    end
    for i, r in ipairs(f.rows) do
        local focus = self.zone == "settings" and self.setting == i
        r.sel:SetShown(focus)
        r.label:SetText(SETTINGS[i].label)
        r.label:SetTextColor(unpack(focus and KC.focusText or KC.cream))
        local value = SETTINGS[i].value()
        r.value:SetText(value)
        r.value:SetTextColor(unpack(value == "Off" and KC.danger or (value == "On" and KC.slot or KC.cream)))
        for _, arrow in ipairs({ r.left, r.right }) do
            arrow:SetTextColor(unpack(focus and KC.focus or KC.dimGold))
        end
    end
    self:DrawZones()
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
    T.zone = "grid"
    if not IC.InCombat() then touch.Apply() end
end)
