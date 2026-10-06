-- R3 rings. Press R3 (optionally holding L1/L2/R1/R2) to open a ring, point
-- at a slot with either stick (the pick stays when the stick springs back)
-- or step with the D-pad, then press Cross to use it. Circle closes. L1/R1
-- flip pages: every ring is cut into pages of eight, like Forever's native
-- radial menu (GamepadRadial), whose art and layout the ring copies.
--
-- It works in combat: every button is a secure button. R3's snippet reads
-- the pad (GetGamePadState) to pick the combo; the stick directions arrive
-- as keys (GamePadStickAxisButtons, switched on while the ring is up) and
-- update the pick; Cross copies the picked slot's action onto itself. Ring
-- contents are rebuilt out of combat only, so loot from a fight shows up
-- afterwards.
local _, IC = ...

-- Measured from GamepadRadial with /ic probe.
local WHEEL_WIDTH, WHEEL_HEIGHT = 540, 541
local SLOT_RADIUS = 150  -- wedges (highlight / empty)
local ICON_RADIUS = 110
local LABEL_RADIUS = 168
local ICON_SIZE = 56
local SLOTS_PER_PAGE = 8
local PICK_LENGTH_SQ = 0.25 -- stick must be at least half way out
local KEY = "PADRSTICK"
local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
local COMBO_BUTTONS = { L1 = "PADLSHOULDER", L2 = "PADLTRIGGER", R1 = "PADRSHOULDER", R2 = "PADRTRIGGER" }
local AXIS_CVAR = "GamePadStickAxisButtons"

local ringData = {}
local rebuildPending, bindingsPending = false, false

---------------------------------------------------------------------------
-- Secure frames
---------------------------------------------------------------------------

local ring = CreateFrame("Frame", "ImprovedControllerRing", UIParent, "SecureHandlerBaseTemplate")
ring:SetSize(WHEEL_WIDTH, WHEEL_HEIGHT)
ring:SetPoint("CENTER")
ring:SetFrameStrata("DIALOG")
ring:Hide()

-- While the ring is up this child captures both sticks (as Controller
-- Forever's and ConsolePort's rings do), so turning a stick to point at a
-- slot doesn't swing the camera or walk the character. It shows and hides
-- with the ring, so the secure show / hide drives it in combat too. The
-- pad state the pick reads (GetGamePadState) is unaffected.
local stickCapture = CreateFrame("Frame", nil, ring)
stickCapture:SetAllPoints(ring)
if stickCapture.EnableGamePadStick then
    stickCapture:EnableGamePadStick(true)
    stickCapture:SetScript("OnGamePadStick", function() end)
end

local function SecureButton(name)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    SecureHandlerSetFrameRef(button, "ring", ring)
    return button
end

-- Shared by the snippets: the slot a stick points at, from the stronger of
-- the two sticks, or nil when neither is pushed past `needed`.
ring:SetAttribute("ic-pick-body", [[
    local needed = ...
    local state = GetGamePadState()
    local sticks = state and state.sticks
    if not sticks then
        return nil
    end
    local x, y, lengthSq = 0, 0, 0
    for _, attribute in ipairs(newtable("ic-stick", "ic-stick2")) do
        local stick = sticks[self:GetAttribute(attribute) or 0]
        if stick and stick.x and stick.y and stick.x * stick.x + stick.y * stick.y > lengthSq then
            x, y, lengthSq = stick.x, stick.y, stick.x * stick.x + stick.y * stick.y
        end
    end
    if lengthSq < needed then
        return nil
    end
    local key = self:GetAttribute("ic-active")
    local best, bestDot
    for index = 1, self:GetAttribute(key .. "-count") or 0 do
        local dot = x * self:GetAttribute(key .. "-dx-" .. index) + y * self:GetAttribute(key .. "-dy-" .. index)
        if not bestDot or dot > bestDot then
            best, bestDot = index, dot
        end
    end
    return best
]])

-- R3: open the ring for the held combo. While it's up R3 does nothing, so
-- clicking the stick by accident while pointing can't close it.
local trigger = SecureButton("ImprovedControllerRingTrigger")
trigger:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(trigger, "OnClick", trigger, [[
    if not down then
        return false
    end
    local ring = self:GetFrameRef("ring")
    if ring:IsShown() then
        self:SetAttribute("ic-mode", nil)
        return false
    end
    local combo = "R3"
    local state = GetGamePadState()
    local buttons = state and state.buttons
    if buttons then
        for _, name in ipairs(newtable("L1", "R1", "L2", "R2")) do
            local index = self:GetAttribute("ic-btn-" .. name)
            if index and buttons[index] then
                combo = name
                break
            end
        end
    end
    local key = self:GetAttribute("ic-combo-" .. combo) or "native"
    self:SetAttribute("ic-mode", key)
    if key ~= "native" then
        ring:SetAttribute("ic-sticky", nil)
        ring:SetAttribute("ic-active", ring:GetAttribute("ic-first-" .. key) or key)
        ring:Show()
    end
    return false
]])

-- Combos left on "native" run R3's normal game binding (Look Here), press
-- and release.
trigger:SetScript("PostClick", function(self, button, down)
    if self:GetAttribute("ic-mode") ~= "native" then
        return
    end
    local action = GetBindingAction(button)
    if action and action ~= "" then
        RunBinding(action, not down and "up" or nil)
    end
end)

-- Key bindings: one button per wheel ("CLICK ImprovedControllerWheel_<key>"
-- in the game's Key Bindings, Bindings.xml) that opens it, or closes it if
-- it is already up. Any key or pad button the player binds works, in combat
-- too.
IC.WHEEL_BINDING_KEYS = { "buffs", "consumables", "emotes", "my1", "my2", "my3", "my4", "my5", "my6", "my7", "my8" }
for _, key in ipairs(IC.WHEEL_BINDING_KEYS) do
    local open = SecureButton("ImprovedControllerWheel_" .. key)
    open:RegisterForClicks("AnyDown")
    open:SetAttribute("ic-ring", key)
    SecureHandlerWrapScript(open, "OnClick", open, [[
        local ring = self:GetFrameRef("ring")
        if ring:IsShown() then
            ring:Hide()
            return false
        end
        local key = self:GetAttribute("ic-ring")
        local first = ring:GetAttribute("ic-first-" .. key)
        if not first then
            return false
        end
        ring:SetAttribute("ic-sticky", nil)
        ring:SetAttribute("ic-active", first)
        ring:Show()
        return false
    ]])
end

-- Stick directions (as keys): move the sticky pick. A key going down means
-- the stick just left the middle; a key coming up means it is springing
-- back, so only a firm reading counts then.
local aim = SecureButton("ImprovedControllerRingAim")
aim:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(aim, "OnClick", aim, [[
    local ring = self:GetFrameRef("ring")
    if ring:IsShown() then
        local pick = ring:RunAttribute("ic-pick-body", down and 0.12 or 0.5)
        if pick then
            ring:SetAttribute("ic-sticky", pick)
        end
    end
    return false
]])

-- D-pad: step the pick round the ring.
local step = SecureButton("ImprovedControllerRingStep")
step:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(step, "OnClick", step, [[
    local ring = self:GetFrameRef("ring")
    local count = ring:GetAttribute(ring:GetAttribute("ic-active") .. "-count") or 0
    if not ring:IsShown() or count < 1 then
        return false
    end
    local current = ring:GetAttribute("ic-sticky")
    local forward = button == "PADDRIGHT" or button == "PADDDOWN"
    if not current then
        current = forward and 1 or count
    elseif forward then
        current = current % count + 1
    else
        current = (current - 2) % count + 1
    end
    ring:SetAttribute("ic-sticky", current)
    return false
]])

-- Cross: use the slot a stick points at right now, else the sticky pick.
-- It acts on the press or the release, whichever the game's
-- ActionButtonUseKeyDown setting makes action buttons fire on.
local use = SecureButton("ImprovedControllerRingUse")
use:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(use, "OnClick", use, [[
    self:SetAttribute("type", nil)
    local ring = self:GetFrameRef("ring")
    if not ring:IsShown() or (down and 1 or 0) ~= (self:GetAttribute("ic-keydown") or 1) then
        return false
    end
    local key = ring:GetAttribute("ic-active")
    local pick = ring:RunAttribute("ic-pick-body", 0.25) or ring:GetAttribute("ic-sticky")
    if not pick then
        return false
    end
    ring:Hide()
    local actionType = ring:GetAttribute(key .. "-type-" .. pick)
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("macrotext", nil)
    self:SetAttribute(actionType == "macro" and "macrotext" or actionType, ring:GetAttribute(key .. "-value-" .. pick))
    self:SetAttribute("type", actionType)
]])

-- L1 / R1: previous / next page, through every ring's pages.
local page = SecureButton("ImprovedControllerRingPage")
page:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(page, "OnClick", page, [[
    local ring = self:GetFrameRef("ring")
    local total = ring:GetAttribute("page-total") or 0
    local position = ring:GetAttribute("pagepos-" .. (ring:GetAttribute("ic-active") or ""))
    if not ring:IsShown() or total < 2 or not position then
        return false
    end
    local step = button == "PADLSHOULDER" and -1 or 1
    ring:SetAttribute("ic-sticky", nil)
    ring:SetAttribute("ic-active", ring:GetAttribute("page-" .. ((position - 1 + step) % total + 1)))
    return false
]])

-- Circle: close.
local close = SecureButton("ImprovedControllerRingClose")
close:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(close, "OnClick", close, [[
    self:GetFrameRef("ring"):Hide()
    return false
]])

-- While the ring is up it owns Cross, Circle, L1, R1, the D-pad and the
-- stick directions, whatever they do otherwise.
SecureHandlerWrapScript(ring, "OnShow", ring, [[
    for _, modifier in ipairs(newtable("", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-")) do
        self:SetBindingClick(true, modifier .. "PAD1", "ImprovedControllerRingUse", "LeftButton")
        self:SetBindingClick(true, modifier .. "PAD2", "ImprovedControllerRingClose", "LeftButton")
        self:SetBindingClick(true, modifier .. "PADLSHOULDER", "ImprovedControllerRingPage", "PADLSHOULDER")
        self:SetBindingClick(true, modifier .. "PADRSHOULDER", "ImprovedControllerRingPage", "PADRSHOULDER")
        for _, key in ipairs(newtable("PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT")) do
            self:SetBindingClick(true, modifier .. key, "ImprovedControllerRingStep", key)
        end
        for _, key in ipairs(newtable("PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT",
                "PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT")) do
            self:SetBindingClick(true, modifier .. key, "ImprovedControllerRingAim", key)
        end
    end
]])
SecureHandlerWrapScript(ring, "OnHide", ring, [[
    self:ClearBindings()
]])

-- The game only sends stick directions as keys with GamePadStickAxisButtons
-- on: switch it on while the ring is up and put it back after. The old
-- value is saved so a /reload mid-ring still restores it. If the game
-- refuses in combat, pointing while pressing Cross and the D-pad still work.
local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    return setter and pcall(setter, name, value)
end

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

local function RestoreAxisCVar()
    if ring:IsShown() then
        return
    end
    if IC.db and IC.db.axisSaved ~= nil and SetCVarSafe(AXIS_CVAR, IC.db.axisSaved) then
        IC.db.axisSaved = nil
    end
end

ring:HookScript("OnShow", function()
    local current = GetCVarSafe(AXIS_CVAR)
    if current and current ~= "1" then
        if IC.db.axisSaved == nil then
            IC.db.axisSaved = current
        end
        SetCVarSafe(AXIS_CVAR, "1")
    end
end)
ring:HookScript("OnHide", RestoreAxisCVar)
IC.OnLogin(RestoreAxisCVar)

---------------------------------------------------------------------------
-- Visuals (Forever's native radial menu art)
---------------------------------------------------------------------------

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.5, 0.5, 0.5 }

local function HasAtlas(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function Atlas(texture, atlas, fallback)
    if HasAtlas(atlas) then
        texture:SetAtlas(atlas)
    elseif fallback then
        texture:SetColorTexture(unpack(fallback))
    end
end

-- A button as inline text in the pad's style (Pad.lua): its glyph, else its name
local function Glyph(key)
    return IC.GlyphText(key, 36)
end

-- Slot i (1..8): 1 at the top, then clockwise, 45 degrees apart.
local function SlotAngle(index)
    return math.pi / 2 - (index - 1) * 2 * math.pi / SLOTS_PER_PAGE
end

local wheel = ring:CreateTexture(nil, "OVERLAY", nil, -3)
wheel:SetPoint("CENTER")
wheel:SetSize(WHEEL_WIDTH, WHEEL_HEIGHT)
Atlas(wheel, "gamepad-radial-menu-wheelbg", { 0, 0, 0, 0.6 })

-- The highlight wedge points outward; the art faces down at rotation 0.
local highlight = ring:CreateTexture(nil, "OVERLAY", nil, -2)
highlight:SetSize(169, 165)
Atlas(highlight, "gamepad-radial-menu-selected", { 1, 0.82, 0, 0.25 })
highlight:Hide()

-- Header: ring name over the top bar, page dots, L1 / R1 prompts.
local header = ring:CreateFontString(nil, "OVERLAY")
header:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
header:SetShadowOffset(1, -1)
header:SetPoint("BOTTOM", ring, "TOP", 0, 50)
local headerBar = ring:CreateTexture(nil, "OVERLAY", nil, -2)
headerBar:SetSize(487, 75)
headerBar:SetPoint("TOP", header, "BOTTOM", 0, 4)
Atlas(headerBar, "gamepad-radial-menu-toptext")
local dotRow = CreateFrame("Frame", nil, ring)
dotRow:SetSize(1, 15)
dotRow:SetPoint("TOP", header, "BOTTOM", 0, -24)
local dots = {}
local pageLeft = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local pageRight = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")

-- Footer: the picked entry's name and the button prompts.
local footerBar = ring:CreateTexture(nil, "OVERLAY", nil, -1)
footerBar:SetSize(570, 151)
footerBar:SetPoint("CENTER", ring, "BOTTOM", 0, -30)
Atlas(footerBar, "gamepad-radial-menu-bottomtext")
local selected = ring:CreateFontString(nil, "OVERLAY")
selected:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
selected:SetShadowOffset(1, -1)
selected:SetTextColor(unpack(GOLD))
selected:SetPoint("CENTER", footerBar, "CENTER", 0, 14)
local prompts = ring:CreateFontString(nil, "OVERLAY")
prompts:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
prompts:SetShadowOffset(1, -1)
prompts:SetPoint("TOP", selected, "BOTTOM", 0, -6)
local function SetPrompts()
    prompts:SetText(Glyph("A") .. " Use      " .. Glyph("B") .. " Close      " .. Glyph("DPAD") .. " Move")
end
SetPrompts()
IC.OnPadStyleChanged(SetPrompts)

local slots = {}
for index = 1, SLOTS_PER_PAGE do
    local angle = SlotAngle(index)
    local dx, dy = math.cos(angle), math.sin(angle)
    local slot = {}
    slot.dx, slot.dy = dx, dy
    slot.empty = ring:CreateTexture(nil, "OVERLAY", nil, -1)
    slot.empty:SetSize(169, 164)
    slot.empty:SetPoint("CENTER", ring, "CENTER", dx * SLOT_RADIUS, dy * SLOT_RADIUS)
    Atlas(slot.empty, "gamepad-radial-menu-disabled")
    slot.empty:SetRotation(angle + math.pi / 2)
    slot.icon = ring:CreateTexture(nil, "OVERLAY", nil, 0)
    slot.icon:SetSize(ICON_SIZE, ICON_SIZE)
    slot.icon:SetPoint("CENTER", ring, "CENTER", dx * ICON_RADIUS, dy * ICON_RADIUS)
    local mask = ring:CreateMaskTexture()
    mask:SetAllPoints(slot.icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    slot.icon:AddMaskTexture(mask)
    slot.count = ring:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.count:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 2, -2)
    slot.label = ring:CreateFontString(nil, "OVERLAY")
    slot.label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    slot.label:SetShadowOffset(1, -1)
    slot.label:SetSize(90, 40)
    slot.label:SetPoint("CENTER", ring, "CENTER", dx * LABEL_RADIUS, dy * LABEL_RADIUS)
    slots[index] = slot
end

local function ItemCount(value)
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    return getCount and getCount(value) or 0
end

local pageOrder = {}  -- page keys in L1 / R1 order
local pageInfo = {}   -- page key -> { ring = key, number = n, of = total }

local function RefreshVisuals()
    local active = ring:GetAttribute("ic-active")
    local entries = ringData[active] or {}
    local info = pageInfo[active]
    header:SetText(info and (IC.RING_LABELS[info.ring] .. (info.of > 1 and ("  " .. info.number .. "/" .. info.of) or "")) or "")
    for index, slot in ipairs(slots) do
        local entry = entries[index]
        slot.empty:SetShown(not entry)
        slot.icon:SetShown(entry ~= nil)
        slot.label:SetShown(entry ~= nil)
        slot.count:SetShown(entry ~= nil)
        if entry then
            slot.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            slot.count:SetText(entry.type == "item" and ItemCount(entry.value) or "")
            slot.label:SetText(entry.label)
            local usable = entry.type ~= "item" or ItemCount(entry.value) > 0
            slot.icon:SetDesaturated(not usable)
            slot.label:SetTextColor(unpack(usable and GOLD or GREY))
        end
    end
    -- One dot per page, the current one lit.
    for _, dot in ipairs(dots) do
        dot:Hide()
    end
    local total = #pageOrder
    for position, key in ipairs(pageOrder) do
        local dot = dots[position]
        if not dot then
            dot = dotRow:CreateTexture(nil, "OVERLAY")
            dot:SetSize(15, 15)
            dots[position] = dot
        end
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", dotRow, "CENTER", (position - (total + 1) / 2) * 20, 0)
        Atlas(dot, key == active and "gamepad-radialgamemenu-cursorbg-neutral"
            or "gamepad-radialgamemenu-cursorbg-inactive", key == active and { 1, 1, 1, 1 } or { 0.4, 0.4, 0.4, 1 })
        dot:Show()
    end
    local edge = (total - 1) * 10 + 12
    pageLeft:ClearAllPoints()
    pageLeft:SetPoint("RIGHT", dotRow, "CENTER", -edge, -2)
    pageLeft:SetText(total > 1 and IC.GlyphText("LB", 38) or "")
    pageRight:ClearAllPoints()
    pageRight:SetPoint("LEFT", dotRow, "CENTER", edge, -2)
    pageRight:SetText(total > 1 and IC.GlyphText("RB", 38) or "")
    selected:SetText(#entries == 0 and "Nothing here" or "")
end

-- Same pick as the secure "ic-pick-body": the stronger of the two sticks.
local function StickPick(entries)
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then
        return nil
    end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local sticks = state and state.sticks
    if not sticks then
        return nil
    end
    local x, y, lengthSq = 0, 0, 0
    for _, attribute in ipairs({ "ic-stick", "ic-stick2" }) do
        local stick = sticks[ring:GetAttribute(attribute) or 0]
        if stick and stick.x and stick.y and stick.x * stick.x + stick.y * stick.y > lengthSq then
            x, y, lengthSq = stick.x, stick.y, stick.x * stick.x + stick.y * stick.y
        end
    end
    if lengthSq < PICK_LENGTH_SQ then
        return nil
    end
    local best, bestDot
    for index in ipairs(entries) do
        local dot = x * slots[index].dx + y * slots[index].dy
        if not bestDot or dot > bestDot then
            best, bestDot = index, dot
        end
    end
    return best
end

local highlighted
local function Highlight(pick)
    highlighted = pick
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    local slot = pick and slots[pick]
    if slot and entries[pick] then
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", ring, "CENTER", slot.dx * SLOT_RADIUS, slot.dy * SLOT_RADIUS)
        highlight:SetRotation(SlotAngle(pick) + math.pi / 2)
        highlight:Show()
        selected:SetText(entries[pick].label)
    else
        highlight:Hide()
        selected:SetText(#entries == 0 and "Nothing here" or "")
    end
    -- The picked entry's label turns white, like the native menu.
    for index, other in ipairs(slots) do
        local entry = entries[index]
        if entry then
            local usable = entry.type ~= "item" or ItemCount(entry.value) > 0
            other.label:SetTextColor(unpack(index == pick and { 1, 1, 1 } or (usable and GOLD or GREY)))
        end
    end
end

ring:SetScript("OnUpdate", function()
    local entries = ringData[ring:GetAttribute("ic-active")] or {}
    local pick = StickPick(entries) or ring:GetAttribute("ic-sticky")
    if pick ~= highlighted then
        Highlight(pick)
    end
end)
ring:HookScript("OnShow", function()
    RefreshVisuals()
    Highlight(nil)
end)
ring:HookScript("OnAttributeChanged", function(_, name)
    if name == "ic-active" and ring:IsShown() then
        RefreshVisuals()
        Highlight(nil)
    end
end)

---------------------------------------------------------------------------
-- Contents and bindings (out of combat only)
---------------------------------------------------------------------------

local function Rebuild()
    if IC.InCombat() then
        rebuildPending = true
        return
    end
    rebuildPending = false
    wipe(pageOrder)
    wipe(pageInfo)
    wipe(ringData)
    -- A deleted wheel's key binding opens nothing
    for _, key in ipairs(IC.WHEEL_BINDING_KEYS) do
        ring:SetAttribute("ic-first-" .. key, nil)
    end
    for _, ringKey in ipairs(IC.RINGS) do
        local build = IC.RingBuilders[ringKey]
        if build then
            local entries = build()
            local pages = math.max(1, math.ceil(#entries / SLOTS_PER_PAGE))
            for number = 1, pages do
                local key = ringKey .. number
                local pageEntries = {}
                for index = 1, SLOTS_PER_PAGE do
                    local entry = entries[(number - 1) * SLOTS_PER_PAGE + index]
                    if not entry then
                        break
                    end
                    pageEntries[index] = entry
                    local angle = SlotAngle(index)
                    ring:SetAttribute(key .. "-dx-" .. index, math.cos(angle))
                    ring:SetAttribute(key .. "-dy-" .. index, math.sin(angle))
                    ring:SetAttribute(key .. "-type-" .. index, entry.type)
                    ring:SetAttribute(key .. "-value-" .. index, entry.value)
                end
                ring:SetAttribute(key .. "-count", #pageEntries)
                ringData[key] = pageEntries
                pageOrder[#pageOrder + 1] = key
                pageInfo[key] = { ring = ringKey, number = number, of = pages }
                ring:SetAttribute("pagepos-" .. key, #pageOrder)
                ring:SetAttribute("page-" .. #pageOrder, key)
            end
            ring:SetAttribute("ic-first-" .. ringKey, ringKey .. 1)
        end
    end
    ring:SetAttribute("page-total", #pageOrder)
    if ring:IsShown() then
        RefreshVisuals()
        Highlight(nil)
    end
end

local rebuildQueued = false
local function QueueRebuild()
    if rebuildQueued then
        return
    end
    rebuildQueued = true
    C_Timer.After(0.3, function()
        rebuildQueued = false
        Rebuild()
    end)
end

IC.QueueRingRebuild = QueueRebuild

local function GamePadIndex(binding)
    if C_GamePad and C_GamePad.ButtonBindingToIndex then
        local index = C_GamePad.ButtonBindingToIndex(binding)
        if index then
            return index + 1 -- GetGamePadState().buttons is 1-based
        end
    end
end

local function StickIndex(name)
    if C_GamePad and C_GamePad.StickConfigNameToIndex then
        local index = C_GamePad.StickConfigNameToIndex(name)
        if index and index >= 0 then
            return index + 1
        end
    end
end

function IC.ApplyRingBindings()
    if IC.InCombat() then
        bindingsPending = true
        return
    end
    bindingsPending = false
    ring:SetAttribute("ic-stick", StickIndex("Right") or 2)
    ring:SetAttribute("ic-stick2", StickIndex("Left") or 1)
    use:SetAttribute("ic-keydown", GetCVarSafe("ActionButtonUseKeyDown") == "0" and 0 or 1)
    local anyRing = false
    for _, combo in ipairs(IC.COMBOS) do
        local key = IC.GetComboRing(combo)
        trigger:SetAttribute("ic-combo-" .. combo, key)
        anyRing = anyRing or key ~= "native"
    end
    for combo, binding in pairs(COMBO_BUTTONS) do
        trigger:SetAttribute("ic-btn-" .. combo, GamePadIndex(binding))
    end
    ClearOverrideBindings(trigger)
    if anyRing then
        for _, modifier in ipairs(MODIFIERS) do
            SetOverrideBindingClick(trigger, true, modifier .. KEY, trigger:GetName(), modifier .. KEY)
        end
    end
end

IC.OnLogin(function()
    Rebuild()
    IC.ApplyRingBindings()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("CVAR_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
    if not IC.db then
        return
    end
    if event == "CVAR_UPDATE" then
        if not IC.InCombat() then
            use:SetAttribute("ic-keydown", GetCVarSafe("ActionButtonUseKeyDown") == "0" and 0 or 1)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        RestoreAxisCVar()
        if bindingsPending then
            IC.ApplyRingBindings()
        end
        if rebuildPending then
            Rebuild()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Last chance to pick up bag changes before the lockdown.
        Rebuild()
    elseif event == "BAG_UPDATE_DELAYED" and ring:IsShown() then
        RefreshVisuals()
        QueueRebuild()
    else
        QueueRebuild()
    end
end)
