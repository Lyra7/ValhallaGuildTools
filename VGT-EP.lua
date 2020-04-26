local MODULE_NAME = "VGT-EP"
local EPFRAME = CreateFrame("Frame");
local CleanDatabase = CreateFrame("Frame");
local PushDatabase = CreateFrame("Frame");
local synchronize = false
local dbSnapshot = {}

local MAX_TIME_TO_KEEP = 30

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

local timeStampToDaysFromNow = function(timestamp)
  return (GetServerTime() - (timestamp or 0)) / (60 * 60 * 24)
end

local withinDays = function(timestamp, days)
  local daysSinceTimestamp = timeStampToDaysFromNow(timestamp)
  if (daysSinceTimestamp > - 0.01 and daysSinceTimestamp < (days or 0)) then
    return true
  end
  return false
end

local validateTime = function(timestamp, sender)
  if (withinDays(timestamp, MAX_TIME_TO_KEEP)) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.TRACE, "invalid timestamp %s from %s", timeStampToDaysFromNow(timestamp), VGT.Safe(sender))
  return false
end

local validateDungeon = function(dungeon, sender)
  if (VGT.dungeons[dungeon] ~= nil) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.DEBUG, "invalid dungeon %s from %s", dungeon, VGT.Safe(sender))
  return false
end

local validateBoss = function(boss, sender)
  if (VGT.bosses[boss] ~= nil) then
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

local validateRecord = function(guildName, timestamp, dungeonName, bossName, sender)
  if (validateGuild(guildName, sender) and validateTime(timestamp, sender) and validateDungeon(dungeonName, sender) and validateBoss(bossName, sender)) then
    return true
  end
  return false
end

local cleanRecord = function(guildName)
  for player, playerData in pairs(VGT_EPDB2[guildName]) do
    for guid, guidData in pairs(playerData) do
      if (not validateRecord(guildName, guidData[1], guidData[2], guidData[3], nil)) then
        VGT_EPDB2[guildName][player][guid] = nil
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "record %s:%s:%s removed for being invalid", guildName, player, guid)
      end
    end
  end
end

function CleanDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey)
  local guildName = VGT.GetMyGuildName()
  if (guildName == nil or VGT_EPDB2[guildName] == nil or VGT.IsInRaid() or withinDays(VGT_DB_TIMESTAMP, 1)) then
    -- Stop the loop
    CleanDatabase:SetScript("OnUpdate", nil)
    return nil
  end

  self.firstPlayerKey = (self.firstPlayerKey or firstPlayerKey)
  self.currentPlayerKey = (self.currentPlayerKey or next(VGT_EPDB2[guildName], self.currentPlayerKey))
  self.currentGuidKey = (self.currentGuidKey or currentGuidKey)
  if (self.firstPlayerKey == self.currentPlayerKey) then
    -- Stop the loop
    CleanDatabase:SetScript("OnUpdate", nil)
    return nil
  end
  VGT_DB_TIMESTAMP = GetServerTime()

  -- Check if player exists
  if (self.currentPlayerKey ~= nil) then
    -- Get next guid data
    self.currentGuidKey, guidData = next(VGT_EPDB2[guildName][self.currentPlayerKey], self.currentGuidKey)
    -- Set the firstKeys
    if (self.firstPlayerKey == nil and self.currentGuidKey == nil) then
      self.firstPlayerKey = self.currentPlayerKey
    end
    -- Check if guid exists
    if (guidData ~= nil) then
      local timestamp = guidData[1]
      local dungeonName = VGT.dungeons[guidData[2]][1]
      local bossName = VGT.bosses[guidData[3]]
      -- Check if data is valid
      if (not validateRecord(guildName, timestamp, dungeonName, bossName, nil)) then
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "CLEANING %s", self.currentGuidKey)
        VGT_EPDB2[guildName][self.currentPlayerKey][self.currentGuidKey] = nil
      end
    else
      -- Get the next player data
      self.currentPlayerKey = next(VGT_EPDB2[guildName], self.currentPlayerKey)
    end
  end
end

-- TODO should only send data that doesnt match by player key instead of entire DB
-- Send a snapshot of the EPDB
function PushDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey)
  self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate
  if (synchronize and VGT.CommAvailability() > 50 and self.sinceLastUpdate >= 0.05) then
    local guildName = VGT.GetMyGuildName()
    if (not dbSnapshot[guildName]) then
      return
    end
    self.firstPlayerKey = (self.firstPlayerKey or firstPlayerKey)
    self.currentPlayerKey = (self.currentPlayerKey or next(dbSnapshot[guildName], self.currentPlayerKey))
    self.currentGuidKey = (self.currentGuidKey or currentGuidKey)

    if (guildName == nil or VGT.IsInRaid() or self.firstPlayerKey == self.currentPlayerKey) then
      -- Stop the loop
      synchronize = false
      self.firstPlayerKey = nil
      self.currentPlayerKey = nil
      self.currentGuidKey = nil
      return nil
    end

    -- Check if player exists
    if (self.currentPlayerKey ~= nil) then
      -- Get next guid data
      self.currentGuidKey, guidData = next(dbSnapshot[guildName][self.currentPlayerKey], self.currentGuidKey)
      -- Set the firstKeys
      if (self.firstPlayerKey == nil and self.currentGuidKey == nil) then
        self.firstPlayerKey = self.currentPlayerKey
      end
      -- Check if guid exists
      if (guidData ~= nil) then
        local timestamp = guidData[1]
        -- Check if data is valid
        if (validateRecord(guildName, timestamp, VGT.dungeons[guidData[2]][1], VGT.bosses[guidData[3]], nil)) then
          -- Send the data
          --TODO send only guidkey + timestamp and pull dungeon and boss from the key
          local key = format("%s:%s:%s", self.currentGuidKey, guildName, self.currentPlayerKey)
          local value = format("%s:%s:%s", timestamp, guidData[2], guidData[3])
          local message = format("%s;%s", key, value)
          VGT.Log(VGT.LOG_LEVEL.TRACE, "sending %s to GUILD for %s:SYNCHRONIZATION_REQUEST.", message, MODULE_NAME)
          VGT.LIBS:SendCommMessage(MODULE_NAME, message, "WHISPER", "Valhallax", "BULK")
        end
      else
        -- Get the next player data
        self.currentPlayerKey = next(dbSnapshot[guildName], self.currentPlayerKey)
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

      if (VGT_EPDB2 == nil) then
        VGT_EPDB2 = {}
      end
      if (groupedGuildiesStr ~= nil) then
        if (VGT_EPDB2[guildName] == nil) then
          VGT_EPDB2[guildName] = {}
        end
        local players = {strsplit(",", groupedGuildiesStr)}
        for i = 1, #players do
          if (VGT_EPDB2[guildName][players[i]] == nil) then
            VGT_EPDB2[guildName][players[i]] = {}
          end
          if (VGT_EPDB2[guildName][players[i]][creatureUID] == nil) then
            VGT_EPDB2[guildName][players[i]][creatureUID] = {timestamp, VGT.dungeons[dungeonName], VGT.bosses[bossName][1]}
          end
        end
      end

      local key = format("%s:%s:%s:%s", MODULE_NAME, creatureUID, guildName, groupedGuildiesStr)
      local value = format("%s:%s:%s", timestamp, dungeonName, bossName)
      local message = format("%s;%s", key, value)
      VGT.Log(VGT.LOG_LEVEL.DEBUG, "saving %s and sending to guild.", message)
      if (IsInGuild()) then
        VGT.LIBS:SendCommMessage(MODULE_NAME, message, "GUILD")
      end
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
  local playerName = UnitName("player")
  if (sender == playerName) then
    return
  end

  local event = strsplit(":", message)
  if (distribution == "WHISPER") then
    local key, value = strsplit(";", message)
    local _, creatureUID, guildName, groupedGuildiesStr = strsplit(":", key)
    local timestamp, dungeonId, bossId = strsplit(":", value)
    local dungeonName = VGT.dungeons[dungeonId][1]
    local bossName = VGT.bosses[bossId]
    if (validateRecord(guildName, timestamp, dungeonName, bossName, sender)) then
      if (VGT_EPDB2 == nil) then
        VGT_EPDB2 = {}
      end
      if (groupedGuildiesStr ~= nil) then
        if (VGT_EPDB2[guildName] == nil) then
          VGT_EPDB2[guildName] = {}
        end
        local players = {strsplit(",", groupedGuildiesStr)}
        for i = 1, #players do
          if (VGT_EPDB2[guildName][players[i]] == nil) then
            VGT_EPDB2[guildName][players[i]] = {}
          end
          if (VGT_EPDB2[guildName][players[i]][creatureUID] == nil) then
            VGT.Log(VGT.LOG_LEVEL.DEBUG, "saving record %s:%s:%s from %s.", guildName, players[i], creatureUID, sender)
            VGT_EPDB2[guildName][players[i]][creatureUID] = {timestamp, VGT.dungeons[dungeonName], VGT.bosses[bossName][1]}
          end
        end
      end
    else
      VGT.Log(VGT.LOG_LEVEL.TRACE, "record %s from %s is invalid to recieve.", value, sender)
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

VGT.rewardEP = function(test)
  local guildTable = {}
  for i = 1, GetNumGuildMembers() do
    local fullname = GetGuildRosterInfo(i)
    local name = strsplit("-", fullname)
    guildTable[name] = true
  end

  local players = {}
  for i = 1, 5 do
    local currentTime = GetServerTime()
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
      if (oldestGuid ~= nil and guildTable[player]) then
        local guidData = playerData[oldestGuid]
        if (not test) then
          _, _, guildRankIndex = GetGuildInfo("player");
          playerData[oldestGuid] = {guidData[1], guidData[2], guidData[3], true}
        end
        if (players[player]) then
          players[player] = players[player] + 1
        else
          players[player] = 1
        end
      end
    end
  end

  if (guildRankIndex == 0) then
    for player, count in pairs(players) do
      CEPGP_addEP(player, 10 * count, "dungeon ep")
    end
  end

  return players
end

VGT.decay = function()
  local guildTable = {}
  for i = 1, 1000 do
    local fullname, _, _, _, _, _, _, officernote = GetGuildRosterInfo(i)
    if (fullname) then
      local name = strsplit("-", fullname)
      guildTable[name] = {i, officernote}
    end
  end

  for name, rosterInfo in pairs(guildTable) do
    local index = rosterInfo[1]
    local officernote = rosterInfo[2]
    if (officernote) then
      local ep, gp = strsplit(",", officernote)
      if (ep and gp) then
        ep = floor(ep * 0.8)
        gp = floor(max(gp * 0.8, 50))
        GuildRosterSetOfficerNote(index, ep..","..gp)
      else
        print("EPGP "..name.." NOT DECAYED, EPGP("..(ep or "nil").."/"..(gp or "nil")..")")
      end
    end
  end

  SendChatMessage("EPGP decayed by 20%", "OFFICER")
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
      local bossName = VGT.bosses[tonumber(cUnitID)]
      if (creatureUID ~= nil and dungeonName ~= nil and bossName ~= nil) then
        handleUnitDeath(creatureUID, dungeonName, bossName)
      end
    end
  end
end

local initialized = false
VGT.EP_Initialize = function()
  if (VGT.OPTIONS.EP.enabled) then
    if (not initialized) then
      if (VGT_EPDB2 == nil) then
        VGT_EPDB2 = {}
      end
      CleanDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) CleanDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) end)
      PushDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) PushDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) end)
      VGT.LIBS:RegisterComm(MODULE_NAME, handleEPMessageReceivedEvent)
      if (UnitName("player") ~= "Valhallax") then
        dbSnapshot = deepcopy(VGT_EPDB2)
        synchronize = true
      end
      initialized = true
    end
  end
end
