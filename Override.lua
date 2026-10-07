-- Button overrides: a controller button (L3, for now), clicked or double-
-- clicked, runs a spell, an item, a macro, an emote or opens a window
-- instead of its own game action. Each is an override binding to a secure
-- button running a macro, so it works in combat (it can only change out of
-- it). Set in the Override tab (OverrideEditor.lua); IC.db.overrides =
-- { [button] = action }, actions as the touchpad's (Touchpad.lua).
local _, IC = ...

local O = {}
IC.Override = O

-- Each: a button (key) and how it is pressed; id: its setting's key
O.BUTTONS = {
    { id = "PADLSTICK", key = "PADLSTICK", tip = "The left stick, clicked. While your bags are open, bag"
        .. " clean-up (General tab) still has it." },
    { id = "PADLSTICK:double", key = "PADLSTICK", double = true, tip = "The left stick, clicked twice"
        .. " quickly. The first click still does the single click's action." },
}

-- Its name: "L3", "L3 double-click"
function O.Label(b)
    return IC.ButtonName(b.key) .. (b.double and " double-click" or "")
end

function O.Settings()
    IC.db.overrides = IC.db.overrides or {}
    return IC.db.overrides
end

function O.Get(button)
    return O.Settings()[button]
end

-- What the button's secure click runs, or nil
function O.Macro(action)
    if type(action) ~= "string" or action == "none" then return nil end
    local emote = action:match("^emote:(.+)$")
    if emote then return "/" .. emote end
    return IC.Touch.Macro(action)
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
    b = CreateFrame("Button", "ImprovedControllerOverride" .. key, UIParent,
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
    -- Per button: its single and double click's macros
    local macros = {}
    for _, b in ipairs(O.BUTTONS) do
        local macro = O.Macro(O.Get(b.id))
        if macro then
            macros[b.key] = macros[b.key] or {}
            macros[b.key][b.double and "double" or "single"] = macro
        end
    end
    for key, m in pairs(macros) do
        local b = SecureButton(key)
        b:RegisterForClicks(onDown and "AnyDown" or "AnyUp")
        b:SetAttribute("ic-single", m.single)
        b:SetAttribute("ic-double", m.double)
        SetOverrideBindingClick(owner, false, key, b:GetName(), "LeftButton")
    end
end

-- An action for a button (nil / "none": back to the game's own)
function O.Set(button, action)
    O.Settings()[button] = (action and action ~= "none") and action or nil
    O.Apply()
end

IC.OnLogin(O.Apply)
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function()
    if pending and IC.db then O.Apply() end
end)
