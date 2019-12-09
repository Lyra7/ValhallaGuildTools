ADDON_NAME, VGT = ...
VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
FRAME = CreateFrame("Frame")

-- ############################################################
-- ##### LIBRARIES ############################################
-- ############################################################

ACE = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceComm-3.0")

-- ############################################################
-- ##### CONSTANTS ############################################
-- ############################################################

local MODULE_NAME = "VGT-Core"

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local HandleInstanceChangeEvent = function()
	local _, instanceType, _, _, _, _, _, instanceID, _, _ = GetInstanceInfo()
	if (instanceType == "party" or instanceType == "raid") then
		local dungeonName = VGT.dungeons[tonumber(instanceID)]
		if (dungeonName ~= nil) then
			Log(LOG_LEVEL.INFO, "Started logging for %s, goodluck!", dungeonName)
			FRAME:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		else
			Log(LOG_LEVEL.DEBUG, "Entered %s(%s) but it is not a tracked dungeon.", dungeonName, instanceID)
		end
	else
		FRAME:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function StringAppend(...)
	local args = {...}
	local str = ""
	for _,v in ipairs(args) do
		if (v ~= nil) then
			str = str..tostring(v)
		end
	end
	return str
end

function TableJoinToArray(a, b)
	local nt = {}
	for _,v in pairs(a) do
		nt[v] = v
	end
	for _,v in pairs(b) do
		nt[v] = v
	end
	return nt
end

function TableToString(t, d, keys, sort, line)
	local s = ""

	if (t == nil) then
		return s
	end

	if (d == nil) then
		d = ","
	end

	if (sort == true) then
		table.sort(t)
		local nt = {}
		for _,v in pairs(t) do
			table.insert(nt, v)
		end
		table.sort(nt)
		t = nt
	end

	for _,v in pairs(t) do
		s = s..d
		if (type(v) == "table") then
			s = s..TableToString(v, d, keys, sort, line)
		else
			if (line) then
				s = s..v.."\n"
			else
				s = s..v
			end
		end
	end

	if (d ~= nil and d ~= "") then
		return string.sub(s, 2)
	else
		return s
	end
end

function TableContains(t, m)
	if (t == nil) then
		return false
	end

	for _,v in pairs(t) do
		if (v == m) then
			return true
		end
	end

	return false
end

function RandomUUID()
    local template ='xxxxxxxx'
    return string.gsub(template, '[xy]', function (c) local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb) return string.format('%x', v) end)
end

function GetMyGuildName()
	if (IsInGuild()) then
		return GetGuildInfo("player")
	else
		return nil
	end
end

function IsInMyGuild(playerName)
	if (playerName == nil) then
		return false
	end

	local playerGuildName = GetGuildInfo(playerName)
	if (playerGuildName == nil) then
		return false
	end

	local myGuildName = GetMyGuildName()
	if (myGuildName == nil) then
		return false
	end

	if (myGuildName == playerGuildName) then
		return true
	end

	return false
end

function CheckGroupForGuildies()
	if (IsInGroup() ~= true) then
		return nil
	end

	local groupMembers = GetHomePartyInfo()
	local guildGroupMembers = {}
	local p = 0
	for i = 0, GetNumGroupMembers() do
		local groupMember = groupMembers[i]
		if (IsInMyGuild(groupMember)) then
			guildGroupMembers[p] = groupMember
			Log(LOG_LEVEL.TRACE, "%s is in my guild", guildGroupMembers[p])
			p = p + 1
		end
	end
	return guildGroupMembers
end

function PrintAbout()
	Log(LOG_LEVEL.SYSTEM, "installed version: %s", VERSION)
end

function PrintHelp()
	Log(LOG_LEVEL.SYSTEM, "Command List:")
	Log(LOG_LEVEL.SYSTEM, "/vgt about - version information")
	Log(LOG_LEVEL.SYSTEM, "/vgt loglevel <%s> - set the addon verbosity (%s)", TableToString(LOG_LEVELS, "|"), LOG_LEVELS[logLevel])
	Log(LOG_LEVEL.SYSTEM, "/vgt dungeontest - sends a dungeon kill test event")
	Log(LOG_LEVEL.SYSTEM, "/vgt dungeons [timeframeInDays:7] - list of players that killed a dungeon boss within the timeframe")
end

local hasNotifiedNewVersion = false
function HandleCoreMessageReceivedEvent(prefix, message, _, sender)
	if (prefix ~= MODULE_NAME) then
		return
	end

	local module, event = strsplit(":", message)
	if (module ~= MODULE_NAME) then
		return
	end

	local playerName = UnitName("player")
	if (sender == playerName) then
		return
	end

	if (event == "SYNCHRONIZATION_REQUEST") then
		local message = VERSION
		Log(LOG_LEVEL.TRACE, "sending %s to %s for %s:SYNCHRONIZATION_REQUEST.", message, sender, MODULE_NAME)
		ACE:SendCommMessage(MODULE_NAME, message, "WHISPER", sender, "ALERT")
	else
		local version = tonumber(message)
		local myVersion = tonumber(VERSION)
		if (hasNotifiedNewVersion == false and addonVersion > tonumber(VERSION)) then
			hasNotifiedNewVersion = true
			Log(LOG_LEVEL.WARN, "there is a newer version of this addon [%s]", version)
		end
	end
end

local function DefaultOrSet(default, value1, value2)
	if (value1 == nil or value1 == value2) then
		return default
	end
	return value1
end

local loaded = false
local entered = false
local function OnEvent(_, event)
	if (not loaded and event == "ADDON_LOADED") then
		if (VGT_CONFIGURATION == nil) then
			VGT_CONFIGURATION = {
				logLevel = LOG.LEVELS[LOG_LEVEL.INFO]
			}
		end
		logLevel = DefaultOrSet(LOG.LEVELS[LOG_LEVEL.INFO], VGT_CONFIGURATION.logLevel, 0)

		ACE:RegisterComm(MODULE_NAME, HandleCoreMessageReceivedEvent)
		VGT_EP_Initialize()
		VGT_Douse_Initialize()

		loaded = true
	end

	if (event == "PLAYER_ENTERING_WORLD") then
		HandleInstanceChangeEvent(event)

		if (not entered) then
			ACE:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST", "GUILD")
			Log(LOG_LEVEL.TRACE, "initialized with version %s", VERSION)
			entered = true
		end
	end

	if (loaded and event == "COMBAT_LOG_EVENT_UNFILTERED") then
		HandleCombatLogEvent(event)
	end

	if (loaded and event == "PLAYER_LOGOUT") then
		VGT_CONFIGURATION.logLevel = logLevel
	end
end
FRAME:RegisterEvent("ADDON_LOADED")
FRAME:RegisterEvent("PLAYER_ENTERING_WORLD")
FRAME:RegisterEvent("PLAYER_LOGOUT")
FRAME:SetScript("OnEvent", OnEvent)

-- ############################################################
-- ##### SLASH COMMANDS #######################################
-- ############################################################

SLASH_VGT1 = "/vgt"
SlashCmdList["VGT"] = function(message)
	local command, arg1 = strsplit(" ", message)
	if (command == "" or command == "help") then
		PrintHelp()
		return
	end

	if (command == "about") then
		PrintAbout()
	elseif (command == "loglevel") then
		SetLogLevel(arg1)
	elseif (command == "dungeontest") then
		HandleUnitDeath("TEST"..RandomUUID(), "TestDungeon", "TestBoss")
	elseif (command == "dungeons") then
		PrintDungeonList(tonumber(arg1), VGT.debug)
	elseif (command == "douse") then
		CheckForDouse()
	else
		Log(LOG_LEVEL.ERROR, "invalid command - type `/vgt help` for a list of commands")
	end
end
