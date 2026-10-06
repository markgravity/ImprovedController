-- A button (L3, the left stick click, unless bound to another in the
-- General tab: IC.db.bagSortKey) cleans up bags while any bag frame is open.
local _, IC = ...

local DEFAULT_KEY = "PADLSTICK"

function IC.BagSortKey()
    return IC.db and IC.db.bagSortKey or DEFAULT_KEY
end

local owner = CreateFrame("Frame", "ImprovedControllerBagsOwner")
local sortButton = CreateFrame("Button", "ImprovedControllerSortBags", UIParent)
sortButton:RegisterForClicks("AnyUp")
sortButton:Hide()

local bound = false
local pending = false

local function SortAllBags()
    if C_Container and C_Container.SortBags then
        C_Container.SortBags()
    elseif SortBags then
        SortBags()
    else
        IC.Print("bag sorting is not available on this client.")
        return
    end
    PlaySound(SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 or 852)
end

sortButton:SetScript("OnClick", SortAllBags)

local bagFrames = {}

local function AnyBagOpen()
    for _, frame in ipairs(bagFrames) do
        if frame:IsShown() then
            return true
        end
    end
    return false
end

local function UpdateBinding()
    local want = IC.db.bagSort ~= false and AnyBagOpen()
    if want == bound then
        pending = false
        return
    end
    if IC.InCombat() then
        -- Override bindings can't change in combat; retry on PLAYER_REGEN_ENABLED.
        pending = true
        return
    end
    pending = false
    if want then
        SetOverrideBindingClick(owner, true, IC.BagSortKey(), sortButton:GetName(), "LeftButton")
    else
        ClearOverrideBindings(owner)
    end
    bound = want
end

local function WatchFrame(frame)
    if not frame or frame.ImprovedControllerWatched then
        return
    end
    frame.ImprovedControllerWatched = true
    table.insert(bagFrames, frame)
    frame:HookScript("OnShow", UpdateBinding)
    frame:HookScript("OnHide", UpdateBinding)
end

local function WatchBagFrames()
    WatchFrame(_G.ContainerFrameCombinedBags)
    local count = NUM_CONTAINER_FRAMES or 13
    for i = 1, count do
        WatchFrame(_G["ContainerFrame" .. i])
    end
end

IC.UpdateBagBinding = UpdateBinding

-- Another button for it (nil: back to L3); out of combat (the General tab)
function IC.SetBagSortKey(key)
    IC.db.bagSortKey = key ~= DEFAULT_KEY and key or nil
    if bound and not IC.InCombat() then
        ClearOverrideBindings(owner)
        bound = false
    end
    UpdateBinding()
end

IC.OnLogin(function()
    WatchBagFrames()
    UpdateBinding()
end)

owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function()
    if pending then
        UpdateBinding()
    end
end)
