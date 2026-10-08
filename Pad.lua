-- Which controller is in hand, and its buttons' names and glyphs. The game
-- ships the glyphs of three styles, picked by the pad's label style as its
-- own prompts do (Blizzard_SharedXML InputIconTexture.lua): "Shapes"
-- (PlayStation), "Letters" (Xbox, and any other pad: "Generic") and
-- "Reverse" (Nintendo Switch). Buttons are named here by place, as the
-- game binds them: A is the bottom face button (PAD1), B the right one
-- (PAD2), X the left (PAD3), Y the top (PAD4). /ic buttons: a style can be
-- forced instead of the detected one.
local _, IC = ...

IC.PAD_STYLES = { "auto", "Shapes", "Letters", "Reverse" }
IC.PAD_STYLE_LABELS = {
    auto = "Automatic", Shapes = "PlayStation", Letters = "Xbox", Reverse = "Nintendo Switch",
}

-- Glyph keys of the game's button names
IC.PAD_KEY = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
    PADLSTICK = "LS", PADRSTICK = "RS",
    PADDUP = "DPAD_UP", PADDDOWN = "DPAD_DOWN", PADDLEFT = "DPAD_LEFT", PADDRIGHT = "DPAD_RIGHT",
    PADBACK = "BACK", PADFORWARD = "START", PADSOCIAL = "SHARE", PADSYSTEM = "HOME",
}

-- The game's glyphs per style (its own prompts' atlases), then the older
-- per-style set (Gamepad_Shp_ / _Ltr_ / _Rev_), then the generic one
local ATLAS = {
    Shapes = {
        A = { "gamepad-ps-buttoncrox-normal", "Gamepad_Shp_Cross_64" },
        B = { "gamepad-ps-buttoncircle-normal", "Gamepad_Shp_Circle_64" },
        X = { "gamepad-ps-buttonsquare-normal", "Gamepad_Shp_Square_64" },
        Y = { "gamepad-ps-buttontriangle-normal", "Gamepad_Shp_Triangle_64" },
        LB = { "gamepad-ps-triggerl1-normal", "Gamepad_Shp_LShoulder_64" },
        RB = { "gamepad-ps-triggerr1-normal", "Gamepad_Shp_RShoulder_64" },
        LT = { "gamepad-ps-triggerl2-normal", "Gamepad_Shp_LTrigger_64" },
        RT = { "gamepad-ps-triggerr2-normal", "Gamepad_Shp_RTrigger_64" },
        LS = { "gamepad-ps-stickl3-normal", "Gamepad_Shp_LStickIn_64" },
        RS = { "gamepad-ps-stickr3-normal", "Gamepad_Shp_RStickIn_64" },
        DPAD = { "gamepad-ps-dpadall-normal" },
        DPAD_LR = { "gamepad-ps-dpadleftright-normal" },
        DPAD_UD = { "gamepad-ps-dpadupdown-normal" },
        DPAD_UP = { "gamepad-ps-dpadup-normal", "Gamepad_Shp_Up_64" },
        DPAD_DOWN = { "gamepad-ps-dpaddown-normal", "Gamepad_Shp_Down_64" },
        DPAD_LEFT = { "gamepad-ps-dpadleft-normal", "Gamepad_Shp_Left_64" },
        DPAD_RIGHT = { "gamepad-ps-dpadright-normal", "Gamepad_Shp_Right_64" },
        BACK = { "gamepad-ps-touchpad-normal", "Gamepad_Shp_TouchpadL_64" },
        TOUCHPAD = { "gamepad-ps-touchpad-normal", "Gamepad_Shp_TouchpadL_64" },
        START = { "gamepad-ps-options-normal", "Gamepad_Shp_Menu_64" },
        SHARE = { "gamepad-ps-create-normal", "gamepad-ps-share-normal", "Gamepad_Shp_Share_64" },
        HOME = { "gamepad-ps-pslogo-normal", "Gamepad_Shp_System_64" },
    },
    Letters = {
        A = { "gamepad-xbox1-buttona-normal", "Gamepad_Ltr_A_64" },
        B = { "gamepad-xbox1-buttonb-normal", "Gamepad_Ltr_B_64" },
        X = { "gamepad-xbox1-buttonx-normal", "Gamepad_Ltr_X_64" },
        Y = { "gamepad-xbox1-buttony-normal", "Gamepad_Ltr_Y_64" },
        LB = { "gamepad-xbox1-trigger-lb-normal", "Gamepad_Ltr_LShoulder_64" },
        RB = { "gamepad-xbox1-trigger-rb-normal", "Gamepad_Ltr_RShoulder_64" },
        LT = { "gamepad-xbox1-trigger-lt-normal", "Gamepad_Ltr_LTrigger_64" },
        RT = { "gamepad-xbox1-trigger-rt-normal", "Gamepad_Ltr_RTrigger_64" },
        LS = { "gamepad-xbox1-stick-l3-normal" },
        RS = { "gamepad-xbox1-stick-r3-normal" },
        DPAD = { "gamepad-xbox1-dpadall-normal" },
        DPAD_LR = { "gamepad-xbox1-dpadleftright-normal" },
        DPAD_UD = { "gamepad-xbox1-dpadupdown-normal" },
        DPAD_UP = { "gamepad-xbox1-dpadup-normal", "Gamepad_Ltr_Up_64" },
        DPAD_DOWN = { "gamepad-xbox1-dpaddown-normal", "Gamepad_Ltr_Down_64" },
        DPAD_LEFT = { "gamepad-xbox1-dpadleft-normal", "Gamepad_Ltr_Left_64" },
        DPAD_RIGHT = { "gamepad-xbox1-dpadright-normal", "Gamepad_Ltr_Right_64" },
        BACK = { "gamepad-xbox1-view-normal", "Gamepad_Ltr_View_64" },
        START = { "gamepad-xbox1-menu-normal", "Gamepad_Ltr_Menu_64" },
        SHARE = { "gamepad-xbox1-share-normal", "Gamepad_Ltr_Share_64" },
        HOME = { "gamepad-xbox1-xblogo-normal", "Gamepad_Ltr_System_64" },
    },
    Reverse = {
        -- Nintendo's letters sit the other way round: the bottom button is B
        A = { "gamepad-switch-128x-face-b-normal", "Gamepad_Rev_B_64" },
        B = { "gamepad-switch-128x-face-a-normal", "Gamepad_Rev_A_64" },
        X = { "gamepad-switch-128x-face-y-normal", "Gamepad_Rev_Y_64" },
        Y = { "gamepad-switch-128x-face-x-normal", "Gamepad_Rev_X_64" },
        LB = { "gamepad-switch-128x-shoulder-l-normal", "Gamepad_Rev_LShoulder_64" },
        RB = { "gamepad-switch-128x-shoulder-r-normal", "Gamepad_Rev_RShoulder_64" },
        LT = { "gamepad-switch-128x-zl-normal", "Gamepad_Rev_LTrigger_64" },
        RT = { "gamepad-switch-128x-zr-normal", "Gamepad_Rev_RTrigger_64" },
        LS = { "gamepad-switch-128x-stick-l3-normal" },
        RS = { "gamepad-switch-128x-stick-r3-normal" },
        DPAD = { "gamepad-switch-128x-dpad-all-normal" },
        DPAD_LR = { "gamepad-switch-128x-dpad-leftright-normal" },
        DPAD_UD = { "gamepad-switch-128x-dpad-updown-normal" },
        DPAD_UP = { "gamepad-switch-128x-dpad-up-normal" },
        DPAD_DOWN = { "gamepad-switch-128x-dpad-down-normal" },
        DPAD_LEFT = { "gamepad-switch-128x-dpad-left-normal", "gamepad-switch-128x-dpad-left-default" },
        DPAD_RIGHT = { "gamepad-switch-128x-dpad-right-normal" },
        BACK = { "gamepad-switch-128x-minus-normal", "Gamepad_Rev_Minus_64" },
        START = { "gamepad-switch-128x-plus-normal", "Gamepad_Rev_Plus_64" },
        SHARE = { "gamepad-switch-128x-capture-normal", "Gamepad_Rev_Capture_64" },
        HOME = { "gamepad-switch-128x-home-normal", "Gamepad_Rev_Home_64" },
    },
}
local GENERIC = {
    LB = "Gamepad_Gen_LShoulder_64", RB = "Gamepad_Gen_RShoulder_64",
    LT = "Gamepad_Gen_LTrigger_64", RT = "Gamepad_Gen_RTrigger_64",
    LS = "Gamepad_Gen_LStickIn_64", RS = "Gamepad_Gen_RStickIn_64",
    DPAD_UP = "Gamepad_Gen_Up_64", DPAD_DOWN = "Gamepad_Gen_Down_64",
    DPAD_LEFT = "Gamepad_Gen_Left_64", DPAD_RIGHT = "Gamepad_Gen_Right_64",
    BACK = "Gamepad_Gen_Back_64", START = "Gamepad_Gen_Forward_64",
    SHARE = "Gamepad_Gen_Share_64", HOME = "Gamepad_Gen_System_64",
}
IC.PAD_ATLAS = ATLAS

local NAMES = {
    Shapes = {
        A = "Cross", B = "Circle", X = "Square", Y = "Triangle",
        LB = "L1", RB = "R1", LT = "L2", RT = "R2", LS = "L3", RS = "R3",
        BACK = "Touchpad", TOUCHPAD = "Touchpad", START = "Options", SHARE = "Create", HOME = "PS",
    },
    Letters = {
        A = "A", B = "B", X = "X", Y = "Y",
        LB = "LB", RB = "RB", LT = "LT", RT = "RT", LS = "LS", RS = "RS",
        BACK = "View", START = "Menu", SHARE = "Share", HOME = "Xbox",
    },
    Reverse = {
        A = "B", B = "A", X = "Y", Y = "X",
        LB = "L", RB = "R", LT = "ZL", RT = "ZR", LS = "L3", RS = "R3",
        BACK = "Minus", START = "Plus", SHARE = "Capture", HOME = "Home",
    },
}
local COMMON_NAMES = {
    DPAD = "D-pad", DPAD_LR = "D-pad", DPAD_UD = "D-pad", DPAD_UP = "D-pad Up", DPAD_DOWN = "D-pad Down",
    DPAD_LEFT = "D-pad Left", DPAD_RIGHT = "D-pad Right", TOUCHPAD = "Touchpad",
    PADDLE1 = "Paddle 1", PADDLE2 = "Paddle 2", PADDLE3 = "Paddle 3", PADDLE4 = "Paddle 4",
}

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
IC.HasAtlas = hasAtlas

-- The pad's own style: what the game's prompts use, else what the active
-- pad reports; "Generic" (no pad, or one SDL does not know) shows Xbox's
local function Detected()
    local style
    local manager = InputDeviceIconSetManager
    if manager and manager.GetActiveInputDeviceIconSet then
        style = manager:GetActiveInputDeviceIconSet()
    end
    if not ATLAS[style] and C_GamePad and C_GamePad.GetDeviceMappedState then
        local ok, state = pcall(C_GamePad.GetDeviceMappedState,
            C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID() or nil)
        if ok and type(state) == "table" then style = state.labelStyle end
    end
    return ATLAS[style] and style or "Letters"
end
IC.DetectedPadStyle = Detected

-- The style in use: the one set with /ic buttons, else the detected one
function IC.PadStyle()
    local set = IC.db and IC.db.padStyle
    if ATLAS[set] then return set end
    return Detected()
end

function IC.SetPadStyle(style)
    IC.db.padStyle = ATLAS[style] and style or nil
    IC.PadStyleChanged()
end

-- A glyph key's atlas in the style in use, or nil (none in this client)
function IC.GlyphAtlas(key)
    key = IC.PAD_KEY[key] or key
    for _, name in ipairs(ATLAS[IC.PadStyle()][key] or {}) do
        if hasAtlas(name) then return name end
    end
    if GENERIC[key] and hasAtlas(GENERIC[key]) then return GENERIC[key] end
    return nil
end

-- A button's name as printed on the pad in use ("Cross", "A", "B"...)
function IC.ButtonName(key)
    key = IC.PAD_KEY[key] or key
    local paddle = key:match("^PADPADDLE(%d)$")
    if paddle then return "Paddle " .. paddle end
    return NAMES[IC.PadStyle()][key] or COMMON_NAMES[key] or key
end

-- A button inline in a text: its glyph, else its name
function IC.GlyphText(key, size)
    local atlas = IC.GlyphAtlas(key)
    if atlas then
        return string.format("|A:%s:%d:%d|a", atlas, size or 16, size or 16)
    end
    return IC.ButtonName(key)
end

-- The R3 combos' names in the style in use ("L1 + R3", "LB + RS"...)
local COMBO_HELD = { L1 = "LB", L2 = "LT", R1 = "RB", R2 = "RT" }
local function RefreshComboLabels()
    for _, combo in ipairs(IC.COMBOS) do
        local held = COMBO_HELD[combo]
        IC.COMBO_LABELS[combo] = (held and IC.ButtonName(held) .. " + " or "") .. IC.ButtonName("RS")
    end
end

-- Called when the style may have changed (a pad plugged in, the setting)
local listeners = {}
function IC.OnPadStyleChanged(fn)
    listeners[#listeners + 1] = fn
end

local lastStyle
function IC.PadStyleChanged()
    local style = IC.PadStyle()
    RefreshComboLabels()
    if style == lastStyle then return end
    lastStyle = style
    for _, fn in ipairs(listeners) do fn(style) end
end

IC.OnLogin(IC.PadStyleChanged)

local watcher = CreateFrame("Frame")
for _, event in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED" }) do
    pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", function()
    if IC.db then IC.PadStyleChanged() end
end)
if InputDeviceIconSetManager and InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback then
    InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(function()
        if IC.db then IC.PadStyleChanged() end
    end, watcher)
end

-- A text with buttons in braces named for the pad in hand:
-- "{A} confirms, {B} cancels" -> "Cross confirms, Circle cancels"
function IC.PadText(text)
    return (text:gsub("{(%u[%u_]*)}", function(key) return IC.ButtonName(key) end))
end
