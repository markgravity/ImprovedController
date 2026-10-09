-- The Sell panel: at the auction house, Square on a bag item (the bag
-- window's cursor on it) opens it beside the bags. Kept simple: what is
-- sold (the item, how many), a small chart of its price over the last
-- days, and one price, suggested from the listings now and its history
-- (Auction.lua). Left / right move the price (held: faster), up / down the
-- duration (longer / shorter), Triangle goes through the suggestions
-- (undercut, match, usual), Cross sells, asking first in a popup
-- (AuctionConfirm.lua; a price the server warns about: a second one),
-- Circle closes. How many is
-- the Auction tab's; the duration starts at the last one picked (also the
-- Auction tab's). "Sell" joins the bag window's button legend while the
-- panel can open; Square is watched, not taken: the game's own Square at
-- the auction house only shows the item in its Sell tab.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local A = IC.Auction
local AH = C_AuctionHouse

local SL = {}
IC.AuctionSell = SL

local SELL_KEY = "PAD3"
local PANEL_W = 340
local CHART_H = 110
local REPEAT_DELAY, REPEAT_EVERY, FAST_AFTER = 0.35, 0.07, 1.5
local DURATIONS = A.Durations()

local function Atlas(tex, name)
    if IC.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local function Glyph(key)
    return IC.GlyphText(key, 24)
end

-- The game's focus colour (controller options: gold, black, blue)
local function FocusColor()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local value = tonumber(get and get("GamepadFocusStateColor") or 1) or 1
    if value == 2 then return 0, 0, 0 end
    if value == 3 then return 0.3, 0.5, 1 end
    return 1, 0.9, 0.4
end

---------------------------------------------------------------------------
-- The panel: Forever's flat panel, the item along its top, the chart,
-- the lines to set, the money it makes; a button legend under it
---------------------------------------------------------------------------
local ok, panel = pcall(K.NewFrame, "Frame", "ImprovedControllerAuctionSell", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    panel = K.NewFrame("Frame", "ImprovedControllerAuctionSell", UIParent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
panel:SetSize(PANEL_W, 384)
panel:SetFrameStrata("DIALOG")
panel:SetPoint("CENTER")
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
SL.panel = panel
-- (Esc closes it, as the game's own windows)
tinsert(UISpecialFrames, panel:GetName())

local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(panel, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

local glowHolder = K.NewFrame("Frame", nil, panel)
local glowRoot = panel.NineSlice or panel
glowHolder:SetPoint("TOPLEFT", glowRoot, "TOPLEFT", -10, 14)
glowHolder:SetPoint("BOTTOMRIGHT", glowRoot, "BOTTOMRIGHT", 14, -14)
glowHolder:SetFrameLevel(panel:GetFrameLevel() + 20)
local glow = glowHolder:CreateTexture(nil, "OVERLAY")
glow:SetAllPoints()
glow:SetShown(Atlas(glow, "gamepad-uiframemetal-focus") or false)

-- The item
local icon = panel:CreateTexture(nil, "ARTWORK")
icon:SetSize(40, 40)
icon:SetPoint("TOPLEFT", 16, -32)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local iconBorder = panel:CreateTexture(nil, "OVERLAY")
iconBorder:SetPoint("TOPLEFT", icon, -1, 1)
iconBorder:SetPoint("BOTTOMRIGHT", icon, 1, -1)
iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
iconBorder:SetBlendMode("ADD")
iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
local count = panel:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
local nameText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
nameText:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
nameText:SetJustifyH("LEFT")
nameText:SetWordWrap(false)
local subText = K.ChatText(panel, 11, KC.help)
subText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
subText:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
subText:SetJustifyH("LEFT")

---------------------------------------------------------------------------
-- The chart (AuctionChart.lua): its price history, the lowest now, the
-- price asked
---------------------------------------------------------------------------
local chart = IC.AuctionChart.New(panel, "Yours")
chart:SetPoint("TOPLEFT", 14, -82)
chart:SetPoint("TOPRIGHT", -14, -82)
chart:SetHeight(CHART_H)

---------------------------------------------------------------------------
-- The price: big, in the middle, between arrows; which suggestion it is
-- under it, then what it is worth against the market
---------------------------------------------------------------------------
local priceText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
priceText:SetPoint("TOP", chart, "BOTTOM", 0, -16)
local leftArrow = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
leftArrow:SetPoint("RIGHT", priceText, "LEFT", -14, 0)
leftArrow:SetText("‹")
local rightArrow = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
rightArrow:SetPoint("LEFT", priceText, "RIGHT", 14, 0)
rightArrow:SetText("›")
local presetText = K.ChatText(panel, 12, KC.dimGold)
presetText:SetPoint("TOP", priceText, "BOTTOM", 0, -6)
local infoText = K.ChatText(panel, 11, KC.cream2)
infoText:SetPoint("TOP", presetText, "BOTTOM", 0, -10)
infoText:SetWidth(PANEL_W - 32)
infoText:SetJustifyH("CENTER")
local warnText = K.ChatText(panel, 11, KC.warn)
warnText:SetPoint("TOP", infoText, "BOTTOM", 0, -4)
warnText:SetWidth(PANEL_W - 32)
warnText:SetJustifyH("CENTER")
-- The receipt along the bottom: label left, amount right, a rule above
-- the profit
local RECEIPT_LINE = 18
local receipt = K.NewFrame("Frame", nil, panel)
receipt:SetPoint("BOTTOMLEFT", 22, 12)
receipt:SetPoint("BOTTOMRIGHT", -22, 12)
receipt:SetHeight(RECEIPT_LINE * 3 + 7)
local receiptLines = {}
for i = 1, 3 do
    local y = -(i - 1) * RECEIPT_LINE - (i == 3 and 7 or 0)
    local label = K.ChatText(receipt, i == 3 and 13 or 12, i == 3 and KC.cream or KC.help)
    label:SetPoint("TOPLEFT", 0, y)
    local value = K.ChatText(receipt, i == 3 and 13 or 12, i == 3 and KC.title or KC.cream)
    value:SetPoint("TOPRIGHT", 0, y)
    value:SetJustifyH("RIGHT")
    receiptLines[i] = { label = label, value = value }
end
local rule = receipt:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetPoint("TOPLEFT", 0, -RECEIPT_LINE * 2 - 1)
rule:SetPoint("TOPRIGHT", 0, -RECEIPT_LINE * 2 - 1)
rule:SetColorTexture(0.45, 0.38, 0.25, 0.9)

-- The button legend under the panel
local legend = K.NewFrame("Frame", nil, panel, "BackdropTemplate")
legend:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, -6)
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
-- The state: S = { bag, slot, loc, itemID, commodity, itemLevel, vendor,
-- price, preset, presets, qty, maxQty, duration, lowestNow, listed, warn,
-- searching, pending (a post the server wants confirmed) }
---------------------------------------------------------------------------
local S

local function Deposit()
    if not S.loc:IsValid() then return nil end
    if S.commodity then return AH.CalculateCommodityDeposit(S.itemID, S.duration, S.qty) end
    return AH.CalculateItemDeposit(S.loc, S.duration, S.qty)
end

function SL.Render()
    if not S or not panel:IsShown() then return end
    titleText:SetText("Sell")
    glow:SetVertexColor(FocusColor())
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[S.quality or 1]
    icon:SetTexture(S.icon or 134400)
    iconBorder:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
    count:SetText(S.qty > 1 and S.qty or "")
    nameText:SetText(S.name or ("item " .. S.itemID))
    nameText:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
    subText:SetText((S.itemLevel and S.itemLevel > 0 and not S.commodity) and ("Item level " .. S.itemLevel)
        or ((S.vendor or 0) > 0 and ("Vendor pays " .. A.Money(S.vendor)) or ""))

    chart:Draw(S)

    priceText:SetText(A.Money(S.price))
    presetText:SetText((S.qty > 1 and "each  ·  " or "") .. (S.presetLabel or "Your own price"))
    local fr, fg, fb = FocusColor()
    leftArrow:SetTextColor(fr, fg, fb)
    rightArrow:SetTextColor(fr, fg, fb)

    local market = A.MarketPrice(S.itemID)
    local parts = {}
    if S.searching then
        parts[#parts + 1] = "Checking the auction house..."
    elseif S.lowestNow then
        parts[#parts + 1] = "Lowest now " .. A.Money(S.lowestNow)
    elseif S.searched then
        parts[#parts + 1] = "None listed now"
    end
    if market then parts[#parts + 1] = "usually " .. A.Money(market) end
    infoText:SetText(table.concat(parts, "   ·   "))
    warnText:SetText(S.warn or "")

    local total = S.price * S.qty
    local deposit = Deposit()
    -- (the deposit comes back when it sells: the profit is the sale less the cut)
    local lines = {
        { "Duration", "|cffc9a25a‹|r " .. DURATIONS[S.duration] .. " |cffc9a25a›|r" },
        { "Deposit |cff9d917a(back if sold)|r", deposit and A.Money(deposit) or "?" },
        { "Profit |cff9d917a(" .. S.qty .. " × after " .. math.floor(A.Cut() * 100) .. "% cut)|r",
            A.Money(total * (1 - A.Cut())) },
    }
    for i, line in ipairs(receiptLines) do
        line.label:SetText(lines[i][1])
        line.value:SetText(lines[i][2])
    end

    hints:SetText(Glyph("A") .. " Sell   " .. Glyph("DPAD_LR") .. " Price   " .. Glyph("DPAD_UD") .. " Duration   "
        .. Glyph("Y") .. " Suggested   " .. Glyph("B") .. " Close")
    legend:SetWidth(math.max(PANEL_W, hints:GetStringWidth() + 28))
end

---------------------------------------------------------------------------
-- Prices: the suggestion, the steps the D-pad moves it by
---------------------------------------------------------------------------
-- The suggestion again (new listings): a price set by hand is kept, a
-- suggested one picked with Triangle stays that one, at its new price
local function Suggest()
    local price, presets, warn, key = A.Suggest(S.itemID, S.listings, S.vendor)
    S.presets, S.warn = presets, warn
    if S.touched and not S.presetLabel then return end
    local picked
    for _, p in ipairs(presets) do
        if p.key == (S.picked or key) then picked = p end
    end
    if picked then
        S.price, S.preset, S.presetLabel = picked.price, picked.key, picked.label
    else
        -- (nothing known: three times what a vendor pays)
        S.price, S.preset, S.presetLabel = price, key, "Vendor price × 3"
    end
end

-- A price's step: about 1-10 % of it, in a round coin
local function Step(price)
    local step = 1
    while step * 100 <= price do step = step * 10 end
    -- (whole silver only, where the auction house takes no copper)
    if AH.SupportsCopperValues and not AH.SupportsCopperValues() then step = math.max(step, 100) end
    return step
end

local function NextPreset()
    if not S.presets or #S.presets == 0 then return end
    local at = 0
    for i, p in ipairs(S.presets) do
        if p.key == S.preset then at = i end
    end
    local p = S.presets[at % #S.presets + 1]
    S.preset, S.presetLabel, S.price, S.picked = p.key, p.label, p.price, p.key
end

local function Adjust(dir, mult)
    local step = Step(S.price) * (mult or 1)
    -- Kept on the step's round numbers
    local price = math.floor((S.price + dir * step) / step + 0.5) * step
    S.price = A.Round(math.max(price, 1))
    S.preset, S.presetLabel, S.picked, S.touched, S.pending, S.armed = nil, nil, nil, true, nil, nil
    -- (kept: its next sale starts at it)
    A.SetMyPrice(S.itemID, S.price)
end

---------------------------------------------------------------------------
-- Searching, posting
---------------------------------------------------------------------------
function SL.Search()
    if not S then return end
    S.searching, S.pending = true, nil
    local itemID = S.itemID
    A.Search(itemID, S.commodity, S.itemLevel, function(listings)
        if not S or S.itemID ~= itemID then return end
        S.searching, S.searched = false, true
        S.listings = listings or S.listings
        S.lowestNow, S.listed = nil, 0
        for _, l in ipairs(S.listings or {}) do
            S.lowestNow = S.lowestNow or l.unit
            S.listed = S.listed + l.count
        end
        Suggest()
        if not listings then S.warn = "No answer from the auction house: prices from history" end
        SL.Render()
    end)
    SL.Render()
end

local function Posted()
    IC.Print("posted " .. S.qty .. " × " .. (S.link or S.name or "item") .. " at " .. A.Money(S.price)
        .. " each (" .. DURATIONS[S.duration] .. ").")
    SL.Close()
end

-- The item still where it was (nothing moved in the bags meanwhile)
local function StillThere(state)
    return S == state and S.loc:IsValid() and C_Item.GetItemID(S.loc) == S.itemID
end

-- Posting, from the popup's Cross (the server wants a hardware event); a
-- price the server warns about: a second popup, its Cross posts it
local function DoPost(state)
    if not StillThere(state) or IC.InCombat() then return end
    local duration, qty, price = S.duration, S.qty, S.price
    local needsConfirm
    if S.commodity then
        needsConfirm = AH.PostCommodity(S.loc, duration, qty, price)
    else
        needsConfirm = AH.PostItem(S.loc, duration, qty, nil, price)
    end
    if not needsConfirm then return Posted() end
    IC.AuctionConfirm.Show({
        title = "Price warning", over = panel,
        icon = S.icon, count = qty, name = S.name or "item", quality = S.quality,
        sub = "|cffff7a5cThe auction house warns about this price|r",
        lines = { { "Price each", A.Money(price) }, { "Duration", DURATIONS[duration] } },
        total = { "Post it anyway?", A.Money(price * qty) },
        accept = "Post anyway",
        onAccept = function()
            if not StillThere(state) then return end
            if S.commodity then
                AH.ConfirmPostCommodity(S.loc, duration, qty, price)
            else
                AH.ConfirmPostItem(S.loc, duration, qty, nil, price)
            end
            Posted()
        end,
    })
end

-- Cross: asked first in a popup (what, how many, at what, how long, what it brings)
function SL.Post()
    if not S or IC.InCombat() then return end
    if not StillThere(S) then return SL.Close() end
    local state = S
    local deposit = Deposit()
    IC.AuctionConfirm.Show({
        title = "Sell", over = panel,
        icon = S.icon, count = S.qty, name = S.name or "item", quality = S.quality,
        sub = S.presetLabel or "Your own price",
        lines = {
            { "Price each", A.Money(S.price) },
            { "Duration", DURATIONS[S.duration] },
            { "Deposit |cff9d917a(back if sold)|r", deposit and A.Money(deposit) or "?" },
        },
        total = { "Profit |cff9d917a(" .. S.qty .. " × after " .. math.floor(A.Cut() * 100) .. "% cut)|r",
            A.Money(S.price * S.qty * (1 - A.Cut())) },
        accept = "Sell",
        onAccept = function() DoPost(state) end,
    })
end

---------------------------------------------------------------------------
-- Opening, closing
---------------------------------------------------------------------------
-- While the panel has the pad, the game's own cursor and the bag window's
-- glow are hidden, so only ours shows
local nativeFocus = {}
local function HideNativeFocus(hide)
    if hide then
        wipe(nativeFocus)
        local nav = _G.SmartNavigation
        if nav and nav.Pointer then nativeFocus[#nativeFocus + 1] = nav.Pointer end
        local frames = { _G.ContainerFrameCombinedBags, _G.AuctionHouseFrame }
        for i = 1, NUM_CONTAINER_FRAMES or 13 do frames[#frames + 1] = _G["ContainerFrame" .. i] end
        for _, f in ipairs(frames) do
            if f and f.FrameGlow then nativeFocus[#nativeFocus + 1] = f.FrameGlow end
        end
        for _, f in ipairs(nativeFocus) do f:SetAlpha(0) end
    else
        for _, f in ipairs(nativeFocus) do f:SetAlpha(1) end
        wipe(nativeFocus)
    end
end

local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)

local function TakePad(on)
    if catcher.EnableGamePadButton and not IC.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end

function SL.Open(bag, slot)
    if IC.InCombat() or not A.Available() or not A.IsOpen() then return end
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not loc:IsValid() or not AH.IsSellItemValid(loc, false) then return end
    local status = AH.GetItemCommodityStatus(loc)
    if status == Enum.ItemCommodityStatus.Unknown then
        IC.Print("that item's details haven't loaded yet: try again.")
        return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return end
    local itemID = info.itemID
    local name, _, quality, _, _, _, _, _, _, _, vendor = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(itemID)
    local commodity = status == Enum.ItemCommodityStatus.Commodity
    local maxQty = (AH.GetAvailablePostCount and AH.GetAvailablePostCount(loc)) or info.stackCount or 1
    maxQty = math.max(1, maxQty)
    local stack = math.min(info.stackCount or 1, maxQty)
    local want = A.Settings().quantity
    S = {
        bag = bag, slot = slot, loc = loc, itemID = itemID, commodity = commodity,
        itemLevel = (not commodity and C_Item.GetCurrentItemLevel) and C_Item.GetCurrentItemLevel(loc) or nil,
        name = name or (info.hyperlink and info.hyperlink:match("%[(.-)%]")), link = info.hyperlink,
        icon = info.iconFileID, quality = quality or info.quality, vendor = vendor or 0,
        maxQty = maxQty, stack = stack,
        qty = want == "one" and 1 or want == "stack" and stack or maxQty,
        duration = A.Settings().duration,
    }
    Suggest()
    -- Beside the bags, between them and the auction house
    panel:ClearAllPoints()
    local bags = _G.ContainerFrameCombinedBags
    if bags and bags:IsShown() then
        panel:SetPoint("TOPRIGHT", bags, "TOPLEFT", -12, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 120, 40)
    end
    panel:Show()
    TakePad(true)
    HideNativeFocus(true)
    SL.Search()
end

function SL.Close()
    panel:Hide()
end

function SL.IsShown()
    return panel:IsShown()
end

panel:SetScript("OnHide", function()
    IC.AuctionConfirm.Hide()
    TakePad(false)
    HideNativeFocus(false)
    A.CancelSearch()
    SL.held = nil
    S = nil
end)

---------------------------------------------------------------------------
-- The pad, while the panel is up
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PAD1 = "A", PAD2 = "B", PAD4 = "Y",
}
local REPEATS = { LEFT = true, RIGHT = true }

local function Press(name, fast)
    -- (a popup up: its press)
    if IC.AuctionConfirm.Press(name) then return end
    if name == "LEFT" or name == "RIGHT" then
        Adjust(name == "RIGHT" and 1 or -1, fast and 10 or 1)
    elseif name == "UP" or name == "DOWN" then
        -- Up: longer, down: shorter
        S.duration = math.max(1, math.min(#DURATIONS, S.duration + (name == "UP" and 1 or -1)))
        -- (kept: the next sale starts at it)
        A.Settings().duration = S.duration
        S.pending, S.armed = nil, nil
    elseif name == "Y" then
        NextPreset()
        S.pending, S.armed = nil, nil
    elseif name == "A" then
        return SL.Post()
    end
    SL.Render()
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        if not name or not S then return end
        -- Circle on its release: on the press, the release would reach the
        -- bag window, which closes the bags
        if name == "B" then return end
        Press(name)
        if REPEATS[name] then SL.held = { name = name, at = GetTime(), next = GetTime() + REPEAT_DELAY } end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if name == "B" then
            if IC.AuctionConfirm.IsShown() then return IC.AuctionConfirm.Press("B") end
            return SL.Close()
        end
        if SL.held and SL.held.name == name then SL.held = nil end
    end)
end

-- Held: again every REPEAT_EVERY, in bigger steps after FAST_AFTER
panel:SetScript("OnUpdate", function()
    local held = SL.held
    if not held or not S then return end
    local now = GetTime()
    if now < held.next then return end
    held.next = now + REPEAT_EVERY
    Press(held.name, now - held.at > FAST_AFTER)
end)

---------------------------------------------------------------------------
-- Square on a bag item at the auction house, and "Sell" in the bag
-- window's button legend: a frame of our own in the game's prompt
-- template after its last prompt, the legend's box only widened to hold
-- it (never anything of ours handed to the game's legend or bindings)
---------------------------------------------------------------------------
local LEGEND_PAD, PROMPT_GAP = 10, 15   -- the game's legend layout (InputLegendPromptGroup.lua)

local function BagLegendBox()
    local footer = _G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags.gamepadFooter
    local legendFrame = footer and footer.isShown and footer.inputLegend
    local box = legendFrame and legendFrame.promptContainerFrame
    return box and box:IsVisible() and box or nil
end

local bagPrompt
local function BagPrompt()
    if bagPrompt == nil then
        bagPrompt = false
        local bags = _G.ContainerFrameCombinedBags
        if not bags then return nil end
        local holder = K.NewFrame("Frame", nil, bags)
        local made, prompt = pcall(function()
            local p = K.NewFrame("Frame", nil, holder, "InputPromptOneIconWithTextTemplate")
            p:SetPromptInputIconKey(1, _G.GAMEPAD_FACE_LEFT or SELL_KEY)
            p:SetPromptText("Sell")
            p:EnablePrompt()
            return p
        end)
        if made and prompt then
            holder.prompt = prompt
            holder:Hide()
            bagPrompt = holder
        end
    end
    return bagPrompt or nil
end

local function PlaceBagPrompt(holder, box)
    local width = box:GetWidth()
    if holder.box ~= box or not holder.setWidth or math.abs(width - holder.setWidth) > 0.5 then
        holder.box, holder.baseWidth = box, width
        holder.prompt:ClearAllPoints()
        holder.prompt:SetPoint("TOPLEFT", box, "TOPLEFT", width - LEGEND_PAD + PROMPT_GAP, -LEGEND_PAD)
    end
    holder:SetFrameLevel(box:GetFrameLevel() + 2)
    holder.setWidth = holder.baseWidth + PROMPT_GAP + holder.prompt:GetWidth()
    box:SetWidth(holder.setWidth)
end

local function HideBagPrompt()
    local holder = bagPrompt
    if not holder or not holder:IsShown() then return end
    holder:Hide()
    local box = holder.box
    if box and holder.setWidth and math.abs(box:GetWidth() - holder.setWidth) <= 0.5 then
        box:SetWidth(holder.baseWidth)
    end
    holder.box, holder.setWidth = nil, nil
end

-- The bag item the bag window's cursor is on, when it can be auctioned
local lastButton, lastItem, recheckAt = nil, nil, 0
local function FocusedItem()
    local nav = _G.SmartNavigation
    if not nav or not nav.GetCurrentButton then return nil end
    local got, button = pcall(nav.GetCurrentButton, nav)
    if not got or not button or not button.GetBagID or not button.hasItem or not button:IsVisible() then
        lastButton, lastItem = nil, nil
        return nil
    end
    if button == lastButton and GetTime() < recheckAt then return lastItem end
    lastButton, recheckAt, lastItem = button, GetTime() + 0.25, nil
    local bag, slot = button:GetBagID(), button:GetID()
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if loc:IsValid() and AH.IsSellItemValid(loc, false) then lastItem = { bag = bag, slot = slot } end
    return lastItem
end

local squareWasDown = false
local focused   -- the item under the cursor a frame ago (the game's own Square may move it)
local watch = CreateFrame("Frame")
watch:Hide()
watch:SetScript("OnUpdate", function()
    local can = A.Settings().sell and A.IsOpen() and not panel:IsShown() and not IC.InCombat()
    local before = focused
    focused = can and FocusedItem() or nil
    local box = focused and BagLegendBox()
    local holder = box and BagPrompt()
    if holder then
        PlaceBagPrompt(holder, box)
        holder:Show()
    else
        HideBagPrompt()
    end
    local down = IsKeyDown and IsKeyDown(SELL_KEY) or false
    local item = focused or before
    if down and not squareWasDown and can and item then SL.Open(item.bag, item.slot) end
    squareWasDown = down
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_POST_WARNING",
    "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        squareWasDown = IsKeyDown and IsKeyDown(SELL_KEY) or false
        watch:Show()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        watch:Hide()
        HideBagPrompt()
        SL.Close()
    elseif event == "AUCTION_HOUSE_POST_WARNING" then
        -- Ours to confirm (our popup), not the game's dialog: it would
        -- confirm its own Sell tab's post, not this one
        -- (after the game's own handler: its UI loads later, so runs after
        -- ours; the event comes during the post call itself)
        if S then
            C_Timer.After(0, function()
                if StaticPopup_Hide then StaticPopup_Hide("AUCTION_HOUSE_POST_WARNING") end
            end)
            SL.Render()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- The item moved or gone: closed; still there: what can be sold again
        if S then
            if not S.loc:IsValid() or C_Item.GetItemID(S.loc) ~= S.itemID then return SL.Close() end
            local max = AH.GetAvailablePostCount and AH.GetAvailablePostCount(S.loc)
            if max and max > 0 then
                S.maxQty = max
                S.qty = math.min(S.qty, max)
            end
            SL.Render()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        SL.Close()
    end
end)

A.OnChange(function() SL.Render() end)
