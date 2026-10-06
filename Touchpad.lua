-- DualSense touchpad clicks. Clicking the pad runs the action of the region
-- the finger is on (top, bottom, left, right, the four corners or the
-- centre): an interface window, a spell, an item or a macro.
--
-- Why a click and not a swipe: on Forever, opening a game window from addon
-- code taints it (its gamepad action bar then trips over a protected call,
-- SetPreferredGamepadInteractTarget, and the game blocks the addon), and
-- Forever passes on only presses from real buttons, so a swipe can't stand
-- in for one. The pad click is a real button (PADBACK): it clicks a secure
-- button whose snippet reads the finger position (GetGamePadState, mapped
-- stick 4) and runs "/click <the game's own button for that window>", as
-- Controller Forever's wheel does. Inside a real press that is a real click,
-- so the window opens untainted, without a prompt, in combat too.
local _, IC = ...

local touch = {}
IC.Touch = touch

local PAD_STICK = 4       -- StickConfigNameToIndex("Pad") is nil on Forever
local DEFAULT_CENTRE = 0.35
local KEY = "PADBACK"     -- what the game calls a touchpad click
local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }

touch.REGIONS = { "up", "down", "left", "right", "upleft", "upright", "downleft", "downright", "centre" }
touch.REGION_LABELS = {
    up = "Top", down = "Bottom", left = "Left", right = "Right", centre = "Centre",
    upleft = "Top left", upright = "Top right", downleft = "Bottom left", downright = "Bottom right",
}
local DEFAULT_CORNER = 0.5

-- What a region can open: the game's own button for it (the first that
-- exists in this client). Only actions with a button here are offered.
local ACTIONS = {
    { key = "map", icon = "Interface\\Icons\\INV_Misc_Map_01", label = "World Map", buttons = { "WorldMapMicroButton", "MiniMapWorldMapButton" } },
    { key = "questlog", icon = "Interface\\Icons\\INV_Misc_Book_08", label = "Quest Log", buttons = { "QuestLogMicroButton" } },
    { key = "character", icon = "Interface\\Icons\\INV_Chest_Cloth_17", label = "Character", buttons = { "CharacterMicroButton" } },
    { key = "bags", icon = "Interface\\Icons\\INV_Misc_Bag_08", label = "Bags", buttons = { "MainMenuBarBackpackButton", "BagsBarBackpackButton" } },
    { key = "spellbook", icon = "Interface\\Icons\\INV_Misc_Book_09", label = "Spellbook", buttons = { "SpellbookMicroButton", "PlayerSpellsMicroButton" } },
    { key = "talents", icon = "Interface\\Icons\\Ability_Marksmanship", label = "Talents", buttons = { "TalentMicroButton", "PlayerSpellsMicroButton" } },
    { key = "social", icon = "Interface\\Icons\\INV_Misc_GroupLooking", label = "Social", buttons = { "SocialsMicroButton", "FriendsMicroButton" } },
    { key = "guild", icon = "Interface\\Icons\\INV_BannerPVP_02", label = "Guild & Communities", buttons = { "GuildMicroButton", "CommunitiesMicroButton" } },
    { key = "groupfinder", icon = "Interface\\Icons\\INV_Misc_Eye_01", label = "Group Finder", buttons = { "LFGMicroButton", "LFDMicroButton", "GroupFinderMicroButton" } },
    { key = "pvp", icon = "Interface\\Icons\\Ability_DualWield", label = "PvP", buttons = { "PVPMicroButton", "HonorMicroButton" } },
    { key = "collections", icon = "Interface\\Icons\\Ability_Mount_RidingHorse", label = "Collections", buttons = { "CollectionsMicroButton" } },
    { key = "achievements", icon = "Interface\\Icons\\INV_Misc_Note_01", label = "Achievements", buttons = { "AchievementMicroButton" } },
    { key = "gamemenu", icon = "Interface\\Icons\\INV_Misc_Gear_01", label = "Game Menu", buttons = { "MainMenuMicroButton" } },
    { key = "icmenu", icon = "Interface\\Icons\\INV_Misc_Gear_02", label = "Improved Controller menu", buttons = { "ImprovedControllerMenuToggle" } },
}
local ACTION_BY_KEY = {}
for _, action in ipairs(ACTIONS) do
    ACTION_BY_KEY[action.key] = action
end

local DEFAULTS = {
    up = "map", down = "character", left = "questlog", right = "bags", centre = "none",
    upleft = "none", upright = "none", downleft = "none", downright = "none",
}

function touch.GetSettings()
    local db = IC.db
    db.touch = db.touch or {}
    local settings = db.touch
    settings.regions = settings.regions or {}
    for region, action in pairs(DEFAULTS) do
        if settings.regions[region] == nil then
            settings.regions[region] = action
        end
    end
    settings.centre = settings.centre or DEFAULT_CENTRE
    settings.corner = settings.corner or DEFAULT_CORNER
    return settings
end

-- The button an action clicks in this client, or nil.
function touch.IsBound(key)
    return key ~= nil and key ~= "none"
end

local function ActionButton(key)
    local action = ACTION_BY_KEY[key]
    for _, name in ipairs(action and action.buttons or {}) do
        local button = _G[name]
        if type(button) == "table" and button.Click then
            return name
        end
    end
end

-- "none" first, then every action this client has a button for.
function touch.GetActions()
    local list = { "none" }
    for _, action in ipairs(ACTIONS) do
        if ActionButton(action.key) then
            list[#list + 1] = action.key
        end
    end
    return list
end

-- A region holds an interface window ("map"...), or "spell:<id>",
-- "item:<id>", "macro:<name>" (IC.ActionInfo), or "none"
local function IsGameAction(key)
    return type(key) == "string" and key:find(":", 1, true) ~= nil
end

function touch.ActionIcon(key)
    if IsGameAction(key) then
        return select(2, IC.ActionInfo(key))
    end
    local action = ACTION_BY_KEY[key]
    return action and action.icon
end

-- What the secure click runs for a region's action, or nil
function touch.Macro(key)
    if IsGameAction(key) then
        local kind, value = key:match("^(%a+):(.+)$")
        if kind == "spell" then
            local name = IC.ActionInfo(key)
            return name and ("/cast " .. name)
        elseif kind == "item" then
            return "/use item:" .. value
        elseif kind == "macro" then
            local _, _, body = GetMacroInfo(value)
            return body
        end
        return nil
    end
    local name = ActionButton(key)
    return name and ("/click " .. name)
end

-- The interface windows a region can open, for the picker
function touch.InterfaceEntries()
    local entries = {}
    for _, key in ipairs(touch.GetActions()) do
        if key ~= "none" then
            entries[#entries + 1] = { action = key, name = touch.ActionLabel(key), icon = touch.ActionIcon(key) }
        end
    end
    return entries
end

-- The region a finger position falls in (the secure click's own test): by
-- the centre size and corner reach, and a region turned off gives its area
-- to its neighbours. nil: every candidate is off.
function touch.RegionAt(x, y)
    local settings = touch.GetSettings()
    local ax, ay = math.abs(x), math.abs(y)
    local h, v = x > 0 and "right" or "left", y > 0 and "up" or "down"
    local corner = v .. h
    local dom, other = h, v
    if ay >= ax then dom, other = v, h end
    local order
    if ax < settings.centre and ay < settings.centre then
        order = { "centre", dom, other, corner }
    elseif ax >= settings.corner and ay >= settings.corner then
        order = { corner, dom, other, "centre" }
    else
        local far = dom == h and ((v == "up" and "down" or "up") .. h) or (v .. (h == "right" and "left" or "right"))
        order = { dom, corner, "centre", far, other }
    end
    for _, name in ipairs(order) do
        if not touch.IsOff(name) then return name end
    end
end

-- Where the finger is on the pad now, or nil
function touch.FingerPosition()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local state = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local stick = state and state.sticks and state.sticks[PAD_STICK]
    if stick then return stick.x or 0, stick.y or 0 end
end

-- A slot turned off: a corner's area becomes its sides', another does
-- nothing when clicked
touch.CORNERS = { upleft = true, upright = true, downleft = true, downright = true }

function touch.IsOff(region)
    local off = touch.GetSettings().off
    return off ~= nil and off[region] == true
end

function touch.ToggleOff(region)
    local settings = touch.GetSettings()
    settings.off = settings.off or {}
    settings.off[region] = not settings.off[region] or nil
    touch.Apply()
    return settings.off[region] == true
end

function touch.SetAction(region, key)
    touch.GetSettings().regions[region] = key or "none"
    touch.Apply()
end

function touch.ActionLabel(key)
    if IsGameAction(key) then
        return IC.ActionInfo(key) or key
    end
    local action = ACTION_BY_KEY[key]
    if not action then
        return "Nothing"
    end
    return ActionButton(key) and action.label or (action.label .. " (not in this client)")
end

---------------------------------------------------------------------------
-- The secure click
---------------------------------------------------------------------------

local click = CreateFrame("Button", "ImprovedControllerTouchClick", UIParent,
    "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
click:SetSize(1, 1)
click:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
click:RegisterForClicks("AnyDown", "AnyUp")
click:SetAttribute("ic-stick", PAD_STICK)

-- Acts on the press or the release, whichever ActionButtonUseKeyDown makes
-- action buttons fire on, and only once per click (the pad's left and right
-- halves are two raw buttons that both report as a click). The secure
-- environment has no GetTime or math, so a "held" flag does the debouncing.
SecureHandlerWrapScript(click, "OnClick", click, [[
    self:SetAttribute("type", nil)
    local keydown = (self:GetAttribute("ic-keydown") or 1) == 1
    if down then
        if self:GetAttribute("ic-held") then
            return false
        end
        self:SetAttribute("ic-held", true)
        if not keydown then
            return false
        end
    else
        if not self:GetAttribute("ic-held") then
            return false
        end
        self:SetAttribute("ic-held", nil)
        if keydown then
            return false
        end
    end
    local state = GetGamePadState()
    local stick = state and state.sticks and state.sticks[self:GetAttribute("ic-stick")]
    local x, y = stick and stick.x or 0, stick and stick.y or 0
    local ax, ay = x < 0 and -x or x, y < 0 and -y or y
    local centre = self:GetAttribute("ic-centre")
    -- The region under the finger; one turned off gives its area to its
    -- neighbours (a side to its corners, a corner to its sides, the centre
    -- to the nearest side): the same as touch.RegionAt
    local h, v = x > 0 and "right" or "left", y > 0 and "up" or "down"
    local corner = v .. h
    local dom, other = h, v
    if ay >= ax then dom, other = v, h end
    local order
    if ax < centre and ay < centre then
        order = newtable("centre", dom, other, corner)
    elseif ax >= self:GetAttribute("ic-corner") and ay >= self:GetAttribute("ic-corner") then
        order = newtable(corner, dom, other, "centre")
    else
        local far = dom == h and ((v == "up" and "down" or "up") .. h) or (v .. (h == "right" and "left" or "right"))
        order = newtable(dom, corner, "centre", far, other)
    end
    local region
    for _, name in ipairs(order) do
        if not self:GetAttribute("ic-off-" .. name) then
            region = name
            break
        end
    end
    if not region then
        return false
    end
    self:SetAttribute("ic-region", region)
    local macro = self:GetAttribute("ic-macro-" .. region)
    if not macro then
        return false
    end
    self:SetAttribute("macrotext", macro)
    self:SetAttribute("type", "macro")
]])

click:SetScript("PostClick", function(self)
    local settings = IC.db and touch.GetSettings()
    if settings and settings.debug and self:GetAttribute("type") then
        local region = self:GetAttribute("ic-region")
        IC.Print("touch: " .. tostring(touch.REGION_LABELS[region]) .. " -> "
            .. touch.ActionLabel(settings.regions[region]))
    end
end)

---------------------------------------------------------------------------
-- Settings onto the secure button (out of combat only)
---------------------------------------------------------------------------

local pending = false

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

function touch.Apply()
    if IC.InCombat() then
        pending = true
        return
    end
    pending = false
    local settings = touch.GetSettings()
    click:SetAttribute("ic-keydown", GetCVarSafe("ActionButtonUseKeyDown") == "0" and 0 or 1)
    click:SetAttribute("ic-centre", settings.centre)
    click:SetAttribute("ic-corner", settings.corner)
    for _, region in ipairs(touch.REGIONS) do
        local off = touch.IsOff(region)
        click:SetAttribute("ic-off-" .. region, off or nil)
        click:SetAttribute("ic-macro-" .. region, not off and touch.Macro(settings.regions[region]) or nil)
    end
    ClearOverrideBindings(click)
    -- While the panel is open it owns the touchpad click (it picks the slot
    -- under the finger); it gives it back when it closes (TouchEditor.lua)
    local panelOpen = IC.Menu and IC.Menu.IsOpen and IC.Menu.IsOpen()
    if settings.enabled ~= false and not panelOpen then
        for _, modifier in ipairs(MODIFIERS) do
            SetOverrideBindingClick(click, true, modifier .. KEY, click:GetName(), "LeftButton")
        end
    end
end

function touch.CycleAction(region, step)
    local settings = touch.GetSettings()
    local list = touch.GetActions()
    local current = 1
    for index, key in ipairs(list) do
        if key == settings.regions[region] then
            current = index
        end
    end
    settings.regions[region] = list[(current - 1 + step) % #list + 1]
    touch.Apply()
end

function touch.SetCentre(size)
    touch.GetSettings().centre = math.max(0.1, math.min(0.8, size))
    touch.Apply()
end

function touch.SetCorner(size)
    touch.GetSettings().corner = math.max(0.2, math.min(0.9, size))
    touch.Apply()
end

-- An earlier version turned the touchpad edges into paddle buttons with a
-- gamepad config; Forever ignores those presses, so take it out again.
local function RemoveOldConfig(settings)
    if settings.configInstalled and C_GamePad and C_GamePad.DeleteConfig then
        C_GamePad.DeleteConfig({ vendorID = 1356, productID = 3302 })
        C_GamePad.ApplyConfigs()
    end
    settings.configInstalled, settings.actions, settings.reach, settings.buttons = nil, nil, nil, nil
end

IC.OnLogin(function()
    RemoveOldConfig(touch.GetSettings())
    touch.Apply()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if not IC.db then
        return
    end
    if pending or event == "CVAR_UPDATE" then
        touch.Apply()
    end
end)
