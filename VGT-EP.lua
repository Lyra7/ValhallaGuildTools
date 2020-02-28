local MODULE_NAME = "VGT-EP"
local MY_EPDB = {}
local EPFRAME = CreateFrame("Frame");
local CleanDatabase = CreateFrame("Frame");
local PushDatabase = CreateFrame("Frame");
local synchronize = false

local MAX_TIME_TO_KEEP = 21

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

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
  --TODO SET MAX TIME
  if (withinDays(timestamp, 30)) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.TRACE, "invalid timestamp %s from %s", timeStampToDaysFromNow(timestamp), VGT.Safe(sender))
  return false
end

local validateDungeon = function(dungeon, sender)
  if (dungeon == "TestDungeon" or VGT.dungeons[dungeon] ~= nil) then
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

function CleanDatabase:onUpdate(sinceLastUpdate, firstKey, currentKey)
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

function PushDatabase:onUpdate(sinceLastUpdate, firstKey, currentKey)
  self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate
  self.firstKey = (self.firstKey or firstKey)
  self.currentKey = (self.currentKey or currentKey)
  if (self.sinceLastUpdate >= 0.1) then
    if (synchronize and VGT.CommAvailability() >= 50 and not VGT.IsInRaid()) then
      self.currentKey, value = next(VGT_EPDB, self.currentKey)
      if (self.currentKey == self.firstKey) then
        synchronize = false
        self.firstKey = nil
        self.currentKey = nil
      else
        if (self.firstKey == nil) then
          self.firstKey = self.currentKey
        end
        if (self.currentKey ~= nil) then
          local message = format("%s;%s", self.currentKey, value)
          VGT.Log(VGT.LOG_LEVEL.TRACE, "sending %s to GUILD for %s:SYNCHRONIZATION_REQUEST.", message, MODULE_NAME)
          VGT.LIBS:SendCommMessage(MODULE_NAME, message, "GUILD", nil, "BULK")
        end
      end
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
        synchronize = true
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

local playerStatistics = function(player)
  local playerData = VGT_EPDB2[VGT.GetMyGuildName()][player]
  local oldestTimestamp = GetServerTime()
  local oldestGuid
  local totalKillCount = 0
  local killCount = 0
  local mostKilledBoss = {}
  local mostKilledBossCount = 0
  local mostKilledBossName = ""
  local mostKilledBossDungeonName = ""

  if (playerData ~= nil) then
    for guid, guidData in pairs(playerData) do
      local timestamp = tonumber(guidData[1])
      local rewarded = guidData[4]
      if (withinDays(timestamp, MAX_TIME_TO_KEEP)) then
        totalKillCount = totalKillCount + 1
        if (not rewarded) then
          killCount = killCount + 1
          if (not mostKilledBoss[guidData[3]]) then
            mostKilledBoss[guidData[3]] = 0
          end
          mostKilledBoss[guidData[3]] = mostKilledBoss[guidData[3]] + 1
          if (timestamp < oldestTimestamp) then
            oldestTimestamp = timestamp
            oldestGuid = guid
          end
        end
      end
    end
    for k, v in pairs(mostKilledBoss) do
      if (v > mostKilledBossCount) then
        mostKilledBossCount = v
        mostKilledBossName = VGT.bosses[k]
        mostKilledBossDungeonName = VGT.dungeons[VGT.bosses[mostKilledBossName][2]][1]
      end
    end
  end
  return player, killCount, totalKillCount, mostKilledBossName, mostKilledBossCount, mostKilledBossDungeonName
end

VGT.rewardEP = function()
  local currentTime = GetServerTime()
  local players = {}
  for player, playerData in pairs(VGT_EPDB2[VGT.GetMyGuildName()]) do
    local oldestTimestamp = currentTime
    local oldestGuid
    local killCount = 0
    for guid, guidData in pairs(playerData) do
      local timestamp = tonumber(guidData[1])
      local rewarded = guidData[4]
      if (withinDays(timestamp, MAX_TIME_TO_KEEP) and not rewarded) then
        killCount = killCount + 1
        if (timestamp < oldestTimestamp) then
          oldestTimestamp = timestamp
          oldestGuid = guid
        end
      end
    end
    if (oldestGuid ~= nil) then
      local guidData = playerData[oldestGuid]
      playerData[oldestGuid] = {guidData[1], guidData[2], guidData[3], true}
      players[player] = true
    end
  end
  return players
end

VGT.importDB = function()
  VGT_EPDB2 = {}
  for k, v in pairs(VGT_EPDB) do
    local module, guid, guild, playersCSV = strsplit(":", k)
    local timestamp, dungeon, boss = strsplit(":", v)
    if (playersCSV ~= nil) then
      if (VGT_EPDB2[guild] == nil) then
        VGT_EPDB2[guild] = {}
      end
      local players = {strsplit(",", playersCSV)}
      for i = 1, #players do
        if (VGT_EPDB2[guild][players[i]] == nil) then
          VGT_EPDB2[guild][players[i]] = {}
        end
        if (VGT_EPDB2[guild][players[i]][guid] == nil) then
          VGT_EPDB2[guild][players[i]][guid] = {}
        end
        VGT_EPDB2[guild][players[i]][guid] = {timestamp, VGT.dungeons[dungeon], VGT.bosses[boss][1]}
      end
    end
  end
end

local function tableSortTop(a, b)
  return a[2] > b[2]
end

VGT.PrintPlayerStatistics = function(playerName)
  if (playerName == nil) then
    playerName = UnitName("player");
  end
  
  playerName = playerName:gsub("^%l", string.upper)

  local player, killCount, totalKillCount, mostKilledBossName, mostKilledBossCount, mostKilledBossDungeonName = playerStatistics(playerName)
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, format("%s Statistics", player));
  if (killCount == 0) then
    VGT.Log(VGT.LOG_LEVEL.SYSTEM, "  no recorded statistics found.");
  else
    VGT.Log(VGT.LOG_LEVEL.SYSTEM, format("  total bosses killed: %s", killCount));
    VGT.Log(VGT.LOG_LEVEL.SYSTEM, format("  most killed boss: %sx %s (%s)", mostKilledBossCount, mostKilledBossName, mostKilledBossDungeonName));
  end
end

VGT.PrintDungeonLeaderboard = function()
  local top = {}
  for player, playerData in pairs(VGT_EPDB2[VGT.GetMyGuildName()]) do
    local player, killCount, totalKillCount, mostKilledBossName, mostKilledBossCount, mostKilledBossDungeonName = playerStatistics(player)
    table.insert(top, {player, killCount, mostKilledBossName, mostKilledBossCount})
  end
  table.sort(top, tableSortTop)
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, format("#### DUNGEON LEADERBOARD (%s days) ####", MAX_TIME_TO_KEEP))
  for i = 1, 5 do
    VGT.Log(VGT.LOG_LEVEL.SYSTEM, format("  %s killed %s bosses (%s %s kills)", top[i][1], top[i][2], top[i][4], top[i][3]))
  end
end

local dungeonQuery = function(_, event, message, sender)
  if (event == "CHAT_MSG_GUILD") then
    if (message == "?dungeon") then
      local playerName = strsplit("-", sender)
      local player, killCount, totalKillCount, mostKilledBossName, mostKilledBossCount, mostKilledBossDungeonName = playerStatistics(playerName)
      SendChatMessage(format("#### %s STATISTICS ####", player), "WHISPER", nil, sender);
      if (killCount == 0) then
        SendChatMessage("  no recorded statistics, are you running ValhallaGuildTools?", "WHISPER", nil, sender);
      else
        SendChatMessage(format("  total bosses killed: %s", killCount), "WHISPER", nil, sender);
        SendChatMessage(format("  most killed boss: %sx %s (%s)", mostKilledBossCount, mostKilledBossName, mostKilledBossDungeonName), "WHISPER", nil, sender);
      end
    end
    if (message == "?dungeontop") then
      local top = {}
      for player, playerData in pairs(VGT_EPDB2[VGT.GetMyGuildName()]) do
        local player, killCount, totalKillCount, mostKilledBossName, mostKilledBossCount, mostKilledBossDungeonName = playerStatistics(player)
        table.insert(top, {player, killCount, mostKilledBossName, mostKilledBossCount})
      end
      table.sort(top, tableSortTop)
      SendChatMessage(format("#### DUNGEON LEADERBOARD (%s days) ####", MAX_TIME_TO_KEEP), "GUILD")
      for i = 1, 5 do
        SendChatMessage(format("  %s killed %s bosses (%s %s kills)", top[i][1], top[i][2], top[i][4], top[i][3]), "GUILD")
      end
    end
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

-- Print the list of players who did dungeons within the timeframe
VGT.PrintDungeonList = function()
  if (VGT.OPTIONS.EP.enabled) then
    local players = VGT.rewardEP()
    local tempTable = {}
    for player, _ in pairs(players) do
      table.insert(tempTable, player)
    end
    table.sort(tempTable)
    local str = ""
    for _, player in pairs(tempTable) do
      str = str.."\n"..player
    end
    str = string.sub(str, 2)

    local text = VGT.Count(players).."\n"..str
    VGT_DUNGEONS_FRAME:Show();
    VGT_DUNGEONS_FRAME_SCROLL:Show()
    VGT_DUNGEONS_FRAME_TEXT:Show()
    VGT_DUNGEONS_FRAME_TEXT:SetText(text)
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
    local dungeon = VGT.dungeons[tonumber(cInstanceID)]
    if (dungeon ~= nil) then
      local dungeonName = VGT.dungeons[tonumber(cInstanceID)][1]
      local bossData = VGT.bosses[tonumber(cUnitID)]
      if (bossData ~= nil) then
        local bossName = bossData[1]
        if (creatureUID ~= nil and dungeonName ~= nil and bossName ~= nil) then
          handleUnitDeath(creatureUID, dungeonName, bossName)
        end
      end
    end
  end
end

local initialized = flase
VGT.EP_Initialize = function()
  if (VGT.OPTIONS.EP.enabled) then
    if (not initialized) then
      if (VGT_EPDB == nil) then
        VGT_EPDB = {}
      end
      if (VGT_EPDB2 == nil) then
        VGT_EPDB2 = {}
      end
      CleanDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate, firstKey, currentKey) CleanDatabase:onUpdate(sinceLastUpdate, firstKey, currentKey) end)
      PushDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate, firstKey, currentKey) PushDatabase:onUpdate(sinceLastUpdate, firstKey, currentKey) end)
      VGT.LIBS:RegisterComm(MODULE_NAME, handleEPMessageReceivedEvent)
      VGT.LIBS:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST:"..VGT.Count(VGT_EPDB), "GUILD")
      initialized = true
    end
  end
end

if (IsGuildLeader()) then
  EPFRAME:RegisterEvent("CHAT_MSG_GUILD")
  EPFRAME:SetScript("OnEvent", dungeonQuery)
end
