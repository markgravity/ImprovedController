-- The auction house window's Tasks tab (AuctionBuy.lua's window): down the
-- left what the tasks (Tasks.lua) still need, in sections (the tasks first):
--   Tasks: each task, what is left of it;
--   To buy here: from the auction house;
--   From a vendor: sold by vendors, bought at one (its own Tasks).
-- On the right, the item picked: the Buy tab's item screen itself (its
-- chart, its quantity or auctions, Cross buys), opened with the quantity
-- still missing; for a vendor's item or a task, what it is.
-- The left stick picks in the list (as Buy's categories); the D-pad and
-- the buttons work the item; Triangle on a task removes it (asking first,
-- AuctionConfirm.lua).
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local A = IC.Auction
local BY = IC.AuctionBuy
local TK = IC.Tasks

local TT = { key = "tasks", label = "Tasks", icon = "Interface\\Icons\\INV_Misc_Note_01" }
IC.AuctionTasks = TT

local LIST_W = 190 + 14            -- the Buy tab's categories' column
local DETAIL_X = 14 + LIST_W + 12
local ROW_H = 48
local OPEN_AFTER = 0.3             -- resting on an item this long: its screen opens (searched)

local Glyph = function(key, size) return BY.Glyph(key, size) end

local f, slots, info
local lines = {}
local sel, top = 1, 1
local pickedAt = 0

local function ItemInfo(id)
    return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id)
end

-- The lines: { header, count } or { need (an item's) } or { task }
local function Build()
    lines = {}
    local here, vendor = {}, {}
    for _, e in ipairs(TK.Needs()) do
        if e.missing > 0 then
            if e.vendor then vendor[#vendor + 1] = e else here[#here + 1] = e end
        end
    end
    local function Section(label, list, color)
        if #list == 0 then return end
        lines[#lines + 1] = { header = label, count = #list, color = color }
        for _, e in ipairs(list) do lines[#lines + 1] = { need = e } end
    end
    local tasks = TK.Tasks()
    if #tasks > 0 then
        lines[#lines + 1] = { header = "Tasks", count = #tasks, color = "|cffffd200" }
        for _, t in ipairs(tasks) do lines[#lines + 1] = { task = t } end
    end
    Section("To buy here", here, "|cff5fd35f")
    Section("From a vendor", vendor, "|cffd8ccb0")
end

local function Selectable(line)
    return line and not line.header
end

-- The line picked: an item to buy here (its screen opens after a moment)
local function Here(line)
    return line and line.need and not line.need.vendor and line.need or nil
end

local function Move(dir)
    local i = sel
    repeat i = i + dir until i < 1 or i > #lines or Selectable(lines[i])
    if lines[i] and i ~= sel then
        sel = i
        pickedAt = GetTime()
    end
end

function TT.Build(parent)
    f = K.NewFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:Hide()

    -- Left: the list
    local box = BY.Panel(f, 0.4)
    box:SetPoint("TOPLEFT", 14, -30)
    box:SetPoint("BOTTOMLEFT", 14, 36)
    box:SetWidth(LIST_W)
    f.title = K.ChatText(box, 12, KC.dimGold)
    f.title:SetPoint("TOP", 0, -10)
    slots = {}
    local width = LIST_W - 16
    for i = 1, math.floor((BY.H - 30 - 36 - 34) / ROW_H) do
        local slot = {}
        slot.row = BY.ItemRow(box, width, ROW_H - 4, width - 50 - 6)
        slot.row:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        slot.row:SetScript("OnClick", function()
            if slot.index then
                sel, pickedAt = slot.index, GetTime()
                BY.Render()
            end
        end)
        slot.header = K.NewFrame("Frame", nil, box)
        slot.header:SetSize(width, ROW_H - 4)
        slot.header:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        slot.header.text = slot.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        slot.header.text:SetPoint("BOTTOMLEFT", 4, 8)
        slot.header.info = K.ChatText(slot.header, 11, KC.help)
        slot.header.info:SetPoint("BOTTOMRIGHT", -4, 8)
        local rule = slot.header:CreateTexture(nil, "ARTWORK")
        rule:SetHeight(1)
        rule:SetPoint("BOTTOMLEFT", 0, 3)
        rule:SetPoint("BOTTOMRIGHT", 0, 3)
        rule:SetColorTexture(0.45, 0.38, 0.25, 0.8)
        slots[i] = slot
    end

    -- Right: what isn't bought here (a vendor's item, a task, nothing yet)
    info = BY.Panel(f, 0.4)
    info:SetPoint("TOPLEFT", DETAIL_X, -30)
    info:SetPoint("BOTTOMRIGHT", -16, 36)
    info.icon = BY.ItemIcon(info, 40)
    info.icon:SetPoint("TOPLEFT", 16, -14)
    info.name = info:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    info.name:SetPoint("TOPLEFT", info.icon, "TOPRIGHT", 10, -2)
    info.name:SetPoint("RIGHT", info, "RIGHT", -16, 0)
    info.name:SetJustifyH("LEFT")
    info.sub = K.ChatText(info, 11, KC.help)
    info.sub:SetPoint("BOTTOMLEFT", info.icon, "BOTTOMRIGHT", 10, 2)
    info.text = K.ChatText(info, 14, KC.cream)
    info.text:SetPoint("TOPLEFT", 22, -78)
    info.text:SetPoint("RIGHT", info, "RIGHT", -22, 0)
    info.text:SetJustifyH("LEFT")
    info.text:SetJustifyV("TOP")
    info.text:SetWordWrap(true)
    info.empty = K.ChatText(info, 13, KC.grey)
    info.empty:SetPoint("CENTER")
    info.empty:SetWidth(400)
    info.empty:SetJustifyH("CENTER")
    return f
end

-- The right side for a vendor's item or a task
local function RenderInfo(line)
    local empty = not line
    info.empty:SetShown(empty)
    for _, part in ipairs({ info.icon, info.icon.border, info.name, info.sub, info.text }) do part:SetShown(not empty) end
    if empty then
        info.empty:SetText("No tasks. In a profession window, on a recipe press " .. IC.ButtonName("Y")
            .. " (More options) and choose Add Task.")
        return
    end
    if line.need then
        local e = line.need
        local _, _, quality, _, _, _, _, _, _, iconID = ItemInfo(e.itemID)
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
        info.icon:SetTexture(iconID or 134400)
        info.icon.border:SetVertexColor(c and c.r or 0.6, c and c.g or 0.6, c and c.b or 0.6, 0.9)
        info.name:SetText(TK.ItemName(e.itemID))
        info.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
        if e.vendor then
            info.sub:SetText("Sold by vendors")
            info.text:SetText("Need " .. e.need .. ", have " .. e.have .. ": buy " .. e.missing .. ".|n|n"
                .. "|cffb9ab8cAt a vendor that sells it, press " .. IC.ButtonName("Y")
                .. " in its window (Tasks) to buy what your tasks need.|r")
        else
            -- (an item to buy here, its screen about to open)
            info.sub:SetText("At the auction house")
            info.text:SetText("Need " .. e.need .. ", have " .. e.have .. ": buy " .. e.missing .. ".|n|n"
                .. "|cffb9ab8cLooking it up...|r")
        end
    else
        local t = line.task
        local left = math.max(0, t.count - (t.made or 0))
        info.icon:SetTexture(t.icon or 134400)
        info.icon.border:SetVertexColor(0.6, 0.6, 0.6, 0.9)
        info.name:SetText(t.name .. " × " .. left)
        info.name:SetTextColor(1, 0.82, 0)
        info.sub:SetText((t.made or 0) > 0 and (t.made .. " made so far") or "Task")
        local parts = {}
        for _, r in ipairs(t.reagents) do
            local need = r.per * left
            local have = math.min(need, TK.ItemCount(r.itemID))
            parts[#parts + 1] = (have >= need and "|cff5fd35f" or "|cffd8ccb0") .. have .. "/" .. need .. "  "
                .. TK.ItemName(r.itemID) .. "|r" .. (have >= need and "" or ("  |cff9d917a"
                .. (TK.FromVendor(r.itemID) and "vendor" or "auction") .. "|r"))
        end
        info.text:SetText(table.concat(parts, "|n"))
    end
end

function TT.Render()
    if not f then return end
    Build()
    if not Selectable(lines[sel]) then
        local was = sel
        sel = 0
        Move(1)
        if sel == 0 then sel = 1 end
        if sel ~= was then pickedAt = GetTime() end
    end
    sel = math.max(1, math.min(sel, math.max(1, #lines)))
    local shown = #slots
    if sel < top then top = sel end
    if sel > top + shown - 1 then top = sel - shown + 1 end
    if top > 1 and lines[top - 1] and lines[top - 1].header and sel == top then top = top - 1 end
    top = math.max(1, math.min(top, math.max(1, #lines - shown + 1)))
    f.title:SetText(Glyph("LS", 18) .. " " .. #TK.Tasks() .. (#TK.Tasks() == 1 and " task" or " tasks"))
    local fr, fg, fb = BY.FocusColor()
    for i, slot in ipairs(slots) do
        local index = top + i - 1
        local line = lines[index]
        slot.index = index
        slot.header:SetShown(line ~= nil and line.header ~= nil)
        slot.row:SetShown(line ~= nil and line.header == nil)
        if line and line.header then
            slot.header.text:SetText(line.color .. line.header:upper() .. "|r")
            slot.header.info:SetText(line.count .. "")
        elseif line then
            local row = slot.row
            if line.need then
                local e = line.need
                local _, _, quality, _, _, _, _, _, _, iconID = ItemInfo(e.itemID)
                row:Fill({
                    icon = iconID, quality = quality, name = TK.ItemName(e.itemID),
                    line = "buy " .. e.missing .. (e.vendor and "  ·  vendor" or ""),
                })
            else
                local t = line.task
                local left = math.max(0, t.count - (t.made or 0))
                local ready = true
                for _, r in ipairs(t.reagents) do
                    if TK.ItemCount(r.itemID) < r.per * left then ready = false end
                end
                row:Fill({
                    icon = t.icon, quality = 1, name = t.name .. " × " .. left,
                    line = ready and "|cff5fd35fready to craft|r" or "reagents to get",
                })
            end
            row.focus:SetShown(index == sel)
            row.focus:SetVertexColor(fr, fg, fb)
        end
    end
    -- Right: the item's screen for one to buy here, else what it is
    local line = lines[sel]
    local here = Here(line)
    -- (another item's screen still up: closed; this one's opens after a moment)
    if BY.DetailItemID() and not (here and BY.DetailItemID() == here.itemID) then BY.DetailClose() end
    info:SetShown(not (here and BY.DetailItemID() == here.itemID))
    if info:IsShown() then
        RenderInfo(line)
        if GameTooltip:GetOwner() == BY.window then GameTooltip:Hide() end
    else
        BY.DetailRender()
        BY.Tip()
    end
end

function TT.Hints()
    local line = lines[sel]
    local here = Here(line)
    local parts = { Glyph("LS") .. " Item" }
    local text = table.concat(parts, "   ") .. "   "
    if here and BY.DetailItemID() == here.itemID then text = text .. BY.DetailHints() end
    if line and line.task then text = text .. Glyph("Y") .. " Remove task   " end
    return text .. Glyph("B") .. " Close"
end

-- The left stick: the list
function TT.StickStep(dir)
    Move(dir)
    BY.Render()
end

function TT.Press(name, fast)
    local line = lines[sel]
    local here = Here(line)
    -- The item's screen first (Circle: not its; the auction house closes)
    if here and BY.DetailItemID() == here.itemID and BY.DetailPress(name, fast, true) then return true end
    if name == "UP" or name == "DOWN" then
        Move(name == "UP" and -1 or 1)
    elseif name == "Y" and line and line.task then
        local t = line.task
        IC.AuctionConfirm.Show({
            title = "Remove task", over = BY.window,
            icon = t.icon, name = t.name, quality = 1, count = math.max(0, t.count - (t.made or 0)),
            sub = "Its reagents stay in your bags",
            accept = "Remove", cancel = "Keep it",
            onAccept = function()
                TK.Remove(t)
                BY.Render()
            end,
        })
    else
        return name ~= "B"
    end
    BY.Render()
    return true
end

-- A moment's rest on an item to buy here: its screen opened (searched),
-- the quantity still missing
function TT.Update(now)
    local here = Here(lines[sel])
    if here and BY.DetailItemID() ~= here.itemID and now - pickedAt >= OPEN_AFTER then
        BY.DetailOpen(here.itemID, here.missing)
        BY.Render()
    end
end

function TT.Show()
    f:Show()
    BY.DetailInto(f, DETAIL_X, -30, -16, 36)
    sel, top, pickedAt = 1, 1, 0
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
