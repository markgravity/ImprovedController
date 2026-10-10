-- Esc > Options > AddOns > Improved Forever: a pointer to the controller
-- panel, which holds every module's settings. Also /if.
local _, IF = ...

local panel = CreateFrame("Frame")
panel.name = IF.TITLE

local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
heading:SetPoint("TOPLEFT", 16, -16)
heading:SetText(IF.TITLE)

local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
help:SetJustifyH("LEFT")
help:SetText(IF.PadText("All settings live in the controller panel: D-pad to move, {A} to choose, {B} to go back. ")
    .. "Open it with /if, or bind \"Toggle Improved Forever panel\" in Key Bindings > AddOns.")

local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
open:SetSize(200, 26)
open:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
open:SetText("Open controller panel")
open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end
    IF.Menu.Open()
end)

IF.OnLogin(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)

---------------------------------------------------------------------------
-- The core's commands (each module adds its own: /if help lists them)
---------------------------------------------------------------------------
-- /if glyphs: the controller style in use, and each style's glyphs this
-- client has (a missing one shows our own, or the button's name)
IF.AddCommand("glyphs", function()
    IF.Print("Buttons: " .. IF.PAD_STYLE_LABELS[IF.PadStyle()] .. " (detected: "
        .. IF.PAD_STYLE_LABELS[IF.DetectedPadStyle()] .. ", set: " .. IF.PAD_STYLE_LABELS[IF.db.padStyle or "auto"] .. ")")
    for _, style in ipairs(IF.PAD_STYLES) do
        local glyphs = IF.PAD_ATLAS[style]
        if glyphs then
            local found, missing = 0, {}
            for key, names in pairs(glyphs) do
                local any = false
                for _, name in ipairs(names) do
                    if IF.HasAtlas(name) then any = true break end
                end
                if any then found = found + 1 else missing[#missing + 1] = key end
            end
            table.sort(missing)
            IF.Print(IF.PAD_STYLE_LABELS[style] .. ": " .. found .. " glyphs"
                .. (#missing > 0 and ", missing " .. table.concat(missing, " ") or ""))
        end
    end
end, ": the controller style and its glyphs")

-- /if buttons <style>: which controller's buttons to show
IF.AddCommand("buttons", function(args)
    local styles = { auto = "auto", playstation = "Shapes", ps = "Shapes", xbox = "Letters", switch = "Reverse",
        nintendo = "Reverse" }
    local style = styles[args[1] or ""]
    if not style then
        IF.Print("usage: /if buttons <auto|playstation|xbox|switch> (now: "
            .. (IF.db.padStyle and IF.PAD_STYLE_LABELS[IF.db.padStyle] or "automatic") .. ")")
        return
    end
    IF.SetPadStyle(style)
    IF.Print("Buttons shown: " .. IF.PAD_STYLE_LABELS[style]
        .. (style == "auto" and (" (" .. IF.PAD_STYLE_LABELS[IF.DetectedPadStyle()] .. ")") or ""))
end, "<auto|playstation|xbox|switch>: which buttons to show")

-- Probe.lua's recorders
IF.AddCommand("probe", function() IF.StartProbe() end, ": record the native radial menu's look")
IF.AddCommand("touchprobe", function() IF.StartTouchProbe() end, ": record what the touchpad reports")
IF.AddCommand("padtest", function() IF.StartPadTest() end)
