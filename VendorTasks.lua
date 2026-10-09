-- The vendor's Tasks: with a merchant's window open and tasks
-- (Tasks.lua) needing something it sells, "Tasks" joins its button
-- legend on Triangle (free there; watched, not taken: a frame of ours in
-- the game's prompt template after its last prompt). Triangle opens a
-- panel beside the window that takes the pad, laid out as the auction
-- house's Tasks tab (AuctionTasks.lua): the tasks down the left (its own
-- list, IC.TaskList: "All tasks", each task, the ready ones), on the right
-- what the picked one (or all) still needs that this vendor sells, how
-- many and what they cost here. The D-pad: left / right the column, up /
-- down the pick in it. Cross held buys the picked item, Triangle held all
-- of them (a "Hold to Buy" bar, AuctionBuy.lua's; full, letting go buys),
-- Circle closes.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local A = IC.Auction
local TK = IC.Tasks
local BY = IC.AuctionBuy

local VT = {}
IC.VendorTasks = VT

local KEY = "PAD4"
local TASKS_W, ITEMS_W, ROW_H, ROWS = 204, 360, 48, 7
local W = 14 + TASKS_W + 10 + ITEMS_W + 14
local H = 30 + ROWS * ROW_H + 14

local function Glyph(key, size)
    return IC.GlyphText(key, size or 22)
end

---------------------------------------------------------------------------
-- What this vendor sells that the picked task (nil: all) misses: { itemID,
-- index, missing, unit (copper an item), bundle (items a purchase), buy
-- (in whole bundles), name, icon, quality }
---------------------------------------------------------------------------
local function Wanted(task)
    local list = {}
    if not (GetMerchantNumItems and GetMerchantItemID and C_MerchantFrame) then return list end
    local missing = {}
    for _, e in ipairs(TK.NeedsFor(task)) do missing[e.itemID] = e.missing end
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
panel:SetSize(W, H)
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

VT.column = "items"                    -- the list the D-pad works
VT.sel, VT.list = 1, {}

-- Left: the tasks (the auction house's list)
local tasks = IC.TaskList(panel, TASKS_W, ROWS - 1, function()
    VT.column, VT.sel = "tasks", 1
    VT.Render()
end)
tasks.frame:SetPoint("TOPLEFT", 14, -30)
tasks.frame:SetPoint("BOTTOMLEFT", 14, 14)
tasks:SetGlyph("DPAD_UD")

-- Right: what this vendor sells for it, the hold box under it
local box = BY.Panel(panel, 0.4)
box:SetPoint("TOPLEFT", 14 + TASKS_W + 10, -30)
box:SetPoint("BOTTOMRIGHT", -14, 14)
local boxTitle = K.ChatText(box, 12, KC.dimGold)
boxTitle:SetPoint("TOP", 0, -10)
local empty = K.ChatText(box, 13, KC.grey)
empty:SetPoint("CENTER", 0, 20)
empty:SetWidth(ITEMS_W - 40)
empty:SetJustifyH("CENTER")
local rows = {}
for i = 1, ROWS - 2 do
    local r = BY.ItemRow(box, ITEMS_W - 16, ROW_H - 4, ITEMS_W - 16 - 50 - 110)
    r:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
    r:SetScript("OnClick", function(self)
        if self.index then
            VT.column, VT.sel = "items", self.index
            VT.Render()
        end
    end)
    rows[i] = r
end
local hold = BY.HoldBox(box)
hold:SetPoint("BOTTOMLEFT", 8, 8)
hold:SetPoint("BOTTOMRIGHT", -8, 8)

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

-- Held: { key ("A": the picked item, "Y": all), start }
local holding

local function Sum(list)
    local sum = 0
    for _, w in ipairs(list) do sum = sum + w.unit * w.buy end
    return sum
end

local function RenderHold()
    local all = holding and holding.key == "Y"
    local w = VT.list[VT.sel]
    local price = all and Sum(VT.list) or (w and w.unit * w.buy)
    hold:SetShown(#VT.list > 0)
    hold:SetHold(BY.HoldProgress(holding and holding.start), all and "Y" or "A", all and "Buy All" or "Buy",
        price and A.Money(price) or nil)
end

function VT.Render()
    if not panel:IsShown() then return end
    titleText:SetText("Tasks")
    tasks:Refresh()
    local list = Wanted(tasks:Picked())
    VT.list = list
    VT.sel = math.max(1, math.min(VT.sel, #list))
    tasks:Render(VT.column == "tasks", #Wanted(nil) .. " sold here")
    boxTitle:SetText((VT.column == "items" and Glyph("DPAD_UD", 18) .. " " or "") .. "Sold here"
        .. (tasks:Picked() and (" for " .. tasks:Picked().name) or ""))
    empty:SetShown(#list == 0)
    empty:SetText(#TK.Tasks() == 0 and "No tasks yet" or "Nothing this vendor sells for it")
    local top = math.max(1, VT.sel - #rows + 1)
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
            r.focus:SetVertexColor(fr, fg, fb, VT.column == "items" and 1 or 0.35)
        end
    end
    RenderHold()
    hints:SetText(Glyph("DPAD_LR") .. " Tasks / Items   " .. Glyph("DPAD_UD") .. " Move   "
        .. (#list > 0 and (Glyph("A") .. " Hold to Buy   " .. Glyph("Y") .. " Hold to Buy All   ") or "")
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
-- Buying: a hold, let go full (as the auction house's)
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

local function BuyList(list)
    if IC.InCombat() or not (_G.MerchantFrame and _G.MerchantFrame:IsShown()) then return end
    for _, w in ipairs(list) do BuyOne(w) end
    PlaySound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
    BY.HoldDone()
    C_Timer.After(0.4, VT.Render)
end

-- Cross / Triangle down: the hold starts (short of money: said, none)
local function HoldStart(key)
    local list = key == "Y" and VT.list or { VT.list[VT.sel] }
    if #list == 0 then return end
    if Sum(list) > GetMoney() then
        IC.Print("not enough money for that.")
        return
    end
    holding = { key = key, start = GetTime() }
    RenderHold()
end

local function HoldRelease(key)
    if not (holding and holding.key == key) then return end
    local full = BY.HoldProgress(holding.start) >= 1
    holding = nil
    if full then
        BuyList(key == "Y" and VT.list or { VT.list[VT.sel] })
    end
    RenderHold()
end

local function HoldDrop()
    holding = nil
    RenderHold()
end

panel:SetScript("OnUpdate", function()
    if holding then
        RenderHold()
        BY.HoldFeel(BY.HoldProgress(holding.start))
    else
        BY.HoldFeel(nil)
    end
end)

---------------------------------------------------------------------------
-- Opening, the pad
---------------------------------------------------------------------------
local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)
local KEYS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD4 = "Y" }

local function Press(name)
    -- (anything else pressed while holding: dropped)
    if holding and name ~= holding.key then HoldDrop() end
    if name == "LEFT" or name == "RIGHT" then
        VT.column = name == "LEFT" and "tasks" or "items"
    elseif name == "UP" or name == "DOWN" then
        local dir = name == "UP" and -1 or 1
        if VT.column == "tasks" then
            if tasks:Step(dir) then VT.sel = 1 end
        else
            VT.sel = VT.sel + dir
        end
    elseif name == "A" or name == "Y" then
        return HoldStart(name)
    else
        return
    end
    VT.Render()
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        if name and name ~= "B" then Press(name) end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if name == "A" or name == "Y" then return HoldRelease(name) end
        -- (Circle on its release: the merchant window's own Circle would close it)
        if name == "B" then VT.Close() end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    catcher:EnableGamePadButton(false)
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
    VT.sel, VT.column = 1, "items"
    holding = nil
    panel:Show()
    if catcher.EnableGamePadButton then catcher:EnableGamePadButton(true) end
    VT.Render()
end

function VT.Close()
    panel:Hide()
end

panel:SetScript("OnHide", function()
    holding = nil
    BY.HoldFeel(nil)
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
        wanted = #Wanted(nil) > 0
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

TK.OnChange(function()
    if panel:IsShown() then VT.Render() end
end)
