-- A button (L3, the left stick click, unless bound to another in the
-- Controller tab: IF.db.bagSortKey) cleans up bags while any bag frame is open.
-- Unbound there: IF.db.bagSort = false.
local IF = ImprovedForever

local DEFAULT_KEY = "PADLSTICK"

function IF.BagSortKey()
    return IF.db and IF.db.bagSortKey or DEFAULT_KEY
end

local owner = CreateFrame("Frame", "ImprovedForeverBagsOwner")
local sortButton = CreateFrame("Button", "ImprovedForeverSortBags", UIParent)
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
        IF.Print("bag sorting is not available on this client.")
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
    local want = IF.db.bagSort ~= false and AnyBagOpen()
    if want == bound then
        pending = false
        return
    end
    if IF.InCombat() then
        -- Override bindings can't change in combat; retry on PLAYER_REGEN_ENABLED.
        pending = true
        return
    end
    pending = false
    if want then
        SetOverrideBindingClick(owner, true, IF.BagSortKey(), sortButton:GetName(), "LeftButton")
    else
        ClearOverrideBindings(owner)
    end
    bound = want
end

local function WatchFrame(frame)
    if not frame or frame.ImprovedForeverWatched then
        return
    end
    frame.ImprovedForeverWatched = true
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

IF.UpdateBagBinding = UpdateBinding

-- Another button for it (nil: back to L3); out of combat (the Controller tab)
function IF.SetBagSortKey(key)
    IF.db.bagSortKey = key ~= DEFAULT_KEY and key or nil
    if bound and not IF.InCombat() then
        ClearOverrideBindings(owner)
        bound = false
    end
    UpdateBinding()
end

IF.OnLogin(function()
    WatchBagFrames()
    UpdateBinding()
end)

owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function()
    if pending then
        UpdateBinding()
    end
end)

-- Its binding, on the Controller tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "bagsort", label = "Bag clean-up", group = "Bags", tab = "controller",
    icon = 133633, context = "bags", order = 20,
    tip = "Sorts your bags. Only while a bag is open: the button does its own job again once they close.",
    accepts = B.Single,
    specs = function() return IF.db.bagSort ~= false and B.One(IF.BagSortKey()) or {} end,
    set = function(spec)
        IF.db.bagSort = spec ~= nil
        if spec then IF.SetBagSortKey(spec) else IF.UpdateBagBinding() end
    end,
})
