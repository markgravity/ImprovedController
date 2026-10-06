-- The configuration panel, adapted from Easy Controller - Forever's
-- ConfigWindow (moust4ki, MIT License, see LICENSE-EasyController.md):
-- 820 x 580, tabs (L1 / R1), each a rail of sections on the left, the
-- section's settings in the middle and what the focused one does on the
-- right; the help bar at the bottom shows where the focus is and what the
-- pad does there. While it is open the pad is bound to hidden buttons of
-- ours, out of combat only, and released when it closes (or combat starts).
-- Open it with /ic, the key binding, or the AddOns options.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C

local menu = {}
IC.Menu = menu

local W, H = 1000, 580
local RAIL_W, LIST_W, DETAIL_W, GAP, BODY_H = 150, 490, 300, 12, 424
local BODY_W = W - 36 -- 964: rail, list and detail with their gaps
local BUDGET = 420
local HEIGHT = { header = 32, check = 36, choice = 36, slider = 36, stat = 36, button = 42 }
local FOCUSABLE = { check = true, choice = true, slider = true, button = true }
local ICON = "Interface\\Icons\\"

local function resolve(v)
    if type(v) == "function" then return v() end
    return v
end

---------------------------------------------------------------------------
-- What the tabs hold
---------------------------------------------------------------------------

menu.TABS = {
    {
        key = "general", label = "General",
        -- GeneralEditor.lua's page: the settings, the big slot, the choices
        sections = {},
    },
    {
        key = "wheels", label = "Wheels",
        -- WheelEditor.lua's page: the rail of wheels and the selected one's editor
        sections = {},
    },
    {
        key = "touchpad", label = "Touchpad",
        -- TouchEditor.lua's page: the corners, the big slot, the picker
        sections = {},
    },
    {
        key = "vibration", label = "Vibration",
        -- VibeEditor.lua's page: the events, the big slot, the patterns
        sections = {},
    },
}

---------------------------------------------------------------------------
-- A tab: a rail of sections, the section's list, a detail panel
---------------------------------------------------------------------------
local Page = {}
Page.__index = Page

local function NewPage(def)
    return setmetatable({ def = def, zone = "list", section = 1, focusId = {}, focusIndex = {}, focusNext = {},
        focusPrev = {}, start = {} }, Page)
end

-- The rows of a section: b.header(text), b.info(text), b.check{...},
-- b.choice{...}, b.slider{...}, b.button{...}, b.stat{...}
local function Builder()
    local rows, b = {}, {}
    local function add(row)
        rows[#rows + 1] = row
        row.id = row.id or (row.kind .. #rows)
        return row
    end
    function b.header(label) return add({ kind = "header", label = label }) end
    function b.info(text) return add({ kind = "info", label = text }) end
    for _, kind in ipairs({ "check", "choice", "slider", "button", "stat" }) do
        b[kind] = function(o)
            o.kind = kind
            return add(o)
        end
    end
    return rows, b
end

local function Focusable(row)
    return row and FOCUSABLE[row.kind] and not resolve(row.disabled) or false
end

function Page:Section()
    return self.def.sections[self.section] or self.def.sections[1]
end

function Page:Rebuild()
    local rows, b = Builder()
    local sec = self:Section()
    if sec and sec.rows then sec.rows(b, self) end
    self.rows = rows
end

-- The row with the focus: the one last focused in this section (by its id),
-- else the row after it or before it, else near its place, else the first
function Page:FocusIndex()
    local rows, key = self.rows, self:Section().key
    for _, id in ipairs({ self.focusId[key], self.focusNext[key], self.focusPrev[key] }) do
        for i, row in ipairs(rows) do
            if row.id == id and Focusable(row) then return i end
        end
    end
    local near = self.focusIndex[key]
    if near then
        for i = math.min(near, #rows), 1, -1 do
            if Focusable(rows[i]) then return i end
        end
    end
    for i, row in ipairs(rows) do
        if Focusable(row) then return i end
    end
end

function Page:SetFocus(i)
    local rows = self.rows
    local row = rows[i]
    if not row then return end
    local key = self:Section().key
    self.focusId[key], self.focusIndex[key] = row.id, i
    local function neighbour(step)
        local j = i + step
        while rows[j] and not Focusable(rows[j]) do j = j + step end
        return rows[j] and rows[j].id
    end
    self.focusNext[key], self.focusPrev[key] = neighbour(1), neighbour(-1)
end

function Page:RowHeight(row)
    if row.kind == "info" then return row.height or 44 end
    return HEIGHT[row.kind] or 36
end

local function Arrow(parent, text, page, row, delta)
    local a = K.NewFrame("Button", nil, parent)
    a:SetSize(22, 22)
    a.box = K.Box(a, 4, 1, "ARTWORK")
    a.box:SetPoints(a)
    a.text = K.Text(a, 13, KC.dimGold)
    a.text:SetPoint("CENTER", 0, 0)
    a.text:SetJustifyH("CENTER")
    a.text:SetText(text)
    a:SetScript("OnClick", function() page:ClickRow(row, delta) end)
    return a
end

local function NewRow(page, n)
    local r = K.NewFrame("Button", nil, page.list)
    r:SetWidth(LIST_W)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.sel = K.NineSlice(r, "ic_select", 128, 32, 10, 10, "ARTWORK")
    -- A section's title
    r.head = K.Text(r, 15, KC.title)
    r.head:SetPoint("BOTTOMLEFT", 2, 7)
    r.headLine = K.Solid(r, KC.line2, 1, "BORDER")
    r.headLine:SetHeight(1)
    r.headLine:SetPoint("BOTTOMLEFT", 0, 2)
    r.headLine:SetPoint("BOTTOMRIGHT", 0, 2)
    -- An explanation
    r.info = K.ChatText(r, 14, KC.help)
    r.info:SetPoint("TOPLEFT", 10, -8)
    r.info:SetWidth(LIST_W - 20)
    r.info:SetWordWrap(true)
    r.info:SetSpacing(6)
    -- A setting: its icon, its label, its control on the right
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(24, 24)
    r.icon:SetPoint("LEFT", 12, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.label = K.Text(r, 16, KC.cream)
    r.status = K.ChatText(r, 13, KC.grey)
    r.status:SetJustifyH("RIGHT")
    r.stat = K.Text(r, 16, KC.focus)
    r.stat:SetJustifyH("RIGHT")
    -- < value >
    r.choice = K.NewFrame("Frame", nil, r)
    r.choice:SetHeight(22)
    r.left = Arrow(r.choice, "<", page, r, -1)
    r.left:SetPoint("LEFT")
    r.right = Arrow(r.choice, ">", page, r, 1)
    r.right:SetPoint("RIGHT")
    r.value = K.Text(r.choice, 15, KC.cream)
    r.value:SetPoint("LEFT", r.left, "RIGHT", 4, 0)
    r.value:SetPoint("RIGHT", r.right, "LEFT", -4, 0)
    r.value:SetJustifyH("CENTER")
    -- The tick box, always on the right
    r.box = K.NewFrame("Button", nil, r)
    r.box:SetSize(24, 24)
    r.box.frame = K.Box(r.box, 3, 2, "ARTWORK")
    r.box.frame:SetPoints(r.box)
    r.box.tick = r.box:CreateTexture(nil, "OVERLAY")
    r.box.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.box.tick:SetPoint("CENTER", 0, 0)
    r.box.tick:SetSize(26, 26)
    r.box.tick:SetVertexColor(KC.focus[1], KC.focus[2], KC.focus[3])
    r.box:SetScript("OnClick", function() page:ClickRow(r) end)
    -- A slider: its track, the filled part, the handle, the value
    r.slider = K.NewFrame("Button", nil, r)
    r.slider:SetHeight(16)
    r.slider.value = K.Text(r.slider, 15, KC.cream)
    r.slider.value:SetPoint("RIGHT")
    r.slider.value:SetWidth(40)
    r.slider.value:SetJustifyH("RIGHT")
    r.slider.track = K.NewFrame("Frame", nil, r.slider)
    r.slider.track:SetPoint("LEFT")
    r.slider.track:SetPoint("RIGHT", -48, 0)
    r.slider.track:SetHeight(8)
    r.slider.trackBox = K.Box(r.slider.track, 4, 1, "ARTWORK")
    r.slider.trackBox:SetPoints(r.slider.track)
    r.slider.fill = K.Solid(r.slider.track, KC.fill, 1, "ARTWORK", 3)
    r.slider.fill:SetPoint("TOPLEFT", 1, -1)
    r.slider.fill:SetPoint("BOTTOMLEFT", 1, 1)
    r.slider.handle = K.Solid(r.slider.track, KC.dimGold, 1, "OVERLAY")
    r.slider.handle:SetSize(14, 16)
    r.slider:SetScript("OnMouseDown", function(self)
        local x = GetCursorPosition() / self:GetEffectiveScale()
        local left, width = self.track:GetLeft(), self.track:GetWidth()
        if left and width and width > 0 then page:SlideRow(r, (x - left) / width) end
    end)
    -- A button row's button
    r.btn = K.Button(r, 15)
    r.btn:SetScript("OnClick", function() page:ClickRow(r) end)
    r:SetScript("OnClick", function(self, button)
        page:ClickRow(self, button == "RightButton" and -1 or nil)
    end)
    page.rowsUI[n] = r
    return r
end

function Page:Build(parent)
    local f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()
    self.frame = f
    local page = self

    -- The rail of sections
    local rail = K.NewFrame("Frame", nil, f)
    rail:SetPoint("TOPLEFT")
    rail:SetSize(RAIL_W, BODY_H)
    local line = K.Solid(rail, KC.line3, 1, "BORDER")
    line:SetPoint("TOPRIGHT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetWidth(1)
    self.railEntries = {}
    for i in ipairs(self.def.sections) do
        local e = K.NewFrame("Button", nil, rail)
        e:SetSize(RAIL_W - 11, 38)
        e:SetPoint("TOPLEFT", 0, -2 - (i - 1) * 42)
        e.sel = K.NineSlice(e, "ic_select", 128, 32, 10, 10, "ARTWORK")
        e.diamond = e:CreateTexture(nil, "OVERLAY")
        e.diamond:SetTexture(K.TEX .. "ic_diamond")
        e.diamond:SetSize(7, 7)
        e.diamond:SetPoint("LEFT", 10, 0)
        e.diamond:SetVertexColor(KC.title[1], KC.title[2], KC.title[3])
        e.label = K.Text(e, 16, KC.rail)
        e.label:SetPoint("LEFT", 25, 0)
        e.label:SetWidth(RAIL_W - 11 - 29)
        e:SetScript("OnClick", function() page:SetSection(i, "rail") end)
        self.railEntries[i] = e
    end

    -- The section's list
    local list = K.NewFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", RAIL_W + GAP, 0)
    list:SetSize(LIST_W, BODY_H)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        page.zone = "list"
        page:MoveFocus(delta > 0 and -1 or 1, 3)
    end)
    self.list = list
    self.rowsUI = {}
    self.moreUp = list:CreateTexture(nil, "OVERLAY")
    self.moreUp:SetTexture(K.TEX .. "ic_tri")
    self.moreUp:SetTexCoord(0, 1, 1, 0)
    self.moreUp:SetSize(11, 11)
    self.moreUp:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, 10)
    self.moreDown = list:CreateTexture(nil, "OVERLAY")
    self.moreDown:SetTexture(K.TEX .. "ic_tri")
    self.moreDown:SetSize(11, 11)
    self.moreDown:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -4, -8)
    for _, t in ipairs({ self.moreUp, self.moreDown }) do t:SetVertexColor(KC.dimGold[1], KC.dimGold[2], KC.dimGold[3]) end
    -- Sections drawn their own way (the wheels' cards) in the list's place
    for _, sec in ipairs(self.def.sections) do
        if sec.view then sec.view:Build(list, self) end
    end

    -- The detail panel
    self.detail = K.Detail(f, DETAIL_W)
    self.detail:SetPoint("TOPRIGHT")
    self.detail:SetHeight(BODY_H)
end

function Page:Show()
    local saved = IC.db.menuSection
    local i = saved and saved[self.def.key]
    if i and self.def.sections[i] then self.section = i end
    self.zone = "list"
    self.frame:Show()
end

function Page:Hide()
    self.frame:Hide()
end

function Page:SetSection(i, zone)
    if not self.def.sections[i] then return end
    if i ~= self.section then menu.Disarm() end
    self.section = i
    if zone then self.zone = zone end
    IC.db.menuSection = IC.db.menuSection or {}
    IC.db.menuSection[self.def.key] = i
    menu.Render()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function SetShownParts(r, parts)
    r.head:SetShown(parts.head or false)
    r.headLine:SetShown(parts.head or false)
    r.info:SetShown(parts.info or false)
    r.icon:SetShown(parts.icon or false)
    r.label:SetShown(parts.label or false)
    r.status:SetShown(parts.status or false)
    r.stat:SetShown(parts.stat or false)
    r.choice:SetShown(parts.choice or false)
    r.box:SetShown(parts.box or false)
    r.slider:SetShown(parts.slider or false)
    r.btn:SetShown(parts.btn or false)
end

function Page:LayoutRow(r, row, focused)
    r.row = row
    r.sel:SetShown(false)
    local kind = row.kind
    if kind == "header" then
        SetShownParts(r, { head = true })
        r.head:SetText(row.label)
        return
    end
    if kind == "info" then
        SetShownParts(r, { info = true })
        r.info:SetText(resolve(row.label))
        return
    end
    local disabled = resolve(row.disabled)
    if kind == "button" then
        SetShownParts(r, { btn = true })
        r.btn:ClearAllPoints()
        r.btn:SetPoint("TOPLEFT", 0, -5)
        r.btn:SetPoint("BOTTOMRIGHT", 0, 5)
        local armed = menu.IsArmed(row.id)
        r.btn.label:SetText(armed and row.armedLabel or resolve(row.label))
        r.btn:SetState({ focus = focused, armed = armed, disabled = disabled })
        return
    end

    -- A setting's row
    r.sel:SetShown(focused)
    local right = LIST_W - 8
    local controlLeft = right
    local parts = { label = true }
    if kind == "check" then
        parts.box = true
        r.box:ClearAllPoints()
        r.box:SetPoint("RIGHT", r, "LEFT", right, 0)
        local on = resolve(row.get)
        r.box.frame:SetColors(KC.boxBg, 1, disabled and KC.boxOff or (on and KC.slot or KC.boxEdge), 1)
        r.box.tick:SetShown(on and true or false)
        controlLeft = right - 24
    elseif kind == "choice" then
        parts.choice = true
        local w = 176
        r.choice:SetWidth(w)
        r.choice:ClearAllPoints()
        r.choice:SetPoint("RIGHT", r, "LEFT", right, 0)
        local arrowColor = disabled and KC.arrowOff or (focused and KC.focus or KC.dimGold)
        for _, a in ipairs({ r.left, r.right }) do
            a.text:SetTextColor(unpack(arrowColor))
            a.box:SetColors(a.pressed and KC.pressed or KC.controlBg, 1, KC.control, 1)
        end
        r.value:SetText(resolve(row.text) or "")
        r.value:SetTextColor(unpack(disabled and KC.disabled or KC.cream))
        controlLeft = right - w
    elseif kind == "slider" then
        parts.slider = true
        r.slider:SetWidth(176)
        r.slider:ClearAllPoints()
        r.slider:SetPoint("RIGHT", r, "LEFT", right, 0)
        local v, lo, hi = resolve(row.get), row.min, row.max
        local frac = hi > lo and math.max(0, math.min(1, (v - lo) / (hi - lo))) or 0
        local trackW = 176 - 48
        r.slider.fill:SetWidth(math.max(0.01, (trackW - 2) * frac))
        r.slider.handle:ClearAllPoints()
        r.slider.handle:SetPoint("CENTER", r.slider.track, "LEFT", (trackW - 14) * frac + 7, 0)
        r.slider.trackBox:SetColors(KC.controlBg, 1, focused and KC.slot or KC.control, 1)
        local hc = focused and KC.focus or KC.dimGold
        r.slider.handle:SetColorTexture(hc[1], hc[2], hc[3], 1)
        r.slider.value:SetText(row.fmt and row.fmt(v) or tostring(v))
        r.slider:SetAlpha(disabled and 0.4 or 1)
        controlLeft = right - 176
    elseif kind == "stat" then
        parts.stat = true
        r.stat:ClearAllPoints()
        r.stat:SetPoint("RIGHT", r, "LEFT", right, 0)
        r.stat:SetText(resolve(row.text) or "")
        controlLeft = right - r.stat:GetStringWidth()
    end
    local status = resolve(row.status)
    if status and kind == "check" then
        parts.status = true
        r.status:ClearAllPoints()
        r.status:SetPoint("RIGHT", r, "LEFT", controlLeft - 10, 0)
        r.status:SetText(status)
        controlLeft = controlLeft - 10 - r.status:GetStringWidth()
    end
    local x = 14
    if row.icon then
        parts.icon = true
        r.icon:SetTexture(resolve(row.icon))
        x = 44
    end
    SetShownParts(r, parts)
    r.label:ClearAllPoints()
    r.label:SetPoint("LEFT", r, "LEFT", x, 0)
    r.label:SetWidth(math.max(20, controlLeft - 10 - x))
    r.label:SetText(resolve(row.label))
    r.label:SetTextColor(unpack(disabled and KC.disabled or (focused and KC.focusText or KC.cream)))
end

function Page:Render()
    -- The rail
    for i, e in ipairs(self.railEntries) do
        local active = i == self.section
        e.label:SetText(self.def.sections[i].label)
        e.label:SetTextColor(unpack(active and KC.focus or KC.rail))
        e.diamond:SetShown(active)
        e.sel:SetShown(active and self.zone == "rail")
    end
    -- A section drawn its own way
    local sec = self:Section()
    for _, other in ipairs(self.def.sections) do
        if other.view then other.view.frame:SetShown(other == sec) end
    end
    if sec.view then
        self.rows = {}
        for _, r in ipairs(self.rowsUI) do r:Hide() end
        self.moreUp:Hide()
        self.moreDown:Hide()
        sec.view:Render(self, self.zone == "list")
        -- A view may bring its own right-hand panel (the touchpad's picker)
        if sec.view.ownsSide then
            self.detail:Hide()
        else
            self.detail:Show()
            self.detail:Set(self.zone == "rail" and { title = sec.label, body = resolve(sec.tip) } or sec.view:Detail(self))
        end
        return
    end
    self.detail:Show()
    -- The list, windowed on the focus (the section title above it kept)
    self:Rebuild()
    local rows = self.rows
    for _, row in ipairs(rows) do
        if row.kind == "info" then
            local probe = self.rowsUI[1] or NewRow(self, 1)
            probe.info:SetText(resolve(row.label))
            row.height = math.floor(probe.info:GetStringHeight() + 16 + 0.5)
        end
    end
    local fi = self:FocusIndex()
    if fi then self:SetFocus(fi) end
    local start = math.max(1, math.min(self.start[sec.key] or 1, #rows))
    local function sum(a, b)
        local t = 0
        for j = a, b do t = t + self:RowHeight(rows[j]) end
        return t
    end
    if sum(1, #rows) <= BUDGET then start = 1 end
    if fi then
        if fi < start then start = (fi > 1 and rows[fi - 1].kind == "header") and fi - 1 or fi end
        while start < fi and sum(start, fi) > BUDGET do start = start + 1 end
    end
    while start > 1 and sum(start - 1, #rows) <= BUDGET do start = start - 1 end
    self.start[sec.key] = start
    local used, n, moreBelow = 0, 0, false
    for j = start, #rows do
        local h = self:RowHeight(rows[j])
        if used + h > BUDGET + 2 then
            moreBelow = true
            break
        end
        n = n + 1
        local r = self.rowsUI[n] or NewRow(self, n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -used)
        r:SetHeight(h)
        r.index = j
        self:LayoutRow(r, rows[j], self.zone == "list" and j == fi)
        r:Show()
        used = used + h
    end
    for j = n + 1, #self.rowsUI do self.rowsUI[j]:Hide() end
    self.moreUp:SetShown(start > 1)
    self.moreDown:SetShown(moreBelow)
    self.detail:Set(self:Detail())
end

function Page:Detail()
    local sec = self:Section()
    if self.zone == "rail" then return { title = sec.label, body = resolve(sec.tip) } end
    local row = self.rows[self:FocusIndex() or 0]
    if not row then return { title = sec.label, body = resolve(sec.tip) } end
    local tag, tagColor
    if row.kind == "check" then
        local on = resolve(row.get)
        tag, tagColor = on and "On" or "Off", on and KC.slot or KC.grey
    end
    return { icon = row.icon and resolve(row.icon), title = resolve(row.title) or resolve(row.label),
        body = resolve(row.tip), tag = tag, tagColor = tagColor, extra = resolve(row.extra) }
end

function Page:Crumb()
    return self.def.label .. " › " .. (self:Section().label or "")
end

---------------------------------------------------------------------------
-- The pad, the mouse
---------------------------------------------------------------------------
function Page:MoveFocus(delta, count)
    local rows, i = self.rows, self:FocusIndex()
    if not i then return menu.Render() end
    local from = i
    for _ = 1, count or 1 do
        local j = i + delta
        while rows[j] and not Focusable(rows[j]) do j = j + delta end
        if rows[j] then i = j end
    end
    if i ~= from then menu.Disarm() end
    self:SetFocus(i)
    menu.Render()
end

-- A row's action: Cross (or a click), or its value moved (delta)
function Page:Act(row, delta)
    if not row or resolve(row.disabled) then return end
    local kind = row.kind
    if delta then
        if kind == "choice" then
            if row.step then row.step(delta) end
        elseif kind == "slider" then
            local v = resolve(row.get) + delta * (row.stepSize or 1)
            row.set(math.max(row.min, math.min(row.max, v)))
        end
        return menu.Render()
    end
    if kind == "check" then
        row.set(not resolve(row.get))
    elseif kind == "choice" then
        if row.step then row.step(1) end
    elseif kind == "button" then
        if row.danger and not menu.IsArmed(row.id) then
            menu.Arm(row.id)
        else
            menu.Disarm()
            row.func()
        end
    end
    menu.Render()
end

function Page:ClickRow(r, delta)
    if not (r and r.index) then return end
    local row = self.rows[r.index]
    if not Focusable(row) then return end
    if menu.armed and menu.armed ~= row.id then menu.Disarm() end
    self.zone = "list"
    self:SetFocus(r.index)
    if delta and not (row.kind == "choice" or row.kind == "slider") then delta = nil end
    if delta and row.kind == "choice" and r.left then
        local a = delta < 0 and r.left or r.right
        a.pressed = true
        C_Timer.After(0.1, function()
            a.pressed = nil
            if menu.IsOpen() then menu.Render() end
        end)
    end
    self:Act(row, delta)
end

function Page:SlideRow(r, frac)
    local row = r.index and self.rows[r.index]
    if not (row and row.kind == "slider") or resolve(row.disabled) then return end
    self.zone = "list"
    self:SetFocus(r.index)
    local step = row.stepSize or 1
    row.set(row.min + math.floor((row.max - row.min) * math.max(0, math.min(1, frac)) / step + 0.5) * step)
    menu.Render()
end

function Page:Press(name)
    local sections = self.def.sections
    if self.zone == "rail" then
        if name == "UP" or name == "DOWN" then
            self:SetSection(math.max(1, math.min(#sections, self.section + (name == "UP" and -1 or 1))))
        elseif name == "A" or name == "RIGHT" then
            self.zone = "list"
            menu.repeatName = nil
            menu.Render()
        else
            return false
        end
        return true
    end
    -- A section drawn its own way: its presses; Circle or an edge back to the rail
    local view = self:Section().view
    if view then
        if view:Press(self, name) then return true end
        if name == "B" or name == "LEFT" then
            self.zone = "rail"
            menu.Render()
            return true
        end
        return false
    end
    local row = self.rows[self:FocusIndex() or 0]
    if name == "UP" or name == "DOWN" then
        self:MoveFocus(name == "UP" and -1 or 1)
    elseif name == "LEFT" then
        if row and (row.kind == "choice" or row.kind == "slider") then
            self:Act(row, -1)
        else
            self.zone = "rail"
            menu.Render()
        end
    elseif name == "RIGHT" then
        if row and (row.kind == "choice" or row.kind == "slider") then self:Act(row, 1) end
    elseif name == "A" then
        if row then self:Act(row) end
    elseif name == "X" or name == "Y" then
        local fn = row and row[name == "X" and "onX" or "onY"]
        if fn then
            fn()
            menu.Render()
        end
    elseif name == "B" then
        self.zone = "rail"
        menu.Render()
    else
        return false
    end
    return true
end

function Page:Help()
    local Hn = K.H
    local tab = Hn({ "LB", "RB" }, "Tab", "RB")
    if self.zone == "rail" then
        return { Hn({ "DPAD" }, "Move"), Hn({ "A" }, "Open", "A"), tab, Hn({ "B" }, "Close", "B") }
    end
    local view = self:Section().view
    if view then return view:Help(self) end
    local row = self.rows[self:FocusIndex() or 0]
    if not row then return { tab, Hn({ "B" }, "Back", "B") } end
    local hints = {}
    if row.kind == "check" then
        hints[#hints + 1] = Hn({ "A" }, resolve(row.get) and "Uncheck" or "Check", "A")
    elseif row.kind == "choice" or row.kind == "slider" then
        hints[#hints + 1] = Hn({ "DPAD_LR" }, "Change", "RIGHT")
    elseif row.kind == "button" then
        hints[#hints + 1] = Hn({ "A" }, row.danger and "Clear" or "Select", "A")
    end
    if row.onX then hints[#hints + 1] = Hn({ "X" }, row.xVerb, "X") end
    if row.onY then hints[#hints + 1] = Hn({ "Y" }, row.yVerb, "Y") end
    hints[#hints + 1] = tab
    hints[#hints + 1] = Hn({ "B" }, "Back", "B")
    return hints
end

-- A touchpad click while this page is up: its section's view, if it wants it
function Page:OnTouch()
    for i, sec in ipairs(self.def.sections) do
        if sec.view and sec.view.OnTouch then
            if i ~= self.section then self:SetSection(i) end
            self.zone = "list"
            sec.view:OnTouch(self)
            return
        end
    end
end

menu.NewPage = NewPage

-- A tab added by another file (WheelEditor.lua), placed before the tab `before`
function menu.AddTab(def, before)
    for i, other in ipairs(menu.TABS) do
        if other.key == before then
            table.insert(menu.TABS, i, def)
            return
        end
    end
    menu.TABS[#menu.TABS + 1] = def
end

---------------------------------------------------------------------------
-- Transient states: a destructive button armed (a second Cross does it;
-- Circle, a move or 4 s let it go), a short message in the crumb (1.8 s)
---------------------------------------------------------------------------
function menu.Arm(id)
    menu.armed = id
    menu.armToken = (menu.armToken or 0) + 1
    local token = menu.armToken
    C_Timer.After(4, function()
        if menu.armToken == token and menu.armed == id then
            menu.armed = nil
            menu.Render()
        end
    end)
end

function menu.IsArmed(id)
    return menu.armed ~= nil and menu.armed == id
end

function menu.Disarm()
    menu.armed = nil
end

function menu.Toast(text, warn)
    menu.toast = { text = text, color = warn and KC.warn or KC.info }
    menu.toastToken = (menu.toastToken or 0) + 1
    local token = menu.toastToken
    C_Timer.After(1.8, function()
        if menu.toastToken == token then
            menu.toast = nil
            menu.Render()
        end
    end)
    menu.Render()
end

---------------------------------------------------------------------------
-- Window: header (40), tabs (44), body (448), help bar (44)
---------------------------------------------------------------------------
local frame
local pages = {}
menu.pages = pages

function menu.IsOpen()
    return frame ~= nil and frame:IsShown()
end

local function CurrentPage()
    return pages[menu.tab] or pages[menu.TABS[1].key]
end

local function Build()
    if frame then return end
    local f = K.NewFrame("Frame", "ImprovedControllerConfigFrame", UIParent)
    f:SetAllPoints(UIParent)
    -- Above every other window (chat, the gamepad bars...), so nothing
    -- shows through the panel's text
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    -- Centred over the game with no window of its own, framed like Forever's
    -- radial menu (its header and footer bands), as the R3 wheel is
    f:Hide()
    frame = f
    local function atlas(texture, name)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
            texture:SetAtlas(name)
            return true
        end
    end

    -- Header, as the R3 wheel's: the tab's name, under it the native top
    -- band with a dot per tab (they click to their tab) between L1 / R1
    f.header = f:CreateFontString(nil, "OVERLAY")
    f.header:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    f.header:SetShadowOffset(1, -1)
    f.header:SetTextColor(1, 1, 1)
    -- (where the R3 wheel has its own: 50 above a 540 wheel at the centre)
    f.header:SetPoint("BOTTOM", f, "CENTER", 0, 320)
    local band = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    band:SetSize(487, 75)
    band:SetPoint("TOP", f.header, "BOTTOM", 0, 4)
    if not atlas(band, "gamepad-radial-menu-toptext") then band:SetColorTexture(0, 0, 0, 0.5) end
    local dotRow = K.NewFrame("Frame", nil, f)
    dotRow:SetSize(1, 15)
    dotRow:SetPoint("TOP", f.header, "BOTTOM", 0, -24)
    f.dots = {}
    local count = #menu.TABS
    for i, def in ipairs(menu.TABS) do
        local d = K.NewFrame("Button", nil, dotRow)
        d:SetSize(15, 15)
        d:SetPoint("CENTER", dotRow, "CENTER", (i - (count + 1) / 2) * 20, 0)
        d.tex = d:CreateTexture(nil, "OVERLAY")
        d.tex:SetAllPoints()
        d.key = def.key
        d:SetScript("OnClick", function() menu.SetTab(def.key) end)
        f.dots[i] = d
    end
    -- L1 / R1 at the native header's size, just clear of the dots
    local edge = (count - 1) / 2 * 20 + 12
    f.lbGlyph = K.Glyph(f, 38)
    f.lbGlyph:SetPoint("RIGHT", dotRow, "CENTER", -edge, 0)
    f.lbGlyph:EnableMouse(true)
    f.lbGlyph:SetScript("OnMouseUp", function() menu.StepTab(-1) end)
    f.rbGlyph = K.Glyph(f, 38)
    f.rbGlyph:SetPoint("LEFT", dotRow, "CENTER", edge, 0)
    f.rbGlyph:EnableMouse(true)
    f.rbGlyph:SetScript("OnMouseUp", function() menu.StepTab(1) end)
    f.atlas = atlas

    -- Body: 964 x 424 inside its margins
    f.body = K.NewFrame("Frame", nil, f)
    f.body:SetPoint("CENTER", f, "CENTER", 0, 10)
    f.body:SetSize(BODY_W, BODY_H)
    for _, def in ipairs(menu.TABS) do
        -- A tab may bring its own page (the Wheels tab: the rail or the editor)
        local page = def.page and def.page(NewPage(def)) or NewPage(def)
        page:Build(f.body)
        pages[def.key] = page
    end

    -- Footer: the native bottom band, where the focus is, the pad's hints
    local bar = K.NewFrame("Frame", nil, f)
    bar:SetPoint("TOP", f, "CENTER", 0, -276)
    bar:SetSize(W, 52)
    f.bar = bar
    f.footer = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.footer:SetPoint("CENTER", bar, "CENTER", 0, -6)
    f.footer:SetHeight(120)
    if not atlas(f.footer, "gamepad-radial-menu-bottomtext") then f.footer:SetColorTexture(0, 0, 0, 0.5) end
    f.crumb = K.ChatText(bar, 13, KC.grey)
    f.crumb:SetPoint("TOP", bar, "TOP", 0, -2)
    f.crumb:SetJustifyH("CENTER")
    f.crumb:SetWordWrap(false)
    f.hintRow = K.NewFrame("Frame", nil, bar)
    f.hintRow:SetSize(1, 30)
    f.hintRow:SetPoint("TOP", bar, "TOP", 0, -18)
    f.hints = {}

    f:SetScript("OnUpdate", function() menu.OnUpdate() end)
    -- The panel takes both sticks while it is open (the camera and the
    -- character stay still); a page may point with them (the wheel editor)
    if f.EnableGamePadStick then
        f:EnableGamePadStick(true)
        f:SetScript("OnGamePadStick", function(_, stick, x, y, len)
            local page = CurrentPage()
            if page and page.OnStick then page:OnStick(stick, x, y, len) end
        end)
    end
    menu.CreateInput()
end

function menu.SetTab(key)
    if not pages[key] then return end
    if key == menu.tab and menu.IsOpen() then
        CurrentPage().zone = "list"
        return menu.Render()
    end
    menu.Disarm()
    local old = CurrentPage()
    if old and menu.tab ~= key then old:Hide() end
    menu.tab = key
    IC.db.menuTab = key
    CurrentPage():Show()
    menu.Render()
end

function menu.StepTab(delta)
    local index = 1
    for i, def in ipairs(menu.TABS) do
        if def.key == menu.tab then index = i end
    end
    menu.SetTab(menu.TABS[(index - 1 + delta) % #menu.TABS + 1].key)
end

function menu.Render()
    if not menu.IsOpen() then return end
    local f = frame
    f.lbGlyph:Set("LB")
    f.rbGlyph:Set("RB")
    local index = 1
    for i, def in ipairs(menu.TABS) do
        if def.key == menu.tab then index = i end
    end
    f.header:SetText(menu.TABS[index].label)
    for _, d in ipairs(f.dots) do
        local active = d.key == menu.tab
        if not f.atlas(d.tex, active and "gamepad-radialgamemenu-cursorbg-neutral"
                or "gamepad-radialgamemenu-cursorbg-inactive") then
            d.tex:SetColorTexture(active and 1 or 0.4, active and 1 or 0.4, active and 1 or 0.4, 1)
        end
    end
    local page = CurrentPage()
    page:Render()

    -- The help bar
    local hints = page:Help() or {}
    if menu.armed then hints = { K.H({ "A" }, "Confirm", "A"), K.H({ "B" }, "Cancel", "B") } end
    -- The line over the hints: only a short message (where you are is the
    -- header's and the lists' to show)
    local crumb, color = "", KC.grey
    if menu.toast then crumb, color = menu.toast.text, menu.toast.color end
    f.crumb:SetText(crumb)
    f.crumb:SetTextColor(unpack(color))
    -- The hints centred in a row; the band as wide as they need
    local x = 0
    for i, hint in ipairs(hints) do
        local h = f.hints[i]
        if not h then
            -- The native footer's size: its glyphs, gold labels
            h = K.Hint(f.hintRow, menu.Press, { glyph = 36, font = 13, color = KC.title })
            f.hints[i] = h
        end
        h:Set(hint)
        h:ClearAllPoints()
        h:SetPoint("LEFT", f.hintRow, "LEFT", x, 0)
        x = x + h:GetWidth() + 18
    end
    for i = #hints + 1, #f.hints do f.hints[i]:Hide() end
    local rowW = math.max(1, x - 18)
    f.hintRow:SetWidth(rowW)
    f.crumb:SetWidth(W - 40)
    -- Wide padding: the band's art fades toward its ends, so it reaches well past the hints
    f.footer:SetWidth(math.max(1000, rowW + 760))
end

---------------------------------------------------------------------------
-- Pad input while open: hidden buttons bound with priority
---------------------------------------------------------------------------
local NAV = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT", ESCAPE = "B",
    PADBACK = "TOUCH",
}
-- Held triggers may add modifiers to the keys
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local REPEAT = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

function menu.Press(name)
    -- A touchpad click: the page may read where the finger is
    if name == "TOUCH" then
        local page = CurrentPage()
        if page and page.OnTouch then page:OnTouch() end
        return
    end
    -- A destructive button armed: Cross does it, Circle cancels, a move lets it go
    if menu.armed then
        if name == "B" then
            menu.Disarm()
            return menu.Render()
        end
        if name == "LB" or name == "RB" then return end
        if name ~= "A" then menu.Disarm() end
    end
    if CurrentPage():Press(name) then return end
    if name == "LB" or name == "RB" then
        menu.StepTab(name == "LB" and -1 or 1)
    elseif name == "B" then
        menu.Close()
    end
end

function menu.CreateInput()
    for key, name in pairs(NAV) do
        local b = K.NewFrame("Button", "ImprovedControllerConfigPad" .. key)
        b:SetSize(1, 1)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetScript("OnClick", function(_, _, down)
            -- Circle acts on release: closing on the press would leave the
            -- release to the game alone
            if name == "B" then
                if down == false then menu.Press(name) end
                return
            end
            if down == false then
                if menu.repeatName == name then menu.repeatName = nil end
                return
            end
            if REPEAT[name] then
                menu.repeatName, menu.repeatKey, menu.repeatAt = name, key, GetTime() + 0.35
            end
            menu.Press(name)
        end)
    end
end

local function BindKey(key)
    local name = "ImprovedControllerConfigPad" .. key
    if key == "ESCAPE" then
        SetOverrideBindingClick(frame, true, key, name)
    else
        for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(frame, true, prefix .. key, name) end
    end
end

-- A button still held (the one that opened the panel) is taken only once
-- released: its release belongs to the game, which saw it pressed
function menu.BindPad()
    if InCombatLockdown() or not frame then return end
    ClearOverrideBindings(frame)
    menu.heldKeys = {}
    for key in pairs(NAV) do
        if key ~= "ESCAPE" and IsKeyDown and IsKeyDown(key) then
            menu.heldKeys[key] = true
        else
            BindKey(key)
        end
    end
end

function menu.UnbindPad()
    menu.heldKeys = nil
    if frame and not InCombatLockdown() then ClearOverrideBindings(frame) end
end

function menu.OnUpdate()
    if menu.heldKeys and next(menu.heldKeys) and not InCombatLockdown() then
        for key in pairs(menu.heldKeys) do
            if not IsKeyDown(key) then
                menu.heldKeys[key] = nil
                BindKey(key)
            end
        end
    end
    -- Its release went elsewhere (the game rebound the pad): over
    if menu.repeatName and IsKeyDown and menu.repeatKey and not IsKeyDown(menu.repeatKey) then
        menu.repeatName = nil
    end
    if menu.repeatName and GetTime() >= menu.repeatAt then
        menu.repeatAt = GetTime() + 0.08
        menu.Press(menu.repeatName)
    end
end

---------------------------------------------------------------------------
-- Open / close: back on the last tab and section
---------------------------------------------------------------------------
function menu.Open(tab)
    if InCombatLockdown() then
        IC.Print("the panel opens after combat.")
        return
    end
    Build()
    if menu.IsOpen() then
        if tab then menu.SetTab(tab) end
        return
    end
    local key = tab or IC.db.menuTab
    if not pages[key or ""] then key = menu.TABS[1].key end
    menu.tab = key
    IC.db.menuTab = key
    menu.Disarm()
    frame:Show()
    CurrentPage():Show()
    menu.BindPad()
    menu.Render()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end

function menu.Close()
    if not menu.IsOpen() then return end
    menu.Disarm()
    CurrentPage():Hide()
    menu.UnbindPad()
    frame:Hide()
    menu.repeatName = nil
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
end

function menu.Toggle()
    if menu.IsOpen() then
        menu.Close()
    else
        menu.Open()
    end
end

-- Target of the "Toggle Improved Controller menu" key binding (and the
-- touchpad's "Improved Controller menu" region)
local toggle = CreateFrame("Button", "ImprovedControllerMenuToggle", UIParent)
toggle:SetScript("OnClick", menu.Toggle)
BINDING_HEADER_IMPROVEDCONTROLLER = "Improved Controller"
_G["BINDING_NAME_CLICK ImprovedControllerMenuToggle:LeftButton"] = "Toggle Improved Controller menu"

-- Combat closes the panel (its bindings can only change out of combat;
-- PLAYER_REGEN_DISABLED comes just before the lockdown); spellbook and bag
-- changes redraw it
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        return menu.Close()
    end
    menu.Render()
end)

-- Another controller in hand (or the General tab's choice): its buttons
IC.OnPadStyleChanged(function() menu.Render() end)

-- The controller's Menu / Options button pressed twice quickly opens this
-- panel (once still opens the game's own menu wheel: the button is only
-- watched, never taken). The game's wheel, opened by the first press, is
-- closed. Out of combat.
local DOUBLE = 0.35
local menuKey = CreateFrame("Frame")
local wasDown, lastPress = false, 0
menuKey:SetScript("OnUpdate", function()
    if not IsKeyDown then return end
    local down = IsKeyDown("PADFORWARD")
    if down and not wasDown then
        local now = GetTime()
        if now - lastPress <= DOUBLE then
            lastPress = 0
            if IC.db and not InCombatLockdown() and not menu.IsOpen() then
                -- (on the next frame: the game handles the press first)
                C_Timer.After(0, function()
                    local radial = _G.GamepadRadial
                    if radial and radial:IsShown() then radial:Hide() end
                    if not InCombatLockdown() then menu.Open() end
                end)
            end
        else
            lastPress = now
        end
    end
    wasDown = down
end)
