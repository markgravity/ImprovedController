-- Improved Forever: Quest Tracker (formerly the Improved Quest Tracker
-- addon). Sort options for the game's own quest tracker (Sort.lua), a sound
-- when a tracked quest's objective completes (ObjectiveSound.lua), a sort
-- menu on the tracker (Menu.lua, Dropdown.lua), set up in its tab
-- (QuestTrackerEditor.lua). Its files share this addon's own table (IQT),
-- left to the other modules as IF.QuestTracker.
local addonName, IQT = ...
local IF = ImprovedForever

IQT.name = addonName
IF.QuestTracker = IQT
IF.AddModule({ key = "quests", label = "Quest Tracker", icon = IF.TEX .. "ic_mod_quests", addon = addonName })

-- Sort modes (nil/"none" = leave the native tracker sort alone)
IQT.SORTS = {
	{ id = "none",          text = "Off (Blizzard sort)" },
	{ id = "zone",          text = "by Zone" },
	{ id = "level",         text = "by Level" },
	{ id = "levelReversed", text = "by Level (reversed)" },
	{ id = "title",         text = "by Title" },
	{ id = "distance",      text = "by Distance" },
}

IQT.COMPLETED = {
	{ id = "none",   text = "Keep in place" },
	{ id = "top",    text = "Completed at top" },
	{ id = "bottom", text = "Completed at bottom" },
}

local DEFAULTS = {
	sort = "none",
	sortCompleted = "none",
	currentZoneFirst = true,
	objectiveSound = true,
	focusFirst = true,
}

-- Per character, in Improved Forever's own (IF.charDB.questTracker)
function IQT.Settings()
	IF.charDB.questTracker = IF.charDB.questTracker or {}
	local db = IF.charDB.questTracker
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then
			db[k] = v
		end
	end
	return db
end

function IQT.Print(msg)
	IF.Print("Quest Tracker: " .. msg)
end

function IQT.IsActive()
	local db = IQT.Settings()
	return db.sort ~= "none" or db.sortCompleted ~= "none" or db.focusFirst
end

-- The focused (super-tracked) quest: C_SuperTrack on Forever, a global on MoP
function IQT.FocusedQuestID()
	local id
	if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
		id = C_SuperTrack.GetSuperTrackedQuestID()
	elseif GetSuperTrackedQuestID then
		id = GetSuperTrackedQuestID()
	end
	return id ~= 0 and id or nil
end

local frame = CreateFrame("Frame")
IQT.eventFrame = frame

-- (the core says which call was blocked; here the reordering stops)
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

-- At login (the saved variables ready): which tracker this client has
local function Login()
	local self = frame
	IQT.Settings()
	if WatchFrame and ShiftQuestWatches then
		IQT.backend = "watchframe"
	elseif C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex and C_QuestLog.AddQuestWatch then
		IQT.backend = "tracker"
	else
		IQT.Print("No supported quest tracker found, addon disabled.")
		return
	end
	-- Distance sort needs the native quest POI distance (Forever); the
	-- WatchFrame backend can't refresh order as you move either
	if IQT.backend ~= "tracker" or not C_QuestLog.GetDistanceSqToQuest then
		for i, entry in ipairs(IQT.SORTS) do
			if entry.id == "distance" then
				tremove(IQT.SORTS, i)
				break
			end
		end
		if IQT.Settings().sort == "distance" then
			IQT.Settings().sort = "none"
		end
	end
	IQT.InitSort()
	IQT.InitMenu()
	IQT.InitObjectiveSound()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- Focus changes: the event name differs per client, so skip unknown ones
	for _, focusEvent in ipairs({ "SUPER_TRACKING_CHANGED", "SUPER_TRACKED_QUEST_CHANGED" }) do
		pcall(self.RegisterEvent, self, focusEvent)
	end
	IQT.RequestSort()
end
IF.OnLogin(Login)

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		local addon = ...
		if addon == addonName then
			IQT.forbidden = true
			IQT.Print("reordering stopped until /reload.")
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		IQT.OnCombatEnd()
	else
		IQT.RequestSort()
	end
end)
