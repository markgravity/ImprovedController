-- The auction house window's Tasks tab (AuctionBuy.lua's window): three
-- columns.
--   Left, the tasks (Tasks.lua): "All tasks", each task still getting its
--     reagents, then a "Ready to craft" section (the bags hold all it needs);
--   middle, what the picked one (all of them: added up) still needs from the
--     auction house, how many are missing (a vendor's items not: bought at
--     one, its own Tasks; how many: said under the list);
--   right, the picked item's screen (the Buy tab's itself: its chart, its
--     quantity or auctions, Cross held buys), opened with the quantity still
--     missing a moment after it is picked.
-- The left stick works the lists: left / right the column (tasks, items),
-- up / down the pick in it; the D-pad and the buttons work the item's
-- screen. Circle closes the auction house.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local A = IC.Auction
local BY = IC.AuctionBuy
local TK = IC.Tasks

local TASKS_W = 190 + 14           -- the Buy tab's categories' column
local ITEMS_W = 236                -- (the item's screen: the rest, as wide as the Sell tab's)
local ITEMS_X = 14 + TASKS_W + 10
local DETAIL_X = ITEMS_X + ITEMS_W + 10
local ROW_H = 48
local OPEN_AFTER = 0.3             -- resting on an item this long: its screen opens (searched)
local ALL_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local TT = { key = "tasks", label = "Tasks", icon = ALL_ICON }
IC.AuctionTasks = TT

local Glyph = function(key, size) return BY.Glyph(key, size) end

local f, taskSlots, itemRows, itemsBox, blank
local column = "items"                 -- the list the stick works
local taskSel, taskTop = 1, 1          -- in taskLines
local taskLines = {}                   -- { all } / { task } / { header, count }
local itemSel, itemTop = 1, 1
local items, vendorCount = {}, 0
local pickedAt = 0

local function ItemInfo(id)
    return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id)
end

-- A task ready to craft (the bags hold all it still needs)
local function Ready(t)
    local left = math.max(0, t.count - (t.made or 0))
    for _, r in ipairs(t.reagents) do
        if TK.ItemCount(r.itemID) < r.per * left then return false end
    end
    return true
end

-- The left list: all tasks, those still getting reagents, then the ready
-- ones under their header
local function TaskLines()
    taskLines = { { all = true } }
    local ready = {}
    for _, t in ipairs(TK.Tasks()) do
        if Ready(t) then ready[#ready + 1] = t else taskLines[#taskLines + 1] = { task = t } end
    end
    if #ready > 0 then
        taskLines[#taskLines + 1] = { header = "Ready to craft", count = #ready }
        for _, t in ipairs(ready) do taskLines[#taskLines + 1] = { task = t } end
    end
end

-- The picked task (nil: all of them)
local function PickedTask()
    local line = taskLines[taskSel]
    return line and line.task or nil
end

-- What the picked task (or all) still needs from the auction house:
-- { itemID, need, have, missing }; how many come from a vendor
local function Gather()
    items, vendorCount = {}, 0
    local task = PickedTask()
    if task then
        local left = math.max(0, task.count - (task.made or 0))
        for _, r in ipairs(task.reagents) do
            local need = r.per * left
            local have = TK.ItemCount(r.itemID)
            local missing = math.max(0, need - have)
            if missing > 0 then
                if TK.FromVendor(r.itemID) then
                    vendorCount = vendorCount + 1
                else
                    items[#items + 1] = { itemID = r.itemID, need = need, have = have, missing = missing }
                end
            end
        end
    else
        for _, e in ipairs(TK.Needs()) do
            if e.missing > 0 then
                if e.vendor then vendorCount = vendorCount + 1 else items[#items + 1] = e end
            end
        end
    end
end

local function Header(parent, width)
    local header = K.NewFrame("Frame", nil, parent)
    header:SetSize(width, ROW_H - 4)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("BOTTOMLEFT", 4, 8)
    header.info = K.ChatText(header, 11, KC.help)
    header.info:SetPoint("BOTTOMRIGHT", -4, 8)
    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 3)
    rule:SetPoint("BOTTOMRIGHT", 0, 3)
    rule:SetColorTexture(0.45, 0.38, 0.25, 0.8)
    return header
end

function TT.Build(parent)
    f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()
    local rowsFit = math.floor((BY.H - 30 - 36 - 34) / ROW_H)

    -- Left: the tasks
    local box = BY.Panel(f, 0.4)
    box:SetPoint("TOPLEFT", 14, -30)
    box:SetPoint("BOTTOMLEFT", 14, 36)
    box:SetWidth(TASKS_W)
    f.title = K.ChatText(box, 12, KC.dimGold)
    f.title:SetPoint("TOP", 0, -10)
    taskSlots = {}
    local width = TASKS_W - 16
    for i = 1, rowsFit do
        local row = BY.ItemRow(box, width, ROW_H - 4, width - 50 - 6)
        row:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        row:SetScript("OnClick", function(self)
            if self.index then
                column = "tasks"
                TT.PickTask(self.index)
                BY.Render()
            end
        end)
        row.header = Header(box, width)
        row.header:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        taskSlots[i] = row
    end

    -- Middle: what to buy here
    itemsBox = BY.Panel(f, 0.4)
    itemsBox:SetPoint("TOPLEFT", ITEMS_X, -30)
    itemsBox:SetPoint("BOTTOMLEFT", ITEMS_X, 36)
    itemsBox:SetWidth(ITEMS_W)
    itemsBox.title = K.ChatText(itemsBox, 12, KC.dimGold)
    itemsBox.title:SetPoint("TOP", 0, -10)
    itemsBox.note = K.ChatText(itemsBox, 11, KC.help)
    itemsBox.note:SetPoint("BOTTOM", 0, 10)
    itemsBox.note:SetWidth(ITEMS_W - 20)
    itemsBox.note:SetJustifyH("CENTER")
    itemsBox.empty = K.ChatText(itemsBox, 12, KC.grey)
    itemsBox.empty:SetPoint("CENTER")
    itemsBox.empty:SetWidth(ITEMS_W - 30)
    itemsBox.empty:SetJustifyH("CENTER")
    itemRows = {}
    width = ITEMS_W - 16
    for i = 1, rowsFit - 1 do
        local row = BY.ItemRow(itemsBox, width, ROW_H - 4, width - 50 - 6)
        row:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        row:SetScript("OnClick", function(self)
            if self.index then
                column = "items"
                itemSel, pickedAt = self.index, 0
                BY.Render()
            end
        end)
        itemRows[i] = row
    end

    -- Right: the item's screen (moved in on Show); nothing picked: a note
    blank = BY.Panel(f, 0.4)
    blank:SetPoint("TOPLEFT", DETAIL_X, -30)
    blank:SetPoint("BOTTOMRIGHT", -16, 36)
    blank.text = K.ChatText(blank, 13, KC.grey)
    blank.text:SetPoint("CENTER")
    blank.text:SetWidth(BY.W - DETAIL_X - 16 - 60)
    blank.text:SetJustifyH("CENTER")
    return f
end

-- A task picked (headers passed over, the way it was going): its items
-- from their top, the item's screen closed until one is picked
function TT.PickTask(index, dir)
    index = math.max(1, math.min(#taskLines, index))
    if taskLines[index] and taskLines[index].header then
        local past = index + (dir or 1)
        if taskLines[past] then index = past else index = taskSel end
    end
    if index == taskSel then return end
    taskSel = index
    itemSel, itemTop, pickedAt = 1, 1, GetTime()
end

local function RenderTasks()
    local tasks = TK.Tasks()
    local n = #taskLines
    taskSel = math.max(1, math.min(taskSel, n))
    if taskLines[taskSel].header then taskSel = taskSel + 1 end
    local shown = #taskSlots
    if taskSel < taskTop then taskTop = taskSel end
    if taskSel > taskTop + shown - 1 then taskTop = taskSel - shown + 1 end
    taskTop = math.max(1, math.min(taskTop, math.max(1, n - shown + 1)))
    f.title:SetText((column == "tasks" and Glyph("LS", 18) .. " " or "") .. #tasks
        .. (#tasks == 1 and " task" or " tasks"))
    local fr, fg, fb = BY.FocusColor()
    for i, row in ipairs(taskSlots) do
        local index = taskTop + i - 1
        local line = taskLines[index]
        row.index = index
        row:SetShown(line ~= nil and not line.header)
        row.header:SetShown(line ~= nil and line.header ~= nil)
        if line and line.header then
            row.header.text:SetText("|cff5fd35f" .. line.header:upper() .. "|r")
            row.header.info:SetText(line.count .. "")
        elseif line then
            if line.all then
                local count = 0
                for _, e in ipairs(TK.Needs()) do
                    if e.missing > 0 and not e.vendor then count = count + 1 end
                end
                row:Fill({ icon = ALL_ICON, quality = 1, name = "All tasks",
                    line = count > 0 and (count .. " to buy here") or "|cff5fd35fnothing to buy here|r" })
            else
                local t = line.task
                local left = math.max(0, t.count - (t.made or 0))
                row:Fill({ icon = t.icon, quality = 1, name = t.name .. " × " .. left,
                    line = Ready(t) and "|cff5fd35fready to craft|r" or "reagents to get" })
            end
            -- (the stick's list: its pick in the focus colour; the other: dimmed)
            row.focus:SetShown(index == taskSel)
            row.focus:SetVertexColor(fr, fg, fb, column == "tasks" and 1 or 0.35)
        end
    end
end

local function RenderItems()
    local n = #items
    itemsBox.title:SetText((column == "items" and Glyph("LS", 18) .. " " or "") .. "To buy here")
    itemsBox.note:SetText(vendorCount > 0 and (vendorCount .. " more from a vendor") or "")
    itemSel = math.max(1, math.min(itemSel, math.max(1, n)))
    local shown = #itemRows
    if itemSel < itemTop then itemTop = itemSel end
    if itemSel > itemTop + shown - 1 then itemTop = itemSel - shown + 1 end
    itemTop = math.max(1, math.min(itemTop, math.max(1, n - shown + 1)))
    itemsBox.empty:SetShown(n == 0)
    itemsBox.empty:SetText(#TK.Tasks() == 0 and "No tasks yet"
        or ("Nothing to buy here" .. (vendorCount > 0 and "" or ":|nthe bags hold it all")))
    local fr, fg, fb = BY.FocusColor()
    for i, row in ipairs(itemRows) do
        local index = itemTop + i - 1
        local e = items[index]
        row.index = index
        row:SetShown(e ~= nil)
        if e then
            local _, _, quality, _, _, _, _, _, _, iconID = ItemInfo(e.itemID)
            row:Fill({
                icon = iconID, quality = quality, name = TK.ItemName(e.itemID),
                line = "buy " .. e.missing .. "  ·  have " .. e.have .. "/" .. e.need,
            })
            row.focus:SetShown(index == itemSel)
            row.focus:SetVertexColor(fr, fg, fb, column == "items" and 1 or 0.35)
        end
    end
end

-- Right: the picked item's screen (opened a moment after it is picked),
-- else what there is to say
local function RenderRight()
    local e = items[itemSel]
    -- (another item's screen still up: closed)
    if BY.DetailItemID() and not (e and BY.DetailItemID() == e.itemID) then BY.DetailClose() end
    local up = e and BY.DetailItemID() == e.itemID
    blank:SetShown(not up)
    if up then
        BY.DetailRender()
        BY.Tip()
        return
    end
    if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
    if #TK.Tasks() == 0 then
        blank.text:SetText("No tasks. In a profession window, on a recipe press " .. IC.ButtonName("Y")
            .. " (More options) and choose Add Task.")
    elseif not e then
        blank.text:SetText("Nothing to buy at the auction house" .. (vendorCount > 0
            and (".|n|cffb9ab8cThe rest is sold by vendors: at one, press " .. IC.ButtonName("Y")
                .. " in its window (Tasks).|r") or ": the bags hold it all."))
    else
        blank.text:SetText("Looking it up...")
    end
end

function TT.Render()
    if not f then return end
    -- (the picked task kept picked as it moves between sections)
    local picked = PickedTask()
    TaskLines()
    if picked then
        for i, line in ipairs(taskLines) do
            if line.task == picked then taskSel = i end
        end
    end
    Gather()
    RenderTasks()
    RenderItems()
    RenderRight()
end

function TT.Hints()
    local text = Glyph("LS") .. " " .. (column == "tasks" and "Task" or "Item") .. "   "
    if BY.DetailItemID() and items[itemSel] and BY.DetailItemID() == items[itemSel].itemID then
        text = text .. BY.DetailHints()
    end
    return text .. Glyph("B") .. " Close"
end

-- The left stick: left / right the column, up / down the pick in it
function TT.StickSide(dir)
    local want = dir < 0 and "tasks" or "items"
    if want == column then return end
    column = want
    PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    BY.Render()
end

function TT.StickStep(dir)
    if column == "tasks" then
        TT.PickTask(taskSel + dir, dir)
    else
        local was = itemSel
        itemSel = math.max(1, math.min(#items, itemSel + dir))
        if itemSel ~= was then pickedAt = GetTime() end
    end
    BY.Render()
end

-- The buttons: the item's screen's (Circle: not its; the auction house closes)
function TT.Press(name, fast)
    if BY.DetailItemID() and BY.DetailPress(name, fast, true) then return true end
    return name ~= "B"
end

-- A moment's rest on an item: its screen opened (searched), the quantity
-- still missing
function TT.Update(now)
    local e = items[itemSel]
    if e and BY.DetailItemID() ~= e.itemID and now - pickedAt >= OPEN_AFTER then
        BY.DetailOpen(e.itemID, e.missing)
        BY.Render()
    end
end

function TT.Show()
    f:Show()
    BY.DetailInto(f, DETAIL_X, -30, -16, 36)
    column, itemSel, itemTop, pickedAt = "items", 1, 1, 0
end

function TT.Hide()
    BY.DetailClose()
    BY.DetailHome()
    if f then f:Hide() end
    if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
end

TK.OnChange(function()
    if f and f:IsShown() then BY.Render() end
end)

BY.AddPage(TT)
