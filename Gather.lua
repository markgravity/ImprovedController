-- Gathering with the minimap (NodeScan.lua reads it):
--   labels: each dot on the minimap gets its name beside it, a herb's or
--     ore's coloured by the skill it gives (as the game colours recipes).
--     Shown and hidden by a hotkey (recorded
--     in the Gather tab, one button or one held + one pressed), a touchpad
--     corner / button override action, or the key binding;
--   alerts: the minimap read every few seconds, and a herb or ore worth
--     having that appears pulses the controller, plays a sound and says
--     what and where.
-- Set in the Gather tab (GatherEditor.lua); IC.db.gather.
local _, IC = ...

local K = IC.ConfigKit
local KC = K.C
local N = IC.NodeScan

local Gather = {}
IC.Gather = Gather

local DEFAULTS = {
    labels = false,      -- the labels on the minimap shown
    colors = true,       -- herbs and ore coloured by the skill they give
    need = true,         -- a red one's label says the skill it needs: "Bruiseweed (100)"
    alert = false,
    alertFor = "skill",  -- skill (gives skill), gather (can gather), any (any herb / ore), all (any dot)
    alertWith = "both",  -- both, vibe, sound, show (the message only)
    interval = 3,        -- seconds between alert scans
}

function Gather.Settings()
    IC.db.gather = IC.db.gather or {}
    local s = IC.db.gather
    for k, v in pairs(DEFAULTS) do
        if s[k] == nil then s[k] = v end
    end
    return s
end

-- A herb or ore's skill colour, or nil (not one, its profession not
-- learnt, or colours off)
function Gather.SkillColor(name)
    if not Gather.Settings().colors then return nil end
    local state = N.State(name)
    return state and N.COLORS[state]
end

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

-- A label's words: "Silverleaf x2", "Bruiseweed (100)" for one beyond the
-- player's skill
function Gather.LabelText(node)
    local text = node.count > 1 and (node.name .. " x" .. node.count) or node.name
    if Gather.Settings().need and N.State(node.name) == "red" then
        text = text .. " (" .. select(2, N.Kind(node.name)) .. ")"
    end
    return text
end

-- The player's place in the world, as yards east and north, or nil (in an
-- instance). The world's x runs north, its y west.
local function PlayerPos()
    if not UnitPosition then return nil end
    local y, x = UnitPosition("player")
    if type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return nil end
    return -y, x
end

local function Vibrate()
    if IC.Vibe and IC.Vibe.Settings().enabled then IC.Vibe.Play("pulse") end
end

---------------------------------------------------------------------------
-- The labels: on the minimap, over its dots
---------------------------------------------------------------------------
local SCAN = 0.5     -- seconds between scans while shown (0.25 where the player's place is unknown)
local DOT = 11       -- the game's dot: a label sits just beside it

local overlay = K.NewFrame("Frame", "ImprovedControllerGatherLabels")
overlay:SetParent(Minimap)
overlay:SetAllPoints(Minimap)
overlay:SetFrameLevel(Minimap:GetFrameLevel() + 5)
overlay:Hide()

local pins = {}
local function Pin(i)
    local p = pins[i]
    if p then return p end
    -- (an empty frame the size of the game's dot, over it)
    p = K.NewFrame("Frame", nil, overlay)
    p:SetSize(DOT, DOT)
    p.label = p:CreateFontString(nil, "OVERLAY")
    p.label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    pins[i] = p
    return p
end

local nodes, scanEast, scanNorth = {}, nil, nil

local function Rescan()
    nodes = N.Scan()
    scanEast, scanNorth = PlayerPos()
end

-- Each node where it is now: its place at the scan, less how far the
-- player has walked since, turned with a turning minimap
local function Place()
    local radius = Minimap:GetWidth() / 2
    local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or radius
    local units = radius / view
    local e, n = PlayerPos()
    local de, dn = 0, 0
    if e and scanEast then de, dn = e - scanEast, n - scanNorth end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local facing = get("rotateMinimap") == "1" and N.Facing() or 0
    local c, s = math.cos(facing), math.sin(facing)
    local edge = radius - 4
    for i, node in ipairs(nodes) do
        local p = Pin(i)
        local east, north = node.east - de, node.north - dn
        local x, y = (east * c + north * s) * units, (-east * s + north * c) * units
        if x * x + y * y > edge * edge then
            p:Hide()
        else
            p:ClearAllPoints()
            p:SetPoint("CENTER", overlay, "CENTER", x, y)
            local color = Gather.SkillColor(node.name)
            local r, g, b = 1, 1, 1
            if color then r, g, b = color[1], color[2], color[3] end
            p.label:SetTextColor(r, g, b)
            p.label:SetText(Gather.LabelText(node))
            -- Beside it, on the side towards the minimap's middle
            p.label:ClearAllPoints()
            if x > 0 then
                p.label:SetPoint("RIGHT", p, "LEFT", -2, 0)
            else
                p.label:SetPoint("LEFT", p, "RIGHT", 2, 0)
            end
            p:Show()
        end
    end
    for i = #nodes + 1, #pins do pins[i]:Hide() end
end

overlay:SetScript("OnUpdate", function(self, elapsed)
    self.left = (self.left or 0) - elapsed
    if self.left <= 0 then
        self.left = PlayerPos() and SCAN or SCAN / 2
        Rescan()
    end
    Place()
end)

function Gather.ApplyLabels()
    local on = Gather.Settings().labels and N.Supported()
    overlay.left = 0
    overlay:SetShown(on and true or false)
end

function Gather.SetLabels(on)
    Gather.Settings().labels = on
    Gather.ApplyLabels()
end

-- The hotkey, the touchpad / override action, the key binding: labels on
-- or off
local lastToggle = 0
function Gather.Toggle()
    -- (a click arrives twice: down and up)
    if GetTime() - lastToggle < 0.3 then return end
    lastToggle = GetTime()
    if not N.Supported() then
        IC.Print("This client can't read the minimap.")
        return
    end
    Gather.SetLabels(not Gather.Settings().labels)
end

local toggle = K.NewFrame("Button", "ImprovedControllerNodeScan", UIParent)
toggle:RegisterForClicks("AnyDown", "AnyUp")
toggle:SetScript("OnClick", Gather.Toggle)
_G["BINDING_NAME_CLICK ImprovedControllerNodeScan:LeftButton"] = "Minimap labels"

---------------------------------------------------------------------------
-- The hotkey: a button, or one held + one pressed ("PADLSHOULDER+PADDUP").
-- Watched, not taken over: the buttons keep their own actions too.
---------------------------------------------------------------------------
function Gather.Key()
    return IC.db and IC.db.gatherKey
end

local function Parts(spec)
    local held, pressed = spec:match("^(.-)%+(.+)$")
    if held then return held, pressed end
    return nil, spec
end

-- Its name: "L1 + D-pad Up"; glyphs too with size
function Gather.KeyText(size)
    local key = Gather.Key()
    if not key then return "Not bound" end
    local held, pressed = Parts(key)
    local function one(k)
        return (size and (IC.GlyphText(k, size) .. " ") or "") .. IC.ButtonName(k)
    end
    return held and (one(held) .. " + " .. one(pressed)) or one(pressed)
end

function Gather.SetKey(key)
    IC.db.gatherKey = key
end

local keyWatch = CreateFrame("Frame")
local wasDown = false
keyWatch:SetScript("OnUpdate", function()
    local key = Gather.Key()
    if not key or not IsKeyDown or (IC.Menu and IC.Menu.IsOpen()) then
        wasDown = false
        return
    end
    local held, pressed = Parts(key)
    local down = IsKeyDown(pressed) and (not held or IsKeyDown(held))
    -- The moment the combination is made
    if down and not wasDown then
        lastToggle = 0
        Gather.Toggle()
    end
    wasDown = down
end)

---------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------
local banner = K.NewFrame("Frame", "ImprovedControllerGatherAlert", UIParent)
banner:SetSize(360, 50)
banner:SetPoint("TOP", UIParent, "TOP", 0, -220)
banner:SetFrameStrata("HIGH")
banner:Hide()
banner.name = K.Text(banner, 20, KC.cream)
banner.name:SetPoint("TOP")
banner.name:SetJustifyH("CENTER")
banner.name:SetShadowOffset(1, -1)
banner.info = K.ChatText(banner, 14, KC.cream2)
banner.info:SetPoint("TOP", banner.name, "BOTTOM", 0, -4)
banner.info:SetJustifyH("CENTER")
banner.info:SetShadowOffset(1, -1)
banner:SetScript("OnUpdate", function(self)
    local left = self.ends - GetTime()
    if left <= 0 then return self:Hide() end
    self:SetAlpha(math.min(1, left))
end)

local function Wanted(name)
    local how = Gather.Settings().alertFor
    if how == "all" then return true end
    if how == "any" then return N.Kind(name) ~= nil end
    local state = N.State(name)
    if how == "gather" then return state ~= nil and state ~= "red" end
    return state == "orange" or state == "yellow" or state == "green"
end

-- "Silverleaf x2" in its colour
local function Label(node)
    local c = Gather.SkillColor(node.name) or KC.white
    local name = node.count > 1 and (node.name .. " x" .. node.count) or node.name
    return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, name)
end

function Gather.Alert(node, more)
    local s = Gather.Settings()
    if s.alertWith == "both" or s.alertWith == "vibe" then Vibrate() end
    local sound = SOUNDKIT and (SOUNDKIT.MAP_PING or SOUNDKIT.RAID_WARNING)
    if (s.alertWith == "both" or s.alertWith == "sound") and sound then PlaySound(sound, "Master") end
    banner.name:SetText(Label(node) .. (more > 0 and ("  |cffb9ab8c+" .. more .. " more|r") or ""))
    banner.info:SetText(N.Direction(node) .. " · " .. N.Distance(node))
    banner.ends = GetTime() + 5
    banner:SetAlpha(1)
    banner:Show()
end

-- What was there at the last look: name -> how many
local seen = {}

local function Watch()
    local s = Gather.Settings()
    if not s.alert or IC.InCombat() or not N.Supported() or not Minimap:IsVisible() then return end
    local counts, fresh = {}, {}
    for _, node in ipairs(N.Scan()) do
        if Wanted(node.name) then
            counts[node.name] = (counts[node.name] or 0) + node.count
            fresh[#fresh + 1] = node
        end
    end
    -- New: a name not seen, or more of it than before
    local new = {}
    for _, node in ipairs(fresh) do
        if (counts[node.name] or 0) > (seen[node.name] or 0) then new[#new + 1] = node end
    end
    seen = counts
    if #new == 0 then return end
    table.sort(new, function(a, b) return N.Yards(a) < N.Yards(b) end)
    Gather.Alert(new[1], #new - 1)
end

local watcher = CreateFrame("Frame")
watcher.left = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - elapsed
    if self.left > 0 then return end
    self.left = Gather.Settings().interval
    Watch()
end)
watcher:Hide()

function Gather.ApplyAlert()
    seen = {}
    watcher.left = 0
    watcher:SetShown(Gather.Settings().alert)
end

IC.OnLogin(function()
    Gather.ApplyLabels()
    Gather.ApplyAlert()
end)

-- /ic nodes [step <n>|debug]
function Gather.Command(option, value)
    value = tonumber(value)
    if option == "step" and value and value >= 2 then
        N.step = value
    elseif option == "debug" then
        N.debug = not N.debug
        if N.debug then Rescan() end
    elseif option then
        IC.Print("usage: /ic nodes [step <n>|debug]")
        return
    else
        lastToggle = 0
        return Gather.Toggle()
    end
    IC.Print(string.format("Minimap nodes: step %d, debug %s", N.step, N.debug and "on" or "off"))
end
