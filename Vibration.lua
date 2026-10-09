-- Controller vibration on game events, adapted from Easy Controller -
-- Forever's Vibration module (moust4ki, MIT License, see
-- LICENSE-EasyController.md): its patterns, played on the two
-- standard motors at one strength for all. Three events: you level up, you
-- land a critical hit (damage or heal), you take one; casts, matched to
-- what they are (fire, Hearthstone, mining, tailoring...). Each has a pattern of
-- its own, or none, grouped as Easy Controller does (Combat, Progress). Set
-- in the Vibration tab (VibeEditor.lua); on / off
-- and strength in the Vibration tab (Settings).
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
    -- Actions, felt as they go (a cast's loop): gathering, then crafting
    { key = "pluck", label = "Rustle", action = true,      -- herbalism: leaves, then the pull
        steps = { { 0.2, 0.3, 0.1 }, { 0.3, 0.2, 0.1 }, { 0, 0, 0.15 }, { 0.25, 0.35, 0.1 }, { 0, 0, 0.25 } } },
    { key = "pickaxe", label = "Pickaxe", action = true,   -- mining: a hard strike, its ring, a swing
        steps = { { 1, 0.8, 0.12 }, { 0.25, 0.15, 0.1 }, { 0, 0, 0.55 } } },
    { key = "skin", label = "Cut", action = true,          -- skinning: the knife drawn back and forth
        steps = { { 0.5, 0.1, 0.15 }, { 0.1, 0.5, 0.15 }, { 0, 0, 0.15 } } },
    { key = "reel", label = "Line", action = true,         -- fishing: a still line, a bob now and then
        steps = { { 0.12, 0.12, 0.5 }, { 0.45, 0.35, 0.1 }, { 0.12, 0.12, 0.4 } } },
    { key = "click", label = "Tumbler", action = true,     -- opening, a lock: small clicks, then give
        steps = { { 0.3, 0.3, 0.1 }, { 0, 0, 0.2 }, { 0.35, 0.35, 0.1 }, { 0, 0, 0.35 } } },
    { key = "hammer", label = "Anvil", action = true,      -- blacksmithing: hammer and its rebound
        steps = { { 0.9, 1, 0.1 }, { 0, 0, 0.15 }, { 0.45, 0.55, 0.1 }, { 0, 0, 0.45 } } },
    { key = "sew", label = "Stitch", action = true,        -- tailoring, first aid: quick small stitches
        steps = { { 0.3, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.3, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.3, 0.2, 0.1 },
            { 0, 0, 0.3 } } },
    { key = "punch", label = "Punch", action = true,       -- leatherworking: the awl through hide
        steps = { { 0.6, 0.35, 0.12 }, { 0.15, 0.1, 0.1 }, { 0, 0, 0.35 } } },
    { key = "bubble", label = "Bubbles", action = true,    -- alchemy: a brew, bubbling here and there
        steps = { { 0.2, 0, 0.1 }, { 0, 0, 0.15 }, { 0, 0.3, 0.1 }, { 0, 0, 0.1 }, { 0.25, 0.25, 0.1 },
            { 0, 0, 0.25 } } },
    { key = "sizzle", label = "Sizzle", action = true,     -- cooking: a pan, never quite still
        steps = { { 0.15, 0.3, 0.1 }, { 0.1, 0.2, 0.1 }, { 0.2, 0.25, 0.1 }, { 0.1, 0.15, 0.1 } } },
    { key = "gears", label = "Ratchet", action = true,     -- engineering: a wrench, notch by notch
        steps = { { 0.5, 0.2, 0.1 }, { 0, 0, 0.1 }, { 0.2, 0.5, 0.1 }, { 0, 0, 0.1 } } },
    { key = "shimmer", label = "Shimmer", action = true,   -- enchanting: magic swelling and fading
        steps = { { 0.1, 0.1, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.5, 0.5, 0.1 }, { 0.3, 0.3, 0.1 }, { 0.1, 0.1, 0.1 },
            { 0, 0, 0.1 } } },
    -- Spells, by family
    { key = "kindle", label = "Kindle", action = true,     -- fire: crackling, building heat
        steps = { { 0.3, 0.15, 0.1 }, { 0.1, 0.35, 0.1 }, { 0.45, 0.25, 0.1 }, { 0.15, 0.4, 0.1 }, { 0.55, 0.45, 0.1 },
            { 0.2, 0.2, 0.1 } } },
    { key = "frost", label = "Frost", action = true,       -- frost: thin, crisp, cold ticks
        steps = { { 0.08, 0.3, 0.1 }, { 0, 0, 0.12 }, { 0.08, 0.25, 0.1 }, { 0.05, 0.1, 0.2 } } },
    { key = "arcane", label = "Arcane", action = true,     -- arcane: bolts flying side to side
        steps = { { 0.5, 0, 0.1 }, { 0, 0, 0.12 }, { 0, 0.5, 0.1 }, { 0, 0, 0.12 } } },
    { key = "shadow", label = "Shadow", action = true,     -- shadow: a low, heavy throb
        steps = { { 0.55, 0.05, 0.25 }, { 0.2, 0, 0.2 }, { 0.4, 0.05, 0.2 }, { 0.1, 0, 0.2 } } },
    { key = "radiance", label = "Radiance", action = true, -- holy: light swelling, both sides
        steps = { { 0.1, 0.1, 0.15 }, { 0.25, 0.25, 0.15 }, { 0.4, 0.4, 0.2 }, { 0.25, 0.25, 0.15 } } },
    { key = "mend", label = "Mend", action = true,         -- healing: a calm, slow pulse
        steps = { { 0.3, 0.3, 0.15 }, { 0.12, 0.12, 0.15 }, { 0, 0, 0.3 } } },
    { key = "static", label = "Static", action = true,     -- nature, lightning: jittery crackle
        steps = { { 0.4, 0, 0.1 }, { 0, 0.45, 0.1 }, { 0.2, 0.2, 0.1 }, { 0.5, 0.1, 0.1 }, { 0, 0, 0.1 },
            { 0.1, 0.5, 0.1 } } },
    { key = "draw", label = "Draw", action = true,         -- aimed shots: the bowstring, tighter and tighter
        steps = { { 0.08, 0.08, 0.2 }, { 0.16, 0.16, 0.2 }, { 0.26, 0.26, 0.2 }, { 0.36, 0.36, 0.2 } } },
    { key = "hearth", label = "Hearth", action = true,     -- Hearthstone, teleports: a long hum rising
        steps = { { 0.08, 0.08, 0.3 }, { 0.15, 0.15, 0.3 }, { 0.25, 0.25, 0.3 }, { 0.12, 0.12, 0.2 } } },
    { key = "ritual", label = "Ritual", action = true,     -- summoning: deep slow beats
        steps = { { 0.6, 0.3, 0.15 }, { 0, 0, 0.35 }, { 0.35, 0.6, 0.15 }, { 0, 0, 0.35 } } },
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
    { key = "casting", label = "Casting" },
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

-- A cast's four moments (its loop, interrupted, cancelled, pushed back)
-- take their patterns from one ready-made set, chosen per kind of cast
V.CAST_PRESETS = {
    { key = "off", label = "Off", icon = V.OFF_ICON },
    { key = "subtle", label = "Subtle", cast = "purr", interrupted = "tick", cancelled = "micro", pushback = "micro" },
    { key = "sweep", label = "Sweep", cast = "sweep", interrupted = "impact", cancelled = "micro", pushback = "tick" },
    { key = "pulse", label = "Pulse", cast = "pulse", interrupted = "double", cancelled = "micro", pushback = "micro" },
    { key = "heart", label = "Heartbeat", cast = "heart", interrupted = "impact", cancelled = "tick", pushback = "micro" },
    { key = "alerts", label = "Alerts only", interrupted = "impact", cancelled = "micro", pushback = "tick" },
}
-- The actions a cast can be (gathering, crafting), each with a set of its
-- own: its pattern while casting, the usual alerts when it ends badly
V.CAST_ACTIONS = {
    { key = "herbalism", label = "Herbalism", kind = "gather", pattern = "pluck", spell = 2366 },
    { key = "mining", label = "Mining", kind = "gather", pattern = "pickaxe", spell = 2575 },
    { key = "skinning", label = "Skinning", kind = "gather", pattern = "skin", spell = 8613 },
    { key = "fishing", label = "Fishing", kind = "gather", pattern = "reel", spell = 7620 },
    { key = "opening", label = "Opening", kind = "gather", pattern = "click", spell = 3365 },
    { key = "blacksmithing", label = "Blacksmithing", kind = "craft", pattern = "hammer", spell = 2018 },
    { key = "tailoring", label = "Tailoring", kind = "craft", pattern = "sew", spell = 3908 },
    { key = "leatherworking", label = "Leatherworking", kind = "craft", pattern = "punch", spell = 2108 },
    { key = "alchemy", label = "Alchemy", kind = "craft", pattern = "bubble", spell = 2259 },
    { key = "cooking", label = "Cooking", kind = "craft", pattern = "sizzle", spell = 2550 },
    { key = "engineering", label = "Engineering", kind = "craft", pattern = "gears", spell = 4036 },
    { key = "enchanting", label = "Enchanting", kind = "craft", pattern = "shimmer", spell = 7411 },
    { key = "firstaid", label = "First Aid", kind = "craft", pattern = "sew", spell = 3273 },
    -- Spells, by family (every rank shares its name: the first's ID names them)
    { key = "fire", label = "Fire", kind = "spell", pattern = "kindle",
        spells = { 133, 11366, 2120, 2948, 348, 6353, 1949, 5740, 5676 } },
    { key = "frostSpells", label = "Frost", kind = "spell", pattern = "frost", spells = { 116, 10, 120 } },
    { key = "arcaneSpells", label = "Arcane", kind = "spell", pattern = "arcane",
        spells = { 5143, 12051, 118, 2912 } },
    { key = "shadowSpells", label = "Shadow", kind = "spell", pattern = "shadow",
        spells = { 686, 689, 1120, 5138, 15407, 8092, 5782, 755, 6201, 693 } },
    { key = "holy", label = "Holy", kind = "spell", pattern = "radiance",
        spells = { 585, 14914, 2006, 7328, 2008, 20484, 879, 10318 } },
    { key = "healing", label = "Healing", kind = "spell", pattern = "mend",
        spells = { 2050, 2054, 2060, 2061, 596, 5185, 8936, 740, 331, 8004, 1064, 635, 19750 } },
    { key = "nature", label = "Nature", kind = "spell", pattern = "static",
        spells = { 403, 421, 5176, 339, 16914, 2637, 6795 } },
    { key = "shots", label = "Shots", kind = "spell", pattern = "draw", spells = { 19434, 1510, 2643 } },
    { key = "travel", label = "Hearthstone", kind = "spell", pattern = "hearth",
        spells = { 8690, 556, 3561, 3562, 3563, 3565, 3566, 3567, 10059, 11416, 11417, 11418, 11419, 11420 } },
    { key = "summon", label = "Summoning", kind = "spell", pattern = "ritual",
        spells = { 688, 697, 712, 691, 698, 5784, 883, 982, 1122 } },
}
-- "Match the action": the set of the action going on
table.insert(V.CAST_PRESETS, 2, { key = "auto", label = "Match the action", auto = true,
    icon = VIBE_ICONS .. "shimmer" })
for _, a in ipairs(V.CAST_ACTIONS) do
    V.CAST_PRESETS[#V.CAST_PRESETS + 1] = { key = a.key, label = a.label, action = a.kind, cast = a.pattern,
        interrupted = "impact", cancelled = "micro", pushback = "tick" }
end

local PRESET = {}
for _, p in ipairs(V.CAST_PRESETS) do
    p.icon = p.icon or VIBE_ICONS .. (p.cast or p.interrupted)
    PRESET[p.key] = p
end
-- (which field of a set each moment uses)
local PHASE = { cast = "cast", interrupted = "interrupted", cancelled = "cancelled", pushback = "pushback" }
V.CAST_PHASES = { "cast", "interrupted", "cancelled", "pushback" }

V.CAST_KINDS = {
    { key = "spell", label = "Spell", icon = EVENT_ICONS .. "cast", preset = "auto", fallback = "sweep",
        tip = "Casting or channelling a spell or an ability. Match the action: fire, frost, healing,"
            .. " Hearthstone... each its own; any other spell, Sweep." },
    { key = "gather", label = "Gathering", icon = EVENT_ICONS .. "gather", preset = "auto",
        tip = "Herbalism, mining, skinning, fishing, opening a chest or a lock." },
    { key = "craft", label = "Crafting", icon = EVENT_ICONS .. "craft", preset = "auto",
        tip = "Making something with a profession (cast with its window open)." },
}
local CAST_KIND = {}
for _, k in ipairs(V.CAST_KINDS) do CAST_KIND[k.key] = k end

-- What the Vibration tab lists: each event, and the kinds of cast (each a
-- set for its four moments)
V.RAIL = {}
for _, e in ipairs(V.EVENTS) do
    if e.parent then
        if e.key == "cast" then
            for _, k in ipairs(V.CAST_KINDS) do
                V.RAIL[#V.RAIL + 1] = { key = "cast_" .. k.key, group = "casting", label = k.label, icon = k.icon,
                    castKind = k.key, tip = k.tip, subs = { e } }
            end
        end
    else
        V.RAIL[#V.RAIL + 1] = { key = e.key, group = e.group, label = e.label, icon = e.icon, subs = { e } }
    end
end

-- db.vibration = { enabled, intensity, events = { key = { on, pattern } } }
function V.Settings()
    IC.db.vibration = IC.db.vibration or {}
    local s = IC.db.vibration
    if s.enabled == nil then s.enabled = true end
    s.casts = s.casts or {}
    for _, k in ipairs(V.CAST_KINDS) do
        if not PRESET[s.casts[k.key]] then s.casts[k.key] = k.preset end
    end
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

-- A kind of cast's set ("off": none)
function V.CastPreset(kind)
    return V.Settings().casts[kind or "spell"] or "off"
end

function V.SetCastPreset(kind, presetKey)
    V.Settings().casts[kind] = PRESET[presetKey] and presetKey or "off"
end

function V.Preset(key)
    return PRESET[key]
end

-- The cast in progress' kind (Gathering, Crafting...; spell by default)
-- and action (Mining, Tailoring...; nil for a spell)
V.castKind = "spell"
V.castAction = nil

-- An event's pattern, or nil when it is off (a cast's moments: from the
-- set of the kind of cast going on)
function V.EventPattern(eventKey)
    if PHASE[eventKey] then
        local preset = PRESET[V.CastPreset(V.castKind)]
        if preset and preset.auto then
            local kind = CAST_KIND[V.castKind]
            preset = PRESET[V.castAction] or PRESET[kind and kind.fallback or "subtle"]
        end
        return preset and preset[PHASE[eventKey]] or nil
    end
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

-- A hold under way (a "Hold to" bar): a rumble on the left grip rising with
-- its progress (0 to 1), both grips at full strength once full; the caller sends it every
-- update (sent on at most every 0.1 s); nil: stopped
local holdSent = 0
function V.Hold(progress)
    if not (C_GamePad and C_GamePad.SetVibration and IC.db) then return end
    if not progress then
        holdSent = 0
        return V.Stop()
    end
    local s = V.Settings()
    if not s.enabled then return end
    local now = GetTime()
    if now - holdSent < 0.1 then return end
    holdSent = now
    local gain = s.intensity
    if progress >= 1 then
        -- (full: both grips at full strength, whatever the intensity: it
        -- must stand out from the filling)
        motors(1, 1)
    else
        motors((0.1 + 0.35 * progress) * gain, 0)
    end
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

function V.SimulateCast(onStep, kind, action)
    V.StopSimulation()
    V.castKind = kind or "spell"
    -- (Match the action: a likely one of that kind)
    if not action then
        for _, a in ipairs(V.CAST_ACTIONS) do
            if a.kind == kind then action = action or a.key end
        end
    end
    V.castAction = action
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
        V.castKind, V.castAction = "spell", nil
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

-- Gathering: these spells (by their names in the game's language), each
-- an action
local GATHER_IDS = {
    herbalism = { 2366, 2368, 3570, 11993 },
    mining = { 2575, 2576, 3564, 10248 },
    skinning = { 8613, 8617, 8618, 10768 },
    fishing = { 7620, 7731, 7732, 18248 },
    opening = { 3365, 6247, 6477, 6478, 21651, 1804 },
}
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local gatherByName, craftByName, spellByName
local function Names()
    if gatherByName then return end
    gatherByName, craftByName = {}, {}
    for action, ids in pairs(GATHER_IDS) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then gatherByName[name] = action end
        end
    end
    spellByName = {}
    for _, a in ipairs(V.CAST_ACTIONS) do
        local name = a.kind == "craft" and SpellName(a.spell)
        if name then craftByName[name] = a.key end
        for _, id in ipairs(a.spells or {}) do
            name = SpellName(id)
            if name and not spellByName[name] then spellByName[name] = a.key end
        end
    end
end

-- The profession whose window is open (its name, in the game's language)
local function OpenProfession()
    if _G.CraftFrame and _G.CraftFrame:IsShown() then
        local name = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
        return name or SpellName(7411)
    end
    if (_G.TradeSkillFrame and _G.TradeSkillFrame:IsShown())
        or (_G.ProfessionsFrame and _G.ProfessionsFrame:IsShown()) then
        if GetTradeSkillLine then return (GetTradeSkillLine()) or "" end
        local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
        return info and info.professionName or ""
    end
end

-- A cast's kind and action
local function CastKind(spellID)
    Names()
    local profession = OpenProfession()
    if profession then
        if secret(profession) then return "craft", nil end
        return "craft", craftByName[profession]
    end
    if spellID and not secret(spellID) then
        local name = SpellName(spellID)
        if name and not secret(name) then
            if gatherByName[name] then return "gather", gatherByName[name] end
            return "spell", spellByName[name]
        end
    end
    return "spell", nil
end

local function CastStarted(event, _, _, spellID)
    V.castKind, V.castAction = CastKind(spellID)
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

