-- Recording a press to bind (Square, on every tab that binds): a box asks
-- for it, and the first button let go ends it: the press is what was
-- pressed last (a button pressed while another is held: the two, "L1 +
-- R3"; asked for, pressed again quickly: twice). Circle alone (or Escape,
-- or 10 s without a press) cancels. The pad
-- is the box's alone while it is up, and until every button is let go
-- after, so no release leaks to the panel or the game.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local menu = IC.Menu

local R = {}
IC.Recorder = R

local WAIT = 10      -- seconds for a first press
local DOUBLE = 0.35  -- seconds for the second press of a double one

-- state: nil (idle), "wait" (no press yet), "press" (buttons down),
-- "release" (done, waiting for the buttons to be let go), "again" (let go:
-- a second press now makes it twice); spec: the last press; down: the
-- buttons held, in the order pressed; info: the finger on the touchpad
-- when it was clicked ({ touch = { x, y } })
local box, opts, state, spec, down, deadline, info, again

local function Build()
    if box then return end
    local d = K.NewFrame("Frame", "ImprovedControllerRecorder", UIParent, "BackdropTemplate")
    d:SetSize(460, 220)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetFrameLevel(500)
    d:EnableMouse(true)
    d:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    d.title = K.Text(d, 17, KC.title)
    d.title:SetPoint("TOP", 0, -26)
    d.title:SetJustifyH("CENTER")
    d.hint = K.ChatText(d, 13, KC.cream2)
    d.hint:SetPoint("TOP", d.title, "BOTTOM", 0, -10)
    d.hint:SetWidth(400)
    d.hint:SetJustifyH("CENTER")
    d.hint:SetSpacing(4)
    d.glyphs = K.GlyphRow(d, 40)
    d.glyphs:SetPoint("CENTER", d, "CENTER", 0, -22)
    d.press = K.Text(d, 15, KC.cream)
    d.press:SetPoint("TOP", d.glyphs, "BOTTOM", 0, -6)
    d.press:SetJustifyH("CENTER")
    d.status = K.ChatText(d, 12, KC.grey)
    d.status:SetPoint("BOTTOM", 0, 22)
    d.status:SetJustifyH("CENTER")
    d:Hide()
    d:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then R.Finish(true) end
    end)
    if d.EnableGamePadButton then
        d:SetScript("OnGamePadButtonDown", function(_, button) R.OnDown(button) end)
        d:SetScript("OnGamePadButtonUp", function(_, button) R.OnUp(button) end)
    end
    d:SetScript("OnUpdate", function() R.OnUpdate() end)
    box = d
end

local function Remove(button)
    for i = #down, 1, -1 do
        if down[i] == button then table.remove(down, i) end
    end
end

-- Let go of what the game no longer has down (a release we missed)
local function Prune()
    if not IsKeyDown then return end
    for i = #down, 1, -1 do
        if not IsKeyDown(down[i]) then table.remove(down, i) end
    end
end

function R.Render()
    local d = box
    local keys = spec and IC.Binds.Glyphs(spec)
    d.glyphs:Set(keys or {})
    d.glyphs:SetShown(keys ~= nil)
    d.press:SetText(spec and IC.Binds.Text(spec) or "")
    if state == "wait" then
        d.status:SetText(IC.PadText("Waiting for a press... {B} alone cancels."))
    elseif state == "press" or state == "again" then
        d.status:SetText(state == "again" and "" or "Let go to bind it.")
    else
        d.status:SetText("Let go of the buttons.")
    end
end

-- opts = { title, hint (what may be pressed), chord (false: one button
-- only), double (a quick second press makes it ":double"), accept =
-- function(spec) (false: not allowed), reject (its message), onDone =
-- function(spec, info), onCancel = function() }
function R.Start(o)
    if IC.InCombat() then return false end
    Build()
    R.Stop()
    opts, state, spec, down, info, again = o, "wait", nil, {}, {}, false
    deadline = GetTime() + WAIT
    box.title:SetText(o.title or "Bind")
    box.hint:SetText(IC.PadText((o.hint or ("Press the button for it"
        .. (o.chord ~= false and ", or hold one and press another" or "") .. "."))
        .. "\nLetting go of a button binds it."))
    box:Show()
    box:EnableKeyboard(true)
    box:SetPropagateKeyboardInput(false)
    if box.EnableGamePadButton then box:EnableGamePadButton(true) end
    R.Render()
    if menu.IsOpen() then menu.Render() end
    return true
end

function R.IsActive()
    return state ~= nil
end

-- Gone without a word (the panel closed)
function R.Stop()
    if not box then return end
    state, opts = nil, nil
    box:Hide()
    if not IC.InCombat() then
        box:EnableKeyboard(false)
        if box.EnableGamePadButton then box:EnableGamePadButton(false) end
    end
end

function R.OnDown(button)
    if state == "release" then
        down[#down + 1] = button
        return
    end
    -- The second press of a double one (any other: ignored)
    if state == "again" then
        down[#down + 1] = button
        if button == spec then spec = spec .. ":double" end
        state = "release"
        return R.Render()
    end
    if button == "PADBACK" and IC.Touch.FingerPosition then
        local x, y = IC.Touch.FingerPosition()
        info.touch = x and { x, y } or nil
    end
    Remove(button)
    Prune()
    -- Under the last button still held, if a second one may be
    local held = opts.chord ~= false and down[#down] or nil
    down[#down + 1] = button
    spec = held and (held .. "+" .. button) or button
    state = "press"
    R.Render()
end

function R.OnUp(button)
    -- (not one pressed while recording: Square's own release)
    local ours = false
    for _, b in ipairs(down) do
        if b == button then ours = true end
    end
    if not ours then return end
    Remove(button)
    -- The first one let go: the press is kept as it is now
    if state == "press" then
        state = "release"
        R.Render()
    end
    if state == "release" and #down == 0 then R.Released() end
end

-- Every button let go: done, or (a single press, twice asked for) a
-- moment for its second press
function R.Released()
    local held, _, double = IC.Binds.Parse(spec)
    if opts.double and not held and not double and not again then
        again = true
        state, deadline = "again", GetTime() + DOUBLE
        return R.Render()
    end
    R.Finish()
end

function R.OnUpdate()
    if (state == "wait" or state == "again") and GetTime() >= deadline then
        return R.Finish(state == "wait")
    end
    if state == "release" then
        Prune()
        if #down == 0 then R.Released() end
    end
end

-- Over: the last press bound (or cancelled), once the buttons are let go
function R.Finish(cancel)
    local o, s, i = opts, spec, info
    R.Stop()
    if not o then return end
    -- (on the next frame: the release that ended it is still being handled)
    C_Timer.After(0, function()
        if cancel or not s or s == "PAD2" then
            if o.onCancel then o.onCancel() end
        elseif o.accept and not o.accept(s) then
            menu.Toast(o.reject or (IC.Binds.Text(s) .. " can't be used for this"), true, 3)
            if o.onCancel then o.onCancel() end
        else
            o.onDone(s, i)
        end
        if menu.IsOpen() then menu.Render() end
    end)
end

-- The help bar while recording
function R.Hints()
    return { K.H({ "B" }, "Alone: cancel", "B") }
end

hooksecurefunc(menu, "Close", R.Stop)
