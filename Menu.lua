-- A controller-driven settings window, built like Controller Forever's
-- menu: D-pad up / down moves, left / right changes a value, Cross chooses,
-- Circle goes back (or closes), L1 / R1 jump a page in long lists. Its keys
-- live on a secure header that drops them and hides the window the moment
-- combat starts. Open it with /ic, the key binding, or the AddOns options.
local _, IC = ...

local menu = {}
IC.Menu = menu

local state = { page = "main", selected = 1, offset = 0, open = false }

local THEME = {
    bg = { 0.045, 0.05, 0.065, 0.94 },
    edge = { 0.95, 0.74, 0.28, 0.85 },
    title = { 1, 1, 1 },
    accent = { 1, 0.78, 0.3 },
    text = { 0.9, 0.9, 0.9 },
    muted = { 0.6, 0.64, 0.72 },
    font = "Fonts\\FRIZQT__.TTF",
}
local VALUE_ON, VALUE_OFF, VALUE_OTHER = { 0.36, 0.9, 0.42 }, { 0.9, 0.38, 0.35 }, { 1, 0.82, 0.35 }
local ROW_HEIGHT, TOP_PAD, BOTTOM_PAD = 26, 40, 92
local MAX_VISIBLE_ROWS = 16
local MENU_WIDTH = 470
local MAX_BUFFS = 24
local ICON = "Interface\\Icons\\"

local function Cross() return IC.Glyph("Gamepad-PS-Cross-Normal", "|cff7fb2ffX|r", 16) end
local function Circle() return IC.Glyph("Gamepad-PS-Circle-Normal", "|cffff6060O|r", 16) end
local function Dpad() return IC.Glyph("Gamepad-PS-DpadAll-Normal", "|cffc9a84cD-pad|r", 16) end

local function OnOff(value)
    return value and "On" or "Off"
end

---------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------

-- A section title the selection skips.
local function header(text)
    return { header = true, name = text }
end

-- An option row. name / value / desc / icon may be strings or functions.
--   activate()       Cross
--   adjust(delta)    D-pad left / right
--   page = "name"    Cross opens that page
--   keep             stay open after activate (default: close)
local function opt(spec)
    local function get(field)
        local value = spec[field]
        if type(value) == "function" then
            local ok, result = pcall(value)
            return ok and result or nil
        end
        return value
    end
    spec.getName = function() return get("name") or "" end
    spec.getValue = function() return get("value") end
    spec.getDesc = function() return get("desc") end
    spec.getIcon = function() return get("icon") end
    return spec
end

local backEntry = opt({ back = true, name = "Back", desc = "Back to the main page." })

local function NextRing(current, step)
    for index, ring in ipairs(IC.RINGS) do
        if ring == current then
            return IC.RINGS[(index - 1 + step) % #IC.RINGS + 1]
        end
    end
    return IC.RINGS[1]
end

local function ComboEntry(combo)
    local function change(step)
        IC.SetComboRing(combo, NextRing(IC.GetComboRing(combo), step))
    end
    return opt({
        name = IC.COMBO_LABELS[combo],
        value = function() return IC.RING_LABELS[IC.GetComboRing(combo)] end,
        desc = "Which ring " .. IC.COMBO_LABELS[combo] .. " opens. Native leaves the game's own R3 action"
            .. " (Look Here) for this combo.",
        adjust = change,
        activate = function() change(1) end,
        keep = true,
    })
end

local function BuffCount()
    return #IC.GetBuffList()
end

local function CopyBuffList()
    local list = {}
    for _, name in ipairs(IC.GetBuffList()) do
        list[#list + 1] = name
    end
    return list
end

local function IndexOf(list, name)
    for index, value in ipairs(list) do
        if value == name then
            return index
        end
    end
end

local function SetBuffList(list)
    IC.charDB.buffs = list
    IC.RefreshRings()
end

local function ToggleBuff(name)
    local list = CopyBuffList()
    local index = IndexOf(list, name)
    if index then
        table.remove(list, index)
    elseif #list >= MAX_BUFFS then
        IC.Print("the Buffs ring holds " .. MAX_BUFFS .. " spells at most.")
        return
    else
        list[#list + 1] = name
    end
    SetBuffList(list)
end

local function MoveBuff(name, delta)
    local list = CopyBuffList()
    local index = IndexOf(list, name)
    local target = index and index + delta
    if not target or target < 1 or target > #list then
        return
    end
    list[index], list[target] = list[target], list[index]
    SetBuffList(list)
end

local function BuffEntry(spell)
    return opt({
        name = function()
            return spell.inBook and spell.name or ("|cff8a93a6" .. spell.name .. " (not in spellbook)|r")
        end,
        icon = spell.icon or (ICON .. "INV_Misc_QuestionMark"),
        value = function()
            local index = IndexOf(IC.GetBuffList(), spell.name)
            return index and ("Slot " .. index) or nil
        end,
        desc = function()
            if IndexOf(IC.GetBuffList(), spell.name) then
                return "On the Buffs ring. Cross removes it; D-pad left / right moves it a slot earlier / later."
            end
            return "Cross puts " .. spell.name .. " on the Buffs ring (next free slot, clockwise from the top)."
        end,
        activate = function() ToggleBuff(spell.name) end,
        adjust = function(delta) MoveBuff(spell.name, delta) end,
        keep = true,
    })
end

menu.pages = {
    main = {
        title = "Improved Controller",
        entries = {
            header("Bags"),
            opt({
                name = "L3 Cleans Up Bags", icon = ICON .. "INV_Misc_Bag_08",
                value = function() return OnOff(IC.db.bagSort ~= false) end,
                desc = "On: while any bag is open, L3 (left stick click) sorts your bags.",
                activate = function()
                    IC.db.bagSort = IC.db.bagSort == false
                    IC.UpdateBagBinding()
                end,
                keep = true,
            }),
            header("R3 Rings"),
            ComboEntry("R3"),
            ComboEntry("L1"),
            ComboEntry("L2"),
            ComboEntry("R1"),
            ComboEntry("R2"),
            opt({
                page = "buffs", name = "Buffs Ring", icon = ICON .. "Spell_Holy_WordFortitude",
                value = function() return BuffCount() .. " spells" end,
                desc = "Choose which spells go on the Buffs ring, and in what order (this character).",
            }),
            header("Touchpad"),
            opt({
                page = "touch", name = "Touchpad Click", icon = ICON .. "INV_Misc_Map_01",
                value = function() return OnOff(IC.Touch.GetSettings().enabled ~= false) end,
                desc = "Click the PS5 touchpad to open a window; where your finger is picks which (map, quest log, bags...).",
            }),
            opt({ name = "Close", desc = "Close this menu.", activate = function() end }),
        },
    },
    touch = {
        title = "Touchpad Click",
        build = function()
            local touch = IC.Touch
            local settings = touch.GetSettings()
            local entries = {
                opt({
                    name = "Touchpad Click",
                    value = function() return OnOff(settings.enabled ~= false) end,
                    desc = "On: clicking the PS5 touchpad opens a window, picked by where your finger is on the"
                        .. " pad (top, bottom, left, right, centre). Works in combat.",
                    activate = function()
                        settings.enabled = settings.enabled == false
                        touch.Apply()
                    end,
                    keep = true,
                }),
                opt({
                    name = "Centre Size",
                    value = function() return math.floor(settings.centre * 100 + 0.5) .. "%" end,
                    desc = "How big the centre region is. Clicks outside it count as top / bottom / left / right,"
                        .. " whichever side the finger is nearest.",
                    adjust = function(delta) touch.SetCentre(settings.centre + delta * 0.05) end,
                    keep = true,
                }),
                header("Regions"),
            }
            for _, region in ipairs(touch.REGIONS) do
                entries[#entries + 1] = opt({
                    name = touch.REGION_LABELS[region],
                    value = function() return touch.ActionLabel(settings.regions[region]) end,
                    desc = "What a click with the finger at the " .. touch.REGION_LABELS[region]:lower()
                        .. " opens. Only windows this client has a button for are offered.",
                    adjust = function(delta) touch.CycleAction(region, delta) end,
                    activate = function() touch.CycleAction(region, 1) end,
                    keep = true,
                })
            end
            entries[#entries + 1] = header("Troubleshooting")
            entries[#entries + 1] = opt({
                name = "Debug",
                value = function() return OnOff(settings.debug) end,
                desc = "On: each touchpad click prints its region and what it opened to chat.",
                activate = function() settings.debug = not settings.debug end,
                keep = true,
            })
            entries[#entries + 1] = backEntry
            return entries
        end,
    },
    buffs = {
        title = "Buffs Ring",
        -- Rebuilt each time the page opens: the spellbook changes.
        build = function()
            local entries = {
                opt({
                    name = "Class Defaults", icon = ICON .. "INV_Misc_Book_09",
                    value = function() return IC.charDB.buffs == nil and "In use" or nil end,
                    desc = "Go back to your class's usual buffs.",
                    activate = function() SetBuffList(nil) end,
                    keep = true,
                }),
                opt({
                    name = "Clear All", icon = ICON .. "Spell_Shadow_SacrificialShield",
                    desc = "Empty the Buffs ring.",
                    activate = function() SetBuffList({}) end,
                    keep = true,
                }),
                header("Spellbook"),
            }
            local spells = IC.GetSpellbookSpells()
            local inBook = {}
            for _, spell in ipairs(spells) do
                spell.inBook = true
                inBook[spell.name] = true
            end
            -- Picked spells that left the spellbook still show, so they can go.
            for _, name in ipairs(IC.GetBuffList()) do
                if not inBook[name] then
                    table.insert(spells, 1, { name = name })
                end
            end
            for _, spell in ipairs(spells) do
                entries[#entries + 1] = BuffEntry(spell)
            end
            entries[#entries + 1] = backEntry
            return entries
        end,
    },
}

---------------------------------------------------------------------------
-- Selection
---------------------------------------------------------------------------

local function Entries()
    return state.entries or {}
end

local function IsSelectable(entry)
    return entry and not entry.header
end

local function NextSelectable(index, step)
    local entries = Entries()
    local count = #entries
    for _ = 1, count do
        index = (index - 1) % count + 1
        if IsSelectable(entries[index]) then
            return index
        end
        index = index + step
    end
    return 1
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local NAV = {
    { key = "PADDUP", action = "Up" },
    { key = "PADDDOWN", action = "Down" },
    { key = "PADDLEFT", action = "Left" },
    { key = "PADDRIGHT", action = "Right" },
    { key = "PAD1", action = "Activate" },
    { key = "PAD2", action = "Close" },
    { key = "PADLSHOULDER", action = "PageUp" },
    { key = "PADRSHOULDER", action = "PageDown" },
}

local headerFrame, frame
local rows = {}

local function ThemeWindow(window, title)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    window:SetBackdropColor(unpack(THEME.bg))
    window:SetBackdropBorderColor(unpack(THEME.edge))
    local shade = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetPoint("TOPLEFT", 1, -1)
    shade:SetPoint("BOTTOMRIGHT", -1, 1)
    shade:SetColorTexture(1, 1, 1, 1)
    if shade.SetGradient and CreateColor then
        pcall(shade.SetGradient, shade, "VERTICAL", CreateColor(0, 0, 0, 0.35), CreateColor(0.12, 0.14, 0.2, 0.25))
    else
        shade:SetColorTexture(0, 0, 0, 0)
    end
    local band = window:CreateTexture(nil, "BORDER")
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(26)
    band:SetColorTexture(1, 1, 1, 1)
    if band.SetGradient and CreateColor then
        pcall(band.SetGradient, band, "VERTICAL", CreateColor(0.08, 0.085, 0.11, 1), CreateColor(0.17, 0.16, 0.14, 1))
    else
        band:SetColorTexture(0.11, 0.12, 0.16, 1)
    end
    local line = window:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.7)
    title:SetFont(THEME.font, 14, "")
    title:SetTextColor(unpack(THEME.title))
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    title:SetPoint("TOP", window, "TOP", 0, -7)
end

local function Refresh()
    if not frame then
        return
    end
    local entries = Entries()
    local count = #entries
    local visible = math.min(count, MAX_VISIBLE_ROWS)
    -- Keep the selection in view.
    if state.selected <= state.offset then
        state.offset = state.selected - 1
    elseif state.selected > state.offset + visible then
        state.offset = state.selected - visible
    end
    state.offset = math.max(0, math.min(state.offset, count - visible))
    frame:SetHeight(TOP_PAD + visible * ROW_HEIGHT + BOTTOM_PAD)

    local page = menu.pages[state.page]
    frame.title:SetText(state.page == "main" and page.title
        or ("Improved Controller  |cff8a93a6>|r  |cffffc84d" .. page.title .. "|r"))
    local selectedEntry = entries[state.selected]
    local hints = { Cross() .. " choose", Circle() .. (state.page == "main" and " close" or " back"), Dpad() .. " move" }
    if selectedEntry and selectedEntry.adjust then
        hints[#hints + 1] = "|cffc9a84c<  >|r change"
    end
    if count > visible then
        hints[#hints + 1] = "|cffc9a84cL1 / R1|r page"
    end
    frame.hint:SetText(table.concat(hints, "     "))
    frame.desc:SetText(selectedEntry and selectedEntry.getDesc and selectedEntry.getDesc() or "")
    frame.scroll:SetText(count > visible
        and string.format("%d-%d of %d", state.offset + 1, state.offset + visible, count) or "")

    for index, row in ipairs(rows) do
        local entryIndex = index + state.offset
        local entry = index <= visible and entries[entryIndex]
        row.entryIndex = entryIndex
        if not entry then
            row:Hide()
        else
            row:Show()
            local selected = entryIndex == state.selected
            row.highlight:SetShown(selected)
            row.bar:SetShown(selected)
            row.value:SetText("")
            row.pill:Hide()
            row.icon:Hide()
            row.text:ClearAllPoints()
            if entry.header then
                row.rule:Show()
                row.text:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 5)
                row.text:SetFont(THEME.font, 11, "")
                row.text:SetText(string.upper(entry.name))
                row.text:SetTextColor(unpack(THEME.accent))
            else
                row.rule:Hide()
                local icon = entry.getIcon()
                if icon then
                    row.icon:SetTexture(icon)
                    row.icon:Show()
                end
                row.text:SetPoint("LEFT", row, "LEFT", 32, 0)
                row.text:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
                row.text:SetFont(THEME.font, entry.icon and 14 or 13, "")
                row.text:SetText(entry.getName())
                if selected then
                    row.text:SetTextColor(unpack(THEME.title))
                else
                    row.text:SetTextColor(THEME.text[1] * 0.85, THEME.text[2] * 0.85, THEME.text[3] * 0.85)
                end
                local value = entry.getValue()
                if entry.page then
                    row.value:SetText((value and (tostring(value) .. "  ") or "") .. "|cff8a93a6>|r")
                    row.value:SetTextColor(unpack(VALUE_OTHER))
                elseif value then
                    local text = tostring(value)
                    local color = text == "On" and VALUE_ON or text == "Off" and VALUE_OFF or VALUE_OTHER
                    if (text == "On" or text == "Off") and not entry.adjust then
                        row.pill:SetVertexColor(color[1], color[2], color[3], 0.22)
                        row.pill:Show()
                    end
                    if entry.adjust then
                        text = "|cff8a7a50<|r  " .. text .. "  |cff8a7a50>|r"
                    end
                    row.value:SetText(text)
                    row.value:SetTextColor(unpack(color))
                end
            end
        end
    end
end

function menu.SetPage(name, select)
    local page = menu.pages[name]
    if not page then
        return
    end
    state.page = name
    state.entries = page.build and page.build() or page.entries
    state.offset = 0
    state.selected = NextSelectable(select or 1, 1)
    Refresh()
end

function menu.Navigate(action)
    if not state.open then
        return
    end
    local entries = Entries()
    if action == "Up" then
        state.selected = NextSelectable(state.selected - 1, -1)
    elseif action == "Down" then
        state.selected = NextSelectable(state.selected + 1, 1)
    elseif action == "PageUp" or action == "PageDown" then
        local step = action == "PageUp" and -1 or 1
        local target = math.max(1, math.min(#entries, state.selected + step * MAX_VISIBLE_ROWS))
        state.selected = NextSelectable(target, step)
    elseif action == "Left" or action == "Right" then
        local entry = entries[state.selected]
        if entry and entry.adjust then
            entry.adjust(action == "Left" and -1 or 1)
        end
    elseif action == "Activate" then
        menu.Activate()
        return
    elseif action == "Close" then
        if state.page ~= "main" then
            menu.Back()
        else
            menu.Close()
        end
        return
    end
    Refresh()
end

function menu.Back()
    local returnTo = state.returnIndex
    state.returnIndex = nil
    menu.SetPage("main", returnTo)
end

function menu.Activate()
    local entry = Entries()[state.selected]
    if not IsSelectable(entry) then
        return
    end
    if entry.page then
        state.returnIndex = state.selected
        menu.SetPage(entry.page)
        return
    end
    if entry.back then
        menu.Back()
        return
    end
    if entry.activate then
        entry.activate()
    end
    if entry.keep then
        Refresh()
    else
        menu.Close()
    end
end

local function CreateMenuFrame()
    -- The header owns the keys and clears them itself when combat starts.
    headerFrame = CreateFrame("Frame", "ImprovedControllerMenuHeader", UIParent, "SecureHandlerStateTemplate")
    headerFrame:SetAllPoints(UIParent)
    headerFrame:SetFrameStrata("DIALOG")
    headerFrame:EnableMouse(false)
    headerFrame:Hide()
    headerFrame:SetAttribute("_onstate-combat", [[
        if newstate == "1" and self:IsShown() then
            self:ClearBindings()
            self:Hide()
        end
    ]])
    RegisterStateDriver(headerFrame, "combat", "[combat] 1; 0")

    frame = CreateFrame("Frame", "ImprovedControllerMenu", headerFrame, "BackdropTemplate")
    frame:SetSize(MENU_WIDTH, TOP_PAD + MAX_VISIBLE_ROWS * ROW_HEIGHT + BOTTOM_PAD)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -140)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        menu.Navigate(delta > 0 and "Up" or "Down")
    end)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ThemeWindow(frame, frame.title)
    frame.scroll = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.scroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)

    for index = 1, MAX_VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(MENU_WIDTH - 24, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -TOP_PAD - (index - 1) * ROW_HEIGHT)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints(row)
        row.highlight:SetColorTexture(1, 1, 1, 1)
        if row.highlight.SetGradient and CreateColor then
            pcall(row.highlight.SetGradient, row.highlight, "HORIZONTAL",
                CreateColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.28),
                CreateColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.03))
        else
            row.highlight:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.14)
        end
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
        row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", -4, 0)
        row.bar:SetWidth(3)
        row.bar:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
        row.rule = row:CreateTexture(nil, "ARTWORK")
        row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 1)
        row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 1)
        row.rule:SetHeight(1)
        row.rule:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.25)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.pill = row:CreateTexture(nil, "ARTWORK")
        row.pill:SetSize(44, 18)
        row.pill:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.pill:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.value:SetJustifyH("RIGHT")
        row.value:SetFont(THEME.font, 13, "")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:SetScript("OnEnter", function(self)
            if IsSelectable(Entries()[self.entryIndex]) then
                state.selected = self.entryIndex
                Refresh()
            end
        end)
        row:SetScript("OnClick", function(self)
            if IsSelectable(Entries()[self.entryIndex]) then
                state.selected = self.entryIndex
                menu.Activate()
            end
        end)
        rows[index] = row
    end

    -- What the selected option does, under the list.
    local descPanel = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    descPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 34)
    descPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 34)
    descPanel:SetHeight(50)
    descPanel:SetColorTexture(0, 0, 0, 0.35)
    local descLine = frame:CreateTexture(nil, "ARTWORK")
    descLine:SetPoint("BOTTOMLEFT", descPanel, "TOPLEFT", 0, 0)
    descLine:SetPoint("BOTTOMRIGHT", descPanel, "TOPRIGHT", 0, 0)
    descLine:SetHeight(1)
    descLine:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.35)
    frame.desc = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.desc:SetPoint("TOPLEFT", descPanel, "TOPLEFT", 10, -7)
    frame.desc:SetPoint("BOTTOMRIGHT", descPanel, "BOTTOMRIGHT", -10, 5)
    frame.desc:SetJustifyH("LEFT")
    frame.desc:SetJustifyV("TOP")
    frame.desc:SetFont(THEME.font, 12, "")
    frame.desc:SetTextColor(0.82, 0.82, 0.78)
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    frame.hint:SetFont(THEME.font, 11, "")
    frame.hint:SetTextColor(unpack(THEME.muted))

    -- Covers the combat state driver hiding the header too.
    frame:SetScript("OnHide", function()
        state.open = false
        if not IC.InCombat() then
            ClearOverrideBindings(headerFrame)
        end
    end)

    -- Hidden buttons the navigation keys click.
    for _, nav in ipairs(NAV) do
        local button = CreateFrame("Button", "ImprovedControllerMenuNav" .. nav.action, headerFrame)
        button:SetSize(1, 1)
        button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
        button:RegisterForClicks("AnyDown")
        button:SetScript("OnClick", function() menu.Navigate(nav.action) end)
        nav.button = button
    end
end

function menu.Open()
    if IC.InCombat() then
        IC.Print("the menu opens after combat.")
        return
    end
    if not frame then
        CreateMenuFrame()
    end
    state.open = true
    ClearOverrideBindings(headerFrame)
    for _, nav in ipairs(NAV) do
        SetOverrideBindingClick(headerFrame, true, nav.key, nav.button:GetName(), "LeftButton")
    end
    headerFrame:Show()
    frame:Show()
    menu.SetPage("main")
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end

function menu.Close()
    if frame and frame:IsShown() then
        frame:Hide()
    end
    if headerFrame and headerFrame:IsShown() and not IC.InCombat() then
        headerFrame:Hide()
    end
    state.open = false
    PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
end

function menu.Toggle()
    if state.open then
        menu.Close()
    else
        menu.Open()
    end
end

-- Target of the "Toggle Improved Controller menu" key binding.
local toggle = CreateFrame("Button", "ImprovedControllerMenuToggle", UIParent)
toggle:SetScript("OnClick", menu.Toggle)
BINDING_HEADER_IMPROVEDCONTROLLER = "Improved Controller"
_G["BINDING_NAME_CLICK ImprovedControllerMenuToggle:LeftButton"] = "Toggle Improved Controller menu"

-- Bag / spell changes while the buffs page is up.
local events = CreateFrame("Frame")
events:RegisterEvent("SPELLS_CHANGED")
events:SetScript("OnEvent", function()
    if state.open and state.page == "buffs" then
        local selected = state.selected
        menu.SetPage("buffs", selected)
    end
end)
