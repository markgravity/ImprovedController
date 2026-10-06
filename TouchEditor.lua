-- The Touchpad tab, laid out like the Wheels tab: the pad in the middle of
-- the screen, drawn with its four corners (its quarters) as slots over a
-- map of where a click lands, and the picker (Spells, Items, Macros,
-- Interface; L2 / R2) down the right as slices of a ring around it. A slot
-- is picked by clicking the touchpad (the corner under the finger) or
-- pointing the right stick; a choice in the picker binds it. Triangle
-- clears a slot, held turns it off. (Turning the touchpad click on / off:
-- the Home tab.)
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local touch = IC.Touch
local MW = IC.MyWheels

local PANEL_W, PICKER_TOP, PICKER_ROWS = 340, 236, 7
local PAD_W, PAD_H = 480, 272
local SLOT_SIZE, ICON_SIZE = 46, 32
local INSET, MAP_COLS, MAP_ROWS = 4, 40, 23
local ARC = 300
local function ArcX(dy)
    return math.sqrt(math.max(0, ARC * ARC - dy * dy))
end

-- The slots, row by row as on the pad
local GRID = {
    { "upleft", "upright" },
    { "downleft", "downright" },
}
local COLS = { 120, 360 }
local ROWS = { 78, 214 }

local function Settings()
    return touch.GetSettings()
end

local T = { zone = "picker", row = 1, col = 1 }
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

    -- The pad, where the wheel is on the Wheels tab: a rounded box the
    -- shape of the DualSense's touchpad
    local pad = K.NewFrame("Frame", nil, f)
    pad:SetSize(PAD_W, PAD_H)
    pad:SetPoint("CENTER", f, "CENTER", 0, 0)
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
        onBack = function() menu.Close() end,
    })
end

function T:Show()
    self.zone = "picker"
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
-- The picker has the pad: up / down, Cross binds, L2 / R2 switch lists.
-- The slot follows the touchpad click and the right stick only.
function T:Press(name)
    if name == "LB" or name == "RB" then return false end
    if name == "Y" then
        self:Triangle()
        return true
    end
    self.zone = "picker"
    if name == "LEFT" or name == "RIGHT" then return true end
    -- (Circle: the picker's back, which closes the panel)
    self.picker:Press(name)
    menu.Render()
    return true
end

function T:Help()
    local H = K.H
    return { H({ "Touchpad" }, "Slot"), H({ "RS" }, "Slot"), H({ "DPAD" }, "Move"), H({ "A" }, "Bind", "A"),
        H({ "LT", "RT" }, "List", "RT"), H({ "Y" }, "Clear (hold: off)", "Y"), H({ "LB", "RB" }, "Tab", "RB"),
        H({ "B" }, "Close", "B") }
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
local REGION_COLOR = { upleft = KC.info, downright = KC.info, upright = KC.slot, downleft = KC.slot }

function T:DrawZones()
    local f = self.frame
    local selected = self:Region()
    -- Brighter while its setting has the focus
    local centreFocus, cornerFocus = false, false
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
                if region == selected and not (centreFocus or cornerFocus) then alpha = 0.28 end
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
    self.zone = "picker"
    local settings = Settings()
    local on = settings.enabled ~= false
    local selected = self:Region()
    for region, s in pairs(f.slots) do
        local key = settings.regions[region]
        local bound = touch.IsBound(key)
        local isSel = region == selected
        local off = touch.IsOff(region)
        s:SetLook({ icon = bound and (touch.ActionIcon(key) or 134400) or nil, discColor = bound and KC.iconBg or nil,
            plus = not bound and not off, hatch = off, glow = isSel and self.zone ~= "picker",
            dash = self.zone == "picker" and isSel })
        s:SetAlpha((on and not off) and 1 or 0.45)
        if self.holding == region then s:SetAlpha(0.7) end
        local label = f.labels[region]
        label:SetText(off and (touch.REGION_LABELS[region] .. " · Off")
            or (bound and touch.ActionLabel(key) or touch.REGION_LABELS[region]))
        label:SetTextColor(unpack(isSel and KC.focus or (bound and KC.cream or KC.grey)))
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
    T.zone = "picker"
    if not IC.InCombat() then touch.Apply() end
end)
