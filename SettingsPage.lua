-- A tab of settings (the Gather tab), laid out like the Vibration tab: the
-- settings down the left by group, the selected one big in the middle with
-- its value, and its choices in a list down the right.
-- A setting that runs on a button: Square records another one for it
-- (Recorder.lua).
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local B = IC.Binds

local PANEL_W, PICKER_ROWS = 340, 8
local RAIL_ROWS = 8                 -- lines on the left at once (as the picker); the rest scroll

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
-- The page: any tab of settings laid out this way.
-- tabKey: its tab in Menu.lua; title: the crumb's first part; groups /
-- items: { { key, label } }, { { key, group, label, icon, tip, note, value /
-- text / options / choose (IC.SettingsOnOff makes them for on / off) } }.
-- A bindable item names its binding in
-- Binds.lua (bindId): a recorded press taking one from something else asks
-- first; toggle = true: recording its own press again unbinds it.
-- An item with a panel draws its own middle instead of a list of choices:
-- panel = { build(f) -> frame (placed where the choices go), render(frame,
-- focused), press(frame, name) -> handled, hints() -> { K.H... } }.
-- hooks (optional): render(G) after each drawing, hide() as the tab goes.
---------------------------------------------------------------------------
function IC.SettingsPage(tabKey, title, GROUPS, ITEMS, hooks)
    hooks = hooks or {}
    local G = { zone = "rail", index = 1 }

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

        -- Right (the Columns layout, ConfigKit): the selected setting's
        -- icon, its value, what it does
        local d = K.ColumnDetail(f, function() G:Aim() end)
        f.big, f.value, f.note = d.big, d.value, d.note

        -- Left: the groups' names and their settings
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
                G.index, G.zone = self.index, "rail"
                menu.Render()
            end)
            f.rows[i] = r
        end

        -- Right: the selected setting's choices
        self.picker = K.Picker(f, PANEL_W, menu.Render, {
            bare = true, rowHeight = 38,
        })
        self.picker:SetPoint("TOPLEFT", f, "CENTER", K.COLS.picker, K.COLS.top)
        self.picker:SetHeight(400)

        -- Middles of their own (an item's panel), shown in the picker's place
        for _, item in ipairs(ITEMS) do
            if item.panel then
                item.panelFrame = item.panel.build(f)
                item.panelFrame:SetPoint("TOPLEFT", f, "CENTER", K.COLS.picker, K.COLS.top)
                item.panelFrame:Hide()
            end
        end

        self:SyncPicker(true)
    end

    function G:SyncPicker(force)
        local item = self:Item()
        if item.panel then return end
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
        if hooks.hide then hooks.hide() end
    end

    function G:Aim()
        if self:Item().panel then
            self.zone = "picker"
            return menu.Render()
        end
        if not self:Item().options then return end
        self.zone = "picker"
        self:SyncPicker()
        self.picker:LoadList()
        menu.Render()
    end

    ---------------------------------------------------------------------------
    -- Binding a Misc item to another button
    ---------------------------------------------------------------------------
    -- Square: a press recorded for the item (Recorder.lua: the first button
    -- let go ends it)
    function G:StartCapture()
        local item = self:Item()
        if not item.bindable or IC.InCombat() then return end
        local def = B.Get(item.bindId)
        IC.Recorder.Start({
            title = "Bind " .. item.label, chord = item.chord and true or false,
            accept = def and def.accepts, reject = item.label .. " can't go on that press",
            onDone = function(spec) G:Offer(item, spec) end,
            onCancel = function() menu.Toast(item.label .. ": unchanged") end,
        })
    end

    function G:StopCapture()
        IC.Recorder.Stop()
    end

    -- A recorded press for an item: bound, or (taking it from something
    -- else) once Cross confirms
    function G:Offer(item, spec)
        local def = B.Get(item.bindId)
        if item.toggle and B.Has(def, spec) then
            B.Assign(item.bindId, nil)
            return menu.Toast(item.label .. ": unbound")
        end
        local gone = B.Conflicts(item.bindId, spec)
        if #gone > 0 then
            self.pending = { item = item, spec = spec }
            menu.Arm("record:" .. item.bindId)
            return menu.Toast(IC.PadText(B.Text(spec) .. " runs " .. B.Names(gone)
                .. ": {A} replaces it, {B} keeps it"), true, 4)
        end
        self:Commit(item, spec)
    end

    function G:Commit(item, spec)
        local gone = B.Assign(item.bindId, spec)
        menu.Toast(item.label .. ": " .. (item.keyText and item.keyText() or B.Text(spec))
            .. (#gone > 0 and (" (" .. B.Names(gone) .. " unbound)") or ""), #gone > 0)
    end

    ---------------------------------------------------------------------------
    -- The pad
    ---------------------------------------------------------------------------
    function G:Press(name)
        -- A recorded press waiting for Cross (any other press let it go)
        local pending = self.pending
        self.pending = nil
        if pending and name == "A" and menu.IsArmed("record:" .. pending.item.bindId) then
            menu.Disarm()
            self:Commit(pending.item, pending.spec)
            menu.Render()
            return true
        end
        if name == "LB" or name == "RB" then return false end
        if name == "X" then
            if self:Item().bindable then self:StartCapture() end
            return true
        end
        if self.zone == "picker" and self:Item().panel then
            -- (left / right are the panel's: Circle goes back)
            local item = self:Item()
            if name == "B" then
                self.zone = "rail"
            elseif not item.panel.press(item.panelFrame, name) then
                return true
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
        local hints = {}
        local item = self:Item()
        if self.zone == "picker" and item.panel then
            for _, hint in ipairs(item.panel.hints()) do hints[#hints + 1] = hint end
        elseif self.zone == "picker" then
            hints[#hints + 1] = H({ "DPAD" }, "Move")
            hints[#hints + 1] = H({ "A" }, "Set", "A")
        else
            hints[#hints + 1] = H({ "DPAD" }, "Pick")
            if item.options or item.panel then hints[#hints + 1] = H({ "A" }, "Edit", "A") end
        end
        if self:Item().bindable then hints[#hints + 1] = H({ "X" }, "Record", "X") end
        hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
        hints[#hints + 1] = H({ "B" }, self.zone == "picker" and "Back" or "Close", "B")
        return hints
    end

    function G:Crumb()
        return title .. " › " .. self:Item().label
    end

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------
    function G:Render()
        local f = self.frame
        if not f then return end
        if self.zone ~= "picker" then self.zone = "rail" end
        self:SyncPicker()
        -- Only RAIL_ROWS lines at once, scrolled to keep the selected one in
        -- view, arrows past the ends when there are more
        local lines = Lines()
        local shown, yAt
        self.railTop, shown, yAt = K.RailWindow(lines, self.index, self.railTop, RAIL_ROWS, K.COLS.top)
        K.RingArrow(f.railUp, f, yAt(0.25), true, K.COLS.rail)
        f.railUp:SetShown(self.railTop > 1)
        K.RingArrow(f.railDown, f, yAt(shown + 0.75), false, K.COLS.rail)
        f.railDown:SetShown(self.railTop + shown - 1 < #lines)
        for i, r in ipairs(f.rows) do
            local line = lines[i]
            local slot = i - self.railTop + 1
            r:SetShown(line ~= nil and slot >= 1 and slot <= shown)
            if r:IsShown() then
                local y = yAt(slot)
                r.seg:Place(f, y, K.COLS.rail)
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
            end
        end
        -- The selected setting: its icon, its value, what it is bound to
        local item = self:Item()
        local off = item.value and item.value() == "off"
        f.big:SetLook({ icon = Resolve(item.icon), discColor = KC.iconBg, hatch = off, dash = true })
        f.big:SetAlpha(off and 0.45 or 1)
        local text = item.text and item.text() or ""
        if item.bindable then
            local key = item.binding()
            text = text .. "|n|cffd8ccb0" .. (IC.Recorder.IsActive() and "Press a button..."
                or ("Button: " .. (item.keyText and item.keyText(20) or B.Text(key, 20)))) .. "|r"
            local clashes = B.ClashesOf(item.bindId)
            if #clashes > 0 then
                text = text .. "|n|cffff7a5cClashes with " .. B.Names(clashes) .. " (General tab)|r"
            end
        end
        f.value:SetText(text)
        f.note:SetText(Resolve(item.note) or item.tip or "")
        self.picker:SetShown(item.options ~= nil and not item.panel)
        self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
        if item.options and not item.panel then self.picker:Render() end
        for _, other in ipairs(ITEMS) do
            if other.panelFrame then other.panelFrame:SetShown(other == item) end
        end
        if item.panel then
            item.panelFrame:SetAlpha(self.zone == "picker" and 1 or 0.5)
            item.panel.render(item.panelFrame, self.zone == "picker")
        end
        if hooks.render then hooks.render(self) end
    end

    for _, def in ipairs(menu.TABS) do
        if def.key == tabKey then
            def.page = function() return G end
        end
    end

    hooksecurefunc(menu, "Close", function()
        G:StopCapture()
        G.zone = "rail"
    end)
    return G
end

IC.SettingsItem, IC.SettingsOnOff = Item, OnOff
