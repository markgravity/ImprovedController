-- Reading the minimap: what its dots are (herbs, ore, quest givers, party
-- members...), and where, without a mouse. Gather.lua builds the node list,
-- the follow arrow and the alerts on it.
--
-- The game draws the minimap's dots itself and tells addons only the names
-- under the minimap's hover point (C_TooltipInfo.GetMinimapMouseover, what
-- its own tooltip shows). Forever's minimap can be told where that point is
-- (Minimap:UpdateMouseoverAtPoint, in screen pixels, for the controller's
-- soft cursor), and answers at once. So a grid of points over the minimap is
-- read in one go; the points that read the same name side by side are one
-- dot, and their middle is where it is.
local _, IC = ...

local N = {}
IC.NodeScan = N

N.step = 6           -- spacing of the points read, in minimap units
N.debug = false      -- print each scan's dots

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function N.Facing()
    local f = GetPlayerFacing and GetPlayerFacing()
    if type(f) ~= "number" or Secret(f) then return nil end
    return f
end

function N.Supported()
    return Minimap and Minimap.UpdateMouseoverAtPoint and C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover
        and true or false
end

---------------------------------------------------------------------------
-- Herbs and ore: the skill each needs (Classic and Burning Crusade, the
-- names as the minimap shows them in English)
---------------------------------------------------------------------------
local HERBS = {
    ["Peacebloom"] = 1, ["Silverleaf"] = 1, ["Bloodthistle"] = 1, ["Earthroot"] = 15, ["Mageroyal"] = 50,
    ["Briarthorn"] = 70, ["Stranglekelp"] = 85, ["Bruiseweed"] = 100, ["Wild Steelbloom"] = 115,
    ["Grave Moss"] = 120, ["Kingsblood"] = 125, ["Liferoot"] = 150, ["Fadeleaf"] = 160, ["Goldthorn"] = 170,
    ["Khadgar's Whisker"] = 185, ["Wintersbite"] = 195, ["Firebloom"] = 205, ["Purple Lotus"] = 210,
    ["Arthas' Tears"] = 220, ["Sungrass"] = 230, ["Blindweed"] = 235, ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250, ["Golden Sansam"] = 260, ["Dreamfoil"] = 270, ["Mountain Silversage"] = 280,
    ["Plaguebloom"] = 285, ["Icecap"] = 290, ["Bloodvine"] = 300, ["Black Lotus"] = 300, ["Felweed"] = 300,
    ["Dreaming Glory"] = 315, ["Ragveil"] = 325, ["Terocone"] = 325, ["Flame Cap"] = 335,
    ["Ancient Lichen"] = 340, ["Netherbloom"] = 350, ["Netherdust Bush"] = 350, ["Nightmare Vine"] = 365,
    ["Mana Thistle"] = 375,
}
local ORES = {
    ["Copper Vein"] = 1, ["Tin Vein"] = 65, ["Incendicite Mineral Vein"] = 65, ["Silver Vein"] = 75,
    ["Ooze Covered Silver Vein"] = 75, ["Lesser Bloodstone Deposit"] = 75, ["Iron Deposit"] = 125,
    ["Indurium Mineral Vein"] = 150, ["Gold Vein"] = 155, ["Ooze Covered Gold Vein"] = 155,
    ["Mithril Deposit"] = 175, ["Ooze Covered Mithril Deposit"] = 175, ["Truesilver Deposit"] = 230,
    ["Ooze Covered Truesilver Deposit"] = 230, ["Dark Iron Deposit"] = 230, ["Small Thorium Vein"] = 245,
    ["Ooze Covered Thorium Vein"] = 245, ["Rich Thorium Vein"] = 275, ["Ooze Covered Rich Thorium Vein"] = 275,
    ["Hakkari Thorium Vein"] = 275, ["Nethercite Deposit"] = 275, ["Fel Iron Deposit"] = 300,
    ["Small Obsidian Chunk"] = 305, ["Large Obsidian Chunk"] = 305, ["Adamantite Deposit"] = 325,
    ["Rich Adamantite Deposit"] = 350, ["Khorium Vein"] = 375,
}
local SKILL_LINE = { herb = 182, ore = 186 }    -- Herbalism, Mining
local SKILL_NAME = { herb = "Herbalism", ore = "Mining" }

-- "herb" / "ore" and the skill it needs, or nil
function N.Kind(name)
    if HERBS[name] then return "herb", HERBS[name] end
    if ORES[name] then return "ore", ORES[name] end
end

-- The player's skill in a kind's profession (nil: not learnt)
local skills, bonuses
local function ReadSkills()
    skills, bonuses = {}, {}
    if not (GetProfessions and GetProfessionInfo) then return end
    for _, index in pairs({ GetProfessions() }) do
        local _, _, rank, _, _, _, line, modifier = GetProfessionInfo(index)
        for kind, id in pairs(SKILL_LINE) do
            if line == id then skills[kind], bonuses[kind] = rank, modifier end
        end
    end
end

function N.Skill(kind)
    if not skills then ReadSkills() end
    return skills[kind]
end

-- Its racial / item bonus, included in N.Skill (nil: none reported)
function N.SkillBonus(kind)
    if not skills then ReadSkills() end
    return bonuses[kind]
end

function N.SkillName(kind)
    return SKILL_NAME[kind]
end

-- How a node stands against the player's skill, as the game colours a
-- profession's recipes: red can't gather it, orange always gives a skill
-- point, yellow mostly, green rarely, grey never. nil: not a herb or ore,
-- or its profession not learnt
N.STATES = { "orange", "yellow", "green", "grey", "red" }
N.COLORS = {
    red = { 1, 0.1, 0.1 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 },
    green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 },
}
function N.State(name)
    local kind, need = N.Kind(name)
    local skill = kind and N.Skill(kind)
    if not skill then return nil end
    if skill < need then return "red" end
    if skill < need + 25 then return "orange" end
    if skill < need + 50 then return "yellow" end
    if skill < need + 100 then return "green" end
    return "grey"
end

function N.Color(name)
    local c = N.COLORS[N.State(name) or ""]
    if c then return c[1], c[2], c[3] end
    return 1, 1, 1
end

local events = CreateFrame("Frame")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("CHAT_MSG_SKILL")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() skills = nil end)

---------------------------------------------------------------------------
-- The scan
---------------------------------------------------------------------------
-- The points: inside the minimap's circle (and within `reach` of cx, cy if
-- given), N.step apart, every other row shifted half a step (no gaps a dot
-- can sit in)
local function Points(radius, cx, cy, reach)
    local grid = {}
    local step = N.step
    local rowStep = step * 0.866
    local r = radius - 2
    local rows = math.floor(r / rowStep)
    local n = math.floor(r / step) + 1
    for j = -rows, rows do
        local shift = (j % 2) * step / 2
        for i = -n, n do
            local x, y = i * step + shift, j * rowStep
            if x * x + y * y <= r * r and (not cx or (x - cx) ^ 2 + (y - cy) ^ 2 <= reach * reach) then
                grid[#grid + 1] = { x = x, y = y }
            end
        end
    end
    return grid
end

-- A tooltip line's own colour, as { r, g, b }, or nil
local function LineColor(line)
    local c = line.leftColor
    if type(c) ~= "table" then return nil end
    if c.GetRGB then return { c:GetRGB() } end
    if c.r then return { c.r, c.g, c.b } end
end

-- name -> how many dots of it are at a point (two dots of one herb under it
-- list it twice), and name -> the colour the game gives it. The player's
-- own arrow is left out.
local function NamesAt(px, py, me)
    local counts, colors = {}, {}
    Minimap:UpdateMouseoverAtPoint(px, py)
    local data = C_TooltipInfo.GetMinimapMouseover()
    for _, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and not Secret(text) then
            local lineColor = LineColor(line)
            for piece in text:gmatch("[^\n]+") do
                -- (a name may carry its own colour code)
                local hex = piece:match("|c%x%x(%x%x%x%x%x%x)")
                local name = strtrim((piece:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
                    :gsub("|A.-|a", "")))
                if name ~= "" and name ~= me then
                    counts[name] = (counts[name] or 0) + 1
                    if hex then
                        colors[name] = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
                            tonumber(hex:sub(5, 6), 16) / 255 }
                    else
                        colors[name] = colors[name] or lineColor
                    end
                end
            end
        end
    end
    return counts, colors
end

-- Points that read the same name next to each other are one dot: its
-- centre is their middle. Two dots of one herb closer than a dot's reach
-- read as one, with the name listed twice: counted.
local function Group(hits)
    local groups = {}
    local near = (N.step * 1.6) ^ 2
    for _, hit in ipairs(hits) do
        -- Every group of this name it touches joins into one
        local home
        for gi = #groups, 1, -1 do
            local g = groups[gi]
            if g.name == hit.name then
                local touches = false
                for _, other in ipairs(g) do
                    if (other.x - hit.x) ^ 2 + (other.y - hit.y) ^ 2 <= near then touches = true break end
                end
                if touches then
                    if home then
                        for _, other in ipairs(g) do home[#home + 1] = other end
                        home.count = math.max(home.count, g.count)
                        table.remove(groups, gi)
                    else
                        home = g
                    end
                end
            end
        end
        if not home then
            home = { name = hit.name, count = 0 }
            groups[#groups + 1] = home
        end
        home[#home + 1] = hit
        home.count = math.max(home.count, hit.count)
        home.color = home.color or hit.color
    end
    -- Minimap units to yards east / north of the player
    local radius = Minimap:GetWidth() / 2
    local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or radius
    local yards = view / radius
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local facing = get("rotateMinimap") == "1" and N.Facing() or 0
    local c, s = math.cos(facing), math.sin(facing)
    local found = {}
    for _, g in ipairs(groups) do
        local x, y = 0, 0
        for _, hit in ipairs(g) do
            x, y = x + hit.x, y + hit.y
        end
        x, y = x / #g, y / #g
        if N.debug then
            local kind, need = N.Kind(g.name)
            local col = g.color and string.format("%02x%02x%02x", g.color[1] * 255, g.color[2] * 255, g.color[3] * 255)
            IC.Print(string.format("  %s x%d: %d point(s) at %.0f,%.0f; game colour %s; needs %s, skill %s (bonus %s) -> %s",
                g.name, g.count, #g, x, y, col or "none", tostring(need), tostring(kind and N.Skill(kind)),
                tostring(kind and N.SkillBonus(kind)), tostring(N.State(g.name))))
        end
        local ex, ny = x * yards, y * yards
        -- A turning minimap has the way you face up
        found[#found + 1] = { name = g.name, count = g.count, x = x, y = y, gameColor = g.color,
            east = ex * c - ny * s, north = ex * s + ny * c }
    end
    return found
end

-- Reads the minimap (or only within `reach` minimap units of x, y), in
-- this frame. Each dot: name, count, x / y on the minimap, east / north in
-- yards from the player
function N.Scan(x, y, reach)
    if not N.Supported() or not Minimap:IsVisible() then return {} end
    local radius = Minimap:GetWidth() / 2
    local mx, my = Minimap:GetCenter()
    if not mx then return {} end
    local e = Minimap:GetEffectiveScale()
    local me = UnitName("player")
    if Minimap.SetUsingSoftCursor then Minimap:SetUsingSoftCursor(true) end
    local hits = {}
    for _, p in ipairs(Points(radius, x, y, reach)) do
        local counts, colors = NamesAt((mx + p.x) * e, (my + p.y) * e, me)
        for name, count in pairs(counts) do
            hits[#hits + 1] = { name = name, x = p.x, y = p.y, count = count, color = colors[name] }
        end
    end
    -- The hover point off the minimap again
    Minimap:UpdateMouseoverAtPoint(-10000, -10000)
    if Minimap.SetUsingSoftCursor then Minimap:SetUsingSoftCursor(false) end
    return Group(hits)
end

---------------------------------------------------------------------------
-- Where a dot is, from where the player stands and faces now
---------------------------------------------------------------------------
local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

function N.Yards(node)
    return math.sqrt(node.east ^ 2 + node.north ^ 2)
end

-- Its angle clockwise from the way the player faces (nil: facing unknown)
function N.Angle(node)
    local facing = N.Facing()
    if not facing then return nil end
    -- Bearing clockwise from north; facing turns anticlockwise from north
    return math.atan2(node.east, node.north) + facing
end

-- "2 o'clock", or a compass point when the facing is unknown
function N.Direction(node)
    local angle = N.Angle(node)
    if angle then
        local clock = math.floor(angle / (2 * math.pi) * 12 + 0.5) % 12
        return (clock == 0 and 12 or clock) .. " o'clock"
    end
    local bearing = math.atan2(node.east, node.north)
    return COMPASS[math.floor(bearing / (math.pi / 4) + 0.5) % 8 + 1]
end

function N.Distance(node)
    local yards = N.Yards(node)
    return yards < 3 and "here" or string.format("%d yd", yards + 0.5)
end
