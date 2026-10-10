-- The windows' look, as the auction window's (ImprovedForever_Auction's
-- AuctionBuy.lua) and the configuration panel's (Menu.lua) share it: the
-- game's flat panel with its title, pages picked with the game's side tabs
-- down its right (the right stick's glyph above them), a list down the left
-- in a dark panel, rows lit with the card stroke in the gamepad's focus
-- colour, the pad's buttons in a legend.
local _, IF = ...

local K = IF.ConfigKit
local KC = K.C

local UI = {}
IF.UI = UI

-- The focus colour the game's gamepad UI uses (Options > Controller)
function UI.FocusColor()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local value = tonumber(get and get("GamepadFocusStateColor") or 1) or 1
    if value == 2 then return 0, 0, 0 end
    if value == 3 then return 0.3, 0.5, 1 end
    return 1, 0.9, 0.4
end

-- A dark inset panel, the tooltip's thin border round it
function UI.Panel(parent, alpha)
    local f = K.NewFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.03, 0.02, 0.01, alpha or 0.5)
    f:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
    return f
end

-- A row's focus: the card stroke, in the focus colour
-- (a rounded ring, nine-sliced: its corners stay round at any width;
-- under the row's text and icon)
function UI.FocusStroke(parent)
    local slice = K.NineSlice(parent, "ic_select", 128, 32, 10, 10, "BORDER")
    local ring = {}
    function ring:SetShown(on) slice:SetShown(on and true or false) end
    function ring:Show() slice:SetShown(true) end
    function ring:Hide() slice:SetShown(false) end
    function ring:SetVertexColor(r, g, b)
        for _, part in ipairs(slice.parts) do part:SetVertexColor(r, g, b) end
    end
    function ring:SetAlpha(a)
        for _, part in ipairs(slice.parts) do part:SetAlpha(a) end
    end
    -- On, in the focus colour (dimmed: lit but not where the pad is)
    function ring:Light(on, dim)
        self:SetShown(on)
        if not on then return end
        local r, g, b = UI.FocusColor()
        self:SetVertexColor(r, g, b)
        self:SetAlpha(dim and 0.45 or 1)
    end
    ring:Hide()
    return ring
end

---------------------------------------------------------------------------
-- The window: the game's flat panel (a plain dialog box where the client
-- has no such template), its title at the top. opaque: a dark stone fill
-- behind it (the panel's own is see-through where nothing sits on it)
---------------------------------------------------------------------------
function UI.Window(name, width, height, opaque)
    local ok, win = pcall(K.NewFrame, "Frame", name, UIParent, "DefaultPanelFlatTemplate")
    if not ok then
        win = K.NewFrame("Frame", name, UIParent, "BackdropTemplate")
        win:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end
    win:SetSize(width, height)
    win:SetFrameStrata("DIALOG")
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    win:Hide()
    if opaque then
        local fill = win:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetPoint("TOPLEFT", 4, -4)
        fill:SetPoint("BOTTOMRIGHT", -4, 4)
        fill:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        fill:SetHorizTile(true)
        fill:SetVertTile(true)
        fill:SetVertexColor(0.32, 0.29, 0.26)
        local shade = win:CreateTexture(nil, "BACKGROUND", nil, -7)
        shade:SetAllPoints(fill)
        shade:SetColorTexture(0, 0, 0, 0.45)
    end
    win.titleText = win.TitleContainer and win.TitleContainer.TitleText
    if not win.titleText then
        win.titleText = K.Text(win, 13, KC.title)
        win.titleText:SetPoint("TOP", 0, -8)
    end
    function win:SetTitle(text) self.titleText:SetText(text) end
    return win
end

---------------------------------------------------------------------------
-- The pages' tabs down the window's right: the game's side tabs (as the
-- character window's), the right stick's glyph above them (tilted up /
-- down it moves through them). tabs:Render(list, selected): list = { {
-- key, label, icon } }; onSelect(key) as one is clicked.
---------------------------------------------------------------------------
function UI.SideTabs(win, onSelect)
    local tabs = { buttons = {} }
    local glyph = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    local function Button(i)
        if tabs.buttons[i] then return tabs.buttons[i] end
        local made, b = pcall(K.NewFrame, "Frame", nil, win, "LargeSideTabButtonTemplate")
        if not (made and b and b.Icon) then
            b = K.NewFrame("Frame", nil, win)
            b:SetSize(44, 54)
            b.Background = b:CreateTexture(nil, "BACKGROUND")
            b.Background:SetAllPoints()
            b.Background:SetColorTexture(0.1, 0.08, 0.05, 0.95)
            b.Icon = b:CreateTexture(nil, "ARTWORK")
            b.Icon:SetSize(36, 36)
            b.Icon:SetPoint("CENTER", -3, 0)
            b.SelectedTexture = b:CreateTexture(nil, "OVERLAY")
            b.SelectedTexture:SetAllPoints()
            b.SelectedTexture:SetColorTexture(1, 0.82, 0.3, 0.3)
        end
        b:EnableMouse(true)
        b:SetScript("OnMouseDown", function(self) onSelect(self.key) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.label)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tabs.buttons[i] = b
        return b
    end

    function tabs:Render(list, selected)
        local previous
        for i, t in ipairs(list) do
            local b = Button(i)
            b.key, b.label = t.key, t.label
            K.SetIcon(b.Icon, t.icon or 134400)
            b:ClearAllPoints()
            if previous then
                b:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
            else
                b:SetPoint("TOPLEFT", win, "TOPRIGHT", -2, -52)
            end
            if b.SelectedTexture then b.SelectedTexture:SetShown(t.key == selected) end
            b:Show()
            previous = b
        end
        for i = #list + 1, #self.buttons do self.buttons[i]:Hide() end
        glyph:ClearAllPoints()
        if self.buttons[1] then glyph:SetPoint("BOTTOM", self.buttons[1], "TOP", -3, 4) end
        glyph:SetText(#list > 1 and IF.GlyphText("RS", 26) or "")
    end

    -- The first tab button (a tooltip placed beside the window goes past them)
    function tabs:Last(count)
        return self.buttons[count or #self.buttons]
    end
    return tabs
end

---------------------------------------------------------------------------
-- A list down a page's left, in a dark panel: its title (the glyph that
-- moves it), its rows, the picked one lit. list:Render(title, entries,
-- selected, focused): entries = { { label } or { header = text } };
-- onClick(index) as a row is clicked.
---------------------------------------------------------------------------
function UI.SideList(parent, width, rowCount, onClick)
    local list = UI.Panel(parent, 0.4)
    list:SetWidth(width)
    list.title = K.ChatText(list, 12, KC.dimGold)
    list.title:SetPoint("TOP", 0, -10)
    list.rows = {}
    for i = 1, rowCount do
        local r = K.NewFrame("Button", nil, list)
        r:SetSize(width - 16, 28)
        r:SetPoint("TOPLEFT", 8, -30 - (i - 1) * 30)
        r.focus = UI.FocusStroke(r)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.text:SetPoint("LEFT", 10, 0)
        r.text:SetPoint("RIGHT", -6, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(self)
            if self.index then onClick(self.index) end
        end)
        list.rows[i] = r
    end

    function list:Render(title, entries, selected, focused)
        self.title:SetText(title or "")
        local n = #self.rows
        local top = math.max(1, math.min(selected - math.floor(n / 2), #entries - n + 1))
        for i, r in ipairs(self.rows) do
            local index = top + i - 1
            local e = entries[index]
            r:SetShown(e ~= nil)
            if e then
                r.index = not e.header and index or nil
                if e.header then
                    r.text:SetText(e.header:upper())
                    r.text:SetTextColor(unpack(KC.dimGold))
                    r.focus:Hide()
                else
                    local on = index == selected
                    r.text:SetText(e.label)
                    r.text:SetTextColor(on and 1 or 0.8, on and 0.95 or 0.74, on and 0.8 or 0.6)
                    r.focus:Light(on, not focused)
                end
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- The legend: a line of the pad's buttons and what they do, in a dark band
-- under the window. legend:SetText(text) (glyphs in the text: IF.PadText)
---------------------------------------------------------------------------
function UI.Legend(win)
    local legend = K.NewFrame("Frame", nil, win, "BackdropTemplate")
    legend:SetPoint("TOP", win, "BOTTOM", 0, -6)
    legend:SetHeight(36)
    legend:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    legend:SetBackdropColor(0.05, 0.04, 0.03, 0.92)
    legend:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
    legend.text = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    legend.text:SetPoint("CENTER")
    function legend:SetText(text)
        self.text:SetText(text)
        self:SetWidth(math.max(500, self.text:GetStringWidth() + 28))
    end
    return legend
end
