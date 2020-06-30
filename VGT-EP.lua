local MODULE_NAME = "VGT-EP"
local EPFRAME = CreateFrame("Frame");
local CleanDatabase = CreateFrame("Frame");
local PushDatabase = CreateFrame("Frame");
local synchronize = false
local cleaning = false
local dbSnapshot = {}

local MINIMUM_GP = 50
local MAX_TIME_TO_KEEP = 30
local MAX_TIME_TO_KEEP_RAID = 8

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

VGT.withinDays = function(timestamp, days)
  local daysSinceTimestamp = timeStampToDaysFromNow(timestamp)
  if (daysSinceTimestamp > - 0.01 and daysSinceTimestamp < (days or 0)) then
    return true
  end
  return false
end

local validateTime = function(timestamp, sender)
  timestamp = tonumber(timestamp)
  if (timestamp and VGT.withinDays(timestamp, MAX_TIME_TO_KEEP)) then
    return true
  end
  VGT.Log(VGT.LOG_LEVEL.TRACE, "invalid timestamp %s from %s", timeStampToDaysFromNow(timestamp), VGT.Safe(sender))
  return false
end

local validateDungeon = function(dungeon, sender)
  local dungeonData = VGT.dungeons[dungeon]
  if (not dungeonData and VGT.trackedRaids[dungeon]) then
    dungeonData = VGT.raids[dungeon]
  end
  if (dungeonData ~= nil) then
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
  for player, playerData in pairs(VGT_DUNGEON_DB[guildName]) do
    for guid, guidData in pairs(playerData) do
      if (not validateRecord(guildName, guidData[1], guidData[2], guidData[3], nil)) then
        VGT_DUNGEON_DB[guildName][player][guid] = nil
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "record %s:%s:%s removed for being invalid", guildName, player, guid)
      end
    end
  end
end

function CleanDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey)
  local guildName = VGT.GetMyGuildName()
  if (guildName == nil or VGT_DUNGEON_DB[guildName] == nil or VGT.IsInRaid() or VGT.withinDays(VGT_DB_TIMESTAMP, 0)) then
    -- Stop the loop
    cleaning = false
    --VGT_DB_TIMESTAMP = GetServerTime()
    CleanDatabase:SetScript("OnUpdate", nil)
    return nil
  end

  self.firstPlayerKey = (self.firstPlayerKey or firstPlayerKey)
  self.currentPlayerKey = (self.currentPlayerKey or next(VGT_DUNGEON_DB[guildName], self.currentPlayerKey))
  self.currentGuidKey = (self.currentGuidKey or currentGuidKey)
  if (self.firstPlayerKey == self.currentPlayerKey) then
    -- Stop the loop
    cleaning = false
    VGT_DB_TIMESTAMP = GetServerTime()
    CleanDatabase:SetScript("OnUpdate", nil)
    return nil
  end

  -- Check if player exists
  if (self.currentPlayerKey ~= nil) then
    -- Get next guid data
    if (VGT_DUNGEON_DB[guildName][self.currentPlayerKey] ~= nil) then
      if (VGT.Count(VGT_DUNGEON_DB[guildName][self.currentPlayerKey]) == 0) then
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "CLEANING %s", self.currentPlayerKey)
        VGT_DUNGEON_DB[guildName][self.currentPlayerKey] = nil
      else
        self.currentGuidKey, timestamp = next(VGT_DUNGEON_DB[guildName][self.currentPlayerKey], self.currentGuidKey)
      end
    else
      self.currentGuidKey = nil
    end
    -- Set the firstKeys
    if (self.firstPlayerKey == nil and self.currentGuidKey == nil) then
      self.firstPlayerKey = self.currentPlayerKey
    end
    -- Check if data exists
    if (timestamp and self.currentGuidKey) then
      local _, dungeonId, bossId = strsplit("-", self.currentGuidKey)
      dungeonId = tonumber(dungeonId)
      bossId = tonumber(bossId)

      local dungeonData = VGT.dungeons[dungeonId]
      if (not dungeonData and VGT.trackedRaids[dungeonId]) then
        dungeonData = VGT.raids[dungeonId]
      end

      -- Check if data is valid
      if (not dungeonData or not validateRecord(guildName, timestamp, dungeonData[1], VGT.bosses[bossId], nil)) then
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "CLEANING %s", self.currentGuidKey)
        VGT_DUNGEON_DB[guildName][self.currentPlayerKey][self.currentGuidKey] = nil
        if (VGT.Count(VGT_DUNGEON_DB[guildName][self.currentPlayerKey]) == 0) then
          VGT.Log(VGT.LOG_LEVEL.DEBUG, "CLEANING %s", self.currentPlayerKey)
          VGT_DUNGEON_DB[guildName][self.currentPlayerKey] = nil
        end
      end
    else
      -- Get the next player data
      self.currentPlayerKey = next(VGT_DUNGEON_DB[guildName], self.currentPlayerKey)
    end
  end
end

-- Send a snapshot of the EPDB
function PushDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey)
  self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate
  if (synchronize and not cleaning and VGT.CommAvailability() > 50 and self.sinceLastUpdate >= 0.05 and IsInGuild()) then
    local guildName = VGT.GetMyGuildName()
    if (not dbSnapshot or not dbSnapshot[guildName]) then
      return nil
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
      -- Get next data
      self.currentGuidKey, timestamp = next(dbSnapshot[guildName][self.currentPlayerKey], self.currentGuidKey)
      -- Set the firstKeys
      if (self.firstPlayerKey == nil and self.currentGuidKey == nil) then
        self.firstPlayerKey = self.currentPlayerKey
      end
      -- Check if data exists
      if (timestamp) then
        local _, dungeonId, bossId = strsplit("-", self.currentGuidKey)
        dungeonId = tonumber(dungeonId)
        bossId = tonumber(bossId)

        -- Check if data is valid
        local dungeonData = VGT.dungeons[dungeonId]
        if (not dungeonData and VGT.trackedRaids[dungeonId]) then
          dungeonData = VGT.raids[dungeonId]
        end
        if (dungeonData and validateRecord(guildName, timestamp, dungeonData[1], VGT.bosses[bossId], nil)) then
          -- Send the data
          local key = format("%s:%s:%s", self.currentGuidKey, guildName, self.currentPlayerKey)
          local message = format("%s;%s", key, timestamp)
          VGT.Log(VGT.LOG_LEVEL.TRACE, "sending %s to GUILD for %s:SYNCHRONIZATION_REQUEST.", message, MODULE_NAME)
          VGT.LIBS:SendCommMessage(MODULE_NAME, message, "GUILD", nil, "BULK")
        end
      else
        -- Get the next player data
        self.currentPlayerKey = next(dbSnapshot[guildName], self.currentPlayerKey)
      end
    end
    self.sinceLastUpdate = 0
  end
end

local handleUnitDeath = function(timestamp, creatureUID, dungeonId, dungeonName, bossId, bossName)
  VGT.Log(VGT.LOG_LEVEL.TRACE, "killed %s in %s.", bossName, dungeonName)
  local guildName = GetGuildInfo("player")
  local groupedGuildies = VGT.CheckGroupForGuildies()
  if (guildName ~= nil) then
    if (groupedGuildies ~= nil and next(groupedGuildies) ~= nil) then
      local playerName = UnitName("player")
      table.insert(groupedGuildies, playerName)
      local groupedGuildiesStr = VGT.TableToString(groupedGuildies, ",", false, true)
      VGT.Log(VGT.LOG_LEVEL.INFO, "killed %s in %s as a guild with %s", bossName, dungeonName, groupedGuildiesStr)

      if (VGT_DUNGEON_DB == nil) then
        VGT_DUNGEON_DB = {}
      end
      if (groupedGuildiesStr ~= nil) then
        if (VGT_DUNGEON_DB[guildName] == nil) then
          VGT_DUNGEON_DB[guildName] = {}
        end
        local players = {strsplit(",", groupedGuildiesStr)}
        for i = 1, #players do
          if (VGT_DUNGEON_DB[guildName][players[i]] == nil) then
            VGT_DUNGEON_DB[guildName][players[i]] = {}
          end
          if (VGT_DUNGEON_DB[guildName][players[i]][creatureUID] == nil) then
            VGT_DUNGEON_DB[guildName][players[i]][creatureUID] = timestamp
          end
        end
      end

      local key = format("%s:%s:%s", creatureUID, guildName, groupedGuildiesStr)
      local message = format("%s;%s", key, timestamp)
      VGT.Log(VGT.LOG_LEVEL.DEBUG, "saving %s and sending to guild.", message)
      if (IsInGuild()) then
        VGT.LIBS:SendCommMessage(MODULE_NAME, message, "GUILD", nil)
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
  if (distribution == "GUILD") then
    local key, timestamp = strsplit(";", message)
    local creatureUID, guildName, groupedGuildiesStr = strsplit(":", key)
    local _, dungeonId, bossId = strsplit("-", creatureUID)
    local dungeonData = VGT.dungeons[tonumber(dungeonId)]
    if (not dungeonData and VGT.trackedRaids[tonumber(dungeonId)]) then
      dungeonData = VGT.raids[tonumber(dungeonId)]
    end
    if (dungeonData ~= nil) then
      local dungeonName = dungeonData[1]
      local bossName = VGT.bosses[tonumber(bossId)]
      if (validateRecord(guildName, timestamp, dungeonName, bossName, sender)) then
        if (VGT_DUNGEON_DB == nil) then
          VGT_DUNGEON_DB = {}
        end
        if (groupedGuildiesStr ~= nil) then
          if (VGT_DUNGEON_DB[guildName] == nil) then
            VGT_DUNGEON_DB[guildName] = {}
          end
          local players = {strsplit(",", groupedGuildiesStr)}
          for i = 1, #players do
            if (VGT_DUNGEON_DB[guildName][players[i]] == nil) then
              VGT_DUNGEON_DB[guildName][players[i]] = {}
            end
            if (VGT_DUNGEON_DB[guildName][players[i]][creatureUID] == nil) then
              VGT.Log(VGT.LOG_LEVEL.DEBUG, "saving record %s:%s:%s from %s.", guildName, players[i], creatureUID, sender)
              VGT_DUNGEON_DB[guildName][players[i]][creatureUID] = timestamp
            else
              VGT.Log(VGT.LOG_LEVEL.TRACE, "record %s:%s:%s from %s already exists.", guildName, players[i], creatureUID, sender)
            end
          end
        end
      end
    else
      VGT.Log(VGT.LOG_LEVEL.TRACE, "record %s from %s is invalid to recieve.", value, sender)
    end
  end
end

local playerStatistics = function(player)
  local playerData = VGT_DUNGEON_DB[VGT.GetMyGuildName()][player]
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
      if (VGT.withinDays(timestamp, MAX_TIME_TO_KEEP)) then
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
        local dungeonData = VGT.dungeons[VGT.bosses[mostKilledBossName][2]]
        if (not dungeonData and VGT.trackedRaids[VGT.bosses[mostKilledBossName][2]]) then
          dungeonData = VGT.raids[VGT.bosses[mostKilledBossName][2]]
        end
        mostKilledBossDungeonName = dungeonData[1]
      end
    end
  end
  return player, killCount, totalKillCount, mostKilledBossName, mostKilledBossCount, mostKilledBossDungeonName
end

function VGT.getBossCountForPlayer(guild, name, raid)
  local killCount = 0
  local guildData = VGT_DUNGEON_DB[guild]
  if (guildData) then
    local playerData = guildData[name]
    if (playerData) then
      for _, guidData in pairs(playerData) do
        if (not guidData[4]) then
          local timestamp = tonumber(guidData[1])
          local dungeonId = tonumber(guidData[2])
          if (raid) then
            if (VGT.withinDays(timestamp, MAX_TIME_TO_KEEP_RAID) and VGT.trackedRaids[dungeonId]) then
              killCount = killCount + 1
            end
          else
            if (VGT.withinDays(timestamp, MAX_TIME_TO_KEEP) and not VGT.trackedRaids[dungeonId]) then
              killCount = killCount + 1
            end
          end
        end
      end
      return killCount
    end
  end
end

audit = {}
--audit["Bonkeybee"] = true
VGT.rewardEP = function(test)
  local guildTable = {}
  for i = 1, GetNumGuildMembers() do
    local fullname, _, _, _, _, _, _, officernote = GetGuildRosterInfo(i)
    local name = strsplit("-", fullname)
    if (not officernote) then
      officernote = "0,50"
    end
    guildTable[name] = {i, officernote}
  end

  local players = {}
  for i = 1, 5 do
    local currentTime = GetServerTime()
    for player, playerData in pairs(VGT_DUNGEON_DB[VGT.GetMyGuildName()]) do
      local oldestTimestamp = currentTime
      local oldestGuid
      local killCount = 0
      for guid, guidData in pairs(playerData) do
        local timestamp = tonumber(guidData[1])
        local rewarded = guidData[4]
        local dungeonId = guidData[2]
        if (VGT.withinDays(timestamp, MAX_TIME_TO_KEEP) and not rewarded and not VGT.trackedRaids[dungeonId]) then
          killCount = killCount + 1
          if (timestamp < oldestTimestamp) then
            oldestTimestamp = timestamp
            oldestGuid = guid
          end
        end
      end
      if (oldestGuid ~= nil and guildTable[player]) then
        local guidData = playerData[oldestGuid]
        if (not test and not audit[player]) then
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

  local _, _, guildRankIndex = GetGuildInfo("player");
  if (guildRankIndex == 1) then
    for player, count in pairs(players) do
      local i = guildTable[player][1]
      local officernote = guildTable[player][2]
      local ep, gp = strsplit(",", officernote)
      if (ep == nil or ep == "" or not tonumber(ep)) then
        ep = 0
      end
      if (gp == nil or gp == "" or not tonumber(gp)) then
        gp = MINIMUM_GP
      end
      local bonus = (10 * count)
      ep = ep + bonus

      if (not test) then
        GuildRosterSetOfficerNote(i, ep..","..gp)
        SendChatMessage("Adding "..bonus.."EP to "..player.." (dungeons)", "OFFICER")
      else
        print("Adding "..bonus.."EP to "..player.." (dungeons)")
      end
    end
  end

  return players
end

VGT.rewardRaidEP = function(test)
  local guildTable = {}
  for i = 1, GetNumGuildMembers() do
    local fullname, _, _, _, _, _, _, officernote = GetGuildRosterInfo(i)
    local name = strsplit("-", fullname)
    if (not officernote) then
      officernote = "0,50"
    end
    guildTable[name] = {i, officernote}
  end

  local players = {}
  local currentTime = GetServerTime()
  for player, playerData in pairs(VGT_DUNGEON_DB[VGT.GetMyGuildName()]) do
    local oldestTimestamp = currentTime
    local oldestGuid
    local killCount = 0
    for guid, guidData in pairs(playerData) do
      local timestamp = tonumber(guidData[1])
      local dungeonId = tonumber(guidData[2])
      local rewarded = guidData[4]
      if (VGT.withinDays(timestamp, MAX_TIME_TO_KEEP_RAID) and not rewarded and VGT.trackedRaids[dungeonId]) then
        killCount = killCount + 1
        if (timestamp < oldestTimestamp) then
          oldestTimestamp = timestamp
          oldestGuid = guid
        end
      end
    end
    if (oldestGuid ~= nil and guildTable[player]) then
      local guidData = playerData[oldestGuid]
      if (not test and not audit[player]) then
        playerData[oldestGuid] = {guidData[1], guidData[2], guidData[3], true}
      end
      if (not players[player]) then
        players[player] = 1
      end
    end
  end

  local _, _, guildRankIndex = GetGuildInfo("player");
  if (guildRankIndex == 1) then
    for player, count in pairs(players) do
      local i = guildTable[player][1]
      local officernote = guildTable[player][2]
      local ep, gp = strsplit(",", officernote)
      if (ep == nil or ep == "" or not tonumber(ep)) then
        ep = 0
      end
      if (gp == nil or gp == "" or not tonumber(gp)) then
        gp = MINIMUM_GP
      end
      local bonus = 100
      ep = ep + bonus

      if (not test) then
        GuildRosterSetOfficerNote(i, ep..","..gp)
        SendChatMessage("Adding "..bonus.."EP to "..player.." (20-man raid)", "OFFICER")
      else
        print("Adding "..bonus.."EP to "..player.." (20-man raid)")
      end
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
  for player, playerData in pairs(VGT_DUNGEON_DB[VGT.GetMyGuildName()]) do
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
  local _, cEvent, _, _, _, _, _, cUID, _, _, _ = CombatLogGetCurrentEventInfo()
  local timestamp = GetServerTime()
  local _, _, _, cInstanceID, _, cUnitID, spawnUID = strsplit("-", cUID)
  if (cEvent == "UNIT_DIED") then
    local creatureUID = spawnUID.."-"..cInstanceID.."-"..cUnitID
    VGT.Log(VGT.LOG_LEVEL.TRACE, "killed %s in %s.", creatureUID, cInstanceID)
    local dungeonData = VGT.dungeons[tonumber(cInstanceID)]
    if (not dungeonData and VGT.trackedRaids[tonumber(cInstanceID)]) then
      dungeonData = VGT.raids[tonumber(cInstanceID)]
    end
    if (dungeonData) then
      local dungeonName = dungeonData[1]
      local bossName = VGT.bosses[tonumber(cUnitID)]
      if (creatureUID and dungeonName and bossName) then
        handleUnitDeath(timestamp, creatureUID, tonumber(cInstanceID), dungeonName, tonumber(cUnitID), bossName)
      end
    end
  end
end

local initialized = false
VGT.EP_Initialize = function()
  if (VGT.OPTIONS.EP.enabled) then
    if (not initialized) then
      if (VGT_DUNGEON_DB == nil) then
        VGT_DUNGEON_DB = {}
      end
      CleanDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) CleanDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) end)
      cleaning = true
      PushDatabase:SetScript("OnUpdate", function(self, sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) PushDatabase:onUpdate(sinceLastUpdate, firstPlayerKey, currentPlayerKey, currentGuidKey) end)
      dbSnapshot = deepcopy(VGT_DUNGEON_DB)
      synchronize = true
      VGT.LIBS:RegisterComm(MODULE_NAME, handleEPMessageReceivedEvent)
      initialized = true
    end
  end
end
