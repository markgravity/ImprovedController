-- The Override tab, laid out like the Touchpad tab: the buttons that can be
-- overridden down the left, the selected one's action big in the middle,
-- and the picker (Spells, Items, Macros, Emotes, Interface; L2 / R2) down
-- the right, as the wheel's. A choice binds it; Triangle gives the button
-- back to the game.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local touch = IC.Touch
local MW = IC.MyWheels
local O = IC.Override

local PANEL_W, PICKER_TOP, PICKER_ROWS = 340, 236, 7
local RAIL_ROWS = 8
local ARC = 300
local function ArcX(dy)
    return math.sqrt(math.max(0, ARC * ARC - dy * dy))
end

local P = { zone = "rail", index = 1 }
O.Editor = P

function P:Button()
    return O.BUTTONS[self.index]
end

local function Label(action)
    if not touch.IsBound(action) then return nil end
    local emote = action:match("^emote:(.+)$")
    if emote then return (IC.ActionInfo(action)) or emote end
    return touch.ActionLabel(action)
end

local function Icon(action)
    if not touch.IsBound(action) then return nil end
    return touch.ActionIcon(action) or select(2, IC.ActionInfo(action)) or 134400
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function P:Build(parent)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- The middle: the selected button's action, big, its name under it
    local big = K.Slot(f, 150, 108)
    big:SetPoint("CENTER", f, "CENTER", 0, 10)
    big:SetScript("OnClick", function(_, button)
        if button == "RightButton" then P:Clear() else P:Aim() end
    end)
    f.big = big
    f.bound = K.Text(f, 16, KC.title)
    f.bound:SetPoint("TOP", big, "BOTTOM", 0, -40)
    f.bound:SetJustifyH("CENTER")
    f.note = K.Text(f, 12, KC.help)
    f.note:SetPoint("TOP", f.bound, "BOTTOM", 0, -8)
    f.note:SetWidth(300)
    f.note:SetJustifyH("CENTER")
    f.note:SetWordWrap(true)

    -- Left: the buttons, slices down the ring's left side
    f.rows = {}
    f.railUp, f.railDown = K.MoreArrows(f)
    for i in ipairs(O.BUTTONS) do
        local r = K.NewFrame("Button", nil, f)
        r:SetSize(200, 34)
        r.seg = K.Segment(r)
        r.label = K.Text(r, 14, KC.rail, "OVERLAY")
        r.label:SetJustifyH("CENTER")
        r.label:SetPoint("CENTER")
        r:SetScript("OnClick", function()
            P.index, P.zone = i, "rail"
            menu.Render()
        end)
        f.rows[i] = r
    end

    -- Right: what a button can run, as the wheel's picker
    local lists = {}
    for _, list in ipairs(MW.CATALOG) do lists[#lists + 1] = list end
    lists[#lists + 1] = { key = "interface", label = "Interface", entries = touch.InterfaceEntries }
    self.picker = K.Picker(f, PANEL_W, menu.Render, {
        bare = true, rowHeight = 38,
        arc = function(y) return ArcX(PICKER_TOP + y) end,
        ring = { anchor = f, theta = 0.34, x = -K.NEAR },
    })
    self.picker:SetPoint("TOPLEFT", f, "CENTER", 30 - K.NEAR, PICKER_TOP)
    self.picker:SetHeight(400)
    self.picker:Open({
        lists = lists, rows = PICKER_ROWS, chooseVerb = "Bind",
        current = function() return O.Get(P:Button().id) end,
        marked = function(e)
            for _, action in pairs(O.Settings()) do
                if action == e.action then return true end
            end
            return false
        end,
        onChoose = function(e) P:Bind(e) end,
        onBack = function()
            P.zone = "rail"
            menu.Render()
        end,
    })
end

function P:Show()
    self.zone = "rail"
    self.frame:Show()
end

function P:Hide()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Binding
---------------------------------------------------------------------------
function P:Aim()
    self.zone = "picker"
    -- On the list of its action, if it has one
    local action = O.Get(self:Button().id)
    local kind = touch.IsBound(action) and (action:match("^(%a+):") or "interface")
    for i, list in ipairs(self.picker.def.lists) do
        if kind and (list.key == kind or list.key == kind .. "s") then self.picker.list = i end
    end
    self.picker:LoadList()
    menu.Render()
end

function P:Bind(e)
    if IC.InCombat() then return menu.Toast("Not in combat", true) end
    local b = self:Button()
    O.Set(b.id, e.action)
    menu.Toast(O.Label(b) .. ": " .. (e.name or ""))
    menu.Render()
end

-- Triangle: the button back to the game's own action
function P:Clear()
    if IC.InCombat() then return menu.Toast("Not in combat", true) end
    local b = self:Button()
    if O.Get(b.id) then
        O.Set(b.id, nil)
        menu.Toast(O.Label(b) .. ": " .. (b.double and "nothing" or "the game's own action"))
    end
    menu.Render()
end

---------------------------------------------------------------------------
-- The pad
---------------------------------------------------------------------------
function P:Press(name)
    if name == "LB" or name == "RB" then return false end
    if name == "Y" then
        self:Clear()
        return true
    end
    if self.zone == "picker" then
        if name == "LEFT" or name == "B" then
            self.zone = "rail"
        elseif name ~= "RIGHT" then
            self.picker:Press(name)
        end
        menu.Render()
        return true
    end
    if name == "UP" or name == "DOWN" then
        self.index = math.max(1, math.min(#O.BUTTONS, self.index + (name == "UP" and -1 or 1)))
    elseif name == "RIGHT" or name == "A" then
        self:Aim()
        return true
    else
        return false
    end
    menu.Render()
    return true
end

function P:Help()
    local H = K.H
    local hints = {}
    if self.zone == "picker" then
        hints[#hints + 1] = H({ "DPAD" }, "Move")
        hints[#hints + 1] = H({ "A" }, "Bind", "A")
        hints[#hints + 1] = H({ "LT", "RT" }, "List", "RT")
    else
        hints[#hints + 1] = H({ "DPAD" }, "Pick button")
        hints[#hints + 1] = H({ "A" }, "Edit", "A")
    end
    hints[#hints + 1] = H({ "Y" }, "Game's own", "Y")
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, self.zone == "picker" and "Buttons" or "Close", "B")
    return hints
end

function P:Crumb()
    return "Override › " .. O.Label(self:Button())
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function P:Render()
    local f = self.frame
    if not f then return end
    if self.zone ~= "picker" then self.zone = "rail" end
    local lines = {}
    for i in ipairs(O.BUTTONS) do lines[i] = { index = i } end
    local shown, thetaAt
    self.railTop, shown, thetaAt = K.RailWindow(lines, self.index, self.railTop, RAIL_ROWS)
    K.RingArrow(f.railUp, f, thetaAt(0.25), true, K.NEAR)
    f.railUp:SetShown(self.railTop > 1)
    K.RingArrow(f.railDown, f, thetaAt(shown + 0.75), false, K.NEAR)
    f.railDown:SetShown(self.railTop + shown - 1 < #lines)
    for i, r in ipairs(f.rows) do
        local slot = i - self.railTop + 1
        r:SetShown(slot >= 1 and slot <= shown)
        if r:IsShown() then
            local theta = thetaAt(slot)
            local b = O.BUTTONS[i]
            r.seg:Place(f, theta, K.NEAR)
            local isSel = i == self.index
            r.seg:SetFocus(isSel and self.zone == "rail")
            local action = O.Get(b.id)
            local glyph = IC.GlyphAtlas(b.key) and (IC.GlyphText(b.key, 18) .. " ") or ""
            r.label:SetText(glyph .. O.Label(b)
                .. (action and ("  |cff9d917a" .. (Label(action) or "") .. "|r") or ""))
            r.label:SetTextColor(unpack(isSel and KC.focus or KC.rail))
            K.Rotate(r.label, K.ReadingAngle(theta))
        end
    end
    local b = self:Button()
    local action = O.Get(b.id)
    local bound = touch.IsBound(action)
    f.big:SetLook({ icon = bound and Icon(action) or nil, discColor = bound and KC.iconBg or nil,
        plus = not bound, dash = true })
    f.bound:SetText(bound and Label(action)
        or (b.double and "|cff9d917aNothing|r" or "|cff9d917aThe game's own action|r"))
    f.note:SetText(b.tip or "")
    self.picker:Show()
    self.picker:SetAlpha(self.zone == "picker" and 1 or 0.5)
    self.picker:Render()
end

---------------------------------------------------------------------------
-- The Override tab (Menu.lua) uses this page
---------------------------------------------------------------------------
for _, def in ipairs(menu.TABS) do
    if def.key == "override" then
        def.page = function() return P end
    end
end

hooksecurefunc(menu, "Close", function()
    P.zone = "rail"
end)
