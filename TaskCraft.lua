-- The profession window's "Add Task": in a recipe's More options
-- (Triangle, the game's own menu), on the recipe picked. It opens a panel
-- that takes the pad: how many to make (the D-pad 1, L1 / R1 5, L2 / R2
-- 20), each reagent's had and still to buy, where from (a vendor, the
-- auction house) and about what it costs; Cross adds the task
-- (Tasks.lua), Circle backs out.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local TK = IC.Tasks

local TC = {}
IC.TaskCraft = TC

local W = 440
local REPEAT_DELAY, REPEAT_EVERY = 0.35, 0.08

local function Glyph(key, size)
    return IC.GlyphText(key, size or 20)
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local ok, panel = pcall(K.NewFrame, "Frame", "ImprovedControllerTask", UIParent, "DefaultPanelFlatTemplate")
if not ok then
    panel = K.NewFrame("Frame", "ImprovedControllerTask", UIParent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end
panel:SetSize(W, 300)
panel:SetFrameStrata("FULLSCREEN_DIALOG")
panel:SetToplevel(true)
panel:EnableMouse(true)
panel:SetClampedToScreen(true)
panel:Hide()
tinsert(UISpecialFrames, panel:GetName())
local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
if not titleText then
    titleText = K.Text(panel, 13, KC.title)
    titleText:SetPoint("TOP", 0, -8)
end

local icon = panel:CreateTexture(nil, "ARTWORK")
icon:SetSize(40, 40)
icon:SetPoint("TOPLEFT", 18, -36)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
name:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
name:SetJustifyH("LEFT")
name:SetWordWrap(false)
local sub = K.ChatText(panel, 11, KC.help)
sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)

-- How many to make: big, between arrows
local qty = K.Text(panel, 40, KC.title)
qty:SetPoint("TOP", panel, "TOP", 0, -96)
local qtyLeft = K.Text(panel, 40, KC.focus)
qtyLeft:SetPoint("RIGHT", qty, "LEFT", -18, 0)
qtyLeft:SetText("‹")
local qtyRight = K.Text(panel, 40, KC.focus)
qtyRight:SetPoint("LEFT", qty, "RIGHT", 18, 0)
qtyRight:SetText("›")
local qtyLabel = K.ChatText(panel, 14, KC.dimGold)
qtyLabel:SetPoint("TOP", qty, "BOTTOM", 0, -8)

-- The reagents, as a receipt: name left, had / to buy and where right
local LINE = 20
local receipt = K.NewFrame("Frame", nil, panel)
receipt:SetPoint("TOPLEFT", 22, -170)
receipt:SetPoint("TOPRIGHT", -22, -170)
local rows = {}
local function Row(i)
    if rows[i] then return rows[i] end
    local r = {
        label = K.ChatText(receipt, 13, KC.help),
        value = K.ChatText(receipt, 13, KC.cream),
    }
    r.value:SetJustifyH("RIGHT")
    rows[i] = r
    return r
end
local rule = receipt:CreateTexture(nil, "ARTWORK")
rule:SetHeight(1)
rule:SetColorTexture(0.45, 0.38, 0.25, 0.9)
local totalLabel = K.ChatText(receipt, 14, KC.cream)
local totalValue = K.ChatText(receipt, 14, KC.title)
totalValue:SetJustifyH("RIGHT")

local legend = K.ChatText(panel, 12, KC.help)
legend:SetPoint("BOTTOM", 0, 14)

---------------------------------------------------------------------------
-- What it shows: S = { recipe, count }
---------------------------------------------------------------------------
local S

local function Render()
    if not S then return end
    local r = S.recipe
    titleText:SetText("Add Task")
    icon:SetTexture(r.icon or 134400)
    name:SetText(r.name)
    sub:SetText(r.makes > 1 and ("makes " .. r.makes .. " each") or "")
    qty:SetText(S.count)
    qtyLabel:SetText("to make" .. (r.makes > 1 and (" (" .. S.count * r.makes .. " items)") or ""))
    -- Each reagent: had and still to buy (what other tasks want counted too)
    local others = {}
    for _, e in ipairs(TK.Needs()) do others[e.itemID] = e.need end
    local y, cost, unknown = 0, 0, false
    for i, reagent in ipairs(r.reagents) do
        local need = reagent.per * S.count
        local have = TK.ItemCount(reagent.itemID)
        local buy = math.max(0, need + (others[reagent.itemID] or 0) - have)
        buy = math.min(buy, need)
        local vendor = TK.FromVendor(reagent.itemID)
        local row = Row(i)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", 0, y)
        row.value:ClearAllPoints()
        row.value:SetPoint("TOPRIGHT", 0, y)
        row.label:SetText(need .. " × " .. TK.ItemName(reagent.itemID))
        row.value:SetText(buy == 0 and "|cff5fd35fhave all|r"
            or ("buy " .. buy .. "  |cff9d917a" .. (vendor and "vendor" or "auction") .. "|r"))
        row.label:Show()
        row.value:Show()
        y = y - LINE
        if buy > 0 then
            local unit = not vendor and IC.Auction and IC.Auction.MarketPrice(reagent.itemID)
            if vendor then
                -- (a vendor's price: what it asks, seen; a fair guess: 4x what it pays)
                local sell = select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(reagent.itemID))
                unit = sell and sell > 0 and sell * 4 or nil
            end
            if unit then cost = cost + unit * buy else unknown = true end
        end
    end
    for i = #r.reagents + 1, #rows do
        rows[i].label:Hide()
        rows[i].value:Hide()
    end
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", 0, y - 3)
    rule:SetPoint("TOPRIGHT", 0, y - 3)
    y = y - 9
    totalLabel:ClearAllPoints()
    totalLabel:SetPoint("TOPLEFT", 0, y)
    totalValue:ClearAllPoints()
    totalValue:SetPoint("TOPRIGHT", 0, y)
    totalLabel:SetText("About" .. (unknown and " |cff9d917a(some prices unknown)|r" or ""))
    totalValue:SetText(IC.Auction and IC.Auction.Money(cost) or tostring(cost))
    y = y - LINE
    receipt:SetHeight(-y)
    panel:SetHeight(170 - y + 50)
    local fr, fg, fb = 1, 0.9, 0.4
    qtyLeft:SetTextColor(fr, fg, fb)
    qtyRight:SetTextColor(fr, fg, fb)
    legend:SetText(Glyph("A") .. " Add task   " .. Glyph("DPAD_LR") .. " 1   " .. Glyph("LB") .. " " .. Glyph("RB")
        .. " 5   " .. Glyph("LT") .. " " .. Glyph("RT") .. " 20   " .. Glyph("B") .. " Cancel")
end

function TC.Open(recipeID, count)
    local recipe = recipeID and TK.Recipe(recipeID)
    if not recipe or IC.InCombat() then return end
    if #recipe.reagents == 0 then
        return IC.Print("that recipe needs nothing to buy.")
    end
    S = { recipe = recipe, count = math.max(1, count or 1) }
    panel:ClearAllPoints()
    local over = _G.ProfessionsFrame
    if over and over:IsShown() then
        panel:SetPoint("CENTER", over, "CENTER", 0, 0)
    else
        panel:SetPoint("CENTER")
    end
    panel:Show()
    Render()
end

function TC.Close()
    panel:Hide()
end

---------------------------------------------------------------------------
-- The pad, while the panel is up (it takes the buttons: the profession
-- window's own wait)
---------------------------------------------------------------------------
local catcher = K.NewFrame("Frame", nil, panel)
catcher:SetAllPoints(panel)
local KEYS = {
    PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
    PADLTRIGGER = "LT", PADRTRIGGER = "RT", PAD1 = "A", PAD2 = "B",
}
local held

local function Step(name)
    local step = (name == "LEFT" or name == "RIGHT") and 1 or (name == "LB" or name == "RB") and 5 or 20
    local up = name == "RIGHT" or name == "RB" or name == "RT"
    local count = S.count
    if step == 1 then
        count = count + (up and 1 or -1)
    elseif up then
        count = (math.floor(count / step) + 1) * step
    else
        count = (math.ceil(count / step) - 1) * step
    end
    S.count = math.max(1, math.min(999, count))
    Render()
end

local function Press(name)
    if not S then return end
    if name == "A" then
        local task = TK.Add(S.recipe.recipeID, S.count)
        if task then IC.Print("task added: " .. S.recipe.name .. " × " .. S.count .. ".") end
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN or 875)
        return TC.Close()
    end
    Step(name)
end

if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        local name = KEYS[button]
        -- (Circle on its release: the press's release would close the profession window)
        if not name or name == "B" then return end
        Press(name)
        if name ~= "A" then held = { name = name, next = GetTime() + REPEAT_DELAY } end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        local name = KEYS[button]
        if name == "B" then return TC.Close() end
        if held and held.name == name then held = nil end
    end)
end
panel:SetScript("OnUpdate", function()
    if held and GetTime() >= held.next then
        held.next = GetTime() + REPEAT_EVERY
        Step(held.name)
    end
end)
panel:SetScript("OnShow", function()
    -- (R2 that opened it is still down: its release comes here, harmless)
    if catcher.EnableGamePadButton and not IC.InCombat() then catcher:EnableGamePadButton(true) end
end)
panel:SetScript("OnHide", function()
    if catcher.EnableGamePadButton and not IC.InCombat() then catcher:EnableGamePadButton(false) end
    held, S = nil, nil
end)

---------------------------------------------------------------------------
-- The profession window: "Add task" in a recipe's More options (Triangle:
-- the game's own menu, tagged MORE_CONTEXT_ACTIONS; added to as the game
-- opens it, only for a recipe of the profession window's list)
---------------------------------------------------------------------------
local function CurrentRecipe()
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if not (form and form.GetRecipeInfo) then return nil end
    local got, info = pcall(form.GetRecipeInfo, form)
    return got and info and info.recipeID or nil
end

local function CurrentAmount()
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local box = page and page.CreateMultipleInputBox
    local got, value = pcall(function() return box:GetValue() end)
    return got and tonumber(value) or 1
end

-- The menu's owner: a row of the profession window's recipe list
local function InRecipeList(region)
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local list = page and page.RecipeList
    if not (list and list:IsVisible()) then return false end
    local frame = region
    while frame do
        if frame == list then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end

if Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("MORE_CONTEXT_ACTIONS", function(owner, rootDescription)
        if not InRecipeList(owner) or not CurrentRecipe() then return end
        rootDescription:CreateButton("Add Task", function()
            -- (after the menu has gone: the panel takes the pad)
            C_Timer.After(0, function() TC.Open(CurrentRecipe(), CurrentAmount()) end)
        end)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function() TC.Close() end)
