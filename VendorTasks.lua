-- The vendor's Tasks: with a merchant's window open and tasks
-- (Tasks.lua) needing something it sells, "Tasks" joins its button
-- legend on Triangle (free there; watched, not taken: a frame of ours in
-- the game's prompt template after its last prompt). Triangle opens a
-- panel beside the window that takes the pad: each such item, how many
-- are still missing and what they cost here. Cross buys the picked one,
-- Triangle all of them (asking first, AuctionConfirm.lua), Circle closes.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local A = IC.Auction
local TK = IC.Tasks
local BY = IC.AuctionBuy

local VT = {}
IC.VendorTasks = VT

local KEY = "PAD4"
local W, ROW_H, ROWS = 420, 50, 6

local function Glyph(key, size)
    return IC.GlyphText(key, size or 22)
end

---------------------------------------------------------------------------
-- What this vendor sells that the tasks miss: { itemID, index, missing,
-- unit (copper an item), bundle (items a purchase), name, icon, quality }
---------------------------------------------------------------------------
local function Wanted()
    local list = {}
    if not (GetMerchantNumItems and GetMerchantItemID and C_MerchantFrame) then return list end
    local missing = {}
    for _, e in ipairs(TK.Needs()) do
        if e.missing > 0 then missing[e.itemID] = e.missing end
    end
    for i = 1, GetMerchantNumItems() or 0 do
        local id = GetMerchantItemID(i)
        local need = id and missing[id]
        if need then
            local info = C_MerchantFrame.GetItemInfo(i)
            -- (gold only: never one with an extended cost)
            if info and info.isPurchasable and not info.hasExtendedCost and (info.price or 0) > 0 then
                local bundle = math.max(1, info.stackCount or 1)
                local _, _, quality = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id)
                list[#list + 1] = {
                    itemID = id, index = i, missing = need, bundle = bundle, unit = info.price / bundle,
                    name = info.name or TK.ItemName(id), icon = info.texture, quality = quality,
                    -- (what a purchase in whole bundles comes to)
                    buy = math.ceil(need / bundle) * bundle,
                }
                missing[id] = nil
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local ok, panel = pcall(K.NewFrame, "Frame", "ImprovedControllerVendorTasks", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    panel = K.NewFrame("Frame", "ImprovedControllerVendorTasks", UIParent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
panel:SetSize(W, 60 + ROWS * ROW_H + 60)
panel:SetFrameStrata("DIALOG")
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
tinsert(UISpecialFrames, panel:GetName())
local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(panel, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end
local empty = K.ChatText(panel, 13, KC.grey)
empty:SetPoint("CENTER")
empty:SetText("Nothing here for your tasks")

local rows = {}
for i = 1, ROWS do
    local r = BY.ItemRow(panel, W - 28, ROW_H - 4, W - 28 - 50 - 110)
    r:SetPoint("TOPLEFT", 14, -30 - (i - 1) * ROW_H)
    r:SetScript("OnClick", function(self)
        if self.index then
            VT.sel = self.index
            VT.Render()
        end
    end)
    rows[i] = r
end
local total = K.ChatText(panel, 14, KC.cream)
total:SetPoint("BOTTOMLEFT", 22, 18)
local totalValue = K.ChatText(panel, 14, KC.title)
totalValue:SetPoint("BOTTOMRIGHT", -22, 18)

-- The button legend under it
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

VT.sel, VT.list = 1, {}

function VT.Render()
    if not panel:IsShown() then return end
    titleText:SetText("Tasks")
    local list = Wanted()
    VT.list = list
    VT.sel = math.max(1, math.min(VT.sel, #list))
    empty:SetShown(#list == 0)
    local top = math.max(1, VT.sel - ROWS + 1)
    local sum = 0
    for _, w in ipairs(list) do sum = sum + w.unit * w.buy end
    local fr, fg, fb = BY.FocusColor()
    for i, r in ipairs(rows) do
        local index = top + i - 1
        local w = list[index]
        r:SetShown(w ~= nil)
        if w then
            r.index = index
            r:Fill({
                icon = w.icon, quality = w.quality, name = w.name,
                line = "buy " .. w.buy .. "  ·  " .. A.Money(w.unit) .. " each"
                    .. (w.bundle > 1 and ("  ·  in " .. w.bundle .. "s") or ""),
                price = A.Money(w.unit * w.buy),
            })
            r.focus:SetShown(index == VT.sel)
            r.focus:SetVertexColor(fr, fg, fb)
        end
    end
    total:SetText(#list > 0 and ("All " .. #list .. (#list == 1 and " item" or " items")) or "")
    totalValue:SetText(#list > 0 and A.Money(sum) or "")
    hints:SetText((#list > 0 and (Glyph("A") .. " Buy   " .. Glyph("Y") .. " Buy all   " .. Glyph("DPAD_UD") .. " Move   ") or "")
        .. Glyph("B") .. " Close")
    legend:SetWidth(math.max(W, hints:GetStringWidth() + 28))
    -- The picked one's tooltip, beside the panel
    local w = list[VT.sel]
    if w then
        GameTooltip:SetOwner(panel, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 8, 0)
        GameTooltip:SetMerchantItem(w.index)
        GameTooltip:Show()
    elseif GameTooltip:GetOwner() == panel then
        GameTooltip:Hide()
    end
end

---------------------------------------------------------------------------
-- Buying (from the popup's Cross: a press)
---------------------------------------------------------------------------
local function BuyOne(w)
    local left = w.buy
    local max = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(w.index)) or left
    max = math.max(w.bundle, max)
    while left > 0 do
        local n = math.min(left, max)
        BuyMerchantItem(w.index, n)
        left = left - n
    end
end

local function Confirm(list)
    local sum, count = 0, 0
    for _, w in ipairs(list) do
        sum = sum + w.unit * w.buy
        count = count + w.buy
    end
    if sum > GetMoney() then
        IC.Print("not enough money for that.")
        return
    end
    local first = list[1]
    local lines = {}
    for i, w in ipairs(list) do
        if i > 5 then
            lines[#lines + 1] = { "and " .. (#list - 5) .. " more", "" }
            break
        end
        lines[#lines + 1] = { w.buy .. " × " .. w.name, A.Money(w.unit * w.buy) }
    end
    IC.AuctionConfirm.Show({
        title = "Buy", over = panel,
        icon = first.icon, count = #list == 1 and first.buy or nil, quality = first.quality,
        name = #list == 1 and first.name or (#list .. " items for your tasks"),
        sub = "From this vendor",
        lines = lines,
        total = { "You pay", A.Money(sum) },
        accept = "Buy",
        onAccept = function()
            if IC.InCombat() or not (_G.MerchantFrame and _G.MerchantFrame:IsShown()) then return end
            for _, w in ipairs(list) do BuyOne(w) end
            PlaySound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
            C_Timer.After(0.4, VT.Render)
        end,
    })
end

---------------------------------------------------------------------------
-- Opening, the pad
---------------------------------------------------------------------------
local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)
local KEYS = { PADDUP = "UP", PADDDOWN = "DOWN", PAD1 = "A", PAD2 = "B", PAD4 = "Y" }

local function Press(name)
    if IC.AuctionConfirm.Press(name) then return end
    if name == "UP" or name == "DOWN" then
        VT.sel = VT.sel + (name == "UP" and -1 or 1)
        return VT.Render()
    end
    if name == "A" and VT.list[VT.sel] then return Confirm({ VT.list[VT.sel] }) end
    if name == "Y" and #VT.list > 0 then return Confirm(VT.list) end
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        if name and name ~= "B" then Press(name) end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        if KEYS[button] ~= "B" then return end
        -- (Circle on its release: the merchant window's own Circle would close it)
        if IC.AuctionConfirm.IsShown() then return IC.AuctionConfirm.Press("B") end
        VT.Close()
    end)
end

function VT.Open()
    if IC.InCombat() then return end
    local merchant = _G.MerchantFrame
    panel:ClearAllPoints()
    if merchant and merchant:IsShown() then
        panel:SetPoint("TOPLEFT", merchant, "TOPRIGHT", 12, 0)
    else
        panel:SetPoint("CENTER")
    end
    VT.sel = 1
    panel:Show()
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(true) end
    VT.Render()
end

function VT.Close()
    panel:Hide()
end

panel:SetScript("OnHide", function()
    IC.AuctionConfirm.Hide()
    if catcher.EnableGamePadButton and not IC.InCombat() then catcher:EnableGamePadButton(false) end
    if GameTooltip:GetOwner() == panel then GameTooltip:Hide() end
end)

---------------------------------------------------------------------------
-- "Tasks" in the merchant window's legend, Triangle watched
---------------------------------------------------------------------------
local LEGEND_PAD, PROMPT_GAP = 10, 15   -- the game's legend layout (InputLegendPromptGroup.lua)

local function LegendBox()
    local footer = _G.MerchantFrame and _G.MerchantFrame.footer
    local legendFrame = footer and footer.isShown and footer.inputLegend
    local box = legendFrame and legendFrame.promptContainerFrame
    return box and box:IsVisible() and box or nil
end

local prompt
local function Prompt()
    if prompt == nil then
        prompt = false
        local merchant = _G.MerchantFrame
        if not merchant then return nil end
        local holder = K.NewFrame("Frame", nil, merchant)
        local made, p = pcall(function()
            local x = K.NewFrame("Frame", nil, holder, "InputPromptOneIconWithTextTemplate")
            x:SetPromptInputIconKey(1, _G.GAMEPAD_FACE_TOP or KEY)
            x:SetPromptText("Tasks")
            x:EnablePrompt()
            return x
        end)
        if made and p then
            holder.prompt = p
            holder:Hide()
            prompt = holder
        end
    end
    return prompt or nil
end

local function PlacePrompt(holder, box)
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

local function HidePrompt()
    local holder = prompt
    if not holder or not holder:IsShown() then return end
    holder:Hide()
    local box = holder.box
    if box and holder.setWidth and math.abs(box:GetWidth() - holder.setWidth) <= 0.5 then
        box:SetWidth(holder.baseWidth)
    end
    holder.box, holder.setWidth = nil, nil
end

local wasDown, wanted, checkAt = false, false, 0
local watch = CreateFrame("Frame")
watch:Hide()
watch:SetScript("OnUpdate", function()
    -- (what it sells for the tasks: looked at now and then, not each frame)
    if GetTime() >= checkAt then
        checkAt = GetTime() + 0.5
        wanted = #Wanted() > 0
    end
    local can = wanted and not panel:IsShown() and not IC.InCombat()
    local box = can and LegendBox()
    local holder = box and Prompt()
    if holder then
        PlacePrompt(holder, box)
        holder:Show()
    else
        HidePrompt()
    end
    local down = IsKeyDown and IsKeyDown(KEY) or false
    -- (only while the merchant's window has the pad: its legend up)
    if down and not wasDown and holder then VT.Open() end
    wasDown = down
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        wasDown, checkAt = IsKeyDown and IsKeyDown(KEY) or false, 0
        watch:Show()
    elseif event == "MERCHANT_CLOSED" then
        watch:Hide()
        HidePrompt()
        VT.Close()
    elseif event == "PLAYER_REGEN_DISABLED" then
        VT.Close()
    else
        checkAt = 0
        VT.Render()
    end
end)
