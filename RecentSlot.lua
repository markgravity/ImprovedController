-- The R3 slot, beside the game's gamepad action bar: the most recent action
-- used from the wheel of the R3 combo held right now (none held: R3's own
-- wheel; L1 held: L1 + R3's...), with its buttons under it. R3 twice (the
-- same combo held) uses it again (Ring.lua).
local _, IC = ...

local K = IC.ConfigKit

local SIZE = 46   -- until a game action button is found to match
local COMBO_BUTTONS = { L1 = "PADLSHOULDER", L2 = "PADLTRIGGER", R1 = "PADRSHOULDER", R2 = "PADRTRIGGER" }
local COMBO_GLYPHS = {
    R3 = { "RS" }, L1 = { "LB", "+", "RS" }, L2 = { "LT", "+", "RS" }, R1 = { "RB", "+", "RS" }, R2 = { "RT", "+", "RS" },
}

local function HasAtlas(name)
    return IC.HasAtlas and IC.HasAtlas(name)
end

local slot = K.NewFrame("Frame", "ImprovedControllerRecentSlot", UIParent)
slot:SetSize(SIZE, SIZE)
slot:SetFrameStrata("LOW")
slot:Hide()

local bg = slot:CreateTexture(nil, "BACKGROUND")
bg:SetPoint("CENTER")
bg:SetSize(SIZE + 6, SIZE + 6)
if HasAtlas("gamepad-actionbar-circleslot-bg") then
    bg:SetAtlas("gamepad-actionbar-circleslot-bg")
else
    bg:SetColorTexture(0, 0, 0, 0.5)
end

local icon = K.RoundIcon(slot, SIZE - 8, "ARTWORK")
icon:SetPoint("CENTER")

local frame = slot:CreateTexture(nil, "OVERLAY")
frame:SetPoint("CENTER")
frame:SetSize(SIZE + 10, SIZE + 10)
if HasAtlas("gamepad-actionbar-circleslot-frame") then frame:SetAtlas("gamepad-actionbar-circleslot-frame") end

local count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
count:SetPoint("BOTTOMRIGHT", -2, 2)

local glyphs = K.GlyphRow(slot, 22)
local label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOM", slot, "TOP", 0, 4)
label:SetWidth(110)
label:SetWordWrap(false)

-- The same size as the game's own gamepad action buttons, measured on
-- screen (other addons may resize them): the first shown action button
-- under its bar
local sample
local function FindButton(frame, depth)
    if depth > 6 then return nil end
    for _, child in ipairs({ frame:GetChildren() }) do
        local name = child:GetName()
        if child:IsShown() and child:IsObjectType("CheckButton") and name and name:find("ActionButton")
            and child:GetWidth() > 0 then
            return child
        end
        local found = child:IsShown() and FindButton(child, depth + 1)
        if found then return found end
    end
end

local size
local function Resize()
    local bar = _G.GamepadMainActionBarFrame
    if not (sample and sample:IsShown() and sample:IsVisible()) then
        sample = bar and bar:IsShown() and FindButton(bar, 0) or nil
    end
    local want = SIZE
    if sample then
        want = sample:GetWidth() * sample:GetEffectiveScale() / slot:GetEffectiveScale()
    end
    want = math.floor(want + 0.5)
    if want == size or want < 8 then return end
    size = want
    slot:SetSize(size, size)
    bg:SetSize(size * 1.13, size * 1.13)
    icon:SetSize(size * 0.83, size * 0.83)
    frame:SetSize(size * 1.22, size * 1.22)
    glyphs:SetScale(math.max(0.5, size / 46))
end

-- Beside the game's bar (right of it), else bottom right of the middle
local function Place()
    local bar = _G.GamepadMainActionBarFrame
    slot:ClearAllPoints()
    if bar and bar:IsShown() then
        slot:SetPoint("LEFT", bar, "RIGHT", 6, -20)
    else
        slot:SetPoint("BOTTOM", UIParent, "BOTTOM", 360, 120)
    end
end

local function HeldCombo()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return "R3" end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local buttons = state and state.buttons
    if not buttons then return "R3" end
    for _, combo in ipairs({ "L1", "R1", "L2", "R2" }) do
        local index = C_GamePad.ButtonBindingToIndex and C_GamePad.ButtonBindingToIndex(COMBO_BUTTONS[combo])
        if index and buttons[index + 1] then return combo end -- (buttons: 1-based)
    end
    return "R3"
end

local function ItemCount(value)
    local id = type(value) == "string" and tonumber(value:match("^item:(%d+)"))
    if not id then return nil end
    local get = (C_Item and C_Item.GetItemCount) or GetItemCount
    return get and get(id) or 0
end

local shownCombo
local function Refresh(force)
    if not IC.db then return end
    local combo = HeldCombo()
    if combo == shownCombo and not force then return end
    shownCombo = combo
    local wheel = IC.GetComboRing(combo)
    if not wheel or wheel == "native" then
        -- Nothing on this combo: R3 alone's wheel then, else hidden
        wheel = IC.GetComboRing("R3")
        combo = "R3"
        if not wheel or wheel == "native" then
            slot:Hide()
            return
        end
    end
    Place()
    slot:Show()
    Resize()
    local recent = IC.RecentAction(wheel)
    icon:SetShown(recent ~= nil)
    if recent then
        K.SetIcon(icon, recent.icon or 134400)
        local n = recent.type == "item" and ItemCount(recent.value)
        count:SetText(n and n > 1 and n or "")
        icon:SetDesaturated(n == 0)
        label:SetText(recent.label or "")
    else
        count:SetText("")
        label:SetText("|cff9d917a" .. (IC.RING_LABELS[wheel] or "") .. "|r")
    end
    -- Its buttons under it: the combo, R3 twice
    local keys = COMBO_GLYPHS[combo]
    local w = glyphs:Set(keys) or 0
    glyphs:ClearAllPoints()
    glyphs:SetPoint("TOPLEFT", slot, "BOTTOM", -w / 2, -4)
end

IC.RecentChanged = function() Refresh(true) end

local elapsed = 0
local sinceResize = 0
slot:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    sinceResize = sinceResize + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    Refresh(false)
    -- (another addon may resize the game's buttons any time)
    if sinceResize >= 1 then
        sinceResize = 0
        Resize()
    end
end)

-- The OnUpdate above only runs while it shows: a small watcher brings it
-- back when a combo gets a wheel again
local watcher = CreateFrame("Frame")
local wait = 0
watcher:SetScript("OnUpdate", function(_, dt)
    wait = wait + dt
    if wait < 0.5 or slot:IsShown() then return end
    wait = 0
    Refresh(true)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function() Refresh(true) end)
IC.OnLogin(function() Refresh(true) end)
IC.OnPadStyleChanged(function() Refresh(true) end)
