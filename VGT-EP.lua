local MODULE_NAME = "VGT-EP"
local MY_EPDB = {}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local Increment = function(value, i)
	if (value == nil) then
		return i
	end
	return value + i
end

-- Create a list of unique players sorted alphabetically that were found in the EPDB
--	timeframeInDays: default 7, controls how long ago to look for records in the EPDB
-- 	includeTests: default false, controls whether or not test records are included
local ConstructPlayerTableFromHistory = function(timeframeInDays, includeTests)
	if (timeframeInDays == nil or timeframeInDays <= 0) then
		timeframeInDays = 7
	end
	local timeframeInSeconds = timeframeInDays * 86400
	local currentTime = GetServerTime()
	local playersTable = {}
	local playerName = UnitName("player")

	-- Loop through each record in the EPDB
	for key,value in pairs(VGT_EPDB) do
		local timestamp, dungeon, boss = strsplit(":", value)

		-- Ignore records that are past the timeframe
		if (timestamp + timeframeInSeconds > currentTime) then
			local _, uid, guild, players = strsplit(":", key)
			local myGuildName = GetMyGuildName()

			-- Ignore records that don't match the player's guild name
			if (myGuildName ~= nil and myGuildName == guild) then

				-- Ignore records which don't have a valid uid
				if (uid ~= nil) then
					local localPlayersTable = {}

					-- Ignore test records if the flag is false
					if (string.match(uid, "TEST")) then
						if (includeTests) then
							localPlayersTable = {strsplit(",", players)}
						end
					else
						localPlayersTable = {strsplit(",", players)}
					end

					playersTable = TableJoinToArray(playersTable, localPlayersTable)
				end
			end
		end
	end
	return playersTable
end

-- Check if the local EPDB already has the
local CheckLocalDBForBossKill = function(key, value)
	if (MY_EPDB[key] == nil) then
		MY_EPDB[key] = value
	else
		Log(LOG_LEVEL.WARN, "!! YOUR KILL WAS NOT RECORDED !!")
		Log(LOG_LEVEL.WARN, "WARN - record %s already exists in local DB. Contact an officer for assistance.", key)
		Log(LOG_LEVEL.WARN, "!! YOUR KILL WAS NOT RECORDED !!")
	end
end

local SaveAndSendBossKill = function(key, value)
	local record = VGT_EPDB[key]
	if (record == nil or record == "") then
		VGT_EPDB[key] = value
		local message = format("%s;%s", key, value)
		Log(LOG_LEVEL.DEBUG, "saving %s and sending to guild.", message)
		ACE:SendCommMessage(MODULE_NAME, message, "GUILD")
	else
		Log(LOG_LEVEL.TRACE, "record %s already exists in DB before it could be saved.", message)
	end
end

local TimeStampToDaysFromNow = function(timestamp)
	return (GetServerTime() - timestamp) / (60 * 60 * 24)
end

local withinDays = function(timestamp, days)
	local daysSinceTimestamp = TimeStampToDaysFromNow(timestamp)
	if (daysSinceTimestamp > -0.01 and daysSinceTimestamp < days) then
		return true
	end
	return false
end

local ValidateTime = function(timestamp)
	if (withinDays(timestamp, 14)) then
		return true
	end
	Log(LOG_LEVEL.DEBUG, "invalid timestamp %s", TimeStampToDaysFromNow(timestamp))
	return false
end

local ValidateDungeon = function(dungeon)
	if (dungeon == "TestDungeon" or TableContains(VGT.dungeons, dungeon)) then
		return true
	end
	Log(LOG_LEVEL.DEBUG, "invalid dungeon %s", dungeon)
	return false
end

local ValidateBoss = function(boss)
	if (boss == "TestBoss" or TableContains(VGT.bosses, boss)) then
		return true
	end
	Log(LOG_LEVEL.DEBUG, "invalid boss %s", boss)
	return false
end

local ValidateGuild = function(guild)
	local myGuildName = GetMyGuildName()
	if (myGuildName ~= nil and myGuildName == guild) then
		return true
	end
	Log(LOG_LEVEL.DEBUG, "invalid guild %s", guild)
	return false
end

local GuildMembersSet = function()
	local guildMembers = {}
	if (IsInGuild()) then
		local numTotalMembers = GetNumGuildMembers()
		for i=1,numTotalMembers do
			local fullname = GetGuildRosterInfo(i)
			local name = strsplit("-", fullname)
			guildMembers[name] = true
		end
	end
	return guildMembers
end

local ValidatePlayers = function(guild, players)
	local playersArray = {strsplit(",", players)}
	local playersSet = ArrayToSet(playersArray)
	if (SubsetCount(playersSet, GuildMembersSet()) > 1) then
		return true
	end
	Log(LOG_LEVEL.DEBUG, "invalid group %s", players)
	return false
end

local ValidateRecord = function(key, value)
	if (key ~= nil and key ~= "" and value ~= nil and value ~= "") then
		local module, creatureUID, guildName, players = strsplit(":", key)
		local timestamp, dungeonName, bossName = strsplit(":", value)
		if (ValidateGuild(guildName) and
			ValidatePlayers(guildName, players) and
			ValidateTime(timestamp) and
			ValidateDungeon(dungeonName) and
			ValidateBoss(bossName)) then
			return true
		end
	end
	return false
end

CleanDatabase = function()
	for k,v in pairs(VGT_EPDB) do
		if (not ValidateRecord(k, v)) then
			Log(LOG_LEVEL.DEBUG, "record %s removed for being invalid", k)
			VGT_EPDB[k] = nil
		end
	end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

-- Print the list of players who did dungeons within the timeframe
--	timeframeInDays: default 7, controls how long ago to look for records in the EPDB
-- 	includeTests: default false, controls whether or not test records are included
PrintDungeonList = function(timeframeInDays, includeTests)
	local str = TableToString(ConstructPlayerTableFromHistory(timeframeInDays, includeTests), "", false, true, true)
	VGT_DUNGEONS_FRAME:Show();
	VGT_DUNGEONS_FRAME_SCROLL:Show()
	VGT_DUNGEONS_FRAME_TEXT:Show()
	VGT_DUNGEONS_FRAME_TEXT:SetText(str)
	VGT_DUNGEONS_FRAME_TEXT:HighlightText()

	VGT_DUNGEONS_FRAME_BUTTON:SetScript("OnClick", function(self) VGT_DUNGEONS_FRAME:Hide() end)
	VGT_DUNGEONS_FRAME_TEXT:SetScript("OnEscapePressed", function(self) self:GetParent():GetParent():Hide() end)
end

HandleUnitDeath = function(creatureUID, dungeonName, bossName)
	local timestamp = GetServerTime()
	Log(LOG_LEVEL.TRACE, "killed %s in %s.", bossName, dungeonName)
	local guildName = GetGuildInfo("player")
	local groupedGuildies = CheckGroupForGuildies()
	if (guildName ~= nil) then
		if (groupedGuildies ~= nil and next(groupedGuildies) ~= nil) then
			local playerName = UnitName("player")
			table.insert(groupedGuildies, playerName)
			local groupedGuildiesStr = TableToString(groupedGuildies, ",", false, true)
			Log(LOG_LEVEL.INFO, "killed %s in %s as a guild with %s", bossName, dungeonName, groupedGuildiesStr)
			local key = format("%s:%s:%s:%s", MODULE_NAME, creatureUID, guildName, groupedGuildiesStr)
			local value = format("%s:%s:%s", timestamp, dungeonName, bossName)
			CheckLocalDBForBossKill(key, value)
			SaveAndSendBossKill(key, value)
		else
			Log(LOG_LEVEL.DEBUG, "skipping boss kill event because you are not in a group with any guild members of %s", guildName)
		end
	else
		Log(LOG_LEVEL.DEBUG, "skipping boss kill event because you are not in a guild")
	end
end

HandleCombatLogEvent = function()
	local cTime, cEvent, _, _, _, _, _, cUID, _, _, _ = CombatLogGetCurrentEventInfo()
	--TODO: possibly use cTime instead of GetServerTime(), if it's accurate across clients
	local _, cTypeID, cInstanceUID, cInstanceID, cUnitUID, cUnitID, hex = strsplit("-", cUID)
	if (cEvent == "UNIT_DIED") then
		local creatureUID = StringAppend(cTypeID, cInstanceUID, cInstanceID, cUnitUID, cUnitID, hex)
		local dungeonName = VGT.dungeons[tonumber(cInstanceID)]
		local bossName = VGT.bosses[tonumber(cUnitID)]
		if (creatureUID ~= nil and dungeonName ~= nil and bossName ~= nil) then
			HandleUnitDeath(creatureUID, dungeonName, bossName)
		end
	end
end

function GetGuildIndexForUnit(player)
	local numTotalMembers, _, _ = GetNumGuildMembers()
	for i=1,numTotalMembers do
		fullname, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
		local name = strsplit("-", fullname)
		if (player == name) then
			return i
		end
	end
	return nil
end

function HandleEPMessageReceivedEvent(prefix, message, distribution, sender)
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

	if (distribution == "GUILD") then
		if (event == "SYNCHRONIZATION_REQUEST") then
			for k,v in pairs(VGT_EPDB) do
				local message = format("%s;%s", k, v)
				Log(LOG_LEVEL.TRACE, "sending %s to %s for %s:SYNCHRONIZATION_REQUEST.", message, sender, MODULE_NAME)
				ACE:SendCommMessage(MODULE_NAME, message, "GUILD", nil, "BULK")
			end
		else
			local key, value = strsplit(";", message)
			local record = VGT_EPDB[key]
			if (record == nil or record == "") then
				if (ValidateRecord(key, value)) then
					Log(LOG_LEVEL.DEBUG, "saving record %s from %s.", message, sender)
					VGT_EPDB[key] = value
				else
					Log(LOG_LEVEL.TRACE, "record %s from %s is invalid to recieve.", value, sender)
				end
			else
				Log(LOG_LEVEL.TRACE, "record %s from %s already exists in DB.", message, sender)
			end
		end
	end
end

function VGT_EP_Initialize()
	if (VGT_EPDB == nil) then
		VGT_EPDB = {}
	end
	CleanDatabase()
	ACE:RegisterComm(MODULE_NAME, HandleEPMessageReceivedEvent)
	ACE:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST", "GUILD")
end
