-- Esc > Options > AddOns > Improved Controller: a pointer to the controller
-- menu, which holds every setting. Also /ic.
local _, IC = ...

local panel = CreateFrame("Frame")
panel.name = "Improved Controller"

local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
heading:SetPoint("TOPLEFT", 16, -16)
heading:SetText("Improved Controller")

local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
help:SetJustifyH("LEFT")
help:SetText(IC.PadText("All settings live in the controller menu: D-pad to move, {A} to choose, {B} to go back. ")
    .. "Open it with /ic, or bind \"Toggle Improved Controller menu\" in Key Bindings > AddOns.")

local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
open:SetSize(200, 26)
open:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
open:SetText("Open controller menu")
open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end
    IC.Menu.Open()
end)

IC.OnLogin(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)

-- /ic                      open the controller menu
-- /ic ring <combo> <ring>  e.g. /ic ring L1 buffs
-- /ic buttons <style>      which controller's buttons to show: auto,
--                          playstation, xbox or switch
-- /ic probe                record the native radial menu's look
-- /ic touchprobe           record what the touchpad reports
-- /ic vibe                 test each vibration motor (which side)
-- /ic glyphs               the controller style, and its glyphs this client has
-- /ic nodes                list what the minimap shows (step/debug tune it)
SLASH_IMPROVEDCONTROLLER1 = "/ic"
SLASH_IMPROVEDCONTROLLER2 = "/improvedcontroller"
SlashCmdList.IMPROVEDCONTROLLER = function(msg)
    local command, combo, ring = strsplit(" ", strtrim(msg or ""):lower())
    if command == "probe" then
        IC.StartProbe()
        return
    end
    if command == "glyphs" then
        -- The controller style in use, and each style's glyphs this client
        -- has (a missing one shows our own, or the button's name)
        IC.Print("Buttons: " .. IC.PAD_STYLE_LABELS[IC.PadStyle()] .. " (detected: "
            .. IC.PAD_STYLE_LABELS[IC.DetectedPadStyle()] .. ", set: " .. IC.PAD_STYLE_LABELS[IC.db.padStyle or "auto"] .. ")")
        for _, style in ipairs(IC.PAD_STYLES) do
            local glyphs = IC.PAD_ATLAS[style]
            if glyphs then
                local found, missing = 0, {}
                for key, names in pairs(glyphs) do
                    local any = false
                    for _, name in ipairs(names) do
                        if IC.HasAtlas(name) then any = true break end
                    end
                    if any then found = found + 1 else missing[#missing + 1] = key end
                end
                table.sort(missing)
                IC.Print(IC.PAD_STYLE_LABELS[style] .. ": " .. found .. " glyphs"
                    .. (#missing > 0 and ", missing " .. table.concat(missing, " ") or ""))
            end
        end
        return
    end
    if command == "buttons" then
        local styles = { auto = "auto", playstation = "Shapes", ps = "Shapes", xbox = "Letters", switch = "Reverse",
            nintendo = "Reverse" }
        local style = styles[combo or ""]
        if not style then
            IC.Print("usage: /ic buttons <auto|playstation|xbox|switch> (now: "
                .. (IC.db.padStyle and IC.PAD_STYLE_LABELS[IC.db.padStyle] or "automatic") .. ")")
            return
        end
        IC.SetPadStyle(style)
        IC.Print("Buttons shown: " .. IC.PAD_STYLE_LABELS[style]
            .. (style == "auto" and (" (" .. IC.PAD_STYLE_LABELS[IC.DetectedPadStyle()] .. ")") or ""))
        return
    end
    if command == "nodes" then
        IC.Gather.Command(combo, ring)
        return
    end
    if command == "vibe" then
        IC.Vibe.TestSides()
        return
    end
    if command == "padtest" then
        IC.StartPadTest()
        return
    end
    if command == "touchprobe" then
        IC.StartTouchProbe()
        return
    end
    if command ~= "ring" then
        IC.Menu.Toggle()
        return
    end
    combo = combo and combo:upper()
    if not IC.COMBO_LABELS[combo] or not IC.RING_LABELS[ring] then
        IC.Print("usage: /ic ring <" .. table.concat(IC.COMBOS, "|") .. "> <" .. table.concat(IC.RINGS, "|") .. ">")
        return
    end
    IC.SetComboRing(combo, ring)
    IC.Print(IC.COMBO_LABELS[combo] .. " -> " .. IC.RING_LABELS[ring])
end
