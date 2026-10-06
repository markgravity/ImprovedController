-- Controller vibration on game events, adapted from Easy Controller -
-- Forever's Vibration module (moust4ki, MIT License, see
-- LICENSE-EasyController.md): its patterns, played on the two
-- standard motors at one strength for all. Three events: you level up, you
-- land a critical hit (damage or heal), you take one. Each has a pattern of
-- its own, or none, grouped as Easy Controller does (Combat, Progress). Set
-- in the Vibration tab (VibeEditor.lua); on / off
-- and strength in the Home tab.
local _, IC = ...

local V = {}
IC.Vibe = V

-- The events' icons, drawn in the radial menu's style (tools/make_vibe_icons.py)
local EVENT_ICONS = "Interface\\AddOns\\ImprovedController\\textures\\ic_event_"

-- Patterns: steps of { low motor, high motor, seconds }; 0, 0 is a pause.
-- Every step drives the low motor and lasts 0.1 s or more: a DualSense
-- (on a Mac at least) gives nothing for the high motor alone or for
-- Easy Controller's shorter taps.
V.PATTERNS = {
    { key = "micro", label = "Micro tick", steps = { { 0.35, 0.3, 0.1 } } },
    { key = "tick", label = "Tick", steps = { { 0.6, 0.6, 0.12 } } },
    { key = "double", label = "Double tick",
        steps = { { 0.7, 0.6, 0.12 }, { 0, 0, 0.12 }, { 0.7, 0.6, 0.12 } } },
    { key = "pulse", label = "Pulse", steps = { { 0.8, 0.5, 0.18 } } },
    { key = "long", label = "Long", steps = { { 0.8, 0.4, 0.6 } } },
    { key = "heart", label = "Heartbeat",
        steps = { { 0.9, 0, 0.09 }, { 0, 0, 0.12 }, { 0.6, 0, 0.09 } } },
    { key = "rise", label = "Crescendo",
        steps = { { 0.3, 0.2, 0.12 }, { 0.6, 0.4, 0.12 }, { 1, 0.6, 0.18 } } },
    -- Ours: a hard knock, its opposite, three taps, a soft purr (a cast's:
    -- it loops while the cast lasts) and a rumble that fades out
    { key = "impact", label = "Impact", steps = { { 1, 1, 0.16 } } },
    { key = "triple", label = "Triple tick",
        steps = { { 0.7, 0.6, 0.11 }, { 0, 0, 0.1 }, { 0.7, 0.6, 0.11 }, { 0, 0, 0.1 }, { 0.7, 0.6, 0.11 } } },
    { key = "purr", label = "Purr",
        steps = { { 0.22, 0.12, 0.1 }, { 0, 0, 0.18 }, { 0.22, 0.12, 0.1 }, { 0, 0, 0.18 } } },
    { key = "fade", label = "Fade out",
        steps = { { 1, 0.7, 0.15 }, { 0.6, 0.4, 0.15 }, { 0.3, 0.2, 0.2 } } },
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
    { key = "progress", label = "Progress" },
}
V.EVENTS = {
    { key = "crit", group = "combat", label = "Critical hit", icon = EVENT_ICONS .. "crit", on = true,
        pattern = "tick", tip = "Your damage or healing lands a critical hit (in WoW Forever: your target"
            .. " takes one, or a critical heal lands on you or it)." },
    { key = "critted", group = "combat", label = "Critical hit taken", icon = EVENT_ICONS .. "critted", on = true,
        pattern = "double", tip = "An enemy lands a critical hit on you." },
    { key = "cast", group = "combat", label = "Spell cast", icon = EVENT_ICONS .. "cast", on = false,
        pattern = "purr", loop = true, tip = "While you cast or channel a spell, its pattern plays over"
            .. " and over until the spell ends (instant spells: nothing)." },
    { key = "levelUp", group = "progress", label = "Level up", icon = EVENT_ICONS .. "levelup", on = true,
        pattern = "rise", tip = "You reach a new level." },
}
local EVENT = {}
for _, e in ipairs(V.EVENTS) do EVENT[e.key] = e end

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

local function motors(low, high)
    C_GamePad.SetVibration("Low", low)
    C_GamePad.SetVibration("High", high)
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
-- loop: played again and again (with a short gap) until V.Stop
function V.Play(key, loop)
    if not (C_GamePad and C_GamePad.SetVibration and IC.db) then return end
    local pattern = PATTERN[key] or PATTERN.tick
    local gain = math.max(0, math.min(1, V.Settings().intensity))
    V.Stop()
    local t = 0
    for _, step in ipairs(pattern.steps) do
        local low, high, length = step[1] * gain, step[2] * gain, step[3]
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

-- An event happened: its pattern, if it is on (the same event at most
-- every 0.4 s). A looping event's plays until V.EndLoop.
local last = {}
function V.Fire(eventKey)
    if not IC.db then return end
    local s = V.Settings()
    local pattern = V.EventPattern(eventKey)
    if not (s.enabled and pattern) then return end
    if EVENT[eventKey].loop then
        V.looping = { key = eventKey, pattern = pattern }
        V.Play(pattern, true)
        return
    end
    local now = GetTime()
    if last[eventKey] and now - last[eventKey] < 0.4 then return end
    last[eventKey] = now
    V.Play(pattern)
end

-- A looping event is over (the cast ended): its loop stops
function V.EndLoop(eventKey)
    if V.looping and V.looping.key == eventKey then
        V.looping = nil
        V.Stop()
    end
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
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
-- A cast or a channel: its loop from start to end
local CAST_START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }
local CAST_END = {
    UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_FAILED = true,
}
for event in pairs(CAST_START) do events:RegisterUnitEvent(event, "player") end
for event in pairs(CAST_END) do events:RegisterUnitEvent(event, "player") end
if hasCombatLog then
    events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
else
    events:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
end
events:SetScript("OnEvent", function(_, event, ...)
    if not IC.db then return end
    if event == "PLAYER_LEVEL_UP" then
        V.Fire("levelUp")
    elseif CAST_START[event] then
        V.Fire("cast")
    elseif CAST_END[event] then
        V.EndLoop("cast")
    elseif event == "UNIT_COMBAT" then
        UnitCombat(...)
    else
        CombatLog()
    end
end)
