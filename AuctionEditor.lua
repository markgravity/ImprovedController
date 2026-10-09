-- The Auction tab, a tab of settings (IC.SettingsPage, SettingsPage.lua):
-- the price scans and what is kept of them, the Buy window, and the Sell
-- panel (Square on a bag item at the auction house): the price it starts
-- at, the quantity, the duration. Auction.lua, AuctionBuy.lua and
-- AuctionSell.lua do the work.
local _, IC = ...

local menu = IC.Menu
local A = IC.Auction
local Item, OnOff = IC.SettingsItem, IC.SettingsOnOff

local ICON = "Interface\\Icons\\"
local TEX = "Interface\\AddOns\\ImprovedController\\textures\\"
local COIN, WATCH = ICON .. "INV_Misc_Coin_01", ICON .. "INV_Misc_PocketWatch_01"

local function S()
    return A.Settings()
end

-- A choice of values: { { value, name, icon }... } on a setting's key
local function Choice(key, label, choices, icon)
    local byValue = {}
    for _, c in ipairs(choices) do byValue[c[1]] = c end
    return {
        value = function() return tostring(S()[key]) end,
        text = function()
            local c = byValue[S()[key]]
            return c and c[2] or tostring(S()[key])
        end,
        options = function()
            local list = {}
            for _, c in ipairs(choices) do
                list[#list + 1] = { action = tostring(c[1]), name = c[2], icon = c[3] or icon }
            end
            return list
        end,
        choose = function(action)
            for _, c in ipairs(choices) do
                if tostring(c[1]) == action then
                    S()[key] = c[1]
                    menu.Toast(label .. ": " .. c[2])
                end
            end
        end,
    }
end

local function Ago(at)
    if not at then return "never" end
    local s = math.max(0, time() - at)
    if s < 3600 then return math.floor(s / 60) .. " min ago" end
    if s < 86400 then return math.floor(s / 3600) .. " h ago" end
    return math.floor(s / 86400) .. " days ago"
end

local ITEMS = {
    Item({
        key = "scan", group = "scan", label = "Scan on open",
        icon = ICON .. "INV_Misc_Spyglass_02",
        tip = "Reads every auction as the auction house opens, and keeps each item's lowest and market price"
            .. " for the day. The server allows one full scan in 15 minutes; it takes a few seconds.",
    }, OnOff(function() return S().scan end, function(on) S().scan = on end, "Scan on open")),
    Item({
        key = "data", group = "scan", label = "Price data",
        icon = ICON .. "INV_Scroll_03",
        tip = "Prices kept for this realm. Scan now needs the auction house open (also /ic scan).",
        text = function()
            if not A.Available() then return "|cffff7a5cNo auction house on this client|r" end
            local n, at = A.Stats()
            local scanning, read, total = A.Scanning()
            return n .. " items priced|nLast scan: " .. Ago(at)
                .. (scanning and ("|n|cff9fd8e2Scanning" .. (total and (" " .. read .. " / " .. total) or "...") .. "|r") or "")
        end,
        value = function() end,
        options = function()
            return {
                { action = "scan", name = "Scan now", icon = ICON .. "INV_Misc_Spyglass_02" },
                { action = "clear", name = menu.IsArmed("auction:clear") and "|cffff7a5cAgain to clear|r"
                    or "Clear this realm's prices", icon = ICON .. "INV_Misc_Bone_HumanSkull_01" },
            }
        end,
        choose = function(action)
            if action == "scan" then
                local ok, why = A.CanScan()
                if ok then A.Scan() end
                menu.Toast(ok and "Scanning the auction house..." or ("Scan: " .. why), not ok, ok and 1.8 or 3)
            elseif menu.IsArmed("auction:clear") then
                menu.Disarm()
                A.Clear()
                menu.Toast("Prices cleared", true)
            else
                menu.Arm("auction:clear")
                menu.Toast("Choose it again to clear this realm's prices", true, 4)
            end
        end,
    }),
    Item({
        key = "keepDays", group = "scan", label = "Keep prices",
        icon = WATCH,
        tip = "How long each day's prices are kept. Older ones go at login.",
    }, Choice("keepDays", "Keep prices", {
        { 14, "14 days" }, { 30, "30 days" }, { 60, "60 days" }, { 90, "90 days" },
    }, WATCH)),
    Item({
        key = "sell", group = "sell", label = "Sell panel",
        icon = COIN,
        tip = "At the auction house, Square on a bag item opens the Sell panel: its price history,"
            .. " the lowest now and a suggested price; left / right change it, Cross sells.",
    }, OnOff(function() return S().sell end, function(on) S().sell = on end, "Sell panel")),
    Item({
        key = "pricing", group = "sell", label = "Start at",
        icon = ICON .. "INV_Misc_Coin_02",
        tip = "The price the panel suggests first; Triangle goes through the others. With none listed,"
            .. " the market price; with nothing known, three times what a vendor pays. A price you set by"
            .. " hand for an item comes first next time (Your last price).",
    }, Choice("pricing", "Start at", {
        { "undercut", "Undercut the lowest" }, { "match", "Match the lowest" },
        { "market", "Market price (its usual)" },
    }, ICON .. "INV_Misc_Coin_02")),
    Item({
        key = "undercut", group = "sell", label = "Undercut by",
        icon = ICON .. "INV_Misc_Coin_03",
        tip = "How far under the lowest price anyone else asks. Your own lowest is matched, never undercut.",
    }, Choice("undercut", "Undercut by", {
        { "1", "1 copper" }, { "100", "1 silver" }, { "1%", "1%" }, { "5%", "5%" },
    }, ICON .. "INV_Misc_Coin_03")),
    Item({
        key = "vendorFloor", group = "sell", label = "Vendor floor",
        icon = ICON .. "INV_Misc_Coin_04",
        tip = "Never suggests less than a vendor pays for it, after the auction house's cut.",
    }, OnOff(function() return S().vendorFloor end, function(on) S().vendorFloor = on end, "Vendor floor")),
    Item({
        key = "quantity", group = "sell", label = "Quantity",
        icon = ICON .. "INV_Misc_Bag_08",
        tip = "How many the Sell panel sells.",
    }, Choice("quantity", "Quantity", {
        { "all", "All in the bags" }, { "stack", "The stack picked" }, { "one", "One" },
    }, ICON .. "INV_Misc_Bag_08")),
    Item({
        key = "duration", group = "sell", label = "Duration",
        icon = WATCH,
        tip = "How long auctions run: longer costs a bigger deposit. Changing it while selling sets it here too.",
    }, Choice("duration", "Duration", {
        { 1, IC.Auction.Durations()[1] }, { 2, IC.Auction.Durations()[2] }, { 3, IC.Auction.Durations()[3] },
    }, WATCH)),
    Item({
        key = "chartDays", group = "sell", label = "Chart",
        icon = ICON .. "INV_Misc_Note_01",
        tip = "The days the price chart shows, and the market price is taken over.",
    }, Choice("chartDays", "Chart", {
        { 7, "Last 7 days" }, { 14, "Last 14 days" }, { 30, "Last 30 days" },
    }, ICON .. "INV_Misc_Note_01")),
}

ITEMS[#ITEMS + 1] = Item({
    key = "buy", group = "buy", label = "Auction window",
    icon = ICON .. "INV_Misc_Bag_10",
    tip = "Opens over the auction house, used with the pad, its tabs down the right (the right stick up / down): Buy (the left"
        .. " stick picks the category, L1 / R1 and L2 / R2 the next two levels, L3 the filters), Sell (your"
        .. " bags sorted for profit) and Auctions (yours, to cancel). Off: the game's own window.",
}, OnOff(function() return S().buy end, function(on) S().buy = on end, "Auction window"))
ITEMS[#ITEMS + 1] = Item({
    key = "buyView", group = "buy", label = "Show results",
    icon = ICON .. "INV_Misc_Bag_10",
    tip = "As a list (names, how many, prices) or a grid of icons. Also in the window's filters (L3).",
}, Choice("buyView", "Show results", { { "list", "As a list" }, { "grid", "As a grid" } }, ICON .. "INV_Misc_Bag_10"))
ITEMS[#ITEMS + 1] = Item({
    key = "tooltip", group = "use", label = "Tooltips",
    icon = ICON .. "INV_Misc_Note_01",
    tip = "Item tooltips show its usual auction price and the latest lowest (and a bag stack's worth).",
}, OnOff(function() return S().tooltip end, function(on) S().tooltip = on end, "Tooltips"))
ITEMS[#ITEMS + 1] = Item({
    key = "destroy", group = "use", label = "Destroy panel",
    icon = TEX .. "ic_emote_no",
    tip = "The Destroy panel leaves out what sells for more at the auction house than to a vendor"
        .. " (unless next to nothing either way), and shows each item's auction worth.",
}, OnOff(function() return S().destroy end, function(on) S().destroy = on end, "Destroy panel"))

ITEMS[#ITEMS + 1] = Item({
    key = "upgradeBags", group = "upgrades", label = "Bag arrows",
    icon = ICON .. "INV_Misc_Bag_08",
    tip = "A green arrow on a bag item better than what you wear in its slot: scored by its stats for"
        .. " your class and talents (else its item level), only what you can wear. The Buy window marks"
        .. " them too (its filters, L3). The Destroy panel never offers one.",
}, OnOff(function() return IC.Upgrades.Settings().bags end, function(on)
    IC.Upgrades.Settings().bags = on
    IC.Upgrades.Refresh()
end, "Bag arrows"))

ITEMS[#ITEMS + 1] = Item({
    key = "tasksTracker", group = "tasks", label = "Tasks panel",
    icon = ICON .. "INV_Misc_Note_01",
    tip = "A Tasks panel on top of the quest tracker (the game stacks it there, the tracker made shorter), in its look: each task (a recipe's More options,"
        .. " Triangle, in a profession window: Add Task) with its reagents for all its crafts, had and needed,"
        .. " where from. With the tracker focused, L2 moves into it: Cross opens a recipe, Square crafts."
        .. " The auction house's Tasks tab and a vendor's (Triangle) buy what is missing.",
}, OnOff(function() return S().tasksTracker end, function(on)
    S().tasksTracker = on
    IC.Tasks.RenderTracker()
end, "Tasks panel"))

local GROUPS = {
    { key = "scan", label = "Prices" },
    { key = "buy", label = "Buying" },
    { key = "sell", label = "Selling" },
    { key = "use", label = "Using prices" },
    { key = "upgrades", label = "Upgrades" },
    { key = "tasks", label = "Tasks" },
}

menu.AddTab({ key = "auction", label = "Auction", sections = {} }, "vibration")
IC.AuctionEditor = IC.SettingsPage("auction", "Auction", GROUPS, ITEMS)
