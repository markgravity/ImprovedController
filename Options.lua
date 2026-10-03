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
help:SetText("All settings live in the controller menu: D-pad to move, Cross to choose, Circle to go back. "
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
-- /ic probe                record the native radial menu's look
-- /ic touchprobe           record what the touchpad reports
SLASH_IMPROVEDCONTROLLER1 = "/ic"
SLASH_IMPROVEDCONTROLLER2 = "/improvedcontroller"
SlashCmdList.IMPROVEDCONTROLLER = function(msg)
    local command, combo, ring = strsplit(" ", strtrim(msg or ""):lower())
    if command == "probe" then
        IC.StartProbe()
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
