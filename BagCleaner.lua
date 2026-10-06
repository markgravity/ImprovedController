-- Bag clean-up panel: with the bags open, R2 + R3 (or the button(s) bound
-- in the General tab) opens a panel listing what is safe to throw
-- away: junk (grey items, white "junk"), and cheap white gear and odds and
-- ends no profession, quest or class uses. Laid out as Forever's loot
-- window: a list of item cards, the picked one's tooltip beside it. Cross
-- destroys the picked item (press twice: once to arm), holding Square and
-- letting go destroys them all, Circle closes. Never in combat.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C

local BC = {}
IC.BagCleaner = BC

local HOLD_ALL = 1.2          -- Square held this long, then let go: destroy all
local CHEAP = 100             -- a stack worth less than this (copper) is "cheap"
local DEFAULT_KEY = "PADRTRIGGER+PADRSTICK"   -- one button, or "held+pressed"

---------------------------------------------------------------------------
-- Finding what to throw away
---------------------------------------------------------------------------
-- Item classes never offered: consumables, containers, reagents,
-- projectiles, quivers, recipes, trade goods, quest items, keys
local KEEP_CLASS = { [0] = true, [1] = true, [5] = true, [6] = true, [7] = true, [9] = true, [11] = true,
    [12] = true, [13] = true }

local function ItemInfo(id)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
    return GetItemInfo(id)
end

local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end
end

local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- Why an item can go, or nil
local function Reason(info)
    local _, _, quality, _, _, _, _, _, _, _, sellPrice, classID, subclassID = ItemInfo(info.itemID)
    quality = quality or info.quality
    if quality == nil then return nil end
    if quality == 0 then return "Junk" end
    if quality ~= 1 or not classID or KEEP_CLASS[classID] then return nil end
    -- Never something with a Use (Hearthstone...) or that can't be sold
    -- (quest-like, special)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if info.hasNoValue or (sellPrice or 0) == 0 or (getSpell and getSpell(info.itemID)) then return nil end
    if classID == 15 and subclassID == 0 then return "Junk" end
    local value = (sellPrice or 0) * (info.stackCount or 1)
    if (classID == 2 or classID == 4 or classID == 15) and value < CHEAP and not info.hasNoValue then
        return "Cheap"
    end
    return nil
end

function BC.Scan()
    local list = {}
    local last = NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, NumSlots(bag) do
            local info = SlotInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                local reason = Reason(info)
                if reason then
                    local sellPrice = select(11, ItemInfo(info.itemID)) or 0
                    list[#list + 1] = {
                        bag = bag, slot = slot, itemID = info.itemID, link = info.hyperlink,
                        icon = info.iconFileID, count = info.stackCount or 1, quality = info.quality or 0,
                        value = sellPrice * (info.stackCount or 1), reason = reason,
                    }
                end
            end
        end
    end
    -- Junk first, then the cheapest
    table.sort(list, function(a, b)
        if (a.reason == "Junk") ~= (b.reason == "Junk") then return a.reason == "Junk" end
        return a.value < b.value
    end)
    return list
end

---------------------------------------------------------------------------
-- Destroying (from a button press; never in combat)
---------------------------------------------------------------------------
local blocked = false

local function DestroyOne(entry)
    local info = SlotInfo(entry.bag, entry.slot)
    if not info or info.itemID ~= entry.itemID or info.isLocked then return false end
    ClearCursor()
    C_Container.PickupContainerItem(entry.bag, entry.slot)
    if not CursorHasItem() then return false end
    blocked = false
    DeleteCursorItem()
    if CursorHasItem() then ClearCursor() end
    return not blocked
end

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:SetScript("OnEvent", function(_, _, addon, fn)
    if addon == IC.name and tostring(fn):find("DeleteCursorItem") then blocked = true end
end)

---------------------------------------------------------------------------
-- The panel: Forever's loot window (its flat panel, item cards, rarity
-- tag, the gamepad focus glow and arrow) with a button legend under it
---------------------------------------------------------------------------
local ROWS, ROW_H, PANEL_W = 6, 48, 262

local function Atlas(tex, name)
    if IC.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

local ok, panel = pcall(K.NewFrame, "Frame", "ImprovedControllerBagCleaner", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    panel = K.NewFrame("Frame", "ImprovedControllerBagCleaner", UIParent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
panel:SetSize(PANEL_W, 52 + ROWS * ROW_H)
panel:SetFrameStrata("DIALOG")
panel:SetPoint("CENTER")
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
BC.panel = panel

-- The game's focus look (FocusEffects.lua): the metal frame glow round a
-- focused panel, in the focus colour and opacity set in the game's
-- controller options (GamepadFocusStateColor: gold, black, blue)
local function FocusColor()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local value = tonumber(get and get("GamepadFocusStateColor") or 1) or 1
    local alpha = tonumber(get and get("GamepadFocusStateOpacity") or 1) or 1
    if value == 2 then return 0, 0, 0, alpha end
    if value == 3 then return 0.3, 0.5, 1, alpha end
    return 1, 0.9, 0.4, alpha
end

local glowHolder = K.NewFrame("Frame", nil, panel)
local glowRoot = panel.NineSlice or panel
glowHolder:SetPoint("TOPLEFT", glowRoot, "TOPLEFT", -10, 14)
glowHolder:SetPoint("BOTTOMRIGHT", glowRoot, "BOTTOMRIGHT", 14, -14)
glowHolder:SetFrameLevel(panel:GetFrameLevel() + 20)
local glow = glowHolder:CreateTexture(nil, "OVERLAY")
glow:SetAllPoints()
glow:SetShown(Atlas(glow, "gamepad-uiframemetal-focus") or false)

local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(panel, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

-- The count and worth, along the panel's bottom
local summary = K.ChatText(panel, 11, KC.help)
summary:SetPoint("BOTTOM", panel, "BOTTOM", 0, 9)
summary:SetJustifyH("CENTER")

local more = { up = panel:CreateTexture(nil, "OVERLAY"), down = panel:CreateTexture(nil, "OVERLAY") }
for key, t in pairs(more) do
    t:SetSize(20, 20)
    if not Atlas(t, "gamepad-smartnavcursor-arrowscroll") then t:SetTexture("Interface\\AddOns\\ImprovedController\\textures\\ic_tri") end
    t:SetPoint(key == "up" and "TOP" or "BOTTOM", panel, key == "up" and "TOP" or "BOTTOM", 0, key == "up" and -22 or 20)
    if key == "up" then t:SetTexCoord(0, 1, 1, 0) end
end

-- The rows: an item card each
local rows = {}
for i = 1, ROWS do
    local r = K.NewFrame("Button", nil, panel)
    r:SetSize(PANEL_W - 22, ROW_H - 4)
    r:SetPoint("TOPLEFT", 11, -26 - (i - 1) * ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if not Atlas(r.bg, "Looting_ItemCard_BG") then r.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8) end
    r.stroke = r:CreateTexture(nil, "BORDER")
    r.stroke:SetAllPoints()
    Atlas(r.stroke, "Looting_ItemCard_Stroke_Normal")
    -- Focused: the card's bright stroke, in the focus colour (as a bag slot's)
    r.focus = r:CreateTexture(nil, "OVERLAY")
    r.focus:SetAllPoints()
    if not Atlas(r.focus, "Looting_ItemCard_Stroke_ClickState") then r.focus:SetColorTexture(1, 0.8, 0.2, 0.25) end
    r.focusGlow = r:CreateTexture(nil, "OVERLAY", nil, 1)
    r.focusGlow:SetAllPoints()
    r.focusGlow:SetBlendMode("ADD")
    Atlas(r.focusGlow, "Looting_ItemCard_HighlightState")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(36, 36)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.iconBorder = r:CreateTexture(nil, "OVERLAY")
    r.iconBorder:SetPoint("TOPLEFT", r.icon, -1, 1)
    r.iconBorder:SetPoint("BOTTOMRIGHT", r.icon, 1, -1)
    r.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    r.iconBorder:SetBlendMode("ADD")
    r.iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    r.count = r:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", -1, 1)
    r.tag = r:CreateTexture(nil, "BORDER", nil, 1)
    r.tag:SetSize(90, 12)
    r.tag:SetPoint("TOPRIGHT", 0, 0)
    Atlas(r.tag, "Looting_RarityTag_Frame")
    r.tagText = r:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny2")
    r.tagText:SetPoint("TOPRIGHT", -4, -1)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -4)
    r.name:SetPoint("RIGHT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.value = K.ChatText(r, 11, KC.help)
    r.value:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 3)
    -- The game's own focus cursor (SmartNavigation's pointer): its large
    -- arrow at 80 %, in the cursor colour, bobbing at the row's left edge
    local pointer = K.NewFrame("Frame", nil, r)
    pointer:SetSize(10, 10)
    pointer:SetPoint("RIGHT", r, "LEFT", 4, 0)
    pointer:SetFrameLevel(r:GetFrameLevel() + 5)
    r.arrow = pointer:CreateTexture(nil, "ARTWORK", nil, 2)
    r.arrow:SetSize(42 * 0.8, 70 * 0.8)
    r.arrow:SetPoint("RIGHT", pointer, "RIGHT", 0, 0)
    if not Atlas(r.arrow, "gamepad-largecursor-white") then
        r.arrow:SetSize(22, 22)
        r.arrow:SetTexture("Interface\\AddOns\\ImprovedController\\textures\\ic_tri")
        r.arrow:SetRotation(math.pi / 2)
    end
    local bob = r.arrow:CreateAnimationGroup()
    bob:SetLooping("REPEAT")
    local out = bob:CreateAnimation("Translation")
    out:SetOffset(4, 0)
    out:SetDuration(1)
    out:SetSmoothing("IN_OUT")
    out:SetOrder(1)
    local back = bob:CreateAnimation("Translation")
    back:SetOffset(-4, 0)
    back:SetDuration(1)
    back:SetSmoothing("IN_OUT")
    back:SetOrder(2)
    bob:Play()
    r:SetScript("OnClick", function()
        BC.index = BC.top + i - 1
        BC.armed = nil
        BC.Render()
    end)
    rows[i] = r
end

-- The button legend under the panel, as the game's own panels have; it
-- grows leftwards, clear of the bag window's own legend on the right
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

local holdBar = legend:CreateTexture(nil, "OVERLAY")
holdBar:SetHeight(3)
holdBar:SetPoint("BOTTOMLEFT", 5, 4)
holdBar:Hide()

BC.items, BC.index, BC.top = {}, 1, 1

-- 10350 -> "1 [gold] 3 [silver] 50 [copper]", with the game's coin icons
local COINS = {
    { 10000, "Interface\\MoneyFrame\\UI-GoldIcon" },
    { 100, "Interface\\MoneyFrame\\UI-SilverIcon" },
    { 1, "Interface\\MoneyFrame\\UI-CopperIcon" },
}
local function Money(copper)
    copper = math.floor(copper or 0)
    local parts = {}
    for _, coin in ipairs(COINS) do
        local n = math.floor(copper / coin[1])
        copper = copper - n * coin[1]
        if n > 0 then parts[#parts + 1] = n .. " |T" .. coin[2] .. ":0:0:2:0|t" end
    end
    return #parts > 0 and table.concat(parts, " ") or ("0 |T" .. COINS[3][2] .. ":0:0:2:0|t")
end

local function Glyph(key)
    return IC.GlyphText(key, 24)
end

function BC.Render()
    local items = BC.items
    local n = #items
    BC.index = math.max(1, math.min(BC.index, math.max(1, n)))
    if BC.index < BC.top then BC.top = BC.index end
    if BC.index > BC.top + ROWS - 1 then BC.top = BC.index - ROWS + 1 end
    BC.top = math.max(1, math.min(BC.top, math.max(1, n - ROWS + 1)))
    local total = 0
    for _, e in ipairs(items) do total = total + e.value end
    titleText:SetText("Clean up bags")
    local focused = BC.focus ~= "bags"
    glow:SetVertexColor(FocusColor())
    glow:SetShown(focused and IC.HasAtlas("gamepad-uiframemetal-focus"))
    summary:SetText(n == 0 and "Nothing to throw away" or
        (n .. (n == 1 and " item" or " items") .. " · worth " .. Money(total)))
    more.up:SetShown(BC.top > 1)
    more.down:SetShown(BC.top + ROWS - 1 < n)
    for i, r in ipairs(rows) do
        local index = BC.top + i - 1
        local e = items[index]
        r:SetShown(e ~= nil)
        if e then
            local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality]
            local selected = index == BC.index and focused
            r.icon:SetTexture(e.icon or 134400)
            r.iconBorder:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
            r.count:SetText(e.count > 1 and e.count or "")
            local name = e.link and e.link:match("%[(.-)%]") or ("item " .. e.itemID)
            r.name:SetText(name)
            r.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
            r.value:SetText(e.value > 0 and Money(e.value) or "no value")
            r.tagText:SetText(e.reason)
            r.focus:SetShown(selected)
            r.focusGlow:SetShown(selected)
            r.arrow:SetShown(selected)
            if selected then
                local fr, fg, fb = FocusColor()
                r.focus:SetVertexColor(fr, fg, fb)
                r.focusGlow:SetVertexColor(fr, fg, fb, 0.35)
                local cursor = GAMEPAD_SMARTNAV_CURSOR_COLOR
                if cursor and cursor.GetRGBA then
                    r.arrow:SetVertexColor(cursor:GetRGBA())
                else
                    r.arrow:SetVertexColor(fr, fg, fb)
                end
            end
            r.stroke:SetAlpha(selected and 0 or 1)
        end
    end
    local e = focused and items[BC.index]
    if e then
        -- Over the bag side (the panel sits left of the bags, with little room
        -- further left); no "equipped" comparison beside it
        GameTooltip:SetOwner(panel, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 26, 0)
        GameTooltip:SetBagItem(e.bag, e.slot)
        GameTooltip:Show()
        for _, tip in ipairs({ _G.ShoppingTooltip1, _G.ShoppingTooltip2 }) do tip:Hide() end
    elseif GameTooltip:GetOwner() == panel then
        GameTooltip:Hide()
    end
    local destroy = BC.armed and "|cffff5c3cAgain to destroy|r" or "Destroy"
    if not focused then
        hints:SetText(Glyph("LT") .. " / " .. Glyph("RT") .. " Clean up bags")
    else
        hints:SetText((n > 0 and (Glyph("A") .. " " .. destroy .. "   " .. Glyph("X") .. " Destroy All (hold)   ") or "")
            .. Glyph("LT") .. " / " .. Glyph("RT") .. " Bags   " .. Glyph("B") .. " Close")
    end
    legend:SetWidth(math.max(PANEL_W, hints:GetStringWidth() + 28))
end

function BC.Refresh()
    if not panel:IsShown() then return end
    local current = BC.items[BC.index]
    BC.items = BC.Scan()
    -- Stay near the same place in the list
    if current then
        for i, e in ipairs(BC.items) do
            if e.bag == current.bag and e.slot == current.slot then BC.index = i end
        end
    end
    BC.Render()
end

---------------------------------------------------------------------------
-- The pad, while the panel is up (priority bindings; out of combat)
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", ESCAPE = "B",
    PADLTRIGGER = "SWITCH", PADRTRIGGER = "SWITCH",
}
-- Kept while the bags have the focus: the way back
local SWITCH_KEYS = { PADLTRIGGER = true, PADRTRIGGER = true }
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }

local function Move(step)
    local n = #BC.items
    if n == 0 then return end
    local i = BC.index + step
    if i >= 1 and i <= n then BC.index = i end
    BC.armed = nil
    BC.Render()
end

local lastName, lastDown, lastAt
function BC.Press(name, down)
    -- (the same press can arrive twice: as a pad button and as a binding)
    local now = GetTime()
    if name == lastName and down == lastDown and lastAt and now - lastAt < 0.05 then return end
    lastName, lastDown, lastAt = name, down, now
    -- L2 / R2 (L2 is the game's Shift: a quick tap): the focus over to the bag window and back
    if name == "SWITCH" then
        if down then BC.SetFocus(BC.focus == "bags" and "panel" or "bags") end
        return
    end
    if BC.focus == "bags" then return end
    if name == "X" then
        -- Hold, then let go: all of them
        if down then
            BC.holdStart = GetTime()
            holdBar:Show()
        elseif BC.holdStart then
            local held = GetTime() - BC.holdStart
            BC.holdStart = nil
            holdBar:Hide()
            if held >= HOLD_ALL then BC.DestroyAll() end
        end
        return
    end
    -- Circle on its release: closing on the press would hand the release to
    -- the bag window, which closes the bags
    if name == "B" then
        if not down then BC.Close() end
        return
    end
    if not down then return end
    if name == "UP" then Move(-1)
    elseif name == "DOWN" then Move(1)
    elseif name == "LEFT" then Move(-ROWS)
    elseif name == "RIGHT" then Move(ROWS)
    elseif name == "A" then
        local e = BC.items[BC.index]
        if not e then return end
        if BC.armed ~= e then
            BC.armed = e
            return BC.Render()
        end
        BC.armed = nil
        BC.Destroy(e)
    end
end

local buttons = {}
for key, name in pairs(KEYS) do
    local b = K.NewFrame("Button", "ImprovedControllerBagCleanerPad" .. key)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(_, _, down) BC.Press(name, down ~= false) end)
    buttons[key] = b
end

local function Bind()
    if IC.InCombat() then return end
    ClearOverrideBindings(panel)
    for key in pairs(KEYS) do
        local name = buttons[key]:GetName()
        if BC.focus == "bags" and not SWITCH_KEYS[key] then
            -- (the bag window's own navigation has it)
        elseif key == "ESCAPE" then
            SetOverrideBindingClick(panel, true, key, name)
        else
            for _, prefix in ipairs(PREFIXES) do SetOverrideBindingClick(panel, true, prefix .. key, name) end
        end
    end
end

-- Which has the pad: the panel (ours, the game's focus hidden) or the bag
-- window (the game's own navigation, ours dimmed; L2 / R2 come back)
function BC.SetFocus(focus)
    BC.focus = focus
    BC.armed, BC.holdStart = nil, nil
    holdBar:Hide()
    Bind()
    BC.TakePad(focus == "panel")
    BC.HideNativeFocus(focus == "panel")
    BC.Render()
end

panel:SetScript("OnUpdate", function()
    if BC.holdStart then
        local p = math.min(1, (GetTime() - BC.holdStart) / HOLD_ALL)
        holdBar:SetWidth(math.max(1, (legend:GetWidth() - 10) * p))
        holdBar:SetColorTexture(p >= 1 and 1 or 0.85, p >= 1 and 0.35 or 0.2, 0.1, 0.9)
    end
end)

function BC.Destroy(e)
    if IC.InCombat() then return end
    local name = e.link or "item"
    if DestroyOne(e) then
        IC.Print("destroyed " .. name .. (e.count > 1 and (" x" .. e.count) or ""))
    elseif blocked then
        IC.Print("the game doesn't let addons destroy items here.")
    end
    C_Timer.After(0.2, BC.Refresh)
end

function BC.DestroyAll()
    if IC.InCombat() then return end
    local done = 0
    for _, e in ipairs(BC.items) do
        if DestroyOne(e) then
            done = done + 1
        elseif blocked then
            break
        end
    end
    if blocked and done == 0 then
        IC.Print("the game doesn't let addons destroy items here.")
    else
        IC.Print("destroyed " .. done .. (done == 1 and " item." or " items."))
    end
    C_Timer.After(0.3, BC.Refresh)
end

function BC.Open()
    if IC.InCombat() or panel:IsShown() then return end
    BC.items, BC.index, BC.top, BC.armed = BC.Scan(), 1, 1, nil
    BC.focus = "panel"
    BC.TakePad(true)
    -- Beside the bags when they are on screen
    panel:ClearAllPoints()
    local bags = _G.ContainerFrameCombinedBags
    if bags and bags:IsShown() then
        panel:SetPoint("TOPRIGHT", bags, "TOPLEFT", -12, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    panel:Show()
    Bind()
    BC.HideNativeFocus(true)
    BC.Render()
end

-- While the panel has the pad, the game's own focus (its cursor, the bag
-- window's glow) is hidden, so only ours shows
local nativeFocus = {}
function BC.HideNativeFocus(hide)
    if hide then
        wipe(nativeFocus)
        local nav = _G.SmartNavigation
        if nav and nav.Pointer then nativeFocus[#nativeFocus + 1] = nav.Pointer end
        local bags = { _G.ContainerFrameCombinedBags }
        for i = 1, NUM_CONTAINER_FRAMES or 13 do bags[#bags + 1] = _G["ContainerFrame" .. i] end
        for _, f in ipairs(bags) do
            if f and f.FrameGlow then nativeFocus[#nativeFocus + 1] = f.FrameGlow end
        end
        for _, f in ipairs(nativeFocus) do f:SetAlpha(0) end
    else
        for _, f in ipairs(nativeFocus) do f:SetAlpha(1) end
        wipe(nativeFocus)
    end
end

function BC.Close()
    if not panel:IsShown() then return end
    panel:Hide()
end

panel:SetScript("OnHide", function()
    BC.TakePad(false)
    BC.HideNativeFocus(false)
    BC.holdStart, BC.armed = nil, nil
    holdBar:Hide()
    if GameTooltip:GetOwner() == panel then GameTooltip:Hide() end
    if not IC.InCombat() then ClearOverrideBindings(panel) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- (its bindings can't be cleared once combat starts)
        panel:Hide()
    else
        BC.Refresh()
    end
end)

---------------------------------------------------------------------------
-- Opening: its button (or two: one held, one pressed) while a bag is open.
-- Watched, not taken over; an R3 combo it uses is left to it by the wheels
-- while the bags are open.
---------------------------------------------------------------------------
function BC.OpenKey()
    return IC.db and IC.db.bagCleanKey or DEFAULT_KEY
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

-- Its name: "R2 + R3"; glyphs too with size
function BC.OpenKeyText(size)
    local held, pressed = Parts(BC.OpenKey())
    local function one(key)
        return (size and (IC.GlyphText(key, size) .. " ") or "") .. IC.ButtonName(key)
    end
    return held and (one(held) .. " + " .. one(pressed)) or one(pressed)
end

function BC.Enabled()
    return IC.db and IC.db.bagClean ~= false
end

local function AnyBagOpen()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then return true end
    end
    return false
end

-- The R3 combo its key is, if any ("R2")
local COMBO_OF = { PADLSHOULDER = "L1", PADLTRIGGER = "L2", PADRSHOULDER = "R1", PADRTRIGGER = "R2" }
local function Combo(spec)
    local held, pressed = Parts(spec)
    if pressed == "PADRSTICK" then return held and COMBO_OF[held] or "R3" end
end

local suppressed
local function Suppress()
    local want = BC.Enabled() and AnyBagOpen() and Combo(BC.OpenKey()) or nil
    if want == suppressed then return end
    if suppressed and not IC.SuppressCombo(suppressed, false) then return end
    if want and not IC.SuppressCombo(want, true) then return end
    suppressed = want
end

function BC.SetOpenKey(key)
    IC.db.bagCleanKey = key ~= DEFAULT_KEY and key or nil
    Suppress()
end

local watcher = CreateFrame("Frame")
local wasDown = false
watcher:SetScript("OnUpdate", function()
    if not IC.db then return end
    Suppress()
    if not BC.Enabled() or panel:IsShown() or IC.InCombat() or not IsKeyDown then
        wasDown = false
        return
    end
    local held, pressed = Parts(BC.OpenKey())
    local down = IsKeyDown(pressed) and (not held or IsKeyDown(held))
    -- The moment the combination is made
    if down and not wasDown and AnyBagOpen() then BC.Open() end
    wasDown = down
end)

-- The panel takes the pad's buttons itself while it has the focus: the bag
-- window's own navigation (Circle: close the bags...) comes before override
-- bindings, a frame taking the pad comes before both
local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)
local PAD_NAME = {}
for key, name in pairs(KEYS) do
    if key ~= "ESCAPE" then PAD_NAME[key] = name end
end
if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        if PAD_NAME[button] then BC.Press(PAD_NAME[button], true) end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        if PAD_NAME[button] then BC.Press(PAD_NAME[button], false) end
    end)
end

function BC.TakePad(on)
    if catcher.EnableGamePadButton and not IC.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end

