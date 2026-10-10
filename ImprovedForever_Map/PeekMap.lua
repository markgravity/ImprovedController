-- Peek map: while a hotkey is held, the game's own Map & Quest Log shows
-- with everything but its map faded out (its frame, the nav bar, the quest
-- list, the gamepad prompts): the map alone, see-through, placed and sized
-- as the Map tab says (PeekMapEditor.lua, IF.db.peekMap); letting go
-- closes it. The native map, so its quests, markers and arrow are all
-- there.
-- Opening a game window from addon code taints it on Forever (Touchpad.lua),
-- so the hotkey is an override binding on a secure button that runs
-- "/click <the map's micro button>" (press: opens, release: closes; on
-- Forever the quest log's, which toggles the Map & Quest Log), in combat
-- too. Set in the Controller tab (Binds.lua); IF.db.peekMapKey. A
-- touchpad corner can hold it too (Touchpad.lua: its Interface list): it
-- clicks the map's button itself, then PeekMap.Opened.
-- While open, the map has the gamepad (its own buttons and sticks), as
-- it always does.
local IF = ImprovedForever

local K = IF.ConfigKit

local PeekMap = {}
IF.PeekMap = PeekMap

local MARGIN = 40      -- from the screen's edge, placed at one

local DEFAULTS = {
    alpha = 0.75,        -- how see-through the map is
    size = 0.6,          -- its height, of the screen's
    anchor = "CENTER",   -- where on the screen: CENTER, TOP, TOPLEFT...
    x = 0,               -- moved from there: right (+) / left (-), of the screen's width
    y = 0,               -- up (+) / down (-), of its height
}

function PeekMap.Settings()
    local db = IF.db
    db.peekMap = db.peekMap or {}
    local settings = db.peekMap
    for k, v in pairs(DEFAULTS) do
        if settings[k] == nil then settings[k] = v end
    end
    -- (offsets were screen px once)
    for _, k in ipairs({ "x", "y" }) do
        if math.abs(settings[k]) > 0.5 then settings[k] = 0 end
    end
    settings.pins = nil
    return settings
end

---------------------------------------------------------------------------
-- The look: while the map is open for a peek, every part of the window but
-- its map (ScrollContainer) faded out, the map moved and scaled onto a
-- frame of ours placed by the settings. Put back as it closes.
-- Only looks change: no size of the map's (that would refit its canvas
-- from our code, and the values it then holds would taint the map's own
-- secure work, closing it included). The map keeps its size; one anchor
-- (its centre) and a scale put it in place.
---------------------------------------------------------------------------
local place = K.NewFrame("Frame", "ImprovedForeverPeekMapPlace", UIParent)
place:SetSize(1, 1)
place:EnableMouse(false)

local peeking = false      -- the open map is a peek
local saved                -- what the look changed: { alphas, points, scale, alpha }

-- The map's size and place on the screen, for the player's map
local function Place()
    local settings = PeekMap.Settings()
    local mapID = MapUtil and MapUtil.GetDisplayableMapForPlayer and MapUtil.GetDisplayableMapForPlayer()
        or C_Map.GetBestMapForUnit("player")
    local layer = mapID and (C_Map.GetMapArtLayers(mapID) or {})[1]
    local aspect = layer and layer.layerWidth / layer.layerHeight or 1.5
    local h = UIParent:GetHeight() * settings.size
    place:SetSize(h * aspect, h)
    local a = settings.anchor
    local x = a:find("LEFT") and MARGIN or a:find("RIGHT") and -MARGIN or 0
    local y = a:find("TOP") and -MARGIN or a:find("BOTTOM") and MARGIN or 0
    place:ClearAllPoints()
    place:SetPoint(a, UIParent, a, x + settings.x * UIParent:GetWidth(), y + settings.y * UIParent:GetHeight())
end

local function Fade(region)
    saved.alphas[region] = region:GetAlpha()
    region:SetAlpha(0)
end

local function Apply()
    local map = WorldMapFrame
    local scroll = map and map.ScrollContainer
    if not scroll or saved then return end
    local w, h = scroll:GetSize()
    if not (w and h and w > 0 and h > 0) then return end
    saved = { alphas = {}, points = {}, scale = scroll:GetScale(), alpha = scroll:GetAlpha() }
    for _, child in ipairs({ map:GetChildren() }) do
        if child ~= scroll then Fade(child) end
    end
    for _, region in ipairs({ map:GetRegions() }) do Fade(region) end
    for i = 1, scroll:GetNumPoints() do saved.points[i] = { scroll:GetPoint(i) } end
    -- Scaled to the place's height, centred on it (offsets in the map's own
    -- scaled units, from the screen's bottom left)
    Place()
    local px, py = place:GetCenter()
    local placeScale = place:GetEffectiveScale()
    local scale = saved.scale * (place:GetHeight() * placeScale) / (h * scroll:GetEffectiveScale())
    scroll:SetScale(scale)
    scroll:ClearAllPoints()
    scroll:SetSize(w, h)
    local mapScale = scroll:GetEffectiveScale()
    scroll:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px * placeScale / mapScale, py * placeScale / mapScale)
    scroll:SetAlpha(PeekMap.Settings().alpha)
end

local function Restore()
    local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not saved then return end
    for region, alpha in pairs(saved.alphas) do region:SetAlpha(alpha) end
    if scroll then
        scroll:SetScale(saved.scale)
        scroll:ClearAllPoints()
        for _, point in ipairs(saved.points) do scroll:SetPoint(unpack(point)) end
        scroll:SetAlpha(saved.alpha)
    end
    saved = nil
end

-- (parts of the window it shows later, a footer, faded too while a peek)
local refade = CreateFrame("Frame")
refade:SetScript("OnUpdate", function()
    if not (peeking and saved and WorldMapFrame) then return end
    for _, child in ipairs({ WorldMapFrame:GetChildren() }) do
        if child ~= WorldMapFrame.ScrollContainer and saved.alphas[child] == nil then Fade(child) end
    end
end)

IF.OnLogin(function()
    local map = WorldMapFrame
    if not map then return end
    map:HookScript("OnHide", function()
        peeking = false
        Restore()
    end)
end)

-- A click of ours has just opened the map (the hold button, a touchpad
-- corner): shown as the peek map
function PeekMap.Opened()
    if peeking or not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    peeking = true
    Apply()
    if PeekMap.debug and saved then
        local scroll = WorldMapFrame.ScrollContainer
        local n = 0
        for _ in pairs(saved.alphas) do n = n + 1 end
        IF.Print(("peek: shown, map %dx%d, alpha %.2f, %d parts faded"):format(scroll:GetWidth(),
            scroll:GetHeight(), scroll:GetEffectiveAlpha(), n))
    end
end

---------------------------------------------------------------------------
-- The hold button: the hotkey's press opens the map (if closed), its
-- release closes it (if open), each on its own phase whatever
-- ActionButtonUseKeyDown says
---------------------------------------------------------------------------
local hold = CreateFrame("Button", "ImprovedForeverPeekMapHold", UIParent,
    "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
hold:SetSize(1, 1)
hold:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
hold:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(hold, "OnClick", hold, [[
    self:SetAttribute("type", nil)
    return self:RunAttribute("ic-peek", down, self:GetAttribute("ic-macro"))
]])

-- A peek's press (opens) or release (closes), for the hold button and a
-- touchpad corner (Touchpad.lua sets it on its button too). Out of combat
-- the map is shown directly, not as a window: Forever's gamepad UI only
-- takes the gamepad for windows (ShowUIPanel), so the player keeps moving.
-- In combat a handle to the map is refused (it isn't protected): its
-- button opens it as a window then, which takes the gamepad. Returns false
-- (nothing to run) or sets the click to run the map's button.
PeekMap.SNIPPET = [[
    local down, macro = ...
    if not PlayerInCombat() then
        local map = self:GetFrameRef("map")
        if not map then return false end
        if down then
            if not map:IsShown() then
                map:Show()
                self:SetAttribute("ic-peek-shown", true)
            end
        elseif self:GetAttribute("ic-peek-shown") or self:GetAttribute("ic-peek-open") then
            map:Hide()
        end
        if not down then
            self:SetAttribute("ic-peek-shown", nil)
            self:SetAttribute("ic-peek-open", nil)
        end
        return false
    end
    if down then
        if self:GetAttribute("ic-peek-shown") or self:GetAttribute("ic-peek-open") then return false end
        self:SetAttribute("ic-peek-open", true)
    else
        if not (self:GetAttribute("ic-peek-shown") or self:GetAttribute("ic-peek-open")) then return false end
        self:SetAttribute("ic-peek-shown", nil)
        self:SetAttribute("ic-peek-open", nil)
    end
    self:SetAttribute("useOnKeyDown", down and true or false)
    self:SetAttribute("macrotext", macro)
    self:SetAttribute("type", "macro")
]]
hold:SetAttribute("ic-peek", PeekMap.SNIPPET)
hold:SetScript("PostClick", function(self, button, down)
    if PeekMap.debug then
        IF.Print("peek: hotkey " .. (down and "down" or "up") .. ", ran: " .. tostring(self:GetAttribute("type"))
            .. ", map open: " .. tostring(WorldMapFrame and WorldMapFrame:IsShown()))
    end
    PeekMap.Opened()
end)

---------------------------------------------------------------------------
-- The hotkey: a button, or one held + one pressed ("PADLSHOULDER+PADDUP"),
-- taken over: an override binding on the hold button. Out of combat.
---------------------------------------------------------------------------
function PeekMap.IsPeeking()
    return peeking
end

function PeekMap.Key()
    return IF.db and IF.db.peekMapKey
end

local pending = false

function PeekMap.Apply()
    if IF.InCombat() then
        pending = true
        return
    end
    pending = false
    local macro = IF.Touch and IF.Touch.Macro("map")
    if WorldMapFrame then hold:SetFrameRef("map", WorldMapFrame) end
    hold:SetAttribute("ic-macro", macro)
    ClearOverrideBindings(hold)
    local key = PeekMap.Key() and IF.Binds.KeyOf(PeekMap.Key())
    -- (kept while the map has the gamepad: its release closes it)
    if key and macro then SetOverrideBindingClick(hold, true, key, hold:GetName(), "LeftButton") end
end

function PeekMap.SetKey(key)
    IF.db.peekMapKey = key
    PeekMap.Apply()
end

IF.OnLogin(PeekMap.Apply)

-- /if peek: what the hotkey is bound to and what a press does (each press
-- printed until /if peek again)
function PeekMap.Probe()
    PeekMap.debug = not PeekMap.debug
    local spec = PeekMap.Key()
    local key = spec and IF.Binds.KeyOf(spec)
    IF.Print("peek: hotkey " .. tostring(spec) .. " -> key " .. tostring(key)
        .. ", bound to: " .. tostring(key and GetBindingAction(key, true)))
    IF.Print("peek: macro " .. tostring(hold:GetAttribute("ic-macro")) .. ", map frame: "
        .. tostring(WorldMapFrame ~= nil) .. ", map scroll: " .. tostring(WorldMapFrame and WorldMapFrame.ScrollContainer ~= nil)
        .. ", in combat: " .. tostring(IF.InCombat()) .. ", pending: " .. tostring(pending))
    IF.Print("peek: press printing " .. (PeekMap.debug and "on" or "off"))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then PeekMap.Apply() end
end)

-- Its binding, on the Controller tab (Binds.lua)
local B = IF.Binds
B.Add({
    id = "peekmap", label = "Peek map", group = "Other", tab = "controller",
    icon = IF.TEX .. "ic_map_peek", context = "world", order = 31,
    tip = "Held: the game's Map & Quest Log shows with only its map, see-through (placed and sized in"
        .. " the Map tab); let go and it closes. Works in combat. Takes the press over while bound, and"
        .. " while held the map has the controller, as it always does. A touchpad corner can open it too"
        .. " (its Interface list).",
    -- (an override binding: a press one can go on)
    accepts = function(spec)
        local _, _, double = B.Parse(spec)
        return not double and B.KeyOf(spec) ~= nil
    end,
    specs = function() return B.One(IF.PeekMap.Key()) end,
    set = function(spec) IF.PeekMap.SetKey(spec) end,
})
