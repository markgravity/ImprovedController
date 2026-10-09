-- The auction house window: over the game's own as it opens (where it
-- is; the game's window hidden behind it), used with the pad. Its pages
-- are tabs down its right, as the character window's (the right stick
-- up / down):
-- Buy (this file), Sell (AuctionSellTab.lua), Auctions (AuctionOwned.lua).
-- Buy: three levels of category (the game's own, AuctionCategories): the
-- main ones down the left (the left stick up / down), the second along
-- the top (L1 / R1), the third under it (L2 / R2), "All" first in each.
-- Under them what is listed, as a list or a grid (the D-pad moves), each
-- with its lowest price and how it compares to its usual one
-- (Auction.lua); the picked one's tooltip beside the window, with the
-- versions listed under it (gear with random stats: each one's stats and
-- lowest price). L3 opens the filters (usable only, up to my level,
-- lowest quality, upgrades: marked with the game's green arrow or only
-- them, Upgrades.lua; list or grid; sort). Cross opens an item: its price
-- chart (AuctionChart.lua), and for goods sold by the unit (commodities) a
-- quantity and its cost, for the rest its auctions one by one; Cross buys,
-- asking first in a popup (AuctionConfirm.lua). Circle goes back, and from a page's top closes the
-- auction house. R3 (a click) shows / hides the tooltips (with what is
-- worn in the item's place beside them).
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local A = IC.Auction
local AH = C_AuctionHouse

local BY = {}
IC.AuctionBuy = BY

local W, H = 920, 600
local SIDE_W = 190
local MAIN_X = SIDE_W + 28            -- the main area's left
local MAIN_W = W - MAIN_X - 16
local CONTENT_TOP = -116
local CONTENT_H = H - 116 - 36
local LIST_H = 50                  -- a row: its name, a line of badges under it, inside the ring
local LIST_ROWS = math.floor(CONTENT_H / LIST_H)
local NAME_ROOM = MAIN_W - 50 - 200     -- a list row's name (the price on the right)
local CELL_W, CELL_H = 114, 148     -- room for two badges side by side, a name on three lines
local GRID_COLS = math.floor(MAIN_W / CELL_W)
local GRID_ROWS = math.floor(CONTENT_H / CELL_H)
local SIDE_ROWS = 16
local STICK_ON, STICK_OFF = 0.6, 0.3
local REPEAT_DELAY, REPEAT_EVERY, FAST_AFTER = 0.35, 0.1, 1.5
local QUERY_DELAY = 0.3               -- categories moved through quickly: one query at the end

local QUALITY_FILTERS = {             -- Enum.AuctionHouseFilter, from poor up
    [0] = 6, [1] = 7, [2] = 8, [3] = 9, [4] = 10, [5] = 11,
}
local QUALITY_NAMES = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic",
    [5] = "Legendary" }

-- A quality's name in its colour
local function QualityName(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, QUALITY_NAMES[q]) or QUALITY_NAMES[q]
end

local function Atlas(tex, name)
    if IC.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local function Glyph(key, size)
    return IC.GlyphText(key, size or 22)
end

local function FocusColor()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local value = tonumber(get and get("GamepadFocusStateColor") or 1) or 1
    if value == 2 then return 0, 0, 0 end
    if value == 3 then return 0.3, 0.5, 1 end
    return 1, 0.9, 0.4
end

local function S()
    return A.Settings()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local ok, win = pcall(K.NewFrame, "Frame", "ImprovedControllerAuctionBuy", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    win = K.NewFrame("Frame", "ImprovedControllerAuctionBuy", UIParent, "BackdropTemplate")
    win:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
win:SetSize(W, H)
win:SetFrameStrata("DIALOG")
win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
win:EnableMouse(true)
win:SetClampedToScreen(true)
win:Hide()
BY.window = win

local titleText = win.TitleContainer and win.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(win, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

-- The pages, one at a time, picked with the tabs down the window's right
-- (the right stick up / down): Buy (this file's), Sell (AuctionSellTab.lua), Auctions
-- (AuctionOwned.lua). A page of another file: BY.AddPage(page), page = {
-- key, label, icon, Build(parent) -> frame, Show(), Hide(), Render(),
-- Press(name, fast) -> handled (Circle unhandled: the auction house
-- closes), Hints() -> the legend's text }.
local buyPage = K.NewFrame("Frame", nil, win)
buyPage:SetAllPoints(win)
BY.tab = "buy"
BY.TABS = { { key = "buy", label = "Buy", icon = "Interface\\Icons\\INV_Misc_Bag_10" } }

function BY.AddPage(page)
    BY.TABS[#BY.TABS + 1] = page
end

local function Panel(parent, alpha)
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
local function FocusStroke(parent)
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
    ring:Hide()
    return ring
end

-- A badge: a small rounded pill with a short text (a price against its
-- usual one, an upgrade's gain). badge:Set(text, color) (nil: hidden)
local BADGE_COLORS = {
    good = { 0.16, 0.48, 0.18 }, bad = { 0.58, 0.16, 0.1 }, plain = { 0.3, 0.26, 0.19 },
    upgrade = { 0.13, 0.33, 0.58 }, later = { 0.36, 0.22, 0.52 },
}
local function Badge(parent, size)
    local b = K.NewFrame("Frame", nil, parent)
    b:SetHeight((size or 11) + 6)
    b.box = K.Box(b, 4, nil, "ARTWORK")
    b.box:SetPoints(b)
    b.text = K.ChatText(b, size or 11, KC.white, "OVERLAY")
    b.text:SetPoint("CENTER", 0, 0)
    function b:Set(text, color)
        self:SetShown(text ~= nil)
        if not text then return end
        self.text:SetText(text)
        self.box:SetColors(BADGE_COLORS[color] or BADGE_COLORS.plain, 0.95)
        self:SetWidth(self.text:GetStringWidth() + 12)
    end
    b:Hide()
    return b
end

-- The badges' icons (tools/make_badge_icons.py): white, on the pill's colour
local BADGE_PRICE = "|T" .. K.TEX .. "ic_badge_price:0:0:0:0|t "
local BADGE_UP = "|T" .. K.TEX .. "ic_badge_up:0:0:0:0|t "

-- Its price against its usual one, as a badge: the tag and "-23%" (good),
-- "+38%" (dear), "+2%" (about usual); nil: no usual price known
local function DealBadge(itemID, price)
    local usual = A.MarketPrice(itemID)
    if not usual or usual <= 0 or not price or price <= 0 then return nil end
    local pct = math.floor((price / usual - 1) * 100 + 0.5)
    local text = BADGE_PRICE .. (pct > 0 and "+" or "") .. pct .. "%"
    if pct <= -5 then return text, "good" end
    if pct >= 5 then return text, "bad" end
    return text, "plain"
end

-- An upgrade's gain as a badge: the arrow and "+12%" (nothing worn: "New");
-- one of a higher level in purple
local function GainBadge(isUpgrade, gain, needLevel)
    if not isUpgrade then return nil end
    local text = BADGE_UP .. (gain and ("+" .. math.max(1, math.floor(gain + 0.5)) .. "%") or "New")
    return text, needLevel and "later" or "upgrade"
end

---------------------------------------------------------------------------
-- The main categories, down the left
---------------------------------------------------------------------------
local side = Panel(buyPage, 0.4)
side:SetPoint("TOPLEFT", 14, -30)
side:SetPoint("BOTTOMLEFT", 14, 36)
side:SetWidth(SIDE_W)
local sideTitle = K.ChatText(side, 12, KC.dimGold)
sideTitle:SetPoint("TOP", 0, -10)
local sideRows = {}
for i = 1, SIDE_ROWS do
    local r = K.NewFrame("Button", nil, side)
    r:SetSize(SIDE_W - 16, 28)
    r:SetPoint("TOPLEFT", 8, -30 - (i - 1) * 30)
    r.focus = FocusStroke(r)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.text:SetPoint("LEFT", 10, 0)
    r.text:SetPoint("RIGHT", -6, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.index then BY.SetMain(self.index) end
    end)
    sideRows[i] = r
end

---------------------------------------------------------------------------
-- The second and third levels, along the top: a bar each, its bumper /
-- trigger glyphs at the ends, the chosen one lit and kept in view
---------------------------------------------------------------------------
local function TopBar(y, leftKey, rightKey)
    local bar = Panel(buyPage, 0.4)
    bar:SetPoint("TOPLEFT", MAIN_X, y)
    bar:SetSize(MAIN_W, 34)
    bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.left:SetPoint("LEFT", 8, 0)
    bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.right:SetPoint("RIGHT", -8, 0)
    bar.keys = { leftKey, rightKey }
    bar.clip = K.NewFrame("Frame", nil, bar)
    bar.clip:SetPoint("TOPLEFT", 44, 0)
    bar.clip:SetPoint("BOTTOMRIGHT", -44, 0)
    bar.clip:SetClipsChildren(true)
    bar.chips = {}
    return bar
end

local bar2 = TopBar(-30, "LB", "RB")
local bar3 = TopBar(-68, "LT", "RT")

local function Chip(bar, i)
    local c = bar.chips[i]
    if c then return c end
    c = K.NewFrame("Button", nil, bar.clip)
    c:SetHeight(26)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.text:SetPoint("CENTER")
    c:SetScript("OnClick", function(self)
        if bar == bar2 then BY.SetSub(self.index) else BY.SetSubSub(self.index) end
    end)
    bar.chips[i] = c
    return c
end

-- names: the chips' names; selected: which (1-based); off: a bar with nothing to pick
local function LayoutBar(bar, names, selected)
    local enabled = #names > 1
    bar.left:SetText(Glyph(bar.keys[1]))
    bar.right:SetText(Glyph(bar.keys[2]))
    bar.left:SetAlpha(enabled and 1 or 0.3)
    bar.right:SetAlpha(enabled and 1 or 0.3)
    local widths, total = {}, 0
    for i, name in ipairs(names) do
        local c = Chip(bar, i)
        c.text:SetText(name)
        widths[i] = c.text:GetStringWidth() + 24
        total = total + widths[i] + 6
    end
    for i = #names + 1, #bar.chips do bar.chips[i]:Hide() end
    -- Scrolled to keep the chosen chip in the middle when they don't all fit
    local clipW = bar.clip:GetWidth()
    if not clipW or clipW <= 0 then clipW = MAIN_W - 88 end
    local x, at = 0, 0
    for i = 1, #names do
        if i == selected then at = x + widths[i] / 2 end
        x = x + widths[i] + 6
    end
    local shift = 0
    if total > clipW then shift = math.max(0, math.min(total - clipW, at - clipW / 2)) end
    x = -shift
    local fr, fg, fb = FocusColor()
    for i = 1, #names do
        local c = bar.chips[i]
        c.index = i
        c:ClearAllPoints()
        c:SetPoint("LEFT", bar.clip, "LEFT", x, 0)
        c:SetWidth(widths[i])
        c:Show()
        local on = i == selected
        if on then
            c.bg:SetColorTexture(fr * 0.45, fg * 0.38, fb * 0.2, 0.9)
            c.text:SetTextColor(1, 0.95, 0.8)
        else
            c.bg:SetColorTexture(0, 0, 0, 0.35)
            c.text:SetTextColor(0.8, 0.74, 0.6)
        end
        x = x + widths[i] + 6
    end
end

---------------------------------------------------------------------------
-- The status line, the content (list or grid), the legend
---------------------------------------------------------------------------
local status = K.ChatText(buyPage, 11, KC.help)
status:SetPoint("TOPLEFT", MAIN_X + 4, -106 + 6)
status:SetPoint("RIGHT", win, "RIGHT", -20, 0)
status:SetJustifyH("LEFT")

local content = K.NewFrame("Frame", nil, buyPage)
content:SetPoint("TOPLEFT", MAIN_X, CONTENT_TOP)
content:SetSize(MAIN_W, CONTENT_H)

local emptyText = K.ChatText(content, 13, KC.grey)
emptyText:SetPoint("CENTER")

local function ItemIcon(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = parent:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", t, -1, 1)
    border:SetPoint("BOTTOMRIGHT", t, 1, -1)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    t.border = border
    return t
end

-- A row of items (the browse list's, an item's auctions): the icon (the
-- upgrade arrow on it), the name, a second line (how many, item level) with
-- the badges after it, the price on the right. row:Fill({ icon, quality,
-- name, line, price, upgrade, gain = { text, color }, deal = { text, color } })
local function ItemRow(parent, width, height, nameW)
    local r = K.NewFrame("Button", nil, parent)
    r:SetSize(width, height)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if not Atlas(r.bg, "Looting_ItemCard_BG") then r.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8) end
    r.focus = FocusStroke(r)
    r.icon = ItemIcon(r, 34)
    r.icon:SetPoint("LEFT", 6, 0)
    r.upgrade = IC.Upgrades.Arrow(r, "BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 50, -7)
    r.name:SetWidth(nameW)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    -- (its line kept clear of the row's bottom: the badges on it stay inside the ring)
    r.qty = K.ChatText(r, 11, KC.help)
    r.qty:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 50, 10)
    r.price = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.price:SetPoint("TOPRIGHT", -12, -7)
    r.gain = Badge(r, 11)
    r.deal = Badge(r, 11)
    function r:Fill(o)
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.quality or 1]
        self.icon:SetTexture(o.icon or 134400)
        self.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
        self.name:SetText(o.name or "...")
        self.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
        self.price:SetText(o.price or "")
        self.upgrade:SetShown(o.upgrade and true or false)
        self.gain:Set(o.gain and o.gain[1], o.gain and o.gain[2])
        self.deal:Set(o.deal and o.deal[1], o.deal and o.deal[2])
        -- The badges after the second line's text (upgrade, price)
        self.qty:SetText(o.line or "")
        local x = (o.line and o.line ~= "") and (self.qty:GetStringWidth() + 8) or 0
        for _, badge in ipairs({ self.gain, self.deal }) do
            if badge:IsShown() then
                badge:ClearAllPoints()
                badge:SetPoint("LEFT", self.qty, "LEFT", x, 0)
                x = x + badge:GetWidth() + 6
            end
        end
    end
    return r
end

-- The browse list's rows
local listRows = {}
for i = 1, LIST_ROWS do
    local r = ItemRow(content, MAIN_W, LIST_H - 4, NAME_ROOM)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * LIST_H)
    r:SetScript("OnClick", function(self)
        if self.index then
            BY.index = self.index
            BY.Render()
        end
    end)
    listRows[i] = r
end

-- Grid cells: the badges along the top (upgrade left, price right), the
-- icon (how many on it), the price under it, the name (three lines)
local gridCells = {}
for i = 1, GRID_COLS * GRID_ROWS do
    local c = K.NewFrame("Button", nil, content)
    local col, row = (i - 1) % GRID_COLS, math.floor((i - 1) / GRID_COLS)
    c:SetSize(CELL_W - 6, CELL_H - 6)
    c:SetPoint("TOPLEFT", col * CELL_W, -row * CELL_H)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.bg:SetColorTexture(0, 0, 0, 0.35)
    c.focus = FocusStroke(c)
    c.icon = ItemIcon(c, 46)
    c.upgrade = IC.Upgrades.Arrow(c, "BOTTOMLEFT", c.icon, "BOTTOMLEFT", -2, -2)
    c.icon:SetPoint("TOP", 0, -26)
    c.count = c:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    c.count:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", -1, 1)
    -- (placed as they show, RenderResults)
    c.gain = Badge(c, 10)
    c.deal = Badge(c, 10)
    c.price = K.ChatText(c, 11, KC.cream)
    c.price:SetPoint("TOP", c.icon, "BOTTOM", 0, -6)
    -- (as the list's names: the game's font, the quality's colour)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOP", c.price, "BOTTOM", 0, -4)
    c.name:SetWidth(CELL_W - 14)
    c.name:SetJustifyH("CENTER")
    c.name:SetJustifyV("TOP")
    c.name:SetWordWrap(true)
    if c.name.SetMaxLines then c.name:SetMaxLines(3) end
    c:SetScript("OnClick", function(self)
        if self.index then
            BY.index = self.index
            BY.Render()
        end
    end)
    gridCells[i] = c
end

local legend = K.NewFrame("Frame", nil, win, "BackdropTemplate")
legend:SetPoint("TOP", win, "BOTTOM", 0, -6)
legend:SetHeight(36)
legend:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
legend:SetBackdropColor(0.05, 0.04, 0.03, 0.92)
legend:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)
local hints = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hints:SetPoint("CENTER")

---------------------------------------------------------------------------
-- The filters (L3): a dropdown as Improved Quest Tracker's (styled as the
-- game's own Menu: its background, titles, radio and check ticks,
-- dividers, the buttons along its bottom), at the content's top right. The
-- D-pad moves, Cross picks, Circle / L3 close (searching again if changed).
---------------------------------------------------------------------------
local DD_ROW, DD_INSET, DD_PAD = 20, { left = 8, top = 8, right = 8, bottom = 15 }, 20

local function Radio(text, key, value)
    return { kind = "radio", text = text,
        isSelected = function() return S()[key] == value end,
        onSelect = function() S()[key] = value end }
end
local function Check(text, key)
    return { kind = "checkbox", text = text,
        isSelected = function() return S()[key] end,
        onSelect = function() S()[key] = not S()[key] end }
end

local ENTRIES = {
    { kind = "title", text = "Filters" },
    Check("Usable only", "buyUsable"),
    Check("Up to my level", "buyMyLevel"),
    { kind = "divider" },
    { kind = "title", text = "Quality |cff9d917a(none ticked: any)|r" },
}
-- (any number ticked; none: any quality)
for q = 0, 5 do
    ENTRIES[#ENTRIES + 1] = { kind = "checkbox", text = QualityName(q),
        isSelected = function() return S().buyQualities[q] end,
        onSelect = function() S().buyQualities[q] = not S().buyQualities[q] or nil end }
end
for _, e in ipairs({
    { kind = "divider" },
    { kind = "title", text = "Upgrades" },
    Radio("Don't show", "buyUpgrades", "off"),
    Radio("Mark with an arrow", "buyUpgrades", "mark"),
    Radio("Upgrades only", "buyUpgrades", "only"),
    { kind = "divider" },
    { kind = "title", text = "Show" },
    Radio("As a list", "buyView", "list"),
    Radio("As a grid", "buyView", "grid"),
    { kind = "divider" },
    { kind = "title", text = "Sort" },
    Radio("Price, lowest first", "buySort", "price"),
    Radio("Name", "buySort", "name"),
}) do ENTRIES[#ENTRIES + 1] = e end

local function Selectable(entry)
    return entry and (entry.kind == "radio" or entry.kind == "checkbox")
end

local filterBox = K.NewFrame("Frame", nil, buyPage)
filterBox:SetFrameLevel(win:GetFrameLevel() + 30)
filterBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -4)
filterBox:EnableMouse(true)
filterBox:Hide()
do
    local bg = filterBox:CreateTexture(nil, "BACKGROUND", nil, -8)
    if not Atlas(bg, "common-dropdown-bg") then bg:SetColorTexture(0.05, 0.04, 0.03, 0.95) end
    bg:SetPoint("TOPLEFT", -10, 3)
    bg:SetPoint("BOTTOMRIGHT", 10, -3)
    bg:SetAlpha(0.925)
end
local ddHint = filterBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
ddHint:SetPoint("BOTTOMLEFT", DD_INSET.left, 6)
ddHint:SetJustifyH("LEFT")

local ddRows = {}
do
    local width, height, previous = 0, DD_INSET.top, nil
    for i, entry in ipairs(ENTRIES) do
        local row = K.NewFrame("Button", nil, filterBox)
        row.index, row.entry = i, entry
        if entry.kind == "divider" then
            row:SetHeight(13)
            local divider = row:CreateTexture(nil, "ARTWORK")
            divider:SetPoint("LEFT")
            divider:SetPoint("RIGHT")
            divider:SetHeight(13)
            divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
        else
            row:SetHeight(DD_ROW)
        end
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetBlendMode("ADD")
        row.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.highlight:Hide()
        local text = row:CreateFontString(nil, "ARTWORK", entry.kind == "title" and "GameFontNormal" or "GameFontHighlight")
        text:SetHeight(DD_ROW)
        text:SetJustifyH("LEFT")
        text:SetText(entry.text or "")
        local contentWidth = text:GetStringWidth()
        if entry.kind == "radio" or entry.kind == "checkbox" then
            local radio = entry.kind == "radio"
            local tick = row:CreateTexture(nil, "ARTWORK")
            if not Atlas(tick, radio and "common-dropdown-tickradial" or "common-dropdown-ticksquare") then
                tick:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            end
            tick:SetSize(16, 16)
            tick:SetPoint("LEFT", radio and -3 or 0, 0)
            row.check = row:CreateTexture(nil, "OVERLAY")
            if not Atlas(row.check, radio and "common-dropdown-icon-radialtick-yellow" or "common-dropdown-icon-checkmark-yellow") then
                row.check:SetColorTexture(1, 0.82, 0, 1)
            end
            row.check:SetSize(radio and 16 or 14, radio and 16 or 14)
            if radio then
                row.check:SetPoint("TOPLEFT", tick, "TOPLEFT")
            else
                row.check:SetPoint("CENTER", tick, "CENTER", 2, 1)
            end
            text:SetPoint("LEFT", tick, "RIGHT", radio and 1 or 7, radio and 0 or 1)
            contentWidth = contentWidth + 16 + 7
            row:SetScript("OnClick", function(self)
                BY.filterRow = self.index
                BY.PickFilter()
            end)
        else
            text:SetPoint("LEFT")
            row:EnableMouse(false)
        end
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
        else
            row:SetPoint("TOPLEFT", DD_INSET.left, -DD_INSET.top)
        end
        row:SetPoint("RIGHT", -DD_INSET.right, 0)
        width = math.max(width, contentWidth)
        height = height + row:GetHeight()
        ddRows[i] = row
        previous = row
    end
    filterBox.baseWidth = width + DD_PAD + DD_INSET.left + DD_INSET.right
    filterBox.baseHeight = height + DD_INSET.bottom + 16
end

-- The next selectable entry up / down from the focused one (wrapping)
local function MoveFilterFocus(step)
    local n = #ENTRIES
    local i = BY.filterRow or 0
    for _ = 1, n do
        i = i + step
        if i < 1 then i = n elseif i > n then i = 1 end
        if Selectable(ENTRIES[i]) then
            BY.filterRow = i
            return
        end
    end
end

---------------------------------------------------------------------------
-- The item (Cross): a box over the content: chart, then buying
---------------------------------------------------------------------------
local detail = Panel(buyPage, 0.97)
detail:SetFrameLevel(win:GetFrameLevel() + 20)
detail:SetAllPoints(content)
detail:Hide()

local dIcon = ItemIcon(detail, 40)
dIcon:SetPoint("TOPLEFT", 16, -14)
local dUpgrade = IC.Upgrades.Arrow(detail, "BOTTOMRIGHT", dIcon, "BOTTOMRIGHT", 2, -2)
local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 10, -2)
dName:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
dName:SetJustifyH("LEFT")
dName:SetWordWrap(false)
local dSub = K.ChatText(detail, 11, KC.help)
dSub:SetPoint("BOTTOMLEFT", dIcon, "BOTTOMRIGHT", 10, 2)

local dChart = IC.AuctionChart.New(detail, "Pay")
dChart:SetPoint("TOPLEFT", 14, -66)
dChart:SetSize(MAIN_W / 2 - 22, 170)
local dInfo = K.ChatText(detail, 11, KC.cream2)
dInfo:SetPoint("TOPLEFT", dChart, "BOTTOMLEFT", 4, -10)
dInfo:SetWidth(MAIN_W / 2 - 30)
dInfo:SetJustifyH("LEFT")

-- Right: the auctions (items), or the quantity and its cost (commodities)
local RIGHT_X = MAIN_W / 2 + 6
local RIGHT_W = MAIN_W / 2 - 22
local AUCTION_ROWS = 5
local AUCTION_H = 50
-- (as the browse list's rows: each auction its own name, stats' badges)
local dRows = {}
for i = 1, AUCTION_ROWS do
    local r = ItemRow(detail, RIGHT_W, AUCTION_H - 4, RIGHT_W - 50 - 90)
    r:SetPoint("TOPLEFT", RIGHT_X, -66 - (i - 1) * AUCTION_H)
    dRows[i] = r
end
-- A commodity's quantity: big, centred up and down above the receipt
-- (placed once the receipt is: below); its steps in the legend
local dQtyMid = K.NewFrame("Frame", nil, detail)
dQtyMid:SetPoint("TOPLEFT", detail, "TOPLEFT", RIGHT_X, -66)
dQtyMid:SetWidth(RIGHT_W)
local dQtyGroup = K.NewFrame("Frame", nil, dQtyMid)
dQtyGroup:SetPoint("LEFT")
dQtyGroup:SetPoint("RIGHT")
dQtyGroup:SetHeight(44 + 10 + 18)
local dQty = K.Text(dQtyGroup, 44, KC.title)
dQty:SetPoint("TOP", 0, 0)
local dQtyLeft = K.Text(dQtyGroup, 44, KC.focus)
dQtyLeft:SetPoint("RIGHT", dQty, "LEFT", -20, 0)
dQtyLeft:SetText("‹")
local dQtyRight = K.Text(dQtyGroup, 44, KC.focus)
dQtyRight:SetPoint("LEFT", dQty, "RIGHT", 20, 0)
dQtyRight:SetText("›")
local dQtyLabel = K.ChatText(dQtyGroup, 16, KC.dimGold)
dQtyLabel:SetPoint("TOP", dQty, "BOTTOM", 0, -10)


-- The receipt, along the right's bottom
local RECEIPT = 3
local receipt = K.NewFrame("Frame", nil, detail)
receipt:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", RIGHT_X, 48)
receipt:SetSize(RIGHT_W, 18 * RECEIPT + 7)
dQtyMid:SetPoint("BOTTOM", receipt, "TOP", 0, 8)
dQtyGroup:SetPoint("CENTER")
local receiptLines = {}
for i = 1, RECEIPT do
    local y = -(i - 1) * 18 - (i == RECEIPT and 7 or 0)
    local big = i == RECEIPT
    local label = K.ChatText(receipt, big and 13 or 12, big and KC.cream or KC.help)
    label:SetPoint("TOPLEFT", 0, y)
    local value = K.ChatText(receipt, big and 13 or 12, big and KC.title or KC.cream)
    value:SetPoint("TOPRIGHT", 0, y)
    receiptLines[i] = { label = label, value = value }
end
local rule = receipt:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetPoint("TOPLEFT", 0, -18 * (RECEIPT - 1) - 1)
rule:SetPoint("TOPRIGHT", 0, -18 * (RECEIPT - 1) - 1)
rule:SetColorTexture(0.45, 0.38, 0.25, 0.9)
local dStatus = K.ChatText(detail, 12, KC.warn)
dStatus:SetPoint("BOTTOM", detail, "BOTTOMLEFT", RIGHT_X + RIGHT_W / 2, 18)
dStatus:SetWidth(RIGHT_W)
dStatus:SetJustifyH("CENTER")

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------
BY.main, BY.sub, BY.subsub = 1, 1, 1   -- 1 in the top bars: "All"
BY.index, BY.top = 1, 1
BY.results = {}

local function Mains()
    local list = {}
    for _, cat in ipairs(_G.AuctionCategories or {}) do
        -- (the WoW Token has its own window)
        if not (cat.HasFlag and cat:HasFlag("WOW_TOKEN_FLAG")) then list[#list + 1] = cat end
    end
    return list
end

local function Subs(cat)
    return cat and cat.subCategories or {}
end

-- The chosen categories, deepest last
local function Chosen()
    local main = Mains()[BY.main]
    local sub = BY.sub > 1 and Subs(main)[BY.sub - 1] or nil
    local subsub = sub and BY.subsub > 1 and Subs(sub)[BY.subsub - 1] or nil
    return main, sub, subsub
end

local function Names(cat)
    local names = { "All" }
    for _, c in ipairs(Subs(cat)) do names[#names + 1] = c.name end
    return names
end

---------------------------------------------------------------------------
-- Browsing
---------------------------------------------------------------------------
local queryToken = 0

local function SendQuery()
    if not A.IsOpen() then return end
    if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
        BY.queryWaiting = true
        return
    end
    BY.queryWaiting = false
    local main, sub, subsub = Chosen()
    local cat = subsub or sub or main
    local filters = {}
    if cat and cat.implicitFilter then filters[#filters + 1] = cat.implicitFilter end
    local s = S()
    if s.buyUsable then filters[#filters + 1] = Enum.AuctionHouseFilter.UsableOnly end
    for q = 0, 5 do
        if s.buyQualities[q] then filters[#filters + 1] = QUALITY_FILTERS[q] end
    end
    local sorts = s.buySort == "name"
        and { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false },
            { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
        or { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
            { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
    AH.SendBrowseQuery({
        searchString = "", sorts = sorts, filters = filters,
        itemClassFilters = cat and cat.filters or nil,
        minLevel = 0, maxLevel = s.buyMyLevel and UnitLevel("player") or 0,
    })
    BY.searching = true
    BY.Render()
end

-- After the categories settle; keep: the same list again (after buying), its place kept
function BY.Query(keep)
    if not keep then BY.results, BY.allResults, BY.index, BY.top = {}, {}, 1, 1 end
    BY.searching = true
    queryToken = queryToken + 1
    local token = queryToken
    C_Timer.After(QUERY_DELAY, function()
        if token == queryToken and win:IsShown() then SendQuery() end
    end)
    BY.Render()
end

function BY.SetMain(i)
    local n = #Mains()
    if n == 0 then return end
    BY.main = (i - 1) % n + 1
    BY.sub, BY.subsub = 1, 1
    BY.Query()
end

function BY.SetSub(i)
    local names = Names((Chosen()))
    BY.sub = (i - 1) % #names + 1
    BY.subsub = 1
    BY.Query()
end

function BY.SetSubSub(i)
    local _, sub = Chosen()
    local names = Names(sub)
    if #names <= 1 then return end
    BY.subsub = (i - 1) % #names + 1
    BY.Query()
end

-- What is shown of what came: with "Upgrades only", the upgrades (those
-- not known yet join as their data come)
function BY.FilterResults()
    local all = BY.allResults or {}
    if S().buyUpgrades ~= "only" then
        BY.results = all
        return
    end
    local list = {}
    for _, result in ipairs(all) do
        if BY.GroupUpgrade(result.itemKey) then list[#list + 1] = result end
    end
    BY.results = list
end

local function ResultsIn()
    BY.allResults = AH.GetBrowseResults() or {}
    BY.FilterResults()
    BY.searching = false
    -- Only upgrades, and few among what came: the rest asked for
    if S().buyUpgrades == "only" and #BY.results < LIST_ROWS and AH.HasFullBrowseResults
        and not AH.HasFullBrowseResults() then
        AH.RequestMoreBrowseResults()
    end
    BY.Render()
end

-- Near the end of what has come: the next part asked for
local function MoreIfNeeded()
    if BY.index > #BY.results - 10 and AH.HasFullBrowseResults and not AH.HasFullBrowseResults() then
        -- (with only upgrades shown, few of what came may show)
        AH.RequestMoreBrowseResults()
    end
end

local function KeyInfo(result)
    return result and AH.GetItemKeyInfo(result.itemKey)
end

-- Its lowest against its usual price: "-23%" (green) / "+15%" (red), or ""
local function Deal(itemID, price)
    local usual = A.MarketPrice(itemID)
    if not usual or usual <= 0 or not price then return "" end
    local pct = math.floor((price / usual - 1) * 100 + 0.5)
    if pct <= -5 then return "|cff5fd35f" .. pct .. "%|r" end
    if pct >= 5 then return "|cffff7a5c+" .. pct .. "%|r" end
    return "|cff9d917a" .. (pct > 0 and "+" or "") .. pct .. "%|r"
end

---------------------------------------------------------------------------
-- An item: D = { result, info, itemID, commodity, listings, row, qty,
-- searching, state (nil, "quote": waiting for the price, "confirm":
-- priced, its popup up, "buying"), quote (unit, total), message }
---------------------------------------------------------------------------
local D

-- What qty of a commodity costs from the listings, cheapest first (nil: not that many)
local function Cost(qty)
    local left, total = qty, 0
    for _, l in ipairs(D.listings or {}) do
        local take = math.min(left, l.count - (l.own or 0))
        if take > 0 then
            total = total + take * l.unit
            left = left - take
        end
        if left <= 0 then break end
    end
    return left <= 0 and total or nil
end

local function Available()
    local n = 0
    for _, l in ipairs(D.listings or {}) do n = n + l.count - (l.own or 0) end
    return n
end

local function Auctions()
    local list = {}
    for _, l in ipairs(D.listings or {}) do
        if l.own < l.count then list[#list + 1] = l end
    end
    return list
end

---------------------------------------------------------------------------
-- The versions listed: a group (one item key) can hold auctions of the
-- same item with different stats (random "of the ..." suffixes). Each
-- auction's own tooltip (its link) gives its lines that make it what it
-- is: + stats, Equip / Use / Chance on hit; auctions with the same
-- lines are one version, at its lowest price, with how many are up.
---------------------------------------------------------------------------
local MAX_VERSIONS = 6
local versionCache = {}   -- key string (KeyString) -> { versions, pending }

local function KeyString(key)
    return key.itemID .. ":" .. (key.itemLevel or 0) .. ":" .. (key.itemSuffix or 0)
end

local TRIGGERS = {}
for _, g in ipairs({ "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC" }) do
    if _G[g] then TRIGGERS[#TRIGGERS + 1] = _G[g] end
end

-- The lines that tell one version from another, or nil (not loaded yet)
local function VersionLines(link)
    local tips = C_TooltipInfo
    if not (tips and tips.GetHyperlink) then return nil end
    local ok, data = pcall(tips.GetHyperlink, link)
    if not ok or not data or not data.lines or #data.lines < 2 then return nil end
    local lines = {}
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if text and text ~= "" then
            local keep = text:match("^[%+%-]%d")
            for _, trigger in ipairs(TRIGGERS) do
                if text:sub(1, #trigger) == trigger then keep = true end
            end
            if keep then lines[#lines + 1] = text end
        end
    end
    return lines
end

local function Versions(listings)
    local byLines, list, pending = {}, {}, false
    for _, l in ipairs(listings or {}) do
        local lines = l.link and VersionLines(l.link)
        if l.link and not lines then pending = true end
        if lines then
            local sig = table.concat(lines, "|")
            local v = byLines[sig]
            if not v then
                v = { lines = lines, price = math.huge, count = 0 }
                byLines[sig] = v
                list[#list + 1] = v
            end
            v.price = math.min(v.price, l.total or l.unit * l.count)
            v.count = v.count + l.count
        end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    return { versions = list, pending = pending }
end

local function AddVersions(key)
    local c = versionCache[KeyString(key)]
    if not c then return end
    local versions = c.versions
    if #versions == 0 then
        if c.pending then GameTooltip:AddLine("Loading the versions listed...", 0.6, 0.55, 0.45) end
        return
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(#versions == 1 and "Listed: 1 version" or ("Listed: " .. #versions .. " versions"), 0.79, 0.64, 0.35)
    for i, v in ipairs(versions) do
        if i > MAX_VERSIONS then
            GameTooltip:AddLine("and " .. (#versions - MAX_VERSIONS) .. " more", 0.6, 0.55, 0.45)
            break
        end
        GameTooltip:AddDoubleLine(" ", A.Money(v.price) .. (v.count > 1 and ("  |cff9d917a(" .. v.count .. ")|r") or ""),
            1, 1, 1, 1, 1, 1)
        if #v.lines == 0 then
            GameTooltip:AddLine("   no extra stats", 0.6, 0.55, 0.45)
        end
        for _, line in ipairs(v.lines) do
            GameTooltip:AddLine("   " .. line, 0.4, 0.9, 0.4, true)
        end
    end
end

local function KeepVersions(key, listings)
    local c = Versions(listings)
    c.listings = listings
    versionCache[KeyString(key)] = c
end

-- A group's upgrade: its best listed version (once its auctions were looked
-- up: gear with random stats, whose plain item has none), else its plain
-- item. Returns upgrade, gain, needLevel.
function BY.GroupUpgrade(itemKey)
    if S().buyUpgrades == "off" then return false end
    local UP = IC.Upgrades
    local c = versionCache[KeyString(itemKey)]
    local best, bestGain, bestNeed = false, nil, nil
    for _, l in ipairs(c and c.listings or {}) do
        if l.link and UP.IsUpgrade(l.link, nil, nil, true) then
            local gain, need = UP.Gain(l.link, nil, nil, true)
            if not best or (gain or 0) > (bestGain or 0) then best, bestGain, bestNeed = true, gain, need end
        end
    end
    if best then return true, bestGain, bestNeed end
    if UP.IsUpgradeKey(itemKey) then return true, UP.GainKey(itemKey) end
    return false
end

-- Why the picked one is an upgrade or not (/ic upgrade): an item's
-- picked auction, else the group's plain item
function BY.Explain()
    if not win:IsShown() or BY.tab ~= "buy" then
        return IC.Print("open the auction house's Buy tab and pick an item first.")
    end
    local link
    if D and not D.commodity then
        local a = Auctions()[D.row]
        link = a and a.link
    end
    local result = BY.results[BY.index]
    if not link and result then link = select(2, (C_Item and C_Item.GetItemInfo or GetItemInfo)(result.itemKey.itemID)) end
    if not link then return IC.Print("no item picked (or its data not loaded yet).") end
    IC.Print("upgrade? " .. link)
    for _, line in ipairs(IC.Upgrades.Explain(link, true)) do IC.Print("  " .. line) end
end

-- Item data come in: the versions still loading worked out again
local function VersionsLoaded()
    local changed = false
    for k, c in pairs(versionCache) do
        if c.pending then
            local again = Versions(c.listings)
            again.listings = c.listings
            versionCache[k] = again
            changed = true
        end
    end
    if changed then BY.Tip() end
end

-- Where tooltips go: under the tabs down the window's right
local tabButtons = {}
function BY.PlaceTip()
    GameTooltip:ClearAllPoints()
    local last = tabButtons[#BY.TABS]
    if last and last:IsShown() then
        GameTooltip:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -12)
    else
        GameTooltip:SetPoint("TOPLEFT", win, "TOPRIGHT", 52, 0)
    end
end

-- Tooltips show as the bag window's do: the game's own setting (CVar
-- GamepadDisableTooltips), which R3 turns on and off here too
function BY.TipsOff()
    local get = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    return get and get("GamepadDisableTooltips") or false
end

function BY.ToggleTips()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then set("GamepadDisableTooltips", BY.TipsOff() and "0" or "1") end
end

-- What is worn in its place, beside the tooltip (gear: the game's own
-- comparison), else no comparison left from before. The game puts it on
-- the side with more room (left: over the window): moved to the
-- tooltip's right, or under it when the screen ends first.
function BY.Compare()
    local tips = {}
    for _, tip in ipairs({ _G.ShoppingTooltip1, _G.ShoppingTooltip2 }) do
        if tip then tips[#tips + 1] = tip end
    end
    if not (GameTooltip_ShowCompareItem and pcall(GameTooltip_ShowCompareItem, GameTooltip)) then
        for _, tip in ipairs(tips) do tip:Hide() end
        return
    end
    local shown, width = {}, 0
    -- (the game shows the second first, the first beside it: worn order)
    for _, tip in ipairs(tips) do
        if tip:IsShown() then
            shown[#shown + 1] = tip
            width = width + tip:GetWidth()
        end
    end
    if #shown == 0 then return end
    local right = GameTooltip:GetRight() or 0
    local fits = right + width <= GetScreenWidth()
    for i, tip in ipairs(shown) do
        tip:ClearAllPoints()
        if i == 1 then
            if fits then
                tip:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 2, 0)
            else
                tip:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -2)
            end
        else
            tip:SetPoint("TOPLEFT", shown[i - 1], "TOPRIGHT", 2, 0)
        end
    end
end

-- The tooltip, beside the window: the picked group (its item key), or in an
-- item the auction picked (its own link: its exact stats)
local function ItemKeyTip(key)
    if GameTooltip.SetItemKey then
        local required = AH.GetItemKeyRequiredLevel and AH.GetItemKeyRequiredLevel(key)
        GameTooltip:SetItemKey(key.itemID, key.itemLevel, key.itemSuffix, required)
    else
        GameTooltip:SetItemByID(key.itemID)
    end
end

function BY.Tip()
    local tipOwner = GameTooltip:GetOwner() == win
    local result = BY.results[BY.index]
    if not win:IsShown() or filterBox:IsShown() or (not D and not result) or BY.TipsOff() then
        if tipOwner then GameTooltip:Hide() end
        return
    end
    GameTooltip:SetOwner(win, "ANCHOR_NONE")
    BY.PlaceTip()
    local key
    if D then
        local auction = not D.commodity and Auctions()[D.row]
        if auction and auction.link then
            GameTooltip:SetHyperlink(auction.link)
        elseif D.commodity then
            GameTooltip:SetItemByID(D.itemID)
        else
            ItemKeyTip(D.result.itemKey)
        end
    else
        key = result.itemKey
        ItemKeyTip(key)
    end
    -- (a group: its versions; an auction's own tooltip is that version)
    if key then AddVersions(key) end
    GameTooltip:Show()
    BY.Compare()
end

-- Gear picked in the list for a moment: its auctions looked up quietly,
-- for its possible stats
local PREFETCH_AFTER = 0.6
local prefetched = {}

local function Prefetch(now)
    local result = not D and not filterBox:IsShown() and not BY.searching and BY.results[BY.index]
    if not result then
        BY.restingOn = nil
        return
    end
    local key = KeyString(result.itemKey)
    if BY.restingOn ~= key then
        BY.restingOn, BY.restingSince = key, now
        return
    end
    if prefetched[key] or now - BY.restingSince < PREFETCH_AFTER then return end
    local info = KeyInfo(result)
    if not info or info.isCommodity or not info.isEquipment then return end
    prefetched[key] = true
    local itemKey = result.itemKey
    A.Search(itemKey.itemID, false, nil, function(listings)
        if listings then
            KeepVersions(itemKey, listings)
            -- (its badges from its versions now; its tooltip too)
            BY.FilterResults()
            BY.Render()
        else
            prefetched[key] = nil
        end
    end, itemKey)
end

function BY.SearchItem()
    if not D then return end
    D.searching, D.state, D.message = true, nil, nil
    local itemID = D.itemID
    A.Search(itemID, D.commodity, nil, function(listings)
        if not D or D.itemID ~= itemID then return end
        D.searching = false
        D.listings = listings or {}
        if not listings then D.message = "No answer from the auction house" end
        if not D.commodity then KeepVersions(D.result.itemKey, D.listings) end
        D.qty = math.max(1, math.min(D.qty or 1, Available()))
        BY.Render()
    end, not D.commodity and D.result.itemKey or nil)
    BY.Render()
end

function BY.OpenItem()
    local result = BY.results[BY.index]
    local info = KeyInfo(result)
    if not result or not info then return end
    D = {
        result = result, info = info, itemID = result.itemKey.itemID, commodity = info.isCommodity,
        row = 1, qty = 1, listings = {},
    }
    detail:Show()
    BY.SearchItem()
end

function BY.CloseItem()
    if D and D.state == "quote" or D and D.state == "confirm" then
        if AH.CancelCommoditiesPurchase then AH.CancelCommoditiesPurchase() end
    end
    D = nil
    detail:Hide()
    BY.Render()
end

-- The header of a buy popup (AuctionConfirm.lua): the item as in the
-- list, how its price compares with its usual one
local function Header(count, unit)
    local info = D.info
    local deal = Deal(D.itemID, unit)
    return {
        icon = info.iconFileID, count = count, name = info.itemName or "item", quality = info.quality,
        sub = deal ~= "" and (deal .. "  |cff9d917aagainst its usual price|r") or "",
    }
end

local function Popup(o, header)
    for k, v in pairs(header) do o[k] = v end
    o.over = win
    IC.AuctionConfirm.Show(o)
end

-- A commodity's price from the server (StartCommoditiesPurchase): asked
-- in a popup, its Cross buys; it holds for a short while
local function ConfirmQuote(unit, total)
    local itemID, qty = D.itemID, D.qty
    local expected = Cost(qty)
    local header = Header(qty, unit)
    if expected and total > expected then
        header.sub = "|cffff7a5cThe price went up by " .. A.Money(total - expected) .. "|r"
    end
    Popup({
        title = "Buy",
        lines = {
            { "Price each", A.Money(unit) },
            { "Quantity", qty .. " of " .. Available() },
            { "Your money", A.Money(GetMoney()) },
        },
        total = { "You pay", A.Money(total) },
        accept = "Buy",
        onAccept = function()
            if not (D and D.itemID == itemID and D.state == "confirm") or IC.InCombat() then return end
            D.state, D.message = "buying", "Buying..."
            AH.ConfirmCommoditiesPurchase(itemID, qty)
            BY.Render()
        end,
        onCancel = function()
            if AH.CancelCommoditiesPurchase then AH.CancelCommoditiesPurchase() end
            if D then D.state, D.quote, D.message = nil, nil, nil end
            BY.Render()
        end,
    }, header)
end

-- Cross (the server wants a hardware event for these): a commodity's price
-- asked of the server first, then the popup; an auction: the popup, its
-- Cross buys it out
local function Buy()
    if not D or D.searching or D.state or IC.InCombat() then return end
    if D.commodity then
        local total = Cost(D.qty)
        if not total then
            D.message = "Not that many for sale"
            return BY.Render()
        end
        if total > GetMoney() then
            D.message = "Not enough money"
            return BY.Render()
        end
        D.state, D.message = "quote", "Getting the price..."
        AH.StartCommoditiesPurchase(D.itemID, D.qty, math.ceil(total / D.qty))
    else
        local auction = Auctions()[D.row]
        if not auction then return end
        local price = auction.total or auction.unit * auction.count
        if price > GetMoney() then
            D.message = "Not enough money"
            return BY.Render()
        end
        local itemID, id = D.itemID, auction.auctionID
        local header = Header(auction.count, auction.unit)
        if auction.link then header.name = auction.link:match("%[(.-)%]") or header.name end
        Popup({
            title = "Buy",
            lines = {
                { "Price each", A.Money(auction.unit) },
                { "Quantity", tostring(auction.count) },
                { "Item level", auction.itemLevel and auction.itemLevel > 0 and tostring(auction.itemLevel) or "—" },
            },
            total = { "You pay", A.Money(price) },
            accept = "Buy",
            onAccept = function()
                if not (D and D.itemID == itemID) or IC.InCombat() then return end
                D.state, D.message = "buying", "Buying..."
                D.bought = auction
                AH.PlaceBid(id, price)
                BY.Render()
            end,
        }, header)
    end
    BY.Render()
end

local function Bought(what)
    PlaySound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
    IC.Print("bought " .. what .. ".")
    if D then
        D.state, D.message = nil, "|cff5fd35fBought|r"
        BY.SearchItem()
        D.message = "|cff5fd35fBought " .. what .. "|r"
    end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function RenderSide()
    local mains = Mains()
    sideTitle:SetText(Glyph("LS", 18) .. " Category")
    local top = math.max(1, math.min(BY.main - math.floor(SIDE_ROWS / 2), #mains - SIDE_ROWS + 1))
    local fr, fg, fb = FocusColor()
    for i, r in ipairs(sideRows) do
        local index = top + i - 1
        local cat = mains[index]
        r:SetShown(cat ~= nil)
        if cat then
            r.index = index
            local on = index == BY.main
            r.text:SetText(cat.name)
            r.text:SetTextColor(on and 1 or 0.8, on and 0.95 or 0.74, on and 0.8 or 0.6)
            r.focus:SetShown(on)
            r.focus:SetVertexColor(fr, fg, fb)
        end
    end
end

local function RenderResults()
    local results = BY.results
    local n = #results
    local grid = S().buyView == "grid"
    local per = grid and GRID_COLS * GRID_ROWS or LIST_ROWS
    local step = grid and GRID_COLS or 1
    BY.index = math.max(1, math.min(BY.index, math.max(1, n)))
    -- Scrolled by whole rows, keeping the picked one in view
    if BY.index < BY.top then BY.top = BY.index - (BY.index - 1) % step end
    if BY.index > BY.top + per - 1 then BY.top = BY.index - per + step - (BY.index - 1) % step end
    BY.top = math.max(1, BY.top)
    emptyText:SetShown(n == 0)
    emptyText:SetText(BY.searching and "Searching..." or "Nothing listed here")
    local fr, fg, fb = FocusColor()
    local focusOn = not D and not filterBox:IsShown()
    for _, r in ipairs(listRows) do r:Hide() end
    for _, c in ipairs(gridCells) do c:Hide() end
    local frames = grid and gridCells or listRows
    for i, f in ipairs(frames) do
        local index = BY.top + i - 1
        local result = results[index]
        if result then
            f.index = index
            local info = KeyInfo(result)
            local c = info and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
            local price = result.minPrice
            local upgrade, gain, needLevel = BY.GroupUpgrade(result.itemKey)
            local gainText, gainColor = GainBadge(upgrade, gain, needLevel)
            local dealText, dealColor = DealBadge(result.itemKey.itemID, price)
            local priceText = price and price > 0 and A.Money(price) or "bid only"
            if grid then
                f.icon:SetTexture(info and info.iconFileID or 134400)
                f.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
                f.name:SetText(info and info.itemName or "...")
                f.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
                f.price:SetText(priceText)
                f.upgrade:SetShown(upgrade)
                f.gain:Set(gainText, gainColor)
                f.deal:Set(dealText, dealColor)
                -- Along the top: the upgrade badge on the left, the price's on the right
                f.gain:ClearAllPoints()
                f.gain:SetPoint("TOPLEFT", 5, -5)
                f.deal:ClearAllPoints()
                f.deal:SetPoint("TOPRIGHT", -5, -5)
                f.count:SetText(result.totalQuantity > 1 and result.totalQuantity or "")
            else
                f:Fill({
                    icon = info and info.iconFileID, quality = info and info.quality,
                    name = info and info.itemName or "...", price = priceText, upgrade = upgrade,
                    line = result.totalQuantity .. " available"
                        .. (result.itemKey.itemLevel and result.itemKey.itemLevel > 0 and info and info.isEquipment
                            and ("  ·  item level " .. result.itemKey.itemLevel) or ""),
                    gain = gainText and { gainText, gainColor }, deal = dealText and { dealText, dealColor },
                })
            end
            local on = focusOn and index == BY.index
            f.focus:SetShown(index == BY.index)
            f.focus:SetVertexColor(fr, fg, fb)
            f.focus:SetAlpha(on and 1 or 0.4)
            f:Show()
        end
    end
    local main, sub, subsub = Chosen()
    local path = (main and main.name or "") .. (sub and (" › " .. sub.name) or "") .. (subsub and (" › " .. subsub.name) or "")
    local s = S()
    local active = {}
    if s.buyUsable then active[#active + 1] = "usable" end
    local qualities = {}
    for q = 0, 5 do
        if s.buyQualities[q] then qualities[#qualities + 1] = QUALITY_NAMES[q]:lower() end
    end
    if #qualities > 0 then active[#active + 1] = table.concat(qualities, " / ") end
    if s.buyMyLevel then active[#active + 1] = "up to my level" end
    if s.buyUpgrades == "only" then active[#active + 1] = "upgrades only" end
    status:SetText(path .. "   ·   " .. (BY.searching and "searching..." or (n .. " found"))
        .. (#active > 0 and ("   ·   |cffc9a25a" .. table.concat(active, ", ") .. "|r") or ""))
end

local function RenderDetail()
    if not D then return end
    local info = D.info
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
    dIcon:SetTexture(info.iconFileID or 134400)
    dIcon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
    dName:SetText(info.itemName)
    dUpgrade:SetShown(BY.GroupUpgrade(D.result.itemKey) and true or false)
    dName:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
    local available = Available()
    dSub:SetText(D.searching and "Searching..." or (available .. " for sale"))
    local lowest = D.listings[1] and D.listings[1].unit
    local pay
    if D.commodity then
        local total = Cost(D.qty)
        pay = total and total / D.qty
    else
        local a = Auctions()[D.row]
        pay = a and a.unit
    end
    dChart:Draw({ itemID = D.itemID, lowestNow = lowest, price = pay, searching = D.searching })
    local usual = A.MarketPrice(D.itemID)
    local parts = {}
    if lowest then parts[#parts + 1] = "Lowest now " .. A.Money(lowest) end
    if usual then parts[#parts + 1] = "usually " .. A.Money(usual) end
    dInfo:SetText(table.concat(parts, "   ·   "))

    local fr, fg, fb = FocusColor()
    local lines
    if D.commodity then
        for _, r in ipairs(dRows) do r:Hide() end
        dQtyMid:Show()
        dQty:SetText(D.qty)
        local fr, fg, fb = FocusColor()
        dQtyLeft:SetTextColor(fr, fg, fb)
        dQtyRight:SetTextColor(fr, fg, fb)
        dQtyLabel:SetText("to buy, of " .. available)

        local total = Cost(D.qty)
        local unit = D.quote and D.quote.unit or (total and total / D.qty)
        total = D.quote and D.quote.total or total
        lines = {
            { "Price each" .. (D.quote and " |cff9d917a(confirmed)|r" or " |cff9d917a(average)|r"), unit and A.Money(unit) or "—" },
            { "Against usual", unit and Deal(D.itemID, unit) ~= "" and Deal(D.itemID, unit) or "—" },
            { "Total", total and A.Money(total) or "not that many" },
        }
    else
        dQtyMid:Hide()
        local auctions = Auctions()
        D.row = math.max(1, math.min(D.row, math.max(1, #auctions)))
        local top = math.max(1, D.row - AUCTION_ROWS + 1)
        for i, r in ipairs(dRows) do
            local a = auctions[top + i - 1]
            r:SetShown(a ~= nil)
            if a then
                local on = top + i - 1 == D.row
                local upgrade = S().buyUpgrades ~= "off" and a.link and IC.Upgrades.IsUpgrade(a.link, nil, nil, true)
                    and true or false
                local gain, needLevel
                if upgrade then gain, needLevel = IC.Upgrades.Gain(a.link, nil, nil, true) end
                local gainText, gainColor = GainBadge(upgrade, gain, needLevel)
                local dealText, dealColor = DealBadge(D.itemID, a.unit)
                local parts = {}
                if a.count > 1 then parts[#parts + 1] = a.count .. " ×  " .. A.Money(a.unit) .. " each" end
                if a.itemLevel and a.itemLevel > 0 and info.isEquipment then
                    parts[#parts + 1] = "item level " .. a.itemLevel
                end
                r:Fill({
                    icon = info.iconFileID, quality = info.quality,
                    -- (its own name: a random suffix's "of the Owl")
                    name = a.link and a.link:match("%[(.-)%]") or info.itemName,
                    line = table.concat(parts, "  ·  "), price = A.Money(a.total or a.unit * a.count),
                    upgrade = upgrade,
                    gain = gainText and { gainText, gainColor }, deal = dealText and { dealText, dealColor },
                })
                r.focus:SetShown(on)
                r.focus:SetVertexColor(fr, fg, fb)
            end
        end
        local a = auctions[D.row]
        local price = a and (a.total or a.unit * a.count)
        lines = {
            { "Auctions", #auctions .. " listed" },
            { "Against usual", a and Deal(D.itemID, a.unit) ~= "" and Deal(D.itemID, a.unit) or "—" },
            { "You pay", price and A.Money(price) or "—" },
        }
    end
    for i, line in ipairs(receiptLines) do
        line.label:SetText(lines[i][1])
        line.value:SetText(lines[i][2])
    end
    dStatus:SetText(D.message or "")
end

local function RenderFilters()
    ddHint:SetText(Glyph("DPAD", 16) .. " Move   " .. Glyph("A", 16) .. " Select   " .. Glyph("B", 16) .. " Close")
    filterBox:SetSize(math.max(filterBox.baseWidth, ddHint:GetStringWidth() + DD_INSET.left + DD_INSET.right),
        filterBox.baseHeight)
    for i, row in ipairs(ddRows) do
        local entry = row.entry
        if Selectable(entry) then row.check:SetShown(entry.isSelected() and true or false) end
        row.highlight:SetShown(i == BY.filterRow)
    end
end

-- For the other pages: the window's parts and looks
BY.Glyph, BY.Panel, BY.FocusStroke, BY.ItemIcon, BY.FocusColor, BY.Atlas, BY.Deal =
    Glyph, Panel, FocusStroke, ItemIcon, FocusColor, Atlas, Deal
BY.W, BY.H = W, H
function BY.IsShown() return win:IsShown() end
function BY.Tab() return BY.tab end

---------------------------------------------------------------------------
-- The tabs down the window's right: the game's side tabs (as the
-- character window's), the right stick's glyph above them (up / down
-- moves through them)
---------------------------------------------------------------------------
local tabKey = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")

local function CurrentPage()
    for _, t in ipairs(BY.TABS) do
        if t.key == BY.tab and t.key ~= "buy" then return t end
    end
end

local function TabButton(i)
    if tabButtons[i] then return tabButtons[i] end
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
    b:SetScript("OnMouseDown", function(self) BY.SetTab(self.key) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tabButtons[i] = b
    return b
end

local function RenderTabs()
    local previous
    for i, t in ipairs(BY.TABS) do
        local b = TabButton(i)
        b.key, b.label = t.key, t.label
        b.Icon:SetTexture(t.icon)
        b:ClearAllPoints()
        if previous then
            b:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
        else
            b:SetPoint("TOPLEFT", win, "TOPRIGHT", -2, -52)
        end
        if b.SelectedTexture then b.SelectedTexture:SetShown(t.key == BY.tab) end
        b:Show()
        previous = b
    end
    tabKey:ClearAllPoints()
    tabKey:SetPoint("BOTTOM", tabButtons[1], "TOP", -3, 4)
    tabKey:SetText(Glyph("RS", 26))
end

-- The legend: a page's buttons, then the right stick for the tabs
local function SetHints(text)
    hints:SetText(text .. "   " .. Glyph("RS") .. " Tabs (tilt) / " .. (BY.TipsOff() and "Tooltip (click)" or "No tooltip (click)"))
    legend:SetWidth(math.max(500, hints:GetStringWidth() + 28))
end

function BY.SetTab(key)
    if key == BY.tab then return end
    local old = CurrentPage()
    if old then old.Hide() else buyPage:Hide() end
    if GameTooltip:GetOwner() == win then GameTooltip:Hide() end
    BY.tab, BY.held = key, nil
    local page = CurrentPage()
    if page then
        if not page.frame then page.frame = page.Build(win) end
        page.Show()
    else
        buyPage:Show()
    end
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
    BY.Render()
end

-- dir: 1 the tab below, -1 the one above (round from the ends)
function BY.StepTab(dir)
    local n = #BY.TABS
    for i, t in ipairs(BY.TABS) do
        if t.key == BY.tab then return BY.SetTab(BY.TABS[(i - 1 + dir) % n + 1].key) end
    end
end

function BY.Render()
    if not win:IsShown() then return end
    RenderTabs()
    local page = CurrentPage()
    if page then
        titleText:SetText("Auction House  ·  " .. page.label)
        page.Render()
        SetHints(page.Hints())
        return
    end
    titleText:SetText("Auction House  ·  Buy")
    RenderSide()
    local main, sub = Chosen()
    LayoutBar(bar2, Names(main), BY.sub)
    local names3 = Names(sub)
    if not sub then names3 = { "—" } end
    LayoutBar(bar3, names3, sub and BY.subsub or 1)
    RenderResults()
    if D then RenderDetail() end
    if filterBox:IsShown() then RenderFilters() end
    local text
    if filterBox:IsShown() then
        text = Glyph("DPAD") .. " Move   " .. Glyph("A") .. " Select   " .. Glyph("LS") .. " / " .. Glyph("B") .. " Close"
    elseif D then
        -- (a commodity's quantity steps: 1, 5, 20)
        local move = D.commodity
            and (Glyph("DPAD_LR") .. " 1   " .. Glyph("LB") .. " " .. Glyph("RB") .. " 5   "
                .. Glyph("LT") .. " " .. Glyph("RT") .. " 20   ")
            or (Glyph("DPAD_UD") .. " Auction   ")
        text = Glyph("A") .. " Buy   " .. move .. Glyph("X") .. " Refresh   " .. Glyph("B") .. " Back"
    else
        text = Glyph("A") .. " Open   " .. Glyph("DPAD") .. " Move   " .. Glyph("LS") .. " Filters   "
            .. Glyph("B") .. " Close"
    end
    SetHints(text)
    BY.Tip()
end

---------------------------------------------------------------------------
-- The pad: buttons, and the left stick (main categories)
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
    PADLSTICK = "LS", PADRSTICK = "RS",
}
local REPEATS = { UP = true, DOWN = true, LEFT = true, RIGHT = true, LB = true, RB = true, LT = true, RT = true }

local function MoveResults(name, fast)
    local grid = S().buyView == "grid"
    local n = #BY.results
    if n == 0 then return end
    local d
    if grid then
        d = ({ UP = -GRID_COLS, DOWN = GRID_COLS, LEFT = -1, RIGHT = 1 })[name]
    else
        d = ({ UP = -1, DOWN = 1, LEFT = -LIST_ROWS, RIGHT = LIST_ROWS })[name]
    end
    if fast and not grid and (name == "UP" or name == "DOWN") then d = d * 5 end
    BY.index = math.max(1, math.min(n, BY.index + d))
    MoreIfNeeded()
end

function BY.PickFilter()
    local entry = ENTRIES[BY.filterRow]
    if not Selectable(entry) then return end
    entry.onSelect()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    BY.filtersChanged = true
    BY.Render()
end

local function CloseFilters()
    filterBox:Hide()
    if BY.filtersChanged then
        BY.filtersChanged = false
        BY.Query()
    end
end

function BY.Press(name, fast)
    -- (a popup up, AuctionConfirm.lua: its press)
    if IC.AuctionConfirm.Press(name) then return BY.Render() end
    if name == "RS" then
        BY.ToggleTips()
        if BY.TipsOff() and GameTooltip:GetOwner() == win then GameTooltip:Hide() end
        return BY.Render()
    end
    local page = CurrentPage()
    if page then
        if page.Press(name, fast) then return end
        if name == "B" and AH.CloseAuctionHouse then AH.CloseAuctionHouse() end
        return
    end
    if filterBox:IsShown() then
        if name == "UP" or name == "DOWN" then
            MoveFilterFocus(name == "UP" and -1 or 1)
        elseif name == "A" then
            return BY.PickFilter()
        elseif name == "LS" or name == "B" then
            CloseFilters()
        end
        return BY.Render()
    end
    if D then
        if name == "B" then return BY.CloseItem() end
        if name == "A" then return Buy() end
        if name == "X" then return BY.SearchItem() end
        if D.state == "buying" or D.state == "quote" then return end
        if D.commodity and (name == "LEFT" or name == "RIGHT") then
            D.qty = math.max(1, math.min(math.max(1, Available()), D.qty + (name == "RIGHT" and 1 or -1) * (fast and 10 or 1)))
            D.state, D.quote, D.message = nil, nil, nil
        elseif D.commodity and (name == "LB" or name == "RB" or name == "LT" or name == "RT") then
            -- L1 / R1: by 5, L2 / R2: by 20 (held: again), on their round
            -- numbers: 1 -> 5 -> 10..., 7 -> 10 up, 5 down; never under 1
            local step = (name == "LB" or name == "RB") and 5 or 20
            local qty
            if name == "RB" or name == "RT" then
                qty = (math.floor(D.qty / step) + 1) * step
            else
                qty = (math.ceil(D.qty / step) - 1) * step
            end
            D.qty = math.max(1, math.min(math.max(1, Available()), qty))
            D.state, D.quote, D.message = nil, nil, nil
        elseif not D.commodity and (name == "UP" or name == "DOWN") then
            D.row = D.row + (name == "UP" and -1 or 1)
            D.state, D.message = nil, nil
        end
        return BY.Render()
    end
    if name == "UP" or name == "DOWN" or name == "LEFT" or name == "RIGHT" then
        MoveResults(name, fast)
    elseif name == "LB" or name == "RB" then
        BY.SetSub(BY.sub + (name == "RB" and 1 or -1))
        return
    elseif name == "LT" or name == "RT" then
        BY.SetSubSub(BY.subsub + (name == "RT" and 1 or -1))
        return
    elseif name == "A" then
        return BY.OpenItem()
    elseif name == "LS" then
        if not Selectable(ENTRIES[BY.filterRow]) then
            BY.filterRow = 0
            MoveFilterFocus(1)
        end
        filterBox:Show()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    elseif name == "B" then
        if AH.CloseAuctionHouse then AH.CloseAuctionHouse() end
        return
    end
    BY.Render()
end

local catcher = K.NewFrame("Frame", nil, win)
catcher:SetAllPoints(win)

-- The left stick, up / down: the main category (held: again, steadily)
local stickY, stickNext = 0, nil
-- The right stick, up / down: the tab above / below (once a push)
local rightY, rightHeld = 0, false
local function Stick(now)
    if filterBox:IsShown() or D then
        stickNext = nil
        return
    end
    local dir = stickY > STICK_ON and -1 or stickY < -STICK_ON and 1 or 0
    if dir == 0 then
        if math.abs(stickY) < STICK_OFF then stickNext = nil end
        return
    end
    if stickNext and now < stickNext then return end
    stickNext = now + (stickNext and REPEAT_EVERY * 2 or REPEAT_DELAY)
    BY.SetMain(BY.main + dir)
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        -- Circle on its release: on the press the release reaches the game's
        -- own window, which closes
        if not name or name == "B" then return end
        BY.Press(name)
        if REPEATS[name] then BY.held = { name = name, at = GetTime(), next = GetTime() + REPEAT_DELAY } end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if name == "B" then return BY.Press("B") end
        if BY.held and BY.held.name == name then BY.held = nil end
    end)
end
if catcher.EnableGamePadStick then
    catcher:SetScript("OnGamePadStick", function(_, stick, _, y)
        if stick == "Left" or stick == "Movement" then stickY = y or 0 end
        if stick == "Right" or stick == "Camera" then rightY = y or 0 end
    end)
end

win:SetScript("OnUpdate", function()
    local now = GetTime()
    if not rightHeld and math.abs(rightY) > STICK_ON then
        rightHeld = true
        BY.StepTab(rightY > 0 and -1 or 1)
    elseif rightHeld and math.abs(rightY) < STICK_OFF then
        rightHeld = false
    end
    if BY.tab == "buy" then
        Stick(now)
        Prefetch(now)
    else
        local page = CurrentPage()
        if page and page.Update then page.Update(now) end
    end
    local held = BY.held
    if held and now >= held.next then
        held.next = now + REPEAT_EVERY
        BY.Press(held.name, now - held.at > FAST_AFTER)
    end
    -- A commodity's price, held for a short while
    if D and D.state == "confirm" and AH.GetQuoteDurationRemaining and AH.GetQuoteDurationRemaining() == 0 then
        IC.AuctionConfirm.Hide()
        D.state, D.quote, D.message = nil, nil, "The price ran out: " .. Glyph("A") .. " again"
        BY.Render()
    end
end)

local function TakePad(on)
    if IC.InCombat() then return end
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(on and true or false) end
    -- (both sticks: the camera and the character stay still)
    if catcher.EnableGamePadStick then catcher:EnableGamePadStick(on and true or false) end
end

---------------------------------------------------------------------------
-- Showing, hiding
---------------------------------------------------------------------------
-- The game's own window stays hidden (not closed: that would close the
-- auction house) while ours is up, its cursor too
local pointer
local function SyncNative()
    local ah = _G.AuctionHouseFrame
    if ah then ah:SetAlpha(win:IsShown() and A.IsOpen() and 0 or 1) end
    local nav = _G.SmartNavigation
    if win:IsShown() then
        if nav and nav.Pointer and not pointer then
            pointer = nav.Pointer
            pointer:SetAlpha(0)
        end
    elseif pointer then
        pointer:SetAlpha(1)
        pointer = nil
    end
end

function BY.Show()
    if IC.InCombat() or not A.Available() or not A.IsOpen() then return end
    if #Mains() == 0 then return end
    -- Where the game's own window is
    local native = _G.AuctionHouseFrame
    win:ClearAllPoints()
    if native and native:GetLeft() then
        win:SetPoint("TOPLEFT", native, "TOPLEFT")
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
    win:Show()
    TakePad(true)
    SyncNative()
    local page = CurrentPage()
    if page then
        if not page.frame then page.frame = page.Build(win) end
        page.Show()
    end
    if #BY.results == 0 and not BY.searching then BY.Query() end
    BY.Render()
end

function BY.Hide()
    win:Hide()
end

win:SetScript("OnHide", function()
    TakePad(false)
    BY.held, stickY, stickNext, rightY, rightHeld = nil, 0, nil, 0, false
    filterBox:Hide()
    if D then BY.CloseItem() end
    local page = CurrentPage()
    if page and page.frame then page.Hide() end
    if GameTooltip:GetOwner() == win then GameTooltip:Hide() end
    IC.AuctionConfirm.Hide()
    SyncNative()
end)

IC.Upgrades.OnChange(function()
    if not win:IsShown() then return end
    BY.FilterResults()
    BY.Render()
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_FAILURE", "ITEM_KEY_ITEM_INFO_RECEIVED",
    "GET_ITEM_INFO_RECEIVED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE",
    "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "AUCTION_HOUSE_SHOW_ERROR", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        BY.results = {}
        -- (after the game's own window has settled, and its own first query)
        C_Timer.After(0.4, function()
            if IC.db and S().buy then BY.Show() end
        end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        -- (listings change: looked up again next visit)
        wipe(prefetched)
        wipe(versionCache)
        win:Hide()
        SyncNative()
    elseif not win:IsShown() then
        return
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        ResultsIn()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        BY.searching = false
        BY.Render()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- (many at once: worked out once, a moment later)
        if not BY.versionsQueued then
            BY.versionsQueued = true
            C_Timer.After(0.2, function()
                BY.versionsQueued = false
                VersionsLoaded()
            end)
        end
    elseif event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        BY.Render()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if BY.queryWaiting then SendQuery() end
    elseif event == "COMMODITY_PRICE_UPDATED" then
        if D and D.state == "quote" then
            local unit, total = ...
            D.state, D.quote, D.message = "confirm", { unit = unit, total = total }, nil
            ConfirmQuote(unit, total)
            BY.Render()
        end
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" or event == "COMMODITY_PURCHASE_FAILED" then
        if D then
            D.state, D.quote, D.message = nil, nil, "Couldn't buy: the price changed or they're gone"
            BY.SearchItem()
            D.message = "Couldn't buy: the price changed or they're gone"
        end
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if D then Bought(D.qty .. " × " .. (D.info.itemName or "item")) end
        BY.Query(true)
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if D and D.state == "buying" then Bought(D.info.itemName or "item") end
        BY.Query(true)
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        if D and D.state == "buying" then
            D.state, D.message = nil, "Couldn't buy it"
            BY.Render()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        win:Hide()
    end
end)
