-- The panel's Wheels tab, adapted from Easy Controller - Forever's MyWheels
-- (moust4ki, MIT License, see textures/LICENSE-EasyController.md). On the
-- left a rail of every wheel (the built-in ones, the player's own, "New
-- wheel"); beside it the selected wheel's editor: its slots around it (8 a
-- page), what opens it, Hotkey / Rename / Delete (or Reset) under it, and
-- the spells / items / macros / emotes picker on the right: a choice fills
-- the slot aimed at and moves on to the next one.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local MW = IC.MyWheels
local menu = IC.Menu

local RAIL_W, GAP, BODY_H = 150, 12, 424
local RAIL_STEP = 34
local ZONE_W, PANEL_W = 390, 400
local CX, CY, RADIUS = 195, 196, 104
local SLOT_SIZE, ICON_SIZE = 50, 36
local PER_PAGE = 8

local W = { zone = "rail", index = 1, slot = 1, btn = 1 }
MW.Page = W

---------------------------------------------------------------------------
-- The wheels on the rail, then "New wheel" while there is room
---------------------------------------------------------------------------
function W:Entries()
    local entries = MW.Wheels()
    if #MW.List() < MW.MAX then
        entries[#entries + 1] = { new = true, label = "+ New wheel" }
    end
    return entries
end

-- The selected wheel (or the "New wheel" entry), kept by its key
function W:Current()
    local entries = self:Entries()
    if self.key then
        for i, e in ipairs(entries) do
            if e.key == self.key then
                self.index = i
                return e, entries
            end
        end
    end
    self.index = math.max(1, math.min(self.index or 1, #entries))
    local e = entries[self.index]
    self.key = e and e.key
    return e, entries
end

local function Editable(wheel)
    return wheel and wheel.slots ~= nil
end

-- What the wheel's slots hold right now (a self-filling one: its content)
local function Slots(wheel)
    if not wheel or wheel.new then return {} end
    return wheel.slots or MW.LiveSlots(wheel)
end

local function Pages(wheel)
    return math.max(1, math.ceil((wheel and wheel.max or PER_PAGE) / PER_PAGE))
end

local function Count(wheel)
    local n = 0
    for _ in pairs(Slots(wheel)) do n = n + 1 end
    return n
end

local function SlotPoint(p)
    local a = (p - 1) * math.pi / 4
    return CX + RADIUS * math.sin(a), CY - RADIUS * math.cos(a)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function W:Build(parent)
    local f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()
    self.frame = f

    -- The rail of wheels
    local rail = K.NewFrame("Frame", nil, f)
    rail:SetPoint("TOPLEFT")
    rail:SetSize(RAIL_W, BODY_H)
    local line = K.Solid(rail, KC.line3, 1, "BORDER")
    line:SetPoint("TOPRIGHT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetWidth(1)
    self.railEntries = {}
    for i = 1, #MW.BUILT_IN_WHEELS + MW.MAX + 1 do
        local e = K.NewFrame("Button", nil, rail)
        e:SetSize(RAIL_W - 11, RAIL_STEP - 4)
        e:SetPoint("TOPLEFT", 0, -2 - (i - 1) * RAIL_STEP)
        e.sel = K.NineSlice(e, "ck_select", 128, 32, 10, 10, "ARTWORK")
        e.diamond = e:CreateTexture(nil, "OVERLAY")
        e.diamond:SetTexture(K.TEX .. "ck_diamond")
        e.diamond:SetSize(7, 7)
        e.diamond:SetPoint("LEFT", 10, 0)
        e.diamond:SetVertexColor(KC.title[1], KC.title[2], KC.title[3])
        e.label = K.Text(e, 15, KC.rail)
        e.label:SetPoint("LEFT", 25, 0)
        e.label:SetWidth(RAIL_W - 11 - 29)
        e:SetScript("OnClick", function()
            if MW.renaming then return end
            W:Select(i)
            W.zone = "rail"
            menu.Render()
        end)
        self.railEntries[i] = e
    end
    -- A rule under the built-in wheels
    local rule = K.Solid(rail, KC.line2, 1, "BORDER")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 6, -#MW.BUILT_IN_WHEELS * RAIL_STEP)
    rule:SetPoint("RIGHT", rail, "RIGHT", -16, 0)

    -- The wheel
    local zone = K.NewFrame("Frame", nil, f)
    zone:SetPoint("TOPLEFT", RAIL_W + GAP, 0)
    zone:SetSize(ZONE_W, BODY_H)
    f.title = K.Text(zone, 18, KC.title)
    f.title:SetPoint("TOP", zone, "TOPLEFT", CX, -4)
    f.title:SetWidth(ZONE_W - 20)
    f.title:SetJustifyH("CENTER")
    f.kicker = K.ChatText(zone, 13, KC.grey)
    f.kicker:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    f.kicker:SetWidth(ZONE_W - 20)
    f.kicker:SetJustifyH("CENTER")
    f.kicker:SetWordWrap(false)
    local disc = zone:CreateTexture(nil, "BACKGROUND")
    disc:SetTexture(K.TEX .. "ck_disc")
    disc:SetSize(270, 270)
    disc:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    local hub = zone:CreateTexture(nil, "BORDER")
    hub:SetTexture(K.TEX .. "ck_hub")
    hub:SetSize(108, 108)
    hub:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    -- In the hub: the focused slot's content, the wheel's count
    f.hubName = K.Text(zone, 13, KC.cream)
    f.hubName:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY - 10))
    f.hubName:SetSize(90, 34)
    f.hubName:SetJustifyH("CENTER")
    f.hubName:SetWordWrap(true)
    if f.hubName.SetMaxLines then f.hubName:SetMaxLines(2) end
    f.count = K.Text(zone, 16, KC.title)
    f.count:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY + 20))
    f.count:SetJustifyH("CENTER")

    f.slots = {}
    for p = 1, PER_PAGE do
        local x, y = SlotPoint(p)
        local s = K.Slot(zone, SLOT_SIZE, ICON_SIZE)
        s:SetPoint("CENTER", zone, "TOPLEFT", x, -y)
        s:SetScript("OnClick", function(_, button)
            if MW.renaming then return end
            menu.Disarm()
            W.slot = W:PageBase() + p
            if button == "RightButton" then
                W:Empty()
            else
                W.zone = "slots"
                W:Aim()
            end
        end)
        f.slots[p] = s
    end

    -- What opens it
    local bind = K.NewFrame("Frame", nil, zone)
    bind:SetSize(10, 20)
    bind:SetPoint("TOP", zone, "TOPLEFT", CX, -(CY + 144))
    bind.label = K.ChatText(bind, 13, KC.grey)
    bind.label:SetPoint("LEFT")
    bind.label:SetText("Hotkey")
    bind.chip = K.NewFrame("Frame", nil, bind)
    bind.chip:SetHeight(20)
    bind.chip:SetPoint("LEFT", bind.label, "RIGHT", 8, 0)
    bind.chip.box = K.Box(bind.chip, 3, 2, "ARTWORK")
    bind.chip.box:SetPoints(bind.chip)
    bind.chip.box:SetColors(KC.controlBg, 1, KC.control, 1)
    bind.chip.text = K.Text(bind.chip, 14, KC.info)
    bind.chip.text:SetPoint("CENTER", 0, 0)
    f.bind = bind

    -- Hotkey, then Rename / Delete (own wheels) or Reset (built-in ones)
    local row = K.NewFrame("Frame", nil, zone)
    row:SetPoint("TOPLEFT", 0, -(BODY_H - 34))
    row:SetSize(ZONE_W, 32)
    f.buttonRow = row
    f.buttons = {}
    for i = 1, 4 do
        local b = K.Button(row, 14)
        b:SetScript("OnClick", function()
            if MW.renaming then return end
            W.zone, W.btn = "buttons", i
            W:Button(i)
        end)
        f.buttons[i] = b
    end

    -- The name typed in a box over the wheel (a physical keyboard)
    local veil = K.NewFrame("Frame", nil, zone)
    veil:SetAllPoints()
    veil:SetFrameLevel(zone:GetFrameLevel() + 20)
    veil:EnableMouse(true)
    K.Solid(veil, { 0.04, 0.03, 0.02 }, 0.72, "BACKGROUND"):SetAllPoints()
    veil:Hide()
    f.veil = veil
    local box = K.NewFrame("Frame", nil, veil)
    box:SetSize(ZONE_W - 20, 136)
    box:SetPoint("TOPLEFT", zone, "TOPLEFT", 10, -140)
    box.bg = K.Box(box, 4, 2, "BACKGROUND")
    box.bg:SetPoints(box)
    box.bg:SetColors(KC.panel, 1, KC.focus, 1)
    box.kicker = K.ChatText(box, 12, KC.grey)
    box.kicker:SetPoint("TOPLEFT", 14, -14)
    box.kicker:SetText("WHEEL NAME")
    local field = K.NewFrame("Frame", nil, box)
    field:SetPoint("TOPLEFT", box.kicker, "BOTTOMLEFT", 0, -8)
    field:SetSize(ZONE_W - 48, 36)
    field.box = K.Box(field, 3, 2, "ARTWORK")
    field.box:SetPoints(field)
    field.box:SetColors(KC.boxBg, 1, KC.control, 1)
    local edit = K.NewFrame("EditBox", nil, field)
    edit:SetAllPoints()
    edit:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
    edit:SetTextColor(KC.focusText[1], KC.focusText[2], KC.focusText[3])
    edit:SetTextInsets(10, 10, 0, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(40)
    edit:SetScript("OnEnterPressed", function(self) W:FinishRename(self:GetText()) end)
    edit:SetScript("OnEscapePressed", function() W:FinishRename(nil) end)
    box.edit = edit
    box.help = K.ChatText(box, 13, KC.help)
    box.help:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 0, -8)
    box.help:SetWidth(ZONE_W - 48)
    box.help:SetWordWrap(true)
    box.help:SetSpacing(5)
    box.help:SetText("D-pad left / right picks a name, Cross confirms, Circle cancels. A keyboard can type one too.")
    self.box = box

    -- Recording a hotkey, then confirming it: a box over the wheel
    local hk = K.NewFrame("Frame", nil, veil)
    hk:SetSize(ZONE_W - 20, 150)
    hk:SetPoint("TOPLEFT", zone, "TOPLEFT", 10, -130)
    hk.bg = K.Box(hk, 4, 2, "BACKGROUND")
    hk.bg:SetPoints(hk)
    hk.bg:SetColors(KC.panel, 1, KC.focus, 1)
    hk.kicker = K.ChatText(hk, 12, KC.grey)
    hk.kicker:SetPoint("TOPLEFT", 14, -14)
    hk.title = K.Text(hk, 17, KC.title)
    hk.title:SetPoint("TOPLEFT", hk.kicker, "BOTTOMLEFT", 0, -8)
    hk.title:SetWidth(ZONE_W - 48)
    hk.title:SetWordWrap(true)
    hk.body = K.ChatText(hk, 13, KC.help)
    hk.body:SetPoint("TOPLEFT", hk.title, "BOTTOMLEFT", 0, -8)
    hk.body:SetWidth(ZONE_W - 48)
    hk.body:SetWordWrap(true)
    hk.body:SetSpacing(5)
    self.hotkeyBox = hk

    -- Takes the controller's presses while recording (not passed on)
    local capture = K.NewFrame("Frame", nil, UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetSize(1, 1)
    capture:SetPoint("CENTER")
    capture:Hide()
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then W:StopCapture() end
    end)
    if capture.EnableGamePadButton then
        capture:SetScript("OnGamePadButtonDown", function(self, button)
            local held = self.held
            if held and held ~= button and IsKeyDown(held) then
                W:Recorded(held, button)
            else
                self.held = button
            end
        end)
        -- A button pressed and let go alone; Circle alone cancels
        capture:SetScript("OnGamePadButtonUp", function(self, button)
            if button ~= self.held then return end
            if button == "PAD2" then
                W:StopCapture()
            else
                W:Recorded(nil, button)
            end
        end)
    end
    self.capture = capture

    -- Right: the picker, or for a self-filling wheel what it does
    self.picker = K.Picker(f, PANEL_W, menu.Render)
    self.picker:SetPoint("TOPRIGHT")
    self.picker:SetHeight(BODY_H)
    self.detail = K.Detail(f, PANEL_W)
    self.detail:SetPoint("TOPRIGHT")
    self.detail:SetHeight(BODY_H)
end

function W:Show()
    self.zone = "rail"
    self.frame:Show()
    self:Select(self.index)
end

function W:Hide()
    self:FinishRename(nil)
    self.pendingSpec = nil
    self:StopCapture()
    self.picker:Close()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Selecting, aiming, filling
---------------------------------------------------------------------------
function W:PageBase()
    return math.floor((self.slot - 1) / PER_PAGE) * PER_PAGE
end

function W:Select(i)
    local entries = self:Entries()
    i = math.max(1, math.min(i, #entries))
    if i ~= self.index then menu.Disarm() end
    self.index = i
    local wheel = entries[i]
    self.key = wheel and wheel.key
    self.slot, self.btn = 1, 1
    self:OpenPicker(wheel)
end

-- The picker for the wheel's lists, aimed at its slot
function W:OpenPicker(wheel)
    if not Editable(wheel) then
        self.picker:Close()
        return
    end
    self.picker:Open({
        kicker = function() return format("Slot %d · %s", W.slot, MW.POSITIONS[(W.slot - 1) % PER_PAGE + 1]) end,
        title = function() return (W:Current() or {}).label or "" end,
        lists = wheel.lists, rows = 10, current = wheel.slots[self.slot], chooseVerb = "Choose, next",
        -- Already in this wheel: a diamond
        marked = function(e)
            local current = W:Current()
            for _, action in pairs(current and current.slots or {}) do
                if action == e.action then return true end
            end
            return false
        end,
        onChoose = function(e)
            if not MW.renaming then W:Fill(e) end
        end,
        onBack = function()
            W.zone = "slots"
            menu.Render()
        end,
    })
end

function W:Aim()
    local wheel = self:Current()
    if not Editable(wheel) then return menu.Render() end
    self.zone = "picker"
    local def = self.picker.def
    local current = wheel.slots[self.slot]
    if def then
        def.current = current
        local kind = current and current:match("^(%a+):")
        for i, list in ipairs(wheel.lists) do
            if kind and list.key == kind .. "s" then
                self.picker:SetList(i)
                break
            end
        end
    end
    menu.Render()
end

function W:Fill(e)
    local wheel = self:Current()
    if not (Editable(wheel) and e and e.action) then return end
    MW.SetWheelSlot(wheel, self.slot, e.action)
    menu.Toast(format("Slot %d: %s", self.slot, e.name or ""))
    self.slot = self.slot % wheel.max + 1
end

function W:Empty()
    local wheel = self:Current()
    if Editable(wheel) and wheel.slots[self.slot] then
        MW.SetWheelSlot(wheel, self.slot, nil)
        menu.Toast("Slot emptied")
    end
    menu.Render()
end

---------------------------------------------------------------------------
-- Hotkeys: Square (or the Hotkey button) records the next press: a button,
-- or L1 / L2 / R1 / R2 held + R3. A box shows what it takes over; Cross
-- saves it (the wheel's old hotkey goes), Circle cancels.
---------------------------------------------------------------------------
function W:StartCapture(wheel)
    if IC.InCombat() or not wheel or wheel.new then return end
    menu.Disarm()
    self.zone, self.pendingSpec = "capture", nil
    local c = self.capture
    c.held = nil
    c:Show()
    c:EnableKeyboard(true)
    c:SetPropagateKeyboardInput(false)
    if c.EnableGamePadButton then c:EnableGamePadButton(true) end
    self.captureToken = (self.captureToken or 0) + 1
    local token = self.captureToken
    C_Timer.After(10, function()
        if W.captureToken == token and W.zone == "capture" then W:StopCapture() end
    end)
    menu.Render()
end

-- Recording over: back on the slots, or on to the confirmation
function W:StopCapture(nextZone)
    local c = self.capture
    if c and c:IsShown() then
        c:Hide()
        c.held = nil
        if not IC.InCombat() then
            c:EnableKeyboard(false)
            if c.EnableGamePadButton then c:EnableGamePadButton(false) end
        end
    end
    if self.zone == "capture" or self.zone == "confirm" then self.zone = nextZone or "slots" end
    menu.Render()
end

function W:Recorded(held, pressed)
    local spec = MW.HotkeySpec(held, pressed)
    if not spec then
        self:StopCapture()
        menu.Toast("Use one button, or L1 / L2 / R1 / R2 held + R3.", true)
        return
    end
    self.pendingSpec = spec
    -- (on the next frame: the press that ended it is still being handled)
    C_Timer.After(0, function() W:StopCapture("confirm") end)
end

function W:SaveHotkey()
    local wheel, spec = self:Current(), self.pendingSpec
    self.pendingSpec = nil
    if wheel and spec then
        MW.SetHotkey(wheel.key, spec)
        menu.Toast(wheel.label .. ": " .. MW.SpecText(spec))
    end
    self.zone = "slots"
    menu.Render()
end

-- The buttons under the wheel: { label, action, armed }
function W:Buttons(wheel)
    if not wheel or wheel.new then return {} end
    local list = { { "Hotkey", function() W:StartCapture(wheel) end } }
    if MW.CombosText(wheel.key) or MW.KeysText(wheel.key) then
        list[#list + 1] = { "No hotkey", function()
            MW.ClearHotkey(wheel.key)
            menu.Toast(wheel.label .. ": no hotkey")
        end }
    end
    if wheel.id then
        list[#list + 1] = { "Rename", function() W:StartRename(wheel) end }
        local armed = menu.IsArmed("delwheel")
        list[#list + 1] = { armed and "Press again to delete" or "Delete", function()
            if menu.IsArmed("delwheel") then
                menu.Disarm()
                MW.Delete(wheel.id)
                W.key = nil
                W:Select(W.index)
                W.zone = "rail"
                menu.Toast("Wheel deleted")
            else
                menu.Arm("delwheel")
            end
        end, armed = armed }
    elseif wheel.reset then
        local armed = menu.IsArmed("resetwheel")
        list[#list + 1] = { armed and "Press again to reset" or wheel.resetLabel, function()
            if menu.IsArmed("resetwheel") then
                menu.Disarm()
                MW.ResetWheel(wheel)
                W:Select(W.index)
                menu.Toast(wheel.label .. " reset")
            else
                menu.Arm("resetwheel")
            end
        end, armed = armed }
    end
    return list
end

function W:Button(i)
    local b = self:Buttons(self:Current())[i]
    if b then b[2]() end
    menu.Render()
end

function W:CreateWheel()
    local id = MW.Create()
    if not id then
        menu.Toast("8 wheels at most. Delete one to make room.", true)
        return
    end
    self.key = MW.RingKey(id)
    self:Current()
    self:Select(self.index)
    self:Aim()
end

---------------------------------------------------------------------------
-- Naming: D-pad left / right goes through suggested names (the pad alone
-- can name a wheel), a keyboard can type any name
---------------------------------------------------------------------------
local SUGGESTIONS = {
    "Combat", "Defensive", "Healing", "Buffs", "Utility", "Cooldowns", "Crowd Control", "Pets", "Travel",
    "Mounts", "Professions", "Food & Drink", "Potions", "Macros", "Social", "Questing", "PvP", "Dungeon",
}

function W:Suggestions(wheel)
    local list = {}
    -- First, what is in its first filled slot
    for i = 1, wheel.max do
        local name = wheel.slots[i] and MW.ActionName(wheel.slots[i])
        if name then
            list[#list + 1] = name
            break
        end
    end
    for _, name in ipairs(SUGGESTIONS) do list[#list + 1] = name end
    list[#list + 1] = "Wheel " .. wheel.id
    return list
end

function W:StepName(step)
    local wheel = self:Current()
    if not (wheel and wheel.id) then return end
    local list = self:Suggestions(wheel)
    self.suggestion = ((self.suggestion or 0) - 1 + step) % #list + 1
    self.box.edit:SetText(list[self.suggestion])
    self.box.edit:HighlightText()
end

function W:StartRename(wheel)
    if not wheel.id or IC.InCombat() then return end
    MW.renaming = wheel.id
    self.suggestion = 0
    self.zone = "rename"
    local edit = self.box.edit
    edit:SetText(wheel.label)
    self.frame.veil:Show()
    edit:SetFocus()
    edit:HighlightText()
end

function W:FinishRename(text)
    local id = MW.renaming
    if not id then return end
    MW.renaming = nil
    self.box.edit:ClearFocus()
    self.frame.veil:Hide()
    if self.zone == "rename" then self.zone = "buttons" end
    if text then MW.Rename(id, text) end
    menu.Render()
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
-- Around the wheel: the nearest slot of the page that way
function W:Nearest(dir)
    local p = (self.slot - 1) % PER_PAGE + 1
    local fx, fy = SlotPoint(p)
    local best, bestScore
    for i = 1, PER_PAGE do
        if i ~= p then
            local x, y = SlotPoint(i)
            local dx, dy = x - fx, y - fy
            local main, cross
            if dir == "UP" then
                main, cross = -dy, dx
            elseif dir == "DOWN" then
                main, cross = dy, dx
            elseif dir == "LEFT" then
                main, cross = -dx, dy
            else
                main, cross = dx, dy
            end
            if main > 6 and math.abs(cross) <= main * 2.2 then
                local score = main + math.abs(cross) * 2
                if not bestScore or score < bestScore then best, bestScore = i, score end
            end
        end
    end
    return best and self:PageBase() + best
end

local DIRS = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

-- The same place on the previous / next page (Buffs: 3 pages of 8)
function W:StepPage(step)
    local wheel = self:Current()
    if not wheel or wheel.new then return end
    local pages = Pages(wheel)
    if pages < 2 then return end
    local page = math.floor((self.slot - 1) / PER_PAGE)
    local p = (self.slot - 1) % PER_PAGE + 1
    page = (page + step) % pages
    self.slot = math.min(wheel.max, page * PER_PAGE + p)
end

-- The right stick points at a slot of the page (top first, clockwise) and
-- aims the picker at it straight away: the next choice fills that slot.
-- A wheel that fills itself just shows the slot.
local AIM_LENGTH = 0.5

function W:OnStick(stick, x, y, len)
    if stick ~= "Right" and stick ~= "Camera" then return end
    if MW.renaming or (len or 0) < AIM_LENGTH then return end
    if self.zone == "capture" or self.zone == "confirm" then return end
    local wheel = self:Current()
    if not wheel or wheel.new then return end
    local angle = math.atan2(x, y) % (2 * math.pi)
    local p = math.floor((angle + math.pi / 8) / (math.pi / 4)) % PER_PAGE + 1
    local slot = self:PageBase() + p
    if slot > wheel.max then return end
    local zone = Editable(wheel) and "picker" or "slots"
    if slot == self.slot and zone == self.zone then return end
    if self.zone ~= zone then menu.Disarm() end
    self.slot, self.zone = slot, zone
    if zone == "picker" and self.picker.def then
        -- On what the slot holds, if anything
        local current = wheel.slots[slot]
        self.picker.def.current = current
        local kind = current and current:match("^(%a+):")
        for i, list in ipairs(wheel.lists) do
            if kind and list.key == kind .. "s" then
                if i ~= self.picker.list then self.picker:SetList(i) end
                break
            end
        end
    end
    menu.Render()
end

function W:Press(name)
    local wheel = self:Current()
    if self.zone == "list" then self.zone = "slots" end
    if self.zone == "capture" then
        return true
    end
    if self.zone == "confirm" then
        if name == "A" then
            self:SaveHotkey()
        elseif name == "B" then
            self.pendingSpec, self.zone = nil, "slots"
            menu.Render()
        end
        return true
    end
    if self.zone == "rename" then
        if name == "A" then
            self:FinishRename(self.box.edit:GetText())
        elseif name == "B" then
            self:FinishRename(nil)
        elseif name == "LEFT" or name == "RIGHT" or name == "UP" or name == "DOWN" then
            self:StepName((name == "LEFT" or name == "UP") and -1 or 1)
        end
        return true
    end
    if self.zone == "rail" then
        if name == "UP" or name == "DOWN" then
            self:Select(self.index + (name == "UP" and -1 or 1))
        elseif name == "A" or name == "RIGHT" then
            if wheel and wheel.new then
                self:CreateWheel()
            elseif wheel then
                self.zone = "slots"
            end
        else
            -- L1 / R1 switch tabs, Circle closes
            return false
        end
        menu.Render()
        return true
    end
    if self.zone == "picker" then
        -- L1 / R1 stay the panel's tabs; Triangle clears the slot aimed at
        if name == "LB" or name == "RB" then return false end
        if name == "Y" then
            self:Empty()
            return true
        end
        self.picker:Press(name)
        menu.Render()
        return true
    end
    if self.zone == "buttons" then
        local count = #self:Buttons(wheel)
        if name == "LEFT" then
            if self.btn == 1 then self.zone = "rail" else self.btn = self.btn - 1 end
        elseif name == "RIGHT" then
            self.btn = math.min(count, self.btn + 1)
        elseif name == "UP" then
            self.zone, self.slot = "slots", math.min(wheel.max, self:PageBase() + 5)
        elseif name == "A" then
            self:Button(self.btn)
            return true
        elseif name == "B" then
            self.zone = "rail"
        elseif name == "LT" or name == "RT" then
            self:StepPage(name == "LT" and -1 or 1)
        elseif name == "LB" or name == "RB" then
            return false
        end
        menu.Render()
        return true
    end
    -- On the slots (L1 / R1 stay the panel's tabs, L2 / R2 turn the page)
    if name == "LB" or name == "RB" then
        return false
    elseif name == "LT" or name == "RT" then
        self:StepPage(name == "LT" and -1 or 1)
    elseif DIRS[name] then
        local to = self:Nearest(name)
        if to and to <= wheel.max then
            self.slot = to
        elseif name == "DOWN" then
            self.zone, self.btn = "buttons", 1
        elseif name == "LEFT" then
            self.zone = "rail"
        end
    elseif name == "A" then
        self:Aim()
        return true
    elseif name == "Y" then
        self:Empty()
        return true
    elseif name == "X" then
        self:StartCapture(wheel)
        return true
    elseif name == "B" then
        self.zone = "rail"
    end
    menu.Render()
    return true
end

function W:Help()
    local H = K.H
    local wheel = self:Current()
    if self.zone == "rename" then
        return { H({ "DPAD_LR" }, "Name", "RIGHT"), H({ "A" }, "Confirm", "A"), H({ "B" }, "Cancel", "B") }
    end
    if self.zone == "capture" then return { H({ "B" }, "Cancel", "B") } end
    if self.zone == "confirm" then return { H({ "A" }, "Save", "A"), H({ "B" }, "Cancel", "B") } end
    if self.zone == "picker" then
        local hints = self.picker:Hints()
        table.insert(hints, #hints, H({ "Y" }, "Clear", "Y"))
        return hints
    end
    if self.zone == "rail" then
        return { H({ "DPAD" }, "Wheel"), H({ "A" }, wheel and wheel.new and "Create" or "Edit", "A"),
            H({ "LB", "RB" }, "Tab", "RB"), H({ "B" }, "Close", "B") }
    end
    if self.zone == "buttons" then
        return { H({ "DPAD_LR" }, "Move", "RIGHT"), H({ "A" }, "Select", "A"), H({ "B" }, "Back", "B") }
    end
    local hints = { H({ "RS" }, "Point"), H({ "DPAD" }, "Slot") }
    if Pages(wheel) > 1 then hints[#hints + 1] = H({ "LT", "RT" }, "Page", "RT") end
    if Editable(wheel) then
        hints[#hints + 1] = H({ "A" }, "Choose", "A")
        hints[#hints + 1] = H({ "Y" }, "Clear", "Y")
    end
    hints[#hints + 1] = H({ "X" }, "Hotkey", "X")
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, "Back", "B")
    return hints
end

function W:Crumb()
    local wheel = self:Current()
    return "Wheels › " .. (wheel and wheel.label or "")
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function W:Render()
    local f = self.frame
    if not f then return end
    if self.zone == "list" then self.zone = "slots" end
    local wheel, entries = self:Current()

    -- The rail
    for i, e in ipairs(self.railEntries) do
        local entry = entries[i]
        e:SetShown(entry ~= nil)
        if entry then
            local active = i == self.index
            e.label:SetText(entry.label)
            e.label:SetTextColor(unpack(active and KC.focus or (entry.new and KC.dimGold or KC.rail)))
            e.diamond:SetShown(active)
            e.sel:SetShown(active and self.zone == "rail")
        end
    end

    -- "New wheel" selected: an empty wheel and what Cross does
    local isNew = wheel == nil or wheel.new
    local slots = Slots(wheel)
    local max = isNew and PER_PAGE or wheel.max
    if self.slot > max then self.slot = 1 end
    local base = self:PageBase()
    f.title:SetText(isNew and "New wheel" or wheel.label)
    local pages = isNew and 1 or Pages(wheel)
    local kicker = isNew and "Cross makes an empty wheel of your own"
        or (wheel.builtin and "Built-in wheel" or "Your wheel")
    if pages > 1 then kicker = kicker .. format(" · page %d / %d (L2 / R2)", base / PER_PAGE + 1, pages) end
    f.kicker:SetText(kicker)

    local onSlots = self.zone == "slots"
    for p, s in ipairs(f.slots) do
        local i = base + p
        local action = slots[i]
        s:SetShown(i <= max)
        s:SetLook({ icon = action and (MW.ActionIcon(action) or 134400), discColor = action and KC.iconBg or nil,
            plus = not action and Editable(wheel), glow = onSlots and i == self.slot,
            dash = self.zone == "picker" and i == self.slot })
        s:SetAlpha(isNew and 0.35 or 1)
    end
    local focused = slots[self.slot]
    local showSlot = onSlots or self.zone == "picker"
    f.hubName:SetText(showSlot and (focused and MW.ActionName(focused)
        or MW.POSITIONS[(self.slot - 1) % PER_PAGE + 1]) or "")
    f.hubName:SetTextColor(unpack(focused and KC.cream or KC.grey))
    f.count:SetText(isNew and "" or format("%d / %d", Count(wheel), max))

    -- What opens it
    f.bind:SetShown(not isNew)
    if not isNew then
        local hotkey = MW.HotkeyText(wheel.key)
        local chip = f.bind.chip
        chip.text:SetText(hotkey or "None yet")
        chip.text:SetTextColor(unpack(hotkey and KC.info or KC.eventOff))
        chip:SetWidth(chip.text:GetStringWidth() + 16)
        f.bind:SetWidth(f.bind.label:GetStringWidth() + 8 + chip:GetWidth())
    end

    -- The buttons
    local buttons = self:Buttons(wheel)
    if self.btn > #buttons then self.btn = math.max(1, #buttons) end
    local shown, flexes = {}, {}
    for i, b in ipairs(f.buttons) do
        local def = buttons[i]
        b:SetShown(def ~= nil)
        if def then
            b.label:SetText(def[1])
            b:SetState({ focus = self.zone == "buttons" and self.btn == i, armed = def.armed })
            shown[#shown + 1] = b
            flexes[#flexes + 1] = def.armed and 1.8 or 1
        end
    end
    if #shown > 0 then K.LayoutRow(f.buttonRow, shown, flexes, 8) end

    -- Right: the picker (faded unless it has the focus), or the detail
    if Editable(wheel) then
        self.detail:Hide()
        if not self.picker:IsOpen() then self:OpenPicker(wheel) end
        self.picker:Show()
        self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
        self.picker:Render()
    else
        self.picker:Close()
        self.detail:Show()
        if isNew then
            self.detail:Set({ title = "New wheel", body = "Makes an empty wheel of your own and opens it: pick a"
                .. " spell, an item, a macro or an emote for each slot. Up to " .. MW.MAX .. " wheels." })
        else
            self.detail:Set({ title = wheel.label, tag = "Fills itself", tagColor = KC.slot, body = wheel.info,
                extra = "Hotkey: " .. (MW.HotkeyText(wheel.key) or "none") .. ". Square records a new one: any controller button, or"
                    .. " L1 / L2 / R1 / R2 + R3." })
        end
    end
    -- The boxes over the wheel: naming, recording, confirming
    local hotkeyZone = self.zone == "capture" or self.zone == "confirm"
    f.veil:SetShown(self.zone == "rename" or hotkeyZone)
    self.box:SetShown(self.zone == "rename")
    local hk = self.hotkeyBox
    hk:SetShown(hotkeyZone)
    if self.zone == "capture" then
        hk.kicker:SetText("HOTKEY · " .. (wheel and wheel.label or ""):upper())
        hk.title:SetText("Press a button")
        hk.body:SetText("Or hold L1 / L2 / R1 / R2 and press R3. Circle alone (or 10 seconds) cancels.")
    elseif self.zone == "confirm" and self.pendingSpec and wheel then
        hk.kicker:SetText("HOTKEY · " .. wheel.label:upper())
        hk.title:SetText("Open " .. wheel.label .. " with " .. MW.SpecText(self.pendingSpec) .. "?")
        local old = MW.HotkeyText(wheel.key)
        hk.body:SetText("Replaces " .. MW.SpecReplaces(self.pendingSpec, wheel.key) .. "."
            .. (old and ("\nIts old hotkey (" .. old .. ") goes.") or "") .. "\nCross saves, Circle cancels.")
    end
end

---------------------------------------------------------------------------
-- The Wheels tab (Menu.lua) uses this page
---------------------------------------------------------------------------
for _, def in ipairs(menu.TABS) do
    if def.key == "wheels" then
        def.page = function() return W end
    end
end

-- The panel closed (Circle, combat) while naming: cancelled
hooksecurefunc(menu, "Close", function()
    W:FinishRename(nil)
    W.pendingSpec = nil
    W:StopCapture()
end)
