local MODULE_NAME = "VGT-EP"
local MY_EPDB = {}

-- Create a list of unique players sorted alphabetically that were found in the EPDB
--	timeframeInDays: default 7, controls how long ago to look for records in the EPDB
-- 	includeTests: true/false controls whether or not test records are included
local function ConstructPlayerTableFromHistory(timeframeInDays, includeTests)
	if (timeframeInDays == nil or timeframeInDays <= 0) then
		timeframeInDays = 7
	end
	local timeframeInSeconds = timeframeInDays * 86400
	local currentTime = GetServerTime()
	local playersTable = {}

	-- Loop through each record in the EPDB
	for key,value in pairs(VGT_EPDB) do
		local timestamp, _, _ = strsplit(":", value)

		-- Ignore records that are past the timeframe
		if (timestamp + timeframeInSeconds > currentTime) then
			local _, uid, guild, players = strsplit(":", key)
			local myGuildName = GetMyGuildName()

			-- Ignore records that don't match the player's guild name
			if (myGuildName ~= nil and myGuildName == guild) then

				-- Ignore records which don't have a valid uid
				if (uid ~= nil and string.match(uid, "TEST")) then

					-- Ignore test records if the flag is true
					if (includeTests == true) then
						playersTable = TableJoinToArray(playersTable, {strsplit(",", players)})
					end
				else
					playersTable = TableJoinToArray(playersTable, {strsplit(",", players)})
				end
			end
		end
	end
	return playersTable
end

function PrintDungeonList(timeframeInDays, includeTests)
	LOG(format("[%s] %s", MODULE_NAME, TableToString(ConstructPlayerTableFromHistory(timeframeInDays, includeTests), ",", true)))
end

local function CheckLocalDBForBossKill(key, value)
	if (MY_EPDB[key] == nil) then
		MY_EPDB[key] = value
	else
		LOG(format("[%s] !! YOUR KILL WAS NOT RECORDED !!", MODULE_NAME))
		LOG(format("[%s] ERROR - record %s already exists in local DB. Contact an officer for assistance.", MODULE_NAME, key))
		LOG(format("[%s] !! YOUR KILL WAS NOT RECORDED !!", MODULE_NAME))
	end
end

local function SaveAndSendBossKill(key, value)
	local record = VGT_EPDB[key]
	if (record == nil or record == "") then
		VGT_EPDB[key] = value
		local message = format("%s;%s", key, value)
		LOG(format("[%s] saving %s and sending to guild.", MODULE_NAME, message), true)
		ACE:SendCommMessage(MODULE_NAME, message, "GUILD")
	else
		LOG(format("[%s] record %s already exists in DB before it could be saved.", MODULE_NAME, message), true)
	end
end

function HandleUnitDeath(creatureUID, dungeonName, bossName)
	local timestamp = GetServerTime()
	LOG(format("[%s] killed %s in %s.", MODULE_NAME, bossName, dungeonName), true)
	local guildName = GetGuildInfo("player")
	local groupedGuildies = CheckGroupForGuildies()
	if (guildName ~= nil and next(groupedGuildies) ~= nil) then
		local playerName = UnitName("player")
		table.insert(groupedGuildies, playerName)
		local groupedGuildiesStr = TableToString(groupedGuildies, ",", true)
		LOG(format("[%s] killed %s in %s as a guild with %s", MODULE_NAME, bossName, dungeonName, groupedGuildiesStr))
		local key = format("%s:%s:%s:%s", MODULE_NAME, creatureUID, guildName, groupedGuildiesStr)
		local value = format("%s:%s:%s", timestamp, dungeonName, bossName)
		CheckLocalDBForBossKill(key, value)
		SaveAndSendBossKill(key, value)
	end
end

-- ############################################################
-- ##### EVENTS ###############################################
-- ############################################################

local function HandleInstanceChangeEvent(event)
	local iName, iType, _, _, _, _, _, iID, _, _ = GetInstanceInfo()
	if (iType == "party" or iType == "raid") then
		FRAME:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		FRAME:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

local function HandleCombatLogEvent(event)
	local cTime, cEvent, _, _, _, _, _, cUID, cName, _, _ = CombatLogGetCurrentEventInfo()
	local s, cTypeID, cInstanceUID, cInstanceID, cUnitUID, cUnitID, hex = strsplit("-", cUID)
	if (cEvent == "UNIT_DIED") then
		local creatureUID = StringAppend(cTypeID, cInstanceUID, cInstanceID, cUnitUID, cUnitID, hex)
		local dungeonName = VGT.dungeons[tonumber(cInstanceID)]
		local bossName = VGT.bosses[tonumber(cUnitID)]
		if (creatureUID ~= nil and dungeonName ~= nil and bossName ~= nil) then
			HandleUnitDeath(creatureUID, dungeonName, bossName)
		end
	end
end

local function HandleMessageReceivedEvent(prefix, message, distribution, sender)
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
		for k,v in pairs(VGT_EPDB) do
			_, _, guildNameFromHistory, _ = strsplit(":", k)
			local guildName = GetMyGuildName()
			if (guildName ~= nil and guildName == guildNameFromHistory) then
				local message = format("%s;%s", k, v)
				LOG(format("[%s] sending %s to %s for SYNCHRONIZATION_REQUEST.", MODULE_NAME, message, sender), true)
				ACE:SendCommMessage(MODULE_NAME, message, "WHISPER", sender, "BULK")
			end
		end
	else
		local key, value = strsplit(";", message)
		local record = VGT_EPDB[key]
		if (record == nil or record == "") then
			LOG(format("[%s] saving record %s from %s.", MODULE_NAME, message, sender), true)
			VGT_EPDB[key] = value
		else
			LOG(format("[%s] record %s from %s already exists in DB.", MODULE_NAME, message, sender), true)
		end
	end
end

local initialized = false
local function OnEvent(self, event, arg1, arg2, arg3)
	if (not initialized and event == "ADDON_LOADED") then
		initialized = true
		if (VGT_EPDB == nil) then
			VGT_EPDB = {}
		end
		ACE:RegisterComm(MODULE_NAME, HandleMessageReceivedEvent)
		ACE:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST", "GUILD")
	end

	if (event == "PLAYER_ENTERING_WORLD") then
		HandleInstanceChangeEvent(event)
	end

	if (initialized and event == "COMBAT_LOG_EVENT_UNFILTERED") then
		HandleCombatLogEvent(event)
	end
end

FRAME:RegisterEvent("ADDON_LOADED")
FRAME:RegisterEvent("PLAYER_ENTERING_WORLD")
FRAME:SetScript("OnEvent", OnEvent)
