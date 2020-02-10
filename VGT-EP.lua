local MODULE_NAME = "VGT-EP"
local MY_EPDB = {}
local CleanDatabase = CreateFrame("Frame");

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

-- Create a list of unique players sorted alphabetically that were found in the EPDB
--	timeframeInDays: default 7, controls how long ago to look for records in the EPDB
local constructPlayerTableFromHistory = function(timeframeInDays)
  if (timeframeInDays == nil or timeframeInDays <= 0) then
    timeframeInDays = 7
  end
  local timeframeInSeconds = timeframeInDays * 86400
  local currentTime = GetServerTime()
  local playersTable = {}
  local playerName = UnitName("player")

  -- Loop through each record in the EPDB
  for key, value in pairs(VGT_EPDB) do
    local timestamp, dungeon, boss = strsplit(":", value)

    -- Ignore records that are past the timeframe
    if (timestamp + timeframeInSeconds > currentTime) then
      local _, uid, guild, players = strsplit(":", key)
      local myGuildName = VGT.GetMyGuildName()

      -- Ignore records that don't match the player's guild name
      if (myGuildName ~= nil and myGuildName == guild) then

        -- Ignore records which don't have a valid uid
        if (uid ~= nil) then
          local localPlayersTable = {}

          -- Ignore test records if the flag is false
          if (not string.match(uid, "TEST")) then
            localPlayersTable = {strsplit(",", players)}
          end

          playersTable = VGT.TableJoinToArray(playersTable, localPlayersTable)
        end
      end
    end
  end
  return playersTable
end

-- Check if the local EPDB already has the
local checkLocalDBForBossKill = function(key, value)
  if (MY_EPDB[key] == nil) then
    MY_EPDB[key] = value
  else
    VGT.Log(VGT.LOG_LEVEL.WARN, "!! YOUR KILL WAS NOT RECORDED !!")
    VGT.Log(VGT.LOG_LEVEL.WARN, "WARN - record %s already exists in local DB. Contact an officer for assistance.", key)
    VGT.Log(VGT.LOG_LEVEL.WARN, "!! YOUR KILL WAS NOT RECORDED !!")
  end
end

local saveAndSendBossKill = function(key, value)
  local record = VGT_EPDB[key]
  if (record == nil or record == "") then
    VGT_EPDB[key] = value
    local message = format("%s;%s", key, value)
    VGT.Log(VGT.LOG_LEVEL.DEBUG, "saving %s and sending to guild.", message)
    VGT.LIBS:SendCommMessage(MODULE_NAME, message, "GUILD")
  else
    VGT.Log(VGT.LOG_LEVEL.TRACE, "record %s already exists in DB before it could be saved.", message)
  end
end

local timeStampToDaysFromNow = function(timestamp)
  return (GetServerTime() - timestamp) / (60 * 60 * 24)
end

local withinDays = function(timestamp, days)
  local daysSinceTimestamp = timeStampToDaysFromNow(timestamp)
  if (daysSinceTimestamp > - 0.01 and daysSinceTimestamp < days) then
    return true
  end
  return false
end

local validateTime = function(timestamp, sender)
  if (withinDays(timestamp, 14)) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.DEBUG, "invalid timestamp %s from %s", timeStampToDaysFromNow(timestamp), VGT.Safe(sender))
  return false
end

local validateDungeon = function(dungeon, sender)
  if (dungeon == "TestDungeon" or VGT.TableContains(VGT.dungeons, dungeon)) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.DEBUG, "invalid dungeon %s from %s", dungeon, VGT.Safe(sender))
  return false
end

local validateBoss = function(boss, sender)
  if (boss == "TestBoss" or VGT.TableContains(VGT.bosses, boss)) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.DEBUG, "invalid boss %s from %s", boss, VGT.Safe(sender))
  return false
end

local validateGuild = function(guild, sender)
  local myGuildName = VGT.GetMyGuildName()
  if (myGuildName ~= nil and myGuildName == guild) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.DEBUG, "invalid guild %s from %s", guild, VGT.Safe(sender))
  return false
end

local guildMembersSet = function()
  local guildMembers = {}
  if (IsInGuild()) then
    local numTotalMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
      local fullname = GetGuildRosterInfo(i)
      local name = strsplit("-", fullname)
      guildMembers[name] = true
    end
  end
  return guildMembers
end

local validatePlayers = function(guild, players, sender)
  local playersArray = {strsplit(",", players)}
  local playersSet = VGT.ArrayToSet(playersArray)
  if (VGT.SubsetCount(playersSet, guildMembersSet()) > 1) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.DEBUG, "invalid group %s from %s", players, VGT.Safe(sender))
  return false
end

local validateRecord = function(key, value, sender)
  if (key ~= nil and key ~= "" and value ~= nil and value ~= "") then
    local module, creatureUID, guildName, players = strsplit(":", key)
    local timestamp, dungeonName, bossName = strsplit(":", value)
    if (validateGuild(guildName, sender) and
      validatePlayers(guildName, players, sender) and
      validateTime(timestamp, sender) and
      validateDungeon(dungeonName, sender) and
    validateBoss(bossName, sender)) then
      return true
    end
  end
  return false
end

local cleanRecord = function(k, v)
  if (not validateRecord(k, v)) then
    VGT_EPDB[k] = nil
    VGT.Log(VGT.LOG_LEVEL.DEBUG, "record %s removed for being invalid", k)
  end
end

local firstKey
local currentKey
function CleanDatabase:onUpdate(sinceLastUpdate)
  self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate
  if (self.sinceLastUpdate >= 0.05) then
    currentKey, currentValue = next(VGT_EPDB, currentKey)
    if (firstKey == nil) then
      firstKey = currentKey
    elseif (firstKey == currentKey) then
      CleanDatabase:SetScript("OnUpdate", nil)
    end
    if (currentKey ~= nil) then
      cleanRecord(currentKey, currentValue)
    end
    self.sinceLastUpdate = 0
  end
end

local handleUnitDeath = function(creatureUID, dungeonName, bossName)
  local timestamp = GetServerTime()
  VGT.Log(VGT.LOG_LEVEL.TRACE, "killed %s in %s.", bossName, dungeonName)
  local guildName = GetGuildInfo("player")
  local groupedGuildies = VGT.CheckGroupForGuildies()
  if (guildName ~= nil) then
    if (groupedGuildies ~= nil and next(groupedGuildies) ~= nil) then
      local playerName = UnitName("player")
      table.insert(groupedGuildies, playerName)
      local groupedGuildiesStr = VGT.TableToString(groupedGuildies, ",", false, true)
      VGT.Log(VGT.LOG_LEVEL.INFO, "killed %s in %s as a guild with %s", bossName, dungeonName, groupedGuildiesStr)
      local key = format("%s:%s:%s:%s", MODULE_NAME, creatureUID, guildName, groupedGuildiesStr)
      local value = format("%s:%s:%s", timestamp, dungeonName, bossName)
      checkLocalDBForBossKill(key, value)
      saveAndSendBossKill(key, value)
    else
      VGT.Log(VGT.LOG_LEVEL.DEBUG, "skipping boss kill event because you are not in a group with any guild members of %s", guildName)
    end
  else
    VGT.Log(VGT.LOG_LEVEL.DEBUG, "skipping boss kill event because you are not in a guild")
  end
end

local getGuildIndexForUnit = function(player)
  local numTotalMembers, _, _ = GetNumGuildMembers()
  for i = 1, numTotalMembers do
    fullname, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
    local name = strsplit("-", fullname)
    if (player == name) then
      return i
    end
  end
  return nil
end

local handleEPMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local module, event, count = strsplit(":", message)
  if (count == nil) then
    count = 0
  end

  if (module ~= MODULE_NAME) then
    return
  end

  local playerName = UnitName("player")
  if (sender == playerName) then
    return
  end

  if (distribution == "GUILD") then
    if (event == "SYNCHRONIZATION_REQUEST") then
      if (count ~= VGT.Count(VGT_EPDB)) then
        for k, v in pairs(VGT_EPDB) do
          local message = format("%s;%s", k, v)
          VGT.Log(VGT.LOG_LEVEL.TRACE, "sending %s to %s for %s:SYNCHRONIZATION_REQUEST.", message, sender, MODULE_NAME)
          VGT.LIBS:SendCommMessage(MODULE_NAME, message, "GUILD", nil, "BULK")
        end
      end
    else
      local key, value = strsplit(";", message)
      local record = VGT_EPDB[key]
      if (record == nil or record == "") then
        if (validateRecord(key, value, sender)) then
          VGT.Log(VGT.LOG_LEVEL.DEBUG, "saving record %s from %s.", message, sender)
          VGT_EPDB[key] = value
        else
          VGT.Log(VGT.LOG_LEVEL.TRACE, "record %s from %s is invalid to recieve.", value, sender)
        end
      else
        VGT.Log(VGT.LOG_LEVEL.TRACE, "record %s from %s already exists in DB.", message, sender)
      end
    end
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

-- Print the list of players who did dungeons within the timeframe
--	timeframeInDays: default 7, controls how long ago to look for records in the EPDB
VGT.PrintDungeonList = function(timeframeInDays)
  if (VGT.OPTIONS.EP.enabled) then
    local str = VGT.TableToString(constructPlayerTableFromHistory(timeframeInDays), "", false, true, true)
    VGT_DUNGEONS_FRAME:Show();
    VGT_DUNGEONS_FRAME_SCROLL:Show()
    VGT_DUNGEONS_FRAME_TEXT:Show()
    VGT_DUNGEONS_FRAME_TEXT:SetText(str)
    VGT_DUNGEONS_FRAME_TEXT:HighlightText()

    VGT_DUNGEONS_FRAME_BUTTON:SetScript("OnClick", function(self) VGT_DUNGEONS_FRAME:Hide() end)
    VGT_DUNGEONS_FRAME_TEXT:SetScript("OnEscapePressed", function(self) self:GetParent():GetParent():Hide() end)
  end
end

-- TODO make this local and make loaded vars global
VGT.HandleCombatLogEvent = function()
  local cTime, cEvent, _, _, _, _, _, cUID, _, _, _ = CombatLogGetCurrentEventInfo()
  --TODO: possibly use cTime instead of GetServerTime(), if it's accurate across clients
  local _, cTypeID, cInstanceUID, cInstanceID, cUnitUID, cUnitID, hex = strsplit("-", cUID)
  if (cEvent == "UNIT_DIED") then
    local creatureUID = VGT.StringAppend(cTypeID, cInstanceUID, cInstanceID, cUnitUID, cUnitID, hex)
    local dungeonName = VGT.dungeons[tonumber(cInstanceID)][1]
    local bossName = VGT.bosses[tonumber(cUnitID)]
    if (creatureUID ~= nil and dungeonName ~= nil and bossName ~= nil) then
      handleUnitDeath(creatureUID, dungeonName, bossName)
    end
  end
end

VGT.EP_Initialize = function()
  if (VGT.OPTIONS.EP.enabled) then
    if (VGT_EPDB == nil) then
      VGT_EPDB = {}
    end
    CleanDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate) CleanDatabase:onUpdate(sinceLastUpdate) end)
    VGT.LIBS:RegisterComm(MODULE_NAME, handleEPMessageReceivedEvent)
    VGT.LIBS:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST:"..VGT.Count(VGT_EPDB), "GUILD", nil, "ALERT")
  end
end
