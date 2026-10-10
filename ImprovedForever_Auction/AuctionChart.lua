-- A price chart (the Sell tab's, the Buy window's): an item's market
-- price a day over the chart's days (a line), each day's lowest (dots),
-- the lowest now (a bright dot on today) and a price of the panel's own
-- (a dashed line: the price asked, the price to pay). Auction.lua's data.
-- IF.AuctionChart.New(parent, label) -> chart (a frame: place and size it);
-- chart:Draw({ itemID, lowestNow, price, searching })
local IF = ImprovedForever

local K = IF.ConfigKit
local KC = K.C
local A = IF.Auction

local AC = {}
IF.AuctionChart = AC

local COLORS = {
    market = { 0.94, 0.89, 0.78 }, lowest = { 0.79, 0.64, 0.35 }, now = { 1, 0.82, 0.29 },
    price = { 0.4, 0.9, 0.4 }, grid = { 0.45, 0.38, 0.25 },
}
local function Hex(c)
    return format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

local function Color(tex, c, a)
    tex:SetColorTexture(c[1], c[2], c[3], a or 1)
end

-- Pools of drawn parts, reused each drawing
local function Pool(make)
    local pool = { used = 0 }
    function pool:Get()
        self.used = self.used + 1
        local part = self[self.used]
        if not part then
            part = make()
            self[self.used] = part
        end
        part:Show()
        return part
    end
    function pool:Reset()
        for i = 1, #self do self[i]:Hide() end
        self.used = 0
    end
    return pool
end

-- label: what the dashed line is called in the key ("Yours", "Pay")
function AC.New(parent, label)
    local chart = K.NewFrame("Frame", nil, parent, "BackdropTemplate")
    chart:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    chart:SetBackdropColor(0, 0, 0, 0.45)
    chart:SetBackdropBorderColor(0.45, 0.38, 0.25, 1)

    local plot = K.NewFrame("Frame", nil, chart)
    plot:SetPoint("TOPLEFT", 10, -22)
    plot:SetPoint("BOTTOMRIGHT", -10, 20)

    local hiText = K.ChatText(chart, 10, KC.help)
    hiText:SetPoint("TOPLEFT", 8, -6)
    local loText = K.ChatText(chart, 10, KC.help)
    loText:SetPoint("BOTTOMLEFT", 8, 5)
    local nowText = K.ChatText(chart, 10, KC.help)
    nowText:SetPoint("BOTTOMRIGHT", -8, 5)
    local keyText = K.ChatText(chart, 10, KC.help)
    keyText:SetPoint("TOPRIGHT", -8, -6)
    keyText:SetText(Hex(COLORS.market) .. "—|r Usual  " .. Hex(COLORS.lowest) .. "•|r Lowest  "
        .. Hex(COLORS.price) .. "- -|r " .. (label or "Yours"))
    local emptyText = K.ChatText(chart, 11, KC.grey)
    emptyText:SetPoint("LEFT", plot, "LEFT", 10, 0)
    emptyText:SetPoint("RIGHT", plot, "RIGHT", -10, 0)
    emptyText:SetJustifyH("CENTER")

    -- Gridlines: the top and bottom of the price range
    for _, point in ipairs({ "TOP", "BOTTOM" }) do
        local g = plot:CreateTexture(nil, "BACKGROUND")
        g:SetHeight(1)
        g:SetPoint(point .. "LEFT")
        g:SetPoint(point .. "RIGHT")
        Color(g, COLORS.grid, 0.5)
    end

    local lines = Pool(function()
        local l = plot:CreateLine(nil, "ARTWORK")
        l:SetThickness(2)
        return l
    end)
    local dots = Pool(function() return plot:CreateTexture(nil, "OVERLAY") end)
    local dashes = Pool(function() return plot:CreateTexture(nil, "ARTWORK", nil, 1) end)

    local function Dot(x, y, size, c)
        local d = dots:Get()
        d:SetSize(size, size)
        d:ClearAllPoints()
        d:SetPoint("CENTER", plot, "BOTTOMLEFT", x, y)
        Color(d, c)
    end

    function chart:Draw(S)
        lines:Reset()
        dots:Reset()
        dashes:Reset()
        local days = A.Settings().chartDays
        local history = A.History(S.itemID, days)
        local values = {}
        for _, d in ipairs(history) do
            values[#values + 1] = d.market
            values[#values + 1] = d.lowest
        end
        if S.lowestNow then values[#values + 1] = S.lowestNow end
        local hasData = #values > 0
        if S.price then values[#values + 1] = S.price end
        emptyText:SetShown(not hasData)
        emptyText:SetText(S.searching and "Searching..." or "No prices for it yet: the auction house is scanned as it opens.")
        hiText:SetShown(hasData)
        loText:SetShown(hasData)
        nowText:SetText(days .. " days ago  ·  today")
        if #values == 0 then return end
        local lo, hi = math.huge, 0
        for _, v in ipairs(values) do
            lo, hi = math.min(lo, v), math.max(hi, v)
        end
        -- A little room above and below; one price alone: a band round it
        local span = hi - lo
        if span <= 0 then span = math.max(hi * 0.2, 2) end
        lo, hi = math.max(0, lo - span * 0.12), hi + span * 0.12
        hiText:SetText(A.Money(hi))
        loText:SetText(A.Money(lo))
        local w, h = plot:GetWidth(), plot:GetHeight()
        if not w or w <= 0 then return end
        local today = A.Today()
        local function X(day)
            return (day - (today - days + 1)) / math.max(1, days - 1) * w
        end
        local function Y(v)
            return (v - lo) / (hi - lo) * h
        end
        -- The market line, the lowest dots
        local last
        for _, d in ipairs(history) do
            local x, y = X(d.day), Y(d.market)
            if last then
                local l = lines:Get()
                l:SetStartPoint("BOTTOMLEFT", plot, last[1], last[2])
                l:SetEndPoint("BOTTOMLEFT", plot, x, y)
                Color(l, COLORS.market)
            end
            Dot(x, y, 4, COLORS.market)
            Dot(x, Y(d.lowest), 5, COLORS.lowest)
            last = { x, y }
        end
        -- The lowest now
        if S.lowestNow then Dot(X(today), Y(S.lowestNow), 8, COLORS.now) end
        -- The panel's price: dashes across
        if S.price then
            local y, x = Y(S.price), 0
            while x < w do
                local dash = dashes:Get()
                dash:SetSize(math.min(6, w - x), 2)
                dash:ClearAllPoints()
                dash:SetPoint("LEFT", plot, "BOTTOMLEFT", x, y)
                Color(dash, COLORS.price)
                x = x + 10
            end
        end
    end

    return chart
end
