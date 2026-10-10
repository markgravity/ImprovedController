-- The panel's Wheels tab, adapted from Easy Controller - Forever's MyWheels
-- (moust4ki, MIT License, see LICENSE-EasyController.md). On the
-- left a rail of every wheel (the built-in ones, the player's own, "New
-- wheel"); beside it the selected wheel's editor: its slots around it (8 a
-- page), what opens it (bound in the Controller tab), Rename / Delete (or
-- Reset), and
-- the spells / items / macros / emotes picker on the right: a choice fills
-- the slot aimed at and moves on to the next one.
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local MW = IF.MyWheels
local menu = IF.Menu

local ZONE_W, PANEL_W = 540, 340
local BOX_W = 380                   -- the rename box over the wheel
-- The Stage layout (ConfigKit): the wheel in the middle, its visible rim
-- 226 from its centre (the art's frame has a clear margin round it), the
-- side lists centred on it up and down
local LIST_STEP = 42
local LIST_SHOWN = 8                -- wheels shown at once on the left; the rest scroll
local PICKER_ROWS = 7               -- entries shown at once on the right
local STAGE = K.Stage(226, 0)
-- The wheel: Forever's radial menu (the R3 ring's art and layout, Ring.lua)
-- at SCALE
local SCALE = 1
local CX, CY = 270, 270             -- in the wheel's 540 x 541 frame
local WEDGE_RADIUS = 150 * SCALE    -- highlight / empty wedges
local ICON_SIZE = math.floor(38 * SCALE + 0.5)
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

-- Slot p's icon, from the wheel's top left (y down)
local function SlotPoint(p)
    local a = (p - 1) * math.pi / 4
    local ix, iy = IF.SlotLayout(math.sin(a), math.cos(a))
    return CX + ix * SCALE, CY - iy * SCALE
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function W:Build(parent)
    -- The whole screen, as the R3 wheel (the panel's frame, not its body)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- The wheels, in rows down the left (placed in Render)
    local rail = K.NewFrame("Frame", nil, f)
    rail:SetAllPoints(f)
    rail:EnableMouseWheel(true)
    rail:SetScript("OnMouseWheel", function(_, delta)
        if MW.renaming then return end
        W:Select(W.index - delta)
        menu.Render()
    end)
    self.railUp, self.railDown = K.MoreArrows(rail)
    self.railEntries = {}
    for i = 1, #MW.BUILT_IN_WHEELS + MW.MAX + 1 do
        local e = K.NewFrame("Button", nil, rail)
        -- A row (K.Segment: a straight slot)
        e:SetSize(200, 34)
        e.seg = K.Segment(e)
        e.label = K.Text(e, 14, KC.rail, "OVERLAY")
        e.label:SetPoint("CENTER")
        e.label:SetWidth(180)
        e.label:SetJustifyH("CENTER")
        e:SetScript("OnClick", function()
            if MW.renaming then return end
            W:Select(i)
            W.zone = "rail"
            menu.Render()
        end)
        self.railEntries[i] = e
    end
    -- The wheel
    local zone = K.NewFrame("Frame", nil, f)
    zone:SetPoint("CENTER", f, "CENTER", 0, 0)
    zone:SetSize(540, 541)
    -- In the hub: the wheel's name, its count, its page
    f.title = K.Text(zone, 15, KC.white)
    f.title:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY - 16))
    f.title:SetWidth(150)
    f.title:SetJustifyH("CENTER")
    f.kicker = K.ChatText(zone, 12, KC.grey)
    f.kicker:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY + 32))
    f.kicker:SetWidth(150)
    f.kicker:SetJustifyH("CENTER")
    f.kicker:SetWordWrap(true)
    f.kicker:SetSpacing(2)
    local function atlas(texture, name, fallback)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
            texture:SetAtlas(name)
        elseif fallback then
            texture:SetTexture(K.TEX .. fallback)
        end
    end
    local wheelBg = zone:CreateTexture(nil, "BACKGROUND", nil, -3)
    wheelBg:SetSize(540 * SCALE, 541 * SCALE)
    wheelBg:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    atlas(wheelBg, "gamepad-radial-menu-wheelbg", "ic_disc")
    -- The highlight wedge (the slot with the focus, or the one the picker
    -- fills): the art faces down at rotation 0
    f.highlight = zone:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.highlight:SetSize(169 * SCALE, 165 * SCALE)
    atlas(f.highlight, "gamepad-radial-menu-selected")
    f.hubName = K.Text(zone, 12, KC.cream)
    f.hubName:Hide()
    f.hubName:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY - 9))
    f.hubName:SetSize(80, 30)
    f.hubName:SetJustifyH("CENTER")
    f.hubName:SetWordWrap(true)
    if f.hubName.SetMaxLines then f.hubName:SetMaxLines(2) end
    -- What it is bound to, as button glyphs, alone in the hub
    f.bindGlyphs = K.GlyphRow(zone, 36)
    -- A wheel of several pages: a dot each (the native page dots), under it
    f.pageDots = {}
    for i = 1, 3 do
        local d = zone:CreateTexture(nil, "OVERLAY")
        d:SetSize(11, 11)
        f.pageDots[i] = d
    end
    f.bindNone = K.ChatText(zone, 13, KC.grey)
    f.bindNone:SetPoint("CENTER", zone, "TOPLEFT", CX, -CY)
    f.bindNone:SetText("Not bound")
    f.count = K.Text(zone, 14, KC.title)
    f.count:SetPoint("CENTER", zone, "TOPLEFT", CX, -(CY + 10))
    f.count:SetJustifyH("CENTER")

    f.slots = {}
    for p = 1, PER_PAGE do
        local a = (p - 1) * math.pi / 4
        local sn, cs = math.sin(a), math.cos(a)
        -- An empty slot: the dimmed wedge, a "+"
        local empty = zone:CreateTexture(nil, "BACKGROUND", nil, -2)
        empty:SetSize(169 * SCALE, 164 * SCALE)
        empty:SetPoint("CENTER", zone, "TOPLEFT", CX + WEDGE_RADIUS * sn, -(CY - WEDGE_RADIUS * cs))
        atlas(empty, "gamepad-radial-menu-disabled")
        empty:SetRotation(math.pi - a)
        local s = K.NewFrame("Button", nil, zone)
        s:SetSize(ICON_SIZE, ICON_SIZE)
        -- Laid out as the wheel in play (Ring.lua, the native radial's)
        local ix, iy, lx, ly = IF.SlotLayout(sn, cs)
        s:SetPoint("CENTER", zone, "TOPLEFT", CX + ix * SCALE, -CY + iy * SCALE)
        s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        s.empty = empty
        s.icon = K.RoundIcon(s, ICON_SIZE, "ARTWORK")
        s.icon:SetPoint("CENTER")
        s.plus = K.Text(s, 18, KC.dimGold, "OVERLAY")
        s.plus:SetPoint("CENTER", 0, 1)
        s.plus:SetText("+")
        s.count = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        s.count:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 3, -2)
        s.label = K.Text(zone, 12, KC.title, "OVERLAY")
        s.label:SetSize(90, 40)
        s.label:SetWordWrap(true)
        s.label:SetJustifyH("CENTER")
        s.label:SetPoint("CENTER", zone, "TOPLEFT", CX + lx * SCALE, -CY + ly * SCALE)
        s:SetScript("OnClick", function(_, button)
            if MW.renaming then return end
            menu.Disarm()
            W.slot = W:PageBase() + p
            if button == "RightButton" then
                W:Empty()
            else
                W:Aim()
            end
        end)
        f.slots[p] = s
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
    box:SetSize(BOX_W, 136)
    box:SetPoint("CENTER", zone, "CENTER", 0, 0)
    box.bg = K.Box(box, 4, 2, "BACKGROUND")
    box.bg:SetPoints(box)
    box.bg:SetColors(KC.panel, 1, KC.focus, 1)
    box.kicker = K.ChatText(box, 12, KC.grey)
    box.kicker:SetPoint("TOPLEFT", 14, -14)
    box.kicker:SetText("WHEEL NAME")
    local field = K.NewFrame("Frame", nil, box)
    field:SetPoint("TOPLEFT", box.kicker, "BOTTOMLEFT", 0, -8)
    field:SetSize(BOX_W - 28, 36)
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
    box.help:SetWidth(BOX_W - 28)
    box.help:SetWordWrap(true)
    box.help:SetSpacing(5)
    self.box = box

    -- The confirmation / recording box: the game's own dialog look
    local d = K.NewFrame("Frame", nil, f, "BackdropTemplate")
    d:SetSize(440, 160)
    d:SetPoint("CENTER", f, "CENTER", 0, 0)
    d:SetFrameLevel(f:GetFrameLevel() + 60)
    d:EnableMouse(true)
    d:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    d.text = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.text:SetFont("Fonts\\FRIZQT__.TTF", 15, "")
    d.text:SetPoint("TOP", d, "TOP", 0, -28)
    d.text:SetWidth(390)
    d.text:SetSpacing(4)
    d.hintRow = K.NewFrame("Frame", nil, d)
    d.hintRow:SetSize(1, 30)
    d.hintRow:SetPoint("BOTTOM", d, "BOTTOM", 0, 22)
    d.hints = {}
    for i = 1, 2 do
        d.hints[i] = K.Hint(d.hintRow, function(press) W:Press(press) end)
    end
    d:Hide()
    self.dialog = d

    -- Right: the picker, or for a self-filling wheel what it does
    self.picker = K.Picker(f, PANEL_W, menu.Render, {
        bare = true, rowHeight = 38,
    })
    self.picker:Center(f, STAGE.picker, STAGE.mid)
    self.picker:SetHeight(400)
    self.detail = K.Detail(f, PANEL_W)
    self.detail:SetPoint("LEFT", f, "CENTER", STAGE.right, STAGE.mid)
    self.detail:SetHeight(300)
end

function W:Show()
    self.zone = "rail"
    self.frame:Show()
    self:Select(self.index)
end

function W:Hide()
    self:FinishRename(nil)
    -- An open confirmation is a no
    if self.popup then self:AnswerPopup(false) end
    if self.dialog then self.dialog:Hide() end
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
        lists = wheel.lists, rows = PICKER_ROWS, current = wheel.slots[self.slot], chooseVerb = "Choose, next",
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
            W.zone = "rail"
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
-- Confirmations: the game's own pop-up (Forever drives it with the pad:
-- Cross accepts, Circle cancels). The panel lets the pad go while it is up.
---------------------------------------------------------------------------
function W:Confirm(text, acceptLabel, onAccept, onCancel)
    if IF.InCombat() then return end
    self.popupReturn = self.zone ~= "popup" and self.zone or self.popupReturn
    self.zone = "popup"
    self.popup = { onAccept = onAccept, onCancel = onCancel }
    self:ShowDialog(text, {
        K.H({ "A" }, acceptLabel or "OK", "A"),
        K.H({ "B" }, "Cancel", "B"),
    })
    menu.Render()
end

-- Cross / Circle on the confirmation
function W:AnswerPopup(accepted)
    local popup = self.popup
    self.popup = nil
    self.dialog:Hide()
    self.zone = self.popupReturn or "rail"
    if popup then
        if accepted then
            popup.onAccept()
        elseif popup.onCancel then
            popup.onCancel()
        end
    end
    menu.Render()
end

-- The box itself: the game's own dialog look (its dark background and gold
-- border), its text, and what Cross / Circle do in it
function W:ShowDialog(text, hints)
    local d = self.dialog
    d.text:SetText(text)
    local x = 0
    for i, h in ipairs(d.hints) do
        local hint = hints and hints[i]
        h:SetShown(hint ~= nil)
        if hint then
            h:Set(hint)
            h:ClearAllPoints()
            h:SetPoint("LEFT", d.hintRow, "LEFT", x, 0)
            x = x + h:GetWidth() + 28
        end
    end
    d.hintRow:SetWidth(math.max(1, x - 28))
    d:SetHeight(math.max(150, d.text:GetStringHeight() + (hints and 100 or 60)))
    d:Show()
end

-- A press, or a hold (0.6 s): Triangle and Square do one thing each way
local HOLD = 0.6

function W:PressOrHold(key, onPress, onHold)
    if self.holding then return end
    local started = GetTime()
    self.holding = key
    C_Timer.NewTicker(0.05, function(ticker)
        local held = IsKeyDown and IsKeyDown(key)
        if held and GetTime() - started >= HOLD then
            ticker:Cancel()
            W.holding = nil
            onHold()
        elseif not held then
            ticker:Cancel()
            W.holding = nil
            onPress()
        end
    end)
end

-- Triangle: clears the slot; held, renames the wheel (a built-in one:
-- back to its defaults, once confirmed)
function W:Triangle(wheel)
    self:PressOrHold("PAD4", function() W:Empty() end, function()
        if wheel.id then
            W:StartRename(wheel)
            menu.Render()
        elseif wheel.reset then
            W:Confirm("Reset the " .. wheel.label .. " wheel to its defaults?", RESET or "Reset", function()
                MW.ResetWheel(wheel)
                W:Select(W.index)
                menu.Toast(wheel.label .. " reset")
            end)
        end
    end)
end

-- Square held: deletes a wheel of yours (once confirmed). Binding a wheel
-- to a press is the Controller tab's.
function W:Square(wheel)
    if not wheel.id then return end
    self:PressOrHold("PAD3", function() menu.Toast(IF.PadText("Hold {X} to delete " .. wheel.label)) end, function()
        W:Confirm('Delete the wheel "' .. wheel.label .. '"?', "Delete", function()
            MW.Delete(wheel.id)
            W.key = nil
            W:Select(W.index)
            W.popupReturn = "rail"
            W.zone = "rail"
            menu.Toast("Wheel deleted")
        end)
    end)
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
    if not wheel.id or IF.InCombat() then return end
    MW.renaming = wheel.id
    self.renameReturn = self.zone
    self.suggestion = 0
    self.zone = "rename"
    local edit = self.box.edit
    self.box.help:SetText(IF.PadText("D-pad left / right picks a name, {A} confirms, {B} cancels. A keyboard can type one too."))
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
    if self.zone == "rename" then self.zone = self.renameReturn or "rail" end
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
    if self.zone == "popup" then return end
    local wheel = self:Current()
    if not wheel or wheel.new then return end
    local angle = math.atan2(x, y) % (2 * math.pi)
    local p = math.floor((angle + math.pi / 8) / (math.pi / 4)) % PER_PAGE + 1
    local slot = self:PageBase() + p
    if slot > wheel.max then return end
    -- Pointing at a slot edits it: the picker takes the focus (a wheel
    -- that fills itself: just the slot)
    local zone = Editable(wheel) and "picker" or self.zone
    if slot == self.slot and zone == self.zone then return end
    if zone ~= self.zone then menu.Disarm() end
    self.slot, self.zone = slot, zone
    if Editable(wheel) and self.picker.def then
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
    if self.zone == "list" or self.zone == "slots" then self.zone = "rail" end
    if self.zone == "popup" then
        if name == "A" then
            self:AnswerPopup(true)
        elseif name == "B" then
            self:AnswerPopup(false)
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
    -- Left / right move between the wheels (left) and the picker or the
    -- buttons (right); up / down move inside them. The wheel's slot follows
    -- the right stick only (W:OnStick); L2 / R2 turn its page from the list
    -- or the buttons, and switch the picker's lists there.
    if name == "LB" or name == "RB" then return false end
    if wheel and not wheel.new then
        if name == "Y" then
            self:Triangle(wheel)
            return true
        elseif name == "X" then
            self:Square(wheel)
            return true
        end
    end
    if self.zone == "rail" then
        if name == "UP" or name == "DOWN" then
            self:Select(self.index + (name == "UP" and -1 or 1))
        elseif name == "A" or name == "RIGHT" then
            if wheel and wheel.new then
                self:CreateWheel()
            elseif wheel and Editable(wheel) then
                self.zone = "picker"
            end
        elseif name == "LT" or name == "RT" then
            self:StepPage(name == "LT" and -1 or 1)
        else
            -- Circle closes the panel
            return false
        end
        menu.Render()
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
    return true
end

function W:Help()
    local H = K.H
    local wheel = self:Current()
    if self.zone == "rename" then
        return { H({ "DPAD_LR" }, "Name", "RIGHT"), H({ "A" }, "Confirm", "A"), H({ "B" }, "Cancel", "B") }
    end
    if self.zone == "popup" then return { H({ "A" }, "Confirm", "A"), H({ "B" }, "Cancel", "B") } end
    -- Only what does something here: a wheel that fills itself has no slot
    -- to edit, "New wheel" nothing to page, bind or clear
    local hints = {}
    local isNew = not wheel or wheel.new
    if self.zone == "rail" then
        hints[#hints + 1] = H({ "DPAD" }, "Pick wheel")
        if isNew then
            hints[#hints + 1] = H({ "A" }, "Create", "A")
        elseif Editable(wheel) then
            hints[#hints + 1] = H({ "RS" }, "Edit slot")
            hints[#hints + 1] = H({ "A" }, "Edit", "A")
        end
    else
        hints[#hints + 1] = H({ "RS" }, "Slot")
        hints[#hints + 1] = H({ "DPAD" }, "Move")
        hints[#hints + 1] = H({ "A" }, "Choose", "A")
        hints[#hints + 1] = H({ "LT", "RT" }, "List", "RT")
    end
    if wheel and not wheel.new then
        if Editable(wheel) then
            hints[#hints + 1] = H({ "Y" }, wheel.id and "Clear (hold: rename)"
                or (wheel.reset and "Clear (hold: reset)" or "Clear"), "Y")
        end
        if wheel.id then hints[#hints + 1] = H({ "X" }, "Hold: delete", "X") end
    end
    hints[#hints + 1] = H({ "B" }, self.zone == "rail" and "Close" or "Wheels", "B")
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
    if self.zone == "list" or self.zone == "slots" then self.zone = "rail" end
    local wheel, entries = self:Current()

    -- The wheels in rows down the left, from the wheel's top edge
    -- Only LIST_SHOWN at once, scrolled to keep the selected one in view
    local n = #entries
    local shown = math.min(n, LIST_SHOWN)
    self.railTop = math.max(1, math.min(self.railTop or 1, n - shown + 1))
    if self.index < self.railTop then self.railTop = self.index end
    if self.index > self.railTop + shown - 1 then self.railTop = self.index - shown + 1 end
    -- The arrows just past the first and last rows
    local top = K.CenterTop(STAGE.mid, shown)
    K.RingArrow(self.railUp, f, K.RowY(top, 0.25), true, STAGE.rail)
    self.railUp:SetShown(self.railTop > 1)
    K.RingArrow(self.railDown, f, K.RowY(top, shown + 0.75), false, STAGE.rail)
    self.railDown:SetShown(self.railTop + shown - 1 < n)
    for i, e in ipairs(self.railEntries) do
        local entry = entries[i]
        local slot = i - self.railTop + 1
        e:SetShown(entry ~= nil and slot >= 1 and slot <= shown)
        if entry and slot >= 1 and slot <= shown then
            -- Down the left from the wheel's top, top first
            e.seg:Place(f, K.RowY(top, slot), STAGE.rail)
            -- Its name
            local active = i == self.index
            e.label:SetText(entry.label)
            e.label:SetTextColor(unpack(active and KC.focus or (entry.new and KC.dimGold or KC.rail)))
            e.seg:SetFocus(active and self.zone == "rail")
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
    -- Under the count: its page, and what opens it
    local lines = {}
    if isNew then lines[1] = IF.ButtonName("A") .. " makes one" end
    if pages > 1 then lines[#lines + 1] = format("Page %d / %d", base / PER_PAGE + 1, pages) end
    if not isNew then
        local hotkey = MW.HotkeyText(wheel.key)
        lines[#lines + 1] = hotkey and ("|cff9fd8e2" .. hotkey .. "|r") or "Not bound"
    end
    f.kicker:SetText(table.concat(lines, "\n"))
    -- The hub shows only what the wheel is bound to
    f.title:Hide()
    f.kicker:Hide()
    f.count:Hide()
    -- The page dots (the one shown lit), under the binding
    local pageNow = base / PER_PAGE + 1
    for i, d in ipairs(f.pageDots) do
        d:SetShown(pages > 1 and i <= pages)
        if pages > 1 and i <= pages then
            d:ClearAllPoints()
            d:SetPoint("CENTER", d:GetParent(), "TOPLEFT", CX + (i - (pages + 1) / 2) * 15, -(CY + 30))
            local name = i == pageNow and "gamepad-radialgamemenu-cursorbg-neutral" or "gamepad-radialgamemenu-cursorbg-inactive"
            if C_Texture.GetAtlasInfo(name) then
                d:SetAtlas(name)
            else
                local v = i == pageNow and 1 or 0.4
                d:SetColorTexture(v, v, v, 1)
            end
        end
    end
    local glyphs = not isNew and MW.BindGlyphs(wheel.key)
    f.bindGlyphs:SetShown(glyphs and true or false)
    f.bindNone:SetShown(not isNew and not glyphs)
    if glyphs then
        local w = f.bindGlyphs:Set(glyphs)
        f.bindGlyphs:ClearAllPoints()
        f.bindGlyphs:SetPoint("CENTER", f.bindGlyphs:GetParent(), "TOPLEFT", CX, -CY)
        f.bindGlyphs:SetWidth(math.max(1, w))
    end

    -- The slot the right stick picked always shows (the picker fills it)
    local onSlots = true
    for p, s in ipairs(f.slots) do
        local i = base + p
        local action = slots[i]
        local shown = i <= max
        s:SetShown(shown)
        -- (an empty slot: just its "+" and its place, no grey wedge)
        s.empty:SetShown(false)
        s.label:SetShown(shown)
        if shown then
            local name, icon = action and MW.ActionName(action), action and MW.ActionIcon(action)
            s.icon:SetShown(action ~= nil)
            if action then K.SetIcon(s.icon, icon or 134400) end
            s.plus:SetShown(not action and Editable(wheel) or false)
            local count = action and action:match("^item:(%d+)$")
            local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
            s.count:SetText(count and getCount and getCount(tonumber(count)) or "")
            s.label:SetText(name or MW.POSITIONS[p])
            local focus = (onSlots or self.zone == "picker") and i == self.slot
            s.label:SetTextColor(unpack(focus and KC.white or (action and KC.title or KC.grey)))
            s:SetAlpha(isNew and 0.35 or 1)
            s.empty:SetAlpha(isNew and 0.35 or 1)
        end
    end
    -- The highlight on the slot with the focus (cyan: the picker fills it)
    local showHighlight = not isNew and self.slot <= max
    f.highlight:SetShown(showHighlight)
    if showHighlight then
        local a = ((self.slot - 1) % PER_PAGE) * math.pi / 4
        f.highlight:ClearAllPoints()
        f.highlight:SetPoint("CENTER", f.highlight:GetParent(), "TOPLEFT",
            CX + WEDGE_RADIUS * math.sin(a), -(CY - WEDGE_RADIUS * math.cos(a)))
        f.highlight:SetRotation(math.pi - a)
        if self.zone == "picker" then
            f.highlight:SetVertexColor(KC.info[1], KC.info[2], KC.info[3])
        else
            f.highlight:SetVertexColor(1, 1, 1)
        end
    end
    local focused = slots[self.slot]
    local showSlot = onSlots or self.zone == "picker"
    f.hubName:SetText(showSlot and (focused and MW.ActionName(focused)
        or MW.POSITIONS[(self.slot - 1) % PER_PAGE + 1]) or "")
    f.hubName:SetTextColor(unpack(focused and KC.cream or KC.grey))
    f.count:SetText(isNew and "" or format("%d / %d", Count(wheel), max))

    -- Right: the picker (faded unless it has the focus), or the detail
    if Editable(wheel) then
        self.detail:Hide()
        if not self.picker:IsOpen() then self:OpenPicker(wheel) end
        self.picker:Show()
        self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
        self.picker:Render()
        self.picker:Center(f, STAGE.picker, STAGE.mid)
    else
        self.picker:Close()
        self.detail:Show()
        if isNew then
            self.detail:Set({ title = "New wheel", body = "Makes an empty wheel of your own and opens it: pick a"
                .. " spell, an item, a macro or an emote for each slot. Up to " .. MW.MAX .. " wheels." })
        else
            self.detail:Set({ title = wheel.label, tag = "Fills itself", tagColor = KC.slot, body = wheel.info,
                extra = "Bound to: " .. (MW.HotkeyText(wheel.key) or "nothing")
                    .. ". Bind it to a press in the Controller tab." })
        end
    end
    -- The box over the wheel: naming
    f.veil:SetShown(self.zone == "rename")
    self.box:SetShown(self.zone == "rename")
end

---------------------------------------------------------------------------
-- The Wheels tab (Menu.lua) uses this page
---------------------------------------------------------------------------
menu.AddTab({ key = "wheel", label = "Wheels", module = "wheel", order = 20, page = W })

-- The panel closed (Circle, combat) while naming: cancelled
hooksecurefunc(menu, "Close", function()
    W:FinishRename(nil)
end)
