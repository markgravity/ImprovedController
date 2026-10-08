-- Button overrides: a press of the controller (a spec, Binds.lua: a button,
-- a button pressed twice, or one pressed while a button the game turns into
-- Shift / Ctrl / Alt is held) runs a spell, an item, a macro, an emote or
-- opens a window instead of its own game action. Each is an override
-- binding to a secure button running a macro, so it works in combat (it can
-- only change out of it). Set in the General tab (BindEditor.lua);
-- IC.db.overrides = { [spec] = action }, actions as the touchpad's
-- (Touchpad.lua). Not on R3 (the wheels') nor a PlayStation touchpad (its
-- corners').
local _, IC = ...

local O = {}
IC.Override = O

function O.Settings()
    IC.db.overrides = IC.db.overrides or {}
    return IC.db.overrides
end

function O.Get(button)
    return O.Settings()[button]
end

-- An action's name and icon (nil: none)
function O.ActionLabel(action)
    if not IC.Touch.IsBound(action) then return nil end
    local emote = action:match("^emote:(.+)$")
    if emote then return (IC.ActionInfo(action)) or emote end
    return IC.Touch.ActionLabel(action)
end

function O.ActionIcon(action)
    if not IC.Touch.IsBound(action) then return nil end
    return IC.Touch.ActionIcon(action) or select(2, IC.ActionInfo(action)) or 134400
end

-- What the button's secure click runs, or nil
function O.Macro(action)
    if type(action) ~= "string" or action == "none" then return nil end
    local emote = action:match("^emote:(.+)$")
    if emote then return "/" .. emote end
    return IC.Touch.Macro(action)
end

-- The key a press is bound on, or nil when an action can't go on it
function O.BindingKey(spec)
    return IC.Binds.KeyOf(spec)
end

function O.Supports(spec)
    return O.BindingKey(spec) ~= nil
end

-- A double press set, its single press not: it does nothing until that has
-- one (the game's own action can't be combined with it)
function O.NeedsSingle(spec)
    local held, pressed, double = IC.Binds.Parse(spec)
    return double and O.Get(spec) ~= nil and O.Get(IC.Binds.Spec(held, pressed)) == nil
end

local owner = CreateFrame("Frame", "ImprovedControllerOverrides")
local buttons = {}
local pending = false

-- A double click: a second click within DOUBLE seconds of the first. The
-- secure click can't tell time, so a plain frame shown for that long
-- after each click (from insecure code, fine in combat) tells it
local DOUBLE = 0.35

local function SecureButton(key)
    local b = buttons[key]
    if b then return b end
    b = CreateFrame("Button", "ImprovedControllerOverride" .. key:gsub("%-", "_"), UIParent,
        "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    b:SetAttribute("type", "macro")
    local window = CreateFrame("Frame", nil, UIParent)
    window:Hide()
    window:SetScript("OnUpdate", function(self, elapsed)
        self.left = self.left - elapsed
        if self.left <= 0 then self:Hide() end
    end)
    SecureHandlerSetFrameRef(b, "window", window)
    -- The second click of a pair runs the double click's action (if it has
    -- one), any other the single click's
    SecureHandlerWrapScript(b, "OnClick", b, [[
        local window = self:GetFrameRef("window")
        local double = self:GetAttribute("ic-double")
        if double and window and window:IsShown() then
            self:SetAttribute("macrotext", double)
        else
            self:SetAttribute("macrotext", self:GetAttribute("ic-single"))
        end
        if not self:GetAttribute("macrotext") then return false end
    ]])
    -- After each click: the window opens, or a pair just ended it
    b:HookScript("OnClick", function()
        if window:IsShown() then
            window:Hide()
        else
            window.left = DOUBLE
            window:Show()
        end
    end)
    buttons[key] = b
    return b
end

function O.Apply()
    if IC.InCombat() then
        pending = true
        return
    end
    pending = false
    ClearOverrideBindings(owner)
    -- Fires on the press or the release, as the game's action buttons do
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local onDown = get and get("ActionButtonUseKeyDown") ~= "0"
    -- Per key bound: its single and double press's macros
    local macros = {}
    for spec, action in pairs(O.Settings()) do
        local key, macro = O.BindingKey(spec), O.Macro(action)
        if key and macro then
            local _, _, double = IC.Binds.Parse(spec)
            macros[key] = macros[key] or {}
            macros[key][double and "double" or "single"] = macro
        end
    end
    for key, m in pairs(macros) do
        -- Only with its own click's action: a double click alone would leave
        -- the single click doing nothing (the game's own action, autorun on
        -- L3, can't be run from here), so the button stays the game's
        if m.single then
            local b = SecureButton(key)
            b:RegisterForClicks(onDown and "AnyDown" or "AnyUp")
            b:SetAttribute("ic-single", m.single)
            b:SetAttribute("ic-double", m.double)
            SetOverrideBindingClick(owner, false, key, b:GetName(), "LeftButton")
        end
    end
end

-- An action for a button (nil / "none": back to the game's own)
function O.Set(button, action)
    O.Settings()[button] = (action and action ~= "none") and action or nil
    O.Apply()
end

IC.OnLogin(O.Apply)
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:RegisterEvent("CVAR_UPDATE")
owner:SetScript("OnEvent", function(_, event)
    if not IC.db then return end
    -- (CVAR_UPDATE: which buttons are Shift / Ctrl / Alt may have changed)
    if pending or event == "CVAR_UPDATE" then O.Apply() end
end)
