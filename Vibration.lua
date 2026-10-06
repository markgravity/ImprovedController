-- Controller vibration on game events, adapted from Easy Controller -
-- Forever's Vibration module (moust4ki, MIT License, see
-- LICENSE-EasyController.md): its patterns, played on the two
-- standard motors at one strength for all. Three events: you level up, you
-- land a critical hit (damage or heal), you take one. Each has a pattern of
-- its own, or none, grouped as Easy Controller does (Combat, Progress). Set
-- in the Vibration tab (VibeEditor.lua); on / off
-- and strength in the General tab.
local _, IC = ...

local V = {}
IC.Vibe = V

-- The events' icons, drawn in the radial menu's style (tools/make_vibe_icons.py)
local EVENT_ICONS = "Interface\\AddOns\\ImprovedController\\textures\\ic_event_"

-- Patterns: steps of { low motor, high motor, seconds }; 0, 0 is a pause.
-- Low is the left grip, high the right. Every step lasts 0.1 s or more: a
-- DualSense (on a Mac at least) gives nothing for Easy Controller's shorter
-- taps.
V.PATTERNS = {
    { key = "micro", label = "Micro tick", steps = { { 0.35, 0.35, 0.1 } } },
    { key = "tick", label = "Tick", steps = { { 0.6, 0.6, 0.12 } } },
    { key = "double", label = "Double tick",
        steps = { { 0.7, 0.7, 0.12 }, { 0, 0, 0.12 }, { 0.7, 0.7, 0.12 } } },
    { key = "pulse", label = "Pulse", steps = { { 0.8, 0.8, 0.18 } } },
    { key = "long", label = "Long", steps = { { 0.8, 0.8, 0.6 } } },
    { key = "heart", label = "Heartbeat",
        steps = { { 0.9, 0.9, 0.1 }, { 0, 0, 0.12 }, { 0.6, 0.6, 0.1 } } },
    { key = "rise", label = "Crescendo",
        steps = { { 0.3, 0.3, 0.12 }, { 0.6, 0.6, 0.12 }, { 1, 1, 0.18 } } },
    -- Ours: a hard knock, its opposite, three taps, a soft purr (a cast's:
    -- it loops while the cast lasts) and a rumble that fades out
    { key = "impact", label = "Impact", steps = { { 1, 1, 0.16 } } },
    { key = "triple", label = "Triple tick",
        steps = { { 0.7, 0.7, 0.11 }, { 0, 0, 0.1 }, { 0.7, 0.7, 0.11 }, { 0, 0, 0.1 }, { 0.7, 0.7, 0.11 } } },
    { key = "purr", label = "Purr",
        steps = { { 0.22, 0.22, 0.1 }, { 0, 0, 0.18 }, { 0.22, 0.22, 0.1 }, { 0, 0, 0.18 } } },
    -- Sweep: left (low motor) to right (high motor) and back; a cast's
    { key = "sweep", label = "Sweep",
        steps = { { 0.7, 0, 0.15 }, { 0.4, 0.4, 0.15 }, { 0, 0.7, 0.15 }, { 0.4, 0.4, 0.15 } } },
    { key = "fade", label = "Fade out",
        steps = { { 1, 1, 0.15 }, { 0.6, 0.6, 0.15 }, { 0.3, 0.3, 0.2 } } },
}
-- Each pattern's icon, drawn in the radial menu's style (tools/make_vibe_icons.py)
local VIBE_ICONS = "Interface\\AddOns\\ImprovedController\\textures\\ic_vibe_"
V.OFF_ICON = VIBE_ICONS .. "off"
local PATTERN = {}
for _, p in ipairs(V.PATTERNS) do
    p.icon = VIBE_ICONS .. p.key
    PATTERN[p.key] = p
end

-- The events, by group (Easy Controller's groups and naming), each with its
-- default state and pattern
V.GROUPS = {
    { key = "combat", label = "Combat" },
    { key = "wheel", label = "Wheel" },
    { key = "progress", label = "Progress" },
}
V.EVENTS = {
    { key = "crit", group = "combat", label = "Critical hit", icon = EVENT_ICONS .. "crit", on = true, combo = true,
        pattern = "tick", tip = "Your damage or healing lands a critical hit (in WoW Forever: your target"
            .. " takes one, or a critical heal lands on you or it)." },
    { key = "critted", group = "combat", label = "Critical hit taken", icon = EVENT_ICONS .. "critted", on = true,
        combo = true,
        pattern = "double", tip = "An enemy lands a critical hit on you." },
    { key = "lowHp", group = "combat", label = "Low health", icon = EVENT_ICONS .. "lowhp", on = true,
        pattern = "heart", loop = true, tip = "While your health is at 35% or less (the game's red"
            .. " low-health warning), its pattern plays over and over." },
    { key = "cast", group = "combat", parent = "spellcast", label = "Casting", icon = EVENT_ICONS .. "cast", on = false,
        pattern = "sweep", loop = true, tip = "While you cast or channel a spell, its pattern plays over"
            .. " and over until the spell ends (instant spells: nothing)." },
    { key = "interrupted", group = "combat", parent = "spellcast", label = "Interrupted", icon = EVENT_ICONS .. "interrupted",
        on = true, pattern = "impact", tip = "Someone interrupts your cast or channel (a kick, a stun, a"
            .. " silence...)." },
    { key = "cancelled", group = "combat", parent = "spellcast", label = "Cancelled", icon = EVENT_ICONS .. "cancelled",
        on = false, pattern = "micro", tip = "You stop your own cast or channel early: you move, jump or"
            .. " cancel it." },
    { key = "pushback", group = "combat", parent = "spellcast", label = "Pushed back", icon = EVENT_ICONS .. "pushback",
        on = true, pattern = "micro", tip = "A hit while you cast or channel costs you cast time: the"
            .. " cast slows, or the channel shortens." },
    { key = "wheelTick", group = "wheel", label = "Slot change", icon = EVENT_ICONS .. "wheel", on = true,
        pattern = "micro", gap = 0.03, tip = "In an open wheel, the pick moves to another slot (stick,"
            .. " D-pad or a new page)." },
    { key = "levelUp", group = "progress", label = "Level up", icon = EVENT_ICONS .. "levelup", on = true,
        pattern = "rise", tip = "You reach a new level." },
}
local EVENT = {}
for _, e in ipairs(V.EVENTS) do EVENT[e.key] = e end

-- What the Vibration tab lists: each event, but a spell cast's four as one
-- ("Spell cast"), each of them a list of its own in the picker
V.RAIL = {}
do
    local parents = {}
    for _, e in ipairs(V.EVENTS) do
        if e.parent then
            local item = parents[e.parent]
            if not item then
                item = { key = e.parent, group = e.group, label = "Spell cast", icon = e.icon, subs = {} }
                parents[e.parent] = item
                V.RAIL[#V.RAIL + 1] = item
            end
            item.subs[#item.subs + 1] = e
        else
            V.RAIL[#V.RAIL + 1] = { key = e.key, group = e.group, label = e.label, icon = e.icon, subs = { e } }
        end
    end
end

-- db.vibration = { enabled, intensity, events = { key = { on, pattern } } }
function V.Settings()
    IC.db.vibration = IC.db.vibration or {}
    local s = IC.db.vibration
    if s.enabled == nil then s.enabled = true end
    s.intensity = s.intensity or 0.8
    s.events = s.events or {}
    for _, e in ipairs(V.EVENTS) do
        local cfg = s.events[e.key]
        if type(cfg) ~= "table" then
            cfg = { on = e.on, pattern = e.pattern }
            s.events[e.key] = cfg
        end
        if not PATTERN[cfg.pattern] then cfg.pattern = e.pattern end
    end
    return s
end

function V.Pattern(key)
    return PATTERN[key]
end

-- An event's pattern, or nil when it is off
function V.EventPattern(eventKey)
    local cfg = V.Settings().events[eventKey]
    return cfg and cfg.on and cfg.pattern or nil
end

-- A pattern for an event ("off": none)
function V.SetEventPattern(eventKey, patternKey)
    local cfg = V.Settings().events[eventKey]
    if patternKey == "off" then
        cfg.on = false
    else
        cfg.on, cfg.pattern = true, patternKey
    end
end

---------------------------------------------------------------------------
-- Playing a pattern
---------------------------------------------------------------------------
local timers = {}

-- Low drives the left grip, High the right (a DualSense, /ic vibe). The
-- right one is felt only from about half strength: any non-zero value is
-- lifted into that range, so both sides feel alike.
local HIGH_FLOOR = 0.5

local function motors(low, high)
    if high > 0 then high = HIGH_FLOOR + (1 - HIGH_FLOOR) * high end
    C_GamePad.SetVibration("Low", low)
    C_GamePad.SetVibration("High", high)
end

-- /ic vibe sides: each vibration type alone, then both motors, so the
-- player can tell which side each one drives (and which do nothing)
local SIDE_TESTS = {
    { "Low", function(v) C_GamePad.SetVibration("Low", v) end },
    { "High", function(v) C_GamePad.SetVibration("High", v) end },
    { "LTrigger", function(v) C_GamePad.SetVibration("LTrigger", v) end },
    { "RTrigger", function(v) C_GamePad.SetVibration("RTrigger", v) end },
    { "Low + High", function(v) motors(v, v) end },
    { "High + Low", function(v)
        C_GamePad.SetVibration("High", v)
        C_GamePad.SetVibration("Low", v)
    end },
}

function V.TestSides()
    if not (C_GamePad and C_GamePad.SetVibration) then
        return IC.Print("vibration: not available on this client")
    end
    V.Stop()
    for i, test in ipairs(SIDE_TESTS) do
        local start = (i - 1) * 2
        C_Timer.After(start, function()
            IC.Print(format("vibe %d/%d: %s", i, #SIDE_TESTS, test[1]))
            -- Sent again every 0.1 s for a second, as patterns do
            for t = 0, 0.9, 0.1 do
                C_Timer.After(t, function()
                    local ok, err = pcall(test[2], 1)
                    if not ok and t == 0 then IC.Print("  refused: " .. tostring(err)) end
                end)
            end
            C_Timer.After(1, function() C_GamePad.StopVibration() end)
        end)
    end
    C_Timer.After(#SIDE_TESTS * 2, function() IC.Print("vibe: done. Which ones did you feel, and on which side?") end)
end

local function later(delay, fn)
    if delay <= 0 then
        fn()
    else
        timers[#timers + 1] = C_Timer.NewTimer(delay, fn)
    end
end

function V.Stop()
    for _, t in ipairs(timers) do t:Cancel() end
    wipe(timers)
    if C_GamePad and C_GamePad.StopVibration then C_GamePad.StopVibration() end
end

-- A pattern at the set strength; the newest replaces the one playing.
-- loop: played again and again (with a short gap) until V.Stop. shape
-- (optional) varies it: { strength, duration (times each step's length),
-- left, right (each side's share, 0 to 1) }
function V.Play(key, loop, shape)
    if not (C_GamePad and C_GamePad.SetVibration and IC.db) then return end
    local pattern = PATTERN[key] or PATTERN.tick
    shape = shape or {}
    local gain = math.max(0, math.min(1, V.Settings().intensity * (shape.strength or 1)))
    local left, right, stretch = shape.left or 1, shape.right or 1, shape.duration or 1
    V.Stop()
    local t = 0
    for _, step in ipairs(pattern.steps) do
        local low, high = step[1] * gain * left, step[2] * gain * right
        local length = math.max(0.1, step[3] * stretch)
        -- Sent again every 0.1 s: holds on a client that lets it fade
        local at = 0
        repeat
            later(t + at, function() motors(low, high) end)
            at = at + 0.1
        until at >= length
        t = t + length
    end
    if loop then
        later(t, function() C_GamePad.StopVibration() end)
        later(t + 0.12, function() V.Play(key, true) end)
    else
        later(t, function()
            C_GamePad.StopVibration()
            -- Over a looping event (a cast still going): back to its loop
            if V.looping then V.Play(V.looping.pattern, true) end
        end)
    end
end

-- Combo events (critical hits, given or taken): one soon after another
-- (within COMBO_WINDOW) plays with a random strength, length and side
-- (more left or more right), each well apart from the last one's, so a run
-- of crits feels like a flurry of blows rather than one buzz repeated. The
-- first of a run plays as set.
local COMBO_WINDOW = 2
local COMBO_STRENGTH, COMBO_LENGTH, COMBO_PAN = { 0.45, 1 }, { 0.7, 1.6 }, 0.8
local comboLast = {}

-- A random value in range, at least gap from previous
local function Apart(lo, hi, previous, gap)
    local v
    repeat
        v = lo + math.random() * (hi - lo)
    until not previous or math.abs(v - previous) >= gap
    return v
end

local function ComboShape(eventKey, chained)
    if not chained then
        comboLast[eventKey] = { strength = 1, duration = 1, pan = 0 }
        return nil
    end
    local previous = comboLast[eventKey] or {}
    local shape = {
        strength = Apart(COMBO_STRENGTH[1], COMBO_STRENGTH[2], previous.strength, 0.2),
        duration = Apart(COMBO_LENGTH[1], COMBO_LENGTH[2], previous.duration, 0.25),
        -- -1 all left .. 1 all right; the far side keeps a little
        pan = Apart(-COMBO_PAN, COMBO_PAN, previous.pan, 0.5),
    }
    shape.left = math.min(1, 1 - shape.pan)
    shape.right = math.min(1, 1 + shape.pan)
    comboLast[eventKey] = shape
    return shape
end

-- An event happened: its pattern, if it is on (the same event at most
-- every 0.4 s; a combo event every 0.15 s, others at their own gap). A looping event's plays until
-- V.EndLoop.
-- Loops still wanted under the one playing (low health under a cast):
-- the newest plays; when it ends, the one before it resumes
local loops = {}

local last = {}
function V.ResetLast(eventKey)
    last[eventKey] = nil
    comboLast[eventKey] = nil
end

function V.Fire(eventKey)
    if not IC.db then return end
    local s = V.Settings()
    local pattern = V.EventPattern(eventKey)
    if not (s.enabled and pattern) then return end
    if EVENT[eventKey].loop then
        V.EndLoop(eventKey)
        V.looping = { key = eventKey, pattern = pattern }
        loops[#loops + 1] = V.looping
        V.Play(pattern, true)
        return
    end
    local now = GetTime()
    local combo = EVENT[eventKey].combo
    local since = last[eventKey] and now - last[eventKey]
    if since and since < (EVENT[eventKey].gap or (combo and 0.15 or 0.4)) then return end
    last[eventKey] = now
    local shape = combo and ComboShape(eventKey, since ~= nil and since < COMBO_WINDOW) or nil
    V.Play(pattern, false, shape)
end

-- A looping event is over (the cast ended): its loop stops
function V.EndLoop(eventKey)
    for i = #loops, 1, -1 do
        if loops[i].key == eventKey then table.remove(loops, i) end
    end
    if V.looping and V.looping.key == eventKey then
        V.looping = loops[#loops]
        if V.looping then
            V.Play(V.looping.pattern, true)
        else
            V.Stop()
        end
    end
end

-- Try it on Spell cast: a cast played out with its four patterns, as a
-- real one would (casting, interrupted; casting, cancelled; casting, pushed
-- back, casting on to its end). onStep(label) as each part starts.
local sim = {}

function V.StopSimulation()
    if #sim == 0 then return end
    for _, t in ipairs(sim) do t:Cancel() end
    wipe(sim)
    V.EndLoop("cast")
    if V.loopDemo then
        V.EndLoop(V.loopDemo)
        V.loopDemo = nil
    end
end

-- Try it on a looping event (low health): its loop for a few seconds, as
-- it would run while the state lasts. Triangle again, or closing the
-- panel, stops it.
function V.SimulateLoop(eventKey, seconds)
    local wasDemo = V.loopDemo == eventKey
    V.StopSimulation()
    if wasDemo then return false end
    V.loopDemo = eventKey
    V.Fire(eventKey)
    sim[#sim + 1] = C_Timer.NewTimer(seconds or 6, function()
        wipe(sim)
        V.EndLoop(eventKey)
        V.loopDemo = nil
    end)
    return true
end

-- Try it on a combo event: a run of six hits at uneven intervals, each
-- shaped as a real run's would be. onStep(n) as hit n lands.
function V.SimulateCombo(eventKey, onStep)
    V.StopSimulation()
    V.ResetLast(eventKey)
    local t = 0
    for n = 1, 6 do
        local hit = n
        sim[#sim + 1] = C_Timer.NewTimer(t, function()
            onStep(hit)
            V.Fire(eventKey)
        end)
        t = t + 0.25 + math.random() * 0.4
    end
    sim[#sim + 1] = C_Timer.NewTimer(t, function() wipe(sim) end)
end

function V.SimulateCast(onStep)
    V.StopSimulation()
    local function at(t, fn)
        sim[#sim + 1] = C_Timer.NewTimer(t, fn)
    end
    local function play(key, loop)
        local pattern = V.EventPattern(key)
        if not pattern then return end
        if loop then V.looping = { key = key, pattern = pattern } end
        V.Play(pattern, loop)
    end
    local function casting()
        onStep(EVENT.cast.label)
        play("cast", true)
    end
    local function ended(key)
        V.EndLoop("cast")
        onStep(EVENT[key].label)
        play(key)
    end
    -- Each cast 2 s, then how it ends; a second's pause before the next
    casting()
    at(2, function() ended("interrupted") end)
    at(3, casting)
    at(5, function() ended("cancelled") end)
    at(6, casting)
    -- Pushed back after 2 s: its pattern, then the cast's loop 2 s more
    at(8, function()
        onStep(EVENT.pushback.label)
        play("pushback")
    end)
    at(10, function()
        V.EndLoop("cast")
        wipe(sim)
        onStep(nil)
    end)
end

---------------------------------------------------------------------------
-- The events
---------------------------------------------------------------------------
-- Combat values WoW Forever may hide from addons
local function secret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Where each kind of combat log entry keeps its "critical" flag
local CRIT_ARG = {
    SWING_DAMAGE = 18, RANGE_DAMAGE = 21, SPELL_DAMAGE = 21, SPELL_PERIODIC_DAMAGE = 21,
    SPELL_HEAL = 18, SPELL_PERIODIC_HEAL = 18,
}
local HEALS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

-- WoW Forever takes the combat log away from addons (no
-- CombatLogGetCurrentEventInfo), so there the crits come from UNIT_COMBAT,
-- which says what a unit took but not from whom: a critical wound on you is
-- "you get crit"; one on your target, or a critical heal on you or it, is
-- "you crit" (in a group, someone else's crit on your target counts too).
-- Where the combat log is still readable, it says exactly who crit whom.
local function CombatLog()
    local info = { CombatLogGetCurrentEventInfo() }
    local sub = info[2]
    local index = CRIT_ARG[sub]
    if not index then return end
    local critical = info[index]
    if secret(critical) or not critical then return end
    local player = UnitGUID("player")
    if secret(info[4]) or secret(info[8]) then return end
    if info[4] == player then
        V.Fire("crit")
    elseif info[8] == player and not HEALS[sub] then
        V.Fire("critted")
    end
end

local function UnitCombat(unit, action, flag)
    if secret(action) or secret(flag) or flag ~= "CRITICAL" then return end
    if unit == "player" then
        if action == "WOUND" then
            V.Fire("critted")
        elseif action == "HEAL" then
            V.Fire("crit")
        end
    elseif unit == "target" and (action == "WOUND" or action == "HEAL") then
        V.Fire("crit")
    end
end

local hasCombatLog = type(CombatLogGetCurrentEventInfo) == "function"
-- Casts and channels: the loop while one lasts, then how it ended. A cast
-- interrupted by someone names who (interruptedBy, hidden: someone still);
-- without one, a cast stopped before its end was the player's doing (a
-- channel's natural end has none either: its end time tells them apart).
-- Each cast's end counts once (a channel stopping says so twice, in
-- either order: a stop with no interrupter waits a moment for one).
local cast = {}

local function interrupter(by)
    return secret(by) or (by ~= nil and by ~= "")
end

local function CastStarted(event)
    cast.ended = false
    cast.channelEnd = nil
    if event == "UNIT_SPELLCAST_CHANNEL_START" and UnitChannelInfo then
        local endMs = select(5, UnitChannelInfo("player"))
        if endMs and not secret(endMs) then cast.channelEnd = endMs / 1000 end
    end
    V.Fire("cast")
end

local function CastEnded(how)
    V.EndLoop("cast")
    if cast.ended then return end
    cast.ended = true
    V.Fire(how)
end

local CAST_HANDLERS = {
    UNIT_SPELLCAST_START = CastStarted,
    UNIT_SPELLCAST_CHANNEL_START = CastStarted,
    UNIT_SPELLCAST_INTERRUPTED = function(_, _, _, _, by)
        CastEnded(interrupter(by) and "interrupted" or "cancelled")
    end,
    UNIT_SPELLCAST_CHANNEL_STOP = function(_, _, _, _, by)
        if interrupter(by) then return CastEnded("interrupted") end
        V.EndLoop("cast")
        if cast.channelEnd and GetTime() < cast.channelEnd - 0.25 then
            C_Timer.After(0.1, function()
                if not cast.ended then CastEnded("cancelled") end
            end)
        end
    end,
    -- A cast's end; how it ended comes with UNIT_SPELLCAST_INTERRUPTED
    UNIT_SPELLCAST_STOP = function() V.EndLoop("cast") end,
    UNIT_SPELLCAST_FAILED = function() V.EndLoop("cast") end,
    UNIT_SPELLCAST_DELAYED = function()
        if not cast.ended then V.Fire("pushback") end
    end,
    UNIT_SPELLCAST_CHANNEL_UPDATE = function()
        if cast.ended then return end
        local endMs = UnitChannelInfo and select(5, UnitChannelInfo("player"))
        if endMs and not secret(endMs) then
            local newEnd = endMs / 1000
            -- Shortened by a hit (not lengthened)
            if cast.channelEnd and newEnd < cast.channelEnd - 0.05 then V.Fire("pushback") end
            cast.channelEnd = newEnd
        end
    end,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
for event in pairs(CAST_HANDLERS) do events:RegisterUnitEvent(event, "player") end
if hasCombatLog then
    events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
else
    events:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
end
events:SetScript("OnEvent", function(_, event, ...)
    if not IC.db then return end
    if event == "PLAYER_LEVEL_UP" then
        V.Fire("levelUp")
    elseif CAST_HANDLERS[event] then
        CAST_HANDLERS[event](event, ...)
    elseif event == "UNIT_COMBAT" then
        UnitCombat(...)
    else
        CombatLog()
    end
end)

---------------------------------------------------------------------------
-- Low health. WoW Forever hides the player's health from addons in combat,
-- but the game's own low-health warning (LowHealthFrame: the red screen
-- edge, at 35%) reads it untainted: its showing is our cue. (It also pulses
-- in combat behind a full-screen window: not low health, skipped.) With
-- that warning off in the game's options, health is read directly when it
-- isn't hidden.
---------------------------------------------------------------------------
local LOW_HP = 0.35
local low = false

local function Secret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

local function FullscreenPanel()
    return GetUIPanel ~= nil and GetUIPanel("fullscreen") ~= nil
end

-- Low: its loop for as long as it lasts
local function SetLow(on)
    if on and not low then
        low = true
        V.Fire("lowHp")
    elseif not on and low then
        low = false
        V.EndLoop("lowHp")
    end
end

local warning = _G.LowHealthFrame
if warning then
    warning:HookScript("OnShow", function()
        if IC.db and not FullscreenPanel() and not UnitIsDeadOrGhost("player") then SetLow(true) end
    end)
    warning:HookScript("OnHide", function() SetLow(false) end)
end

local health = CreateFrame("Frame")
health:RegisterUnitEvent("UNIT_HEALTH", "player")
health:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
health:RegisterEvent("PLAYER_DEAD")
health:SetScript("OnEvent", function(_, event)
    if not IC.db then return end
    if event == "PLAYER_DEAD" or UnitIsDeadOrGhost("player") then return SetLow(false) end
    -- The game's warning does it, when it is on
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if warning and get and get("doNotFlashLowHealthWarning") ~= "1" then return end
    local hp, max = UnitHealth("player"), UnitHealthMax("player")
    if Secret(hp) or Secret(max) or not max or max <= 0 then return end
    SetLow(hp / max <= LOW_HP)
end)

