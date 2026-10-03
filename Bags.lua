-- L3 (left stick click) cleans up bags while any bag frame is open.
local _, IC = ...

local SORT_KEY = "PADLSTICK"

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
        SetOverrideBindingClick(owner, true, SORT_KEY, sortButton:GetName(), "LeftButton")
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
