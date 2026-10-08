-- The General tab: every press the addon answers, on a drawing of the
-- controller (each button marked when something of ours is on it, red when
-- two things clash there). A press is picked by making it: Square ("Find
-- press", Recorder.lua) and press the button (or hold one and press
-- another, or press one twice). The drawing lights it, under it what each
-- way of pressing that button does, and on the right, as the other tabs'
-- pickers, what the press can do, on what it does now: Cross binds. A
-- choice taking a press from something else asks first (Cross again).
-- The other tabs still bind their own things, through Binds.lua, so they
-- warn the same way.
-- On a PlayStation controller the touchpad shows its four corners: each
-- runs what it holds when the pad is clicked there (Touchpad.lua), picked
-- from Spells / Items / Macros / Interface (L2 / R2). Find press and click
-- the pad: the corner under the finger. Triangle clears one, held turns it
-- off.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu
local B = IC.Binds
local touch = IC.Touch
local MW = IC.MyWheels

local TEX = "Interface\\AddOns\\ImprovedController\\textures\\"
local PANEL_W, PICKER_ROWS = 340, 7

-- The drawing (tools/make_controller.py) at SCALE, its centre from the
-- screen's; the list on its right as the Wheels tab's, round the same
-- middle
local ART_W, ART_H, SCALE = 512, 256, 1.2
local ART_AT = { 0, 60 }
-- The Stage layout (ConfigKit): the drawing in the middle, its body 230
-- from its centre, the list on its right, centred on it up and down
local STAGE = K.Stage(230, ART_AT[2])

-- Its buttons: where they sit on the drawing (its pixels, y down), their
-- glyph's size; the touchpad's corners (region) in its recess
local SPOTS = {
    { key = "PADLTRIGGER", x = 148, y = 22 }, { key = "PADRTRIGGER", x = 364, y = 22 },
    { key = "PADLSHOULDER", x = 148, y = 56 }, { key = "PADRSHOULDER", x = 364, y = 56 },
    { key = "PADDUP", x = 128, y = 80, size = 28 }, { key = "PADDDOWN", x = 128, y = 140, size = 28 },
    { key = "PADDLEFT", x = 98, y = 110, size = 28 }, { key = "PADDRIGHT", x = 158, y = 110, size = 28 },
    { key = "PAD4", x = 384, y = 80, size = 28 }, { key = "PAD1", x = 384, y = 140, size = 28 },
    { key = "PAD3", x = 354, y = 110, size = 28 }, { key = "PAD2", x = 414, y = 110, size = 28 },
    { key = "PADLSTICK", x = 196, y = 158, size = 38 }, { key = "PADRSTICK", x = 316, y = 158, size = 38 },
    { key = "PADBACK", x = 256, y = 96, size = 40 },
    { key = "TOUCH:upleft", region = "upleft", x = 232, y = 84, size = 20 },
    { key = "TOUCH:upright", region = "upright", x = 280, y = 84, size = 20 },
    { key = "TOUCH:downleft", region = "downleft", x = 232, y = 108, size = 20 },
    { key = "TOUCH:downright", region = "downright", x = 280, y = 108, size = 20 },
    { key = "PADSOCIAL", x = 178, y = 74, size = 24 }, { key = "PADFORWARD", x = 334, y = 74, size = 24 },
}
local SPOT = {}
for _, s in ipairs(SPOTS) do SPOT[s.key] = s end

local LINES = 6
-- key: the button picked (or a touchpad corner), nil until one is found;
-- spec: the press on it
local P = { variant = {} }
B.Editor = P

-- A touchpad (its corners) only on a PlayStation controller; elsewhere the
-- same button is View / Minus
local function HasTouchpad()
    return IC.PadStyle() == "Shapes"
end

local function Visible(s)
    if s.region then return HasTouchpad() end
    if s.key == "PADBACK" then return not HasTouchpad() end
    return true
end

local function Region()
    return P.key and SPOT[P.key].region
end

---------------------------------------------------------------------------
-- What is bound where, read once a drawing
---------------------------------------------------------------------------
local function Snapshot()
    local bySpec = {}
    for _, def in ipairs(B.All()) do
        for _, spec in ipairs(def.specs()) do
            bySpec[spec] = bySpec[spec] or {}
            table.insert(bySpec[spec], def)
        end
    end
    return bySpec
end

local function Clashes(defs, spec)
    for i = 1, #(defs or {}) do
        for j = i + 1, #defs do
            if B.Clash(defs[i], defs[j], spec) then return true end
        end
    end
    return false
end

local function NoneName(spec)
    local held, _, double = B.Parse(spec)
    if not held and not double then
        -- (no name for it: what it does depends on what has the focus)
        return "The game's own"
    end
    return "Nothing"
end

local function DefText(def)
    return def.label .. (def.context == "bags" and " |cff9d917a(bags open)|r" or "")
end

---------------------------------------------------------------------------
-- The picker: what the press picked can do
---------------------------------------------------------------------------
function P:Spec()
    return self.spec or self.key
end

-- Ours that can go on the press: the wheels (wheels = true), or the rest
-- (an action has its own lists: Spells, Items...)
local function Ours(spec, wheels)
    local defs = {}
    for _, def in ipairs(B.All()) do
        if def.kind ~= "action" and (def.group == "Wheels") == wheels and def.accepts(spec) then
            defs[#defs + 1] = def
        end
    end
    return defs
end

local function Entries(spec, wheels)
    local entries = { { action = "none", name = NoneName(spec), icon = TEX .. "ic_emote_no" } }
    local group, groups = nil, {}
    local defs = Ours(spec, wheels)
    for _, def in ipairs(defs) do groups[def.group] = true end
    local many = next(groups) and next(groups, next(groups)) ~= nil
    for _, def in ipairs(defs) do
        if many and def.group ~= group then
            group = def.group
            entries[#entries + 1] = { header = group }
        end
        local sub
        local here = B.Has(def, spec)
        local there = def.specs()[1]
        if not here and there then
            sub = "on " .. B.Text(there)
        elseif def.context == "bags" then
            sub = "bags open"
        end
        entries[#entries + 1] = { action = def.id, name = def.label, icon = def.icon, sub = sub, here = here,
            def = def }
    end
    return entries
end

-- What a press or a corner can run: as the wheels' picker (Spells, Items,
-- Macros, Emotes; a corner: no emotes), and Interface (the game's windows)
local function ActionLists(emotes)
    local lists = {}
    for _, list in ipairs(MW.CATALOG) do
        if emotes or list.key ~= "emotes" then lists[#lists + 1] = list end
    end
    lists[#lists + 1] = { key = "interface", label = "Interface", entries = touch.InterfaceEntries }
    return lists
end

-- The list an action is in (or fallback)
local function ListOf(lists, action, fallback)
    local kind = touch.IsBound(action) and (action:match("^(%a+):") or "interface")
    for i, list in ipairs(lists) do
        if kind and (list.key == kind or list.key == kind .. "s") then return i end
    end
    return fallback or 1
end

function P:SyncPicker(force)
    -- Nothing picked: no list
    if not self.key then
        self.pickerFor = nil
        return self.picker:Close()
    end
    local want = Region() or self:Spec()
    if self.pickerFor == want and not force then return end
    self.pickerFor = want
    local region = Region()
    if region then
        local lists = ActionLists(false)
        self.picker:Open({
            lists = lists, list = self.variant[self.key] or ListOf(lists, touch.GetSettings().regions[region]),
            rows = PICKER_ROWS, chooseVerb = "Bind",
            current = function() return touch.GetSettings().regions[region] end,
            marked = function(e)
                for _, action in pairs(touch.GetSettings().regions) do
                    if action == e.action then return true end
                end
                return false
            end,
            onChoose = function(e) P:BindCorner(region, e) end,
        })
        return
    end
    -- A press: the wheels (where one can go on it), the addon's other
    -- things (Misc), then what it can run (where an action can go on it),
    -- on the list of what it does now
    local spec = self:Spec()
    local lists = {}
    if #Ours(spec, true) > 0 then
        lists[#lists + 1] = { key = "wheels", label = "Wheels", entries = function() return Entries(spec, true) end }
    end
    lists[#lists + 1] = { key = "misc", label = "Misc", entries = function() return Entries(spec, false) end }
    local misc = #lists
    if B.ActionFits(spec) then
        for _, list in ipairs(ActionLists(true)) do lists[#lists + 1] = list end
    end
    local start = misc
    local bound = B.Bound(spec)[1]
    if B.ActionOn(spec) then
        start = ListOf(lists, B.ActionOn(spec), misc)
    elseif bound and bound.group == "Wheels" then
        start = 1
    end
    self.picker:Open({
        lists = lists, list = start,
        rows = PICKER_ROWS, chooseVerb = "Bind",
        current = function(list)
            if list.key ~= "wheels" and list.key ~= "misc" then return B.ActionOn(spec) end
            for _, def in ipairs(B.Bound(spec)) do
                if def.kind ~= "action" and (def.group == "Wheels") == (list.key == "wheels") then return def.id end
            end
            return "none"
        end,
        marked = function(e)
            if e.def or e.action == "none" then return e.here end
            return e.action == B.ActionOn(spec)
        end,
        onChoose = function(e)
            if e.def or e.action == "none" then P:Choose(e) else P:ChooseAction(spec, e) end
        end,
    })
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function NewSpot(parent, s)
    local size = s.size or 30
    local b = K.NewFrame("Button", nil, parent)
    b:SetSize(size + 8, size + 8)
    b:SetPoint("CENTER", parent, "TOPLEFT", s.x, -s.y)
    b:RegisterForClicks("LeftButtonUp")
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(TEX .. "ic_slot_glow")
    b.glow:SetBlendMode("ADD")
    b.glow:SetSize(size * 2, size * 2)
    b.glow:SetPoint("CENTER")
    b.ring = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.ring:SetTexture(TEX .. "ic_ring_dash")
    b.ring:SetSize(size + 12, size + 12)
    b.ring:SetPoint("CENTER")
    if s.region then
        -- A corner: what it runs, or a "+"
        b.icon = K.RoundIcon(b, size, "ARTWORK")
        b.icon:SetPoint("CENTER")
        b.plus = K.Text(b, 14, KC.dimGold, "OVERLAY")
        b.plus:SetPoint("CENTER", 0, 1)
        b.plus:SetText("+")
    else
        b.glyph = K.Glyph(b, size)
        b.glyph:SetPoint("CENTER")
    end
    b.dot = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.dot:SetTexture(TEX .. "ic_dot")
    b.dot:SetSize(10, 10)
    b.dot:SetPoint("CENTER", b, "TOPRIGHT", -4, -4)
    -- (the mouse may pick one; the pad finds it by pressing it)
    b:SetScript("OnClick", function()
        P.key, P.spec = s.key, not s.region and s.key or nil
        menu.Render()
    end)
    return b
end

function P:Build(parent)
    local stage = parent:GetParent() or parent
    local f = K.NewFrame("Frame", nil, stage)
    f:SetAllPoints(stage)
    f:Hide()
    self.frame = f

    -- The middle: the controller and its buttons
    local art = K.NewFrame("Frame", nil, f)
    art:SetSize(ART_W, ART_H)
    art:SetScale(SCALE)
    art.tex = art:CreateTexture(nil, "BACKGROUND")
    art.tex:SetTexture(TEX .. "ic_controller")
    art.tex:SetAllPoints()
    f.art = art
    f.spots = {}
    for _, s in ipairs(SPOTS) do f.spots[s.key] = NewSpot(art, s) end

    -- Under it: the button picked, what each way of pressing it does, a note
    f.title = K.Text(f, 16, KC.title)
    f.title:SetPoint("TOP", art, "BOTTOM", 0, -10)
    f.title:SetJustifyH("CENTER")
    f.lines = {}
    for i = 1, LINES do
        local l = K.ChatText(f, 13, KC.cream)
        l:SetPoint("TOP", f.title, "BOTTOM", 0, -10 - (i - 1) * 20)
        l:SetWidth(470)
        l:SetJustifyH("CENTER")
        l:SetWordWrap(false)
        f.lines[i] = l
    end
    f.note = K.Text(f, 12, KC.help)
    f.note:SetWidth(440)
    f.note:SetJustifyH("CENTER")
    f.note:SetWordWrap(true)

    -- Right: what the press can do
    self.picker = K.Picker(f, PANEL_W, menu.Render, {
        bare = true, rowHeight = 38, tabs = true,
    })
    self.picker:Center(f, STAGE.picker, STAGE.mid)
    self.picker:SetHeight(400)
end

function P:Show()
    self.pickerFor = nil
    self.frame:Show()
end

function P:Hide()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Binding
---------------------------------------------------------------------------
-- After a change: the list back on what the press does now
local function Done(text, warn)
    menu.Toast(text, warn)
    P.picker:LoadList()
    menu.Render()
end

function P:Choose(e)
    if IC.InCombat() then return menu.Toast("Not in combat", true) end
    local spec = self:Spec()
    local text = B.Text(spec)
    if e.action == "none" then
        local bound = B.Bound(spec)
        if #bound == 0 then return menu.Toast(text .. ": nothing of ours on it") end
        local armId = "clear:" .. spec
        if not menu.IsArmed(armId) then
            menu.Arm(armId)
            return menu.Toast(IC.PadText("Unbind " .. B.Names(bound) .. " from " .. text .. "? {A} again"), true, 4)
        end
        menu.Disarm()
        B.Clear(spec)
        return Done(text .. ": " .. NoneName(spec):lower())
    end
    local def = B.Get(e.action)
    if not def then return end
    if B.Has(def, spec) then return menu.Toast(def.label .. " is on " .. text .. " already") end
    -- Taking it from something else asks first: Cross again
    local gone = B.Conflicts(def.id, spec)
    local armId = "bind:" .. def.id .. "@" .. spec
    if #gone > 0 and not menu.IsArmed(armId) then
        menu.Arm(armId)
        return menu.Toast(IC.PadText(text .. " runs " .. B.Names(gone) .. ": {A} again replaces it"), true, 4)
    end
    menu.Disarm()
    local from = def.specs()[1]
    B.Assign(def.id, spec)
    Done(def.label .. ": " .. text .. (from and (" (was " .. B.Text(from) .. ")") or "")
        .. (#gone > 0 and (", " .. B.Names(gone) .. " unbound") or ""), #gone > 0)
end

-- A spell, item, macro, emote or window onto the press (a crossbar
-- press: in its slot, Native.lua; else Override.lua); taking it from
-- something else asks first: Cross again
function P:ChooseAction(spec, e)
    if IC.InCombat() then return menu.Toast("Not in combat", true) end
    local O = IC.Override
    local text = B.Text(spec)
    if B.ActionOn(spec) == e.action then return menu.Toast((e.name or "") .. " is on " .. text .. " already") end
    local id = "action:" .. spec
    local gone = B.Conflicts(id, spec)
    local armId = "act:" .. spec .. "@" .. e.action
    if #gone > 0 and not menu.IsArmed(armId) then
        menu.Arm(armId)
        return menu.Toast(IC.PadText(text .. " runs " .. B.Names(gone) .. ": {A} again replaces it"), true, 4)
    end
    menu.Disarm()
    B.Take(id, spec)
    if B.SetAction(spec, e.action, e.name, type(e.icon) == "number" and e.icon or nil) == false then
        return Done(text .. ": couldn't put " .. (e.name or "it") .. " there", true)
    end
    local held, pressed = B.Parse(spec)
    Done(text .. ": " .. (e.name or "") .. (#gone > 0 and (", " .. B.Names(gone) .. " unbound") or "")
        .. (O.OutOfCombatOnly(spec) and " (out of combat only: " .. B.Text(B.Spec(held, pressed)) .. " stays the game's)" or ""),
        #gone > 0 or O.OutOfCombatOnly(spec))
end

-- Square: find a press by making it (Recorder.lua). The touchpad: the
-- corner under the finger.
function P:Find()
    if IC.InCombat() then return end
    IC.Recorder.Start({
        title = "Find a press", chord = true, double = true,
        hint = "Press the button, hold one and press another, or press one twice.",
        onDone = function(spec, info)
            local _, pressed = B.Parse(spec)
            if pressed == "PADBACK" and HasTouchpad() then
                local region = info and info.touch and touch.RegionAt(info.touch[1], info.touch[2])
                if not (region and SPOT["TOUCH:" .. region]) then
                    return menu.Toast("Click the touchpad in the corner you want", true)
                end
                P.key, P.spec = "TOUCH:" .. region, nil
                return
            end
            if not (SPOT[pressed] and Visible(SPOT[pressed])) then
                return menu.Toast(B.Text(spec) .. " isn't on the drawing", true)
            end
            P.key, P.spec = pressed, spec
        end,
    })
end

function P:BindCorner(region, e)
    -- (the touchpad click turned off: binding a corner turns it on)
    touch.GetSettings().enabled = true
    touch.SetAction(region, e.action)
    Done(touch.REGION_LABELS[region] .. ": " .. (e.name or ""))
end

-- Triangle on a corner: a press clears it, held (0.6 s) turns it off / on
local HOLD = 0.6

function P:CornerTriangle(region)
    if self.holding then return end
    local started = GetTime()
    self.holding = region
    self.holdTicker = C_Timer.NewTicker(0.05, function(ticker)
        local held = IsKeyDown and IsKeyDown("PAD4")
        if held and GetTime() - started >= HOLD then
            ticker:Cancel()
            P.holding = nil
            local off = touch.ToggleOff(region)
            Done(touch.REGION_LABELS[region] .. (off and " turned off" or " turned on")
                .. (off and touch.CORNERS[region] and " (its sides take its area)" or ""))
        elseif not held then
            ticker:Cancel()
            P.holding = nil
            if touch.IsBound(touch.GetSettings().regions[region]) then
                touch.SetAction(region, "none")
                Done(touch.REGION_LABELS[region] .. " cleared")
            end
        end
    end)
end

---------------------------------------------------------------------------
-- The pad: the picker; Square finds another press
---------------------------------------------------------------------------
function P:Press(name)
    if name == "X" then
        self:Find()
        return true
    end
    if name == "LB" or name == "RB" then return false end
    -- Circle: a press picked lets it go (back to finding one); else the
    -- panel closes
    if name == "B" then
        if not self.key then return false end
        self.key, self.spec, self.pickerFor = nil, nil, nil
        menu.Disarm()
        menu.Render()
        return true
    end
    if not self.key then return true end
    if name == "Y" then
        if Region() then
            self:CornerTriangle(Region())
        else
            self:Choose({ action = "none" })
        end
        return true
    end
    self.picker:Press(name)
    menu.Render()
    return true
end

function P:Help()
    local H = K.H
    local hints = { H({ "X" }, "Find press", "X") }
    if not self.key then
        hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
        hints[#hints + 1] = H({ "B" }, "Close", "B")
        return hints
    end
    hints[#hints + 1] = H({ "DPAD" }, "Move")
    hints[#hints + 1] = H({ "A" }, "Bind", "A")
    if self.picker.def and #self.picker.def.lists > 1 then hints[#hints + 1] = H({ "LT", "RT" }, "List", "RT") end
    if Region() then
        hints[#hints + 1] = H({ "Y" }, "Clear (hold: off)", "Y")
    else
        hints[#hints + 1] = H({ "Y" }, "Unbind", "Y")
    end
    hints[#hints + 1] = H({ "LB", "RB" }, "Tab", "RB")
    hints[#hints + 1] = H({ "B" }, "Back", "B")
    return hints
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Tint(t, c, a)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
end

-- The touchpad's corners: what each runs, the one picked lit
local function RenderCorners(f)
    local settings = touch.GetSettings()
    local on = settings.enabled ~= false
    for _, s in ipairs(SPOTS) do
        local b, region = f.spots[s.key], s.region
        if region then
            local action = settings.regions[region]
            local bound, off = touch.IsBound(action), touch.IsOff(region)
            if bound then K.SetIcon(b.icon, touch.ActionIcon(action) or 134400) end
            b.icon:SetShown(bound)
            b.icon:SetDesaturated(off or not on)
            b.plus:SetShown(not bound and not off)
            local picked = s.key == P.key
            b.glow:SetShown(picked)
            Tint(b.glow, KC.focus, 0.9)
            b.ring:SetShown(picked)
            Tint(b.ring, KC.focus)
            b.dot:SetShown(off)
            Tint(b.dot, KC.danger)
            b:SetAlpha((off or not on) and 0.45 or 1)
        end
    end
end

function P:Render()
    local f = self.frame
    if not f then return end
    -- Another controller in hand: the touchpad's corners / its View button
    if self.key and not Visible(SPOT[self.key]) then
        if Region() then
            self.key, self.spec = "PADBACK", "PADBACK"
        else
            self.key, self.spec = "TOUCH:upleft", nil
        end
    end
    self:SyncPicker()
    if Region() then self.variant[self.key] = self.picker.list end
    -- (a scaled frame's offsets are in its own units)
    local at = ART_AT
    f.art:ClearAllPoints()
    f.art:SetPoint("CENTER", f, "CENTER", at[1] / SCALE, at[2] / SCALE)
    local spec = self:Spec()
    local bySpec = Snapshot()
    local held = B.Parse(spec)
    local region = Region()

    -- Where the picker's focused choice is bound now (its other press)
    local preview = {}
    local e = self.key and self.picker.entries and self.picker.entries[self.picker.index or 0]
    if e and e.def and not e.here then
        for _, s in ipairs(e.def.specs()) do
            local h, p = B.Parse(s)
            preview[p] = true
            if h then preview[h] = true end
        end
    end

    -- The buttons: the one picked lit, marks for what is on each
    for _, s in ipairs(SPOTS) do
        local key, b = s.key, f.spots[s.key]
        b:SetShown(Visible(s))
        if not s.region and b:IsShown() then
            b.glyph:Set(IC.PAD_KEY[key] or key)
            local any, clash = false, false
            local list = { key, key .. ":double" }
            for _, h in ipairs(B.HOLDS) do list[#list + 1] = h .. "+" .. key end
            for _, sp in ipairs(list) do
                local defs = bySpec[sp]
                if defs then
                    any = true
                    clash = clash or Clashes(defs, sp)
                end
            end
            local picked = key == self.key
            b.glow:SetShown(picked)
            Tint(b.glow, KC.focus, 0.9)
            local ring = picked or (not region and key == held) or preview[key]
            b.ring:SetShown(ring and true or false)
            if picked then
                Tint(b.ring, KC.focus)
            elseif key == held then
                Tint(b.ring, KC.dimGold, 0.8)
            else
                Tint(b.ring, KC.info)
            end
            b.dot:SetShown(any)
            Tint(b.dot, clash and KC.danger or KC.slot)
            b.glyph:SetAlpha((picked or any or preview[key]) and 1 or 0.7)
        end
    end
    if HasTouchpad() then RenderCorners(f) end

    if not self.key then
        -- Nothing picked yet: how to pick
        f.title:SetText("No press picked")
        for i = 1, LINES do f.lines[i]:Hide() end
        f.note:SetText(IC.PadText("{X} finds a press: press the button, hold one and press another, or press one"
            .. " twice. What it can do then shows on the right. A gold dot: something is on that button; red: two"
            .. " things clash."))
    elseif region then
        -- Under it: the four corners, the one picked lit
        local settings = touch.GetSettings()
        f.title:SetText(IC.GlyphText("TOUCHPAD", 20) .. " Touchpad · " .. touch.REGION_LABELS[region])
        for i, r in ipairs(touch.REGIONS) do
            local l = f.lines[i]
            local action = settings.regions[r]
            local what = touch.IsOff(r) and "|cffff7a5cOff|r"
                or (touch.IsBound(action) and touch.ActionLabel(action) or "|cff9d917aEmpty|r")
            l:SetText(touch.REGION_LABELS[r] .. "   " .. what)
            l:SetTextColor(unpack(r == region and KC.focusText or KC.cream2))
            l:SetAlpha(r == region and 1 or 0.8)
            l:Show()
        end
        for i = #touch.REGIONS + 1, LINES do f.lines[i]:Hide() end
        local note
        if settings.enabled == false then
            note = "|cffff7a5cThe touchpad click is off: binding a corner turns it on.|r"
        else
            note = IC.PadText("Clicking the touchpad in this corner runs it, in combat too. {A} picks what;"
                .. " {Y} clears it, held turns it off (its sides take its area).")
        end
        f.note:SetText(note)
    else
        -- Under it: each way of pressing the button picked
        f.title:SetText(IC.GlyphText(self.key, 20) .. " " .. IC.ButtonName(self.key))
        local n = 0
        local variants = B.Variants(self.key)
        local listed = false
        for _, s in ipairs(variants) do listed = listed or s == spec end
        -- (a press the list doesn't have: one held that isn't a shoulder or trigger)
        if not listed then table.insert(variants, 2, spec) end
        for i, s in ipairs(variants) do
            local list = { spec = s }
            local defs = bySpec[s]
            local current = s == spec
            -- (each one bound, and the one picked)
            if defs or current or i == 1 then
                n = n + 1
                local l = f.lines[n]
                if not l then break end
                local what
                if defs then
                    local names = {}
                    for _, def in ipairs(defs) do names[#names + 1] = DefText(def) end
                    what = table.concat(names, ", ")
                    if Clashes(defs, list.spec) then what = "|cffff7a5c" .. what .. " (clash)|r" end
                    -- A double-click alone: watched, so out of combat only (Override.lua)
                    if IC.Override.OutOfCombatOnly(list.spec) then
                        what = what .. " |cfff0a090(out of combat only)|r"
                    end
                else
                    what = "|cff9d917a" .. NoneName(list.spec) .. "|r"
                end
                l:SetText(B.Text(list.spec, 16) .. "   " .. what)
                l:SetTextColor(unpack(current and KC.focusText or KC.cream2))
                l:SetAlpha(current and 1 or 0.8)
                l:Show()
            end
        end
        for i = n + 1, LINES do f.lines[i]:Hide() end

        -- The note: the focused choice explained, else what to do here
        local note
        if e and e.def then
            note = e.def.tip
            local gone = not e.here and B.Conflicts(e.def.id, spec) or {}
            if #gone > 0 then
                note = "|cffff7a5cReplaces " .. B.Names(gone) .. " on " .. B.Text(spec) .. ".|r " .. (note or "")
            end
        elseif e and e.action and e.action ~= "none" then
            -- A spell, item... for the press
            note = "Runs it on " .. B.Text(spec) .. ", in combat too."
            local gone = B.ActionOn(spec) ~= e.action and B.Conflicts("action:" .. spec, spec) or {}
            if #gone > 0 then note = "|cffff7a5cReplaces " .. B.Names(gone) .. ".|r " .. note end
        else
            note = IC.PadText("Takes off whatever of ours is on " .. B.Text(spec) .. ". {X} finds another press:"
                .. " a gold dot, something is on that button; red, two things clash.")
        end
        local held, pressed, double = B.Parse(spec)
        if double and not IC.Override.Get(B.Spec(held, pressed)) then
            -- (watched: the first press stays the game's, Override.lua)
            note = note .. " |cfff0a090A double-click on its own works out of combat only: " .. B.Text(B.Spec(held, pressed))
                .. " pressed once still does the game's own, and WoW won't change bindings in combat.|r"
        end
        if IC.Native.SlotOf(spec) then
            -- (the game's crossbar: the same slot as its own editor's)
            note = note .. " |cff9fd8e2This is the game's crossbar slot (the page shown): it changes there"
                .. " too, and changes made there show here.|r"
        elseif not B.ActionFits(spec) then
            note = note .. " |cff9d917aSpells and items can't go on this press (" .. IC.ButtonName("RS")
                .. ": the wheels'; a held button: only the game's crossbar modifiers with the D-pad or face"
                .. " buttons, or one the game makes Shift / Ctrl / Alt).|r"
        end
        f.note:SetText(note or "")
    end

    -- The note just under the last line shown
    local last = f.title
    for i = 1, LINES do
        if f.lines[i]:IsShown() then last = f.lines[i] end
    end
    f.note:ClearAllPoints()
    f.note:SetPoint("TOP", last, "BOTTOM", 0, -12)

    if self.key then
        self.picker:Show()
        self.picker:Render()
        self.picker:Center(self.frame, STAGE.picker, STAGE.mid)
    end
end

---------------------------------------------------------------------------
-- The General tab, the first
---------------------------------------------------------------------------
menu.AddTab({ key = "general", label = "General", sections = {}, page = function() return P end }, "wheels")

-- The panel kept the touchpad click while it was open; give it back
hooksecurefunc(menu, "Close", function()
    -- Next time: nothing picked
    P.key, P.spec = nil, nil
    if not IC.InCombat() then touch.Apply() end
end)
