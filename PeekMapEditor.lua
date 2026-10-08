-- The Map tab, a tab of settings (IC.SettingsPage, SettingsPage.lua): how
-- the peek map looks (opacity, size, place on the screen and an offset
-- from it: two sliders, dragged with the right stick); seen the next time
-- it opens. Its hotkey and touchpad corner are set in the General tab
-- (Binds.lua). PeekMap.lua does the work.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local PeekMap = IC.PeekMap
local Item = IC.SettingsItem

local TEX = "Interface\\AddOns\\ImprovedController\\textures\\"
local OPACITY, SIZE = TEX .. "ic_map_opacity", TEX .. "ic_map_size"

-- A place on the screen's icon: the map's spot on a screen
local function PosIcon(anchor)
    return TEX .. "ic_map_pos_" .. anchor:lower()
end

local function S()
    return PeekMap.Settings()
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

---------------------------------------------------------------------------
-- The offset: two sliders (left / right, up / down) in the middle; the
-- D-pad picks one and moves it 1% a step, the right stick drags the map
-- (while the item is picked, in the list or the sliders), Triangle centres
---------------------------------------------------------------------------
local LIMIT, STEP, SPEED = 0.5, 0.01, 0.5   -- of the screen; SPEED a second at full tilt
local DEAD = 0.2                           -- the stick's dead zone
local AXES = {
    { key = "x", label = "Left / right" },
    { key = "y", label = "Up / down" },
}

local function Percent(v)
    return math.floor(v * 100 + (v < 0 and -0.5 or 0.5))
end

local function Clamp(v)
    return math.max(-LIMIT, math.min(LIMIT, v))
end

local function RightStick()
    local index = C_GamePad and C_GamePad.StickConfigNameToIndex and C_GamePad.StickConfigNameToIndex("Right") or 2
    local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
    local stick = state and state.sticks and state.sticks[index]
    if stick then return stick.x or 0, stick.y or 0 end
    return 0, 0
end

local TRACK_L, TRACK_R = 132, 64   -- the track's ends, in from the row's sides

local OFFSET = {
    build = function(parent)
        local p = K.NewFrame("Frame", nil, parent)
        p:SetSize(340, 160)
        p.row = 1
        p.rows = {}
        for i, axis in ipairs(AXES) do
            local r = K.NewFrame("Button", nil, p)
            r:SetSize(316, 35)
            -- (where a single list's rows start: no name above them)
            r:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -(i - 1) * K.ROW_STEP)
            r.seg = K.Segment(r)
            r.label = K.Text(r, 14, KC.rail)
            r.label:SetPoint("LEFT", 12, 0)
            r.label:SetText(axis.label)
            r.value = K.Text(r, 14, KC.cream)
            r.value:SetPoint("RIGHT", -12, 0)
            r.value:SetWidth(48)
            r.value:SetJustifyH("RIGHT")
            r.track = K.NewFrame("Frame", nil, r)
            r.track:SetPoint("LEFT", TRACK_L, 0)
            r.track:SetPoint("RIGHT", -TRACK_R, 0)
            r.track:SetHeight(8)
            r.trackBox = K.Box(r.track, 4, 1, "ARTWORK")
            r.trackBox:SetPoints(r.track)
            r.mid = K.Solid(r.track, KC.boxEdge, 1, "ARTWORK", 3)
            r.mid:SetSize(2, 14)
            r.mid:SetPoint("CENTER")
            r.handle = K.Solid(r.track, KC.dimGold, 1, "OVERLAY")
            r.handle:SetSize(12, 18)
            r:SetScript("OnClick", function()
                p.row = i
                menu.Render()
            end)
            p.rows[i] = r
        end
        -- The right stick drags the map while this shows
        p:SetScript("OnUpdate", function(self, elapsed)
            local x, y = RightStick()
            local moved = false
            for _, v in ipairs({ { "x", x }, { "y", y } }) do
                local tilt = v[2]
                if math.abs(tilt) > DEAD then
                    local speed = (math.abs(tilt) - DEAD) / (1 - DEAD)
                    S()[v[1]] = Clamp(S()[v[1]] + (tilt > 0 and 1 or -1) * speed * speed * SPEED * elapsed)
                    moved = true
                end
            end
            if moved then menu.Render() end
        end)
        return p
    end,
    render = function(p, focused)
        for i, axis in ipairs(AXES) do
            local r = p.rows[i]
            local on = focused and p.row == i
            r.seg:SetFocus(on)
            r.label:SetTextColor(unpack(on and KC.focus or KC.rail))
            local v = S()[axis.key]
            r.value:SetText((Percent(v) > 0 and "+" or "") .. Percent(v) .. "%")
            local w = r.track:GetWidth()
            if not w or w <= 0 then w = 316 - TRACK_L - TRACK_R end
            r.handle:ClearAllPoints()
            r.handle:SetPoint("CENTER", r.track, "LEFT", (v + LIMIT) / (2 * LIMIT) * w, 0)
            r.trackBox:SetColors(KC.controlBg, 1, on and KC.slot or KC.control, 1)
            local hc = on and KC.focus or KC.dimGold
            r.handle:SetColorTexture(hc[1], hc[2], hc[3], 1)
        end
    end,
    press = function(p, name)
        if name == "UP" or name == "DOWN" then
            p.row = name == "UP" and 1 or 2
        elseif name == "LEFT" or name == "RIGHT" then
            local key = AXES[p.row].key
            S()[key] = Clamp((Percent(S()[key]) + (name == "RIGHT" and 1 or -1)) * STEP)
        elseif name == "Y" then
            S().x, S().y = 0, 0
            menu.Toast("Offset: none")
        else
            return false
        end
        return true
    end,
    hints = function()
        local H = K.H
        return {
            H({ "DPAD" }, "Adjust"), H({ "RS" }, "Drag", "RS"), H({ "Y" }, "Centre", "Y"),
            H({ "LB", "RB" }, "Tab", "RB"), H({ "B" }, "Back", "B"),
        }
    end,
}

local ITEMS = {
    Item({
        key = "alpha", group = "look", label = "Opacity",
        icon = OPACITY,
        tip = "How solid the map is: lower shows more of the game through it.",
    }, Choice("alpha", "Opacity", {
        { 0.3, "30%" }, { 0.45, "45%" }, { 0.6, "60%" }, { 0.75, "75%" }, { 0.9, "90%" }, { 1, "100%" },
    }, OPACITY)),
    Item({
        key = "size", group = "look", label = "Size",
        icon = SIZE,
        tip = "The map's height, of the screen's.",
    }, Choice("size", "Size", {
        { 0.4, "40% of the screen" }, { 0.5, "50% of the screen" }, { 0.6, "60% of the screen" },
        { 0.7, "70% of the screen" }, { 0.8, "80% of the screen" }, { 0.9, "90% of the screen" },
    }, SIZE)),
    Item({
        key = "anchor", group = "look", label = "Position",
        icon = function() return PosIcon(S().anchor) end,
        tip = "Where on the screen the map shows.",
    }, Choice("anchor", "Position", {
        { "CENTER", "Centre", PosIcon("CENTER") }, { "TOP", "Top", PosIcon("TOP") },
        { "BOTTOM", "Bottom", PosIcon("BOTTOM") }, { "LEFT", "Left", PosIcon("LEFT") },
        { "RIGHT", "Right", PosIcon("RIGHT") }, { "TOPLEFT", "Top left", PosIcon("TOPLEFT") },
        { "TOPRIGHT", "Top right", PosIcon("TOPRIGHT") }, { "BOTTOMLEFT", "Bottom left", PosIcon("BOTTOMLEFT") },
        { "BOTTOMRIGHT", "Bottom right", PosIcon("BOTTOMRIGHT") },
    })),
    Item({
        key = "offset", group = "look", label = "Offset",
        icon = TEX .. "ic_map_offset",
        tip = "Moves the map from its position, by a share of the screen. The right stick drags it;"
            .. " in the sliders, the D-pad moves it 1% at a time.",
        text = function()
            local x, y = S().x, S().y
            if Percent(x) == 0 and Percent(y) == 0 then return "None" end
            return (x < 0 and "Left " or "Right ") .. math.abs(Percent(x)) .. "%, "
                .. (y < 0 and "Down " or "Up ") .. math.abs(Percent(y)) .. "%"
        end,
        panel = OFFSET,
    }),
}

local GROUPS = {
    { key = "look", label = "Peek map" },
}

menu.AddTab({ key = "peekmap", label = "Map", sections = {} }, "vibration")
IC.PeekMapEditor = IC.SettingsPage("peekmap", "Map", GROUPS, ITEMS)
