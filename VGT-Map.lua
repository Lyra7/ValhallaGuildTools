local MODULE_NAME = "VGT-Map"
local FRAME = CreateFrame("Frame")

local BUFFER_STEP = 10
local bufferPins = {}
local players = {}

local FRAME_TYPE = "Frame"
local PLAYER = "player"
local COMM_CHANNEL = "GUILD"
local COMM_PRIORITY = "NORMAL"
local PERCENT = "%"
local NEW_LINE = "\n"
local DELIMITER = ":"
local NAME_SEPERATOR = "-"
local HP_SEPERATOR = " - "
local BACKGROUND = "BACKGROUND"
local SCRIPT_ENTER = "OnEnter"
local SCRIPT_LEAVE = "OnLeave"
local PIN_TEXTURE = "Interface\\MINIMAP\\ObjectIcons.blp"

local PIN_SIZE = 10

local hiddenAppearanceData = {
		size = 0,
		sublevel = UNIT_POSITION_FRAME_DEFAULT_SUBLEVEL,
		texture = UNIT_POSITION_FRAME_DEFAULT_TEXTURE,
		shouldShow = false,
		useClassColor = false,
		showRotation = false
}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local colorString = function(colorHex, str)
  return "|c"..colorHex..str.."|r"
end

local formatPlayerTooltip = function(player)
  local text = colorString(select(4, GetClassColor(player.Class)), player.Name)

  if (player.HP ~= nil) then
    return text..HP_SEPERATOR..colorString("ff"..VGT.RGBToHex(VGT.ColorGradient(tonumber(player.HP), 1, 0, 0, 1, 1, 0, 0, 1, 0)), VGT.Round(player.HP * 100, 0)..PERCENT)
  end
end

local onEnterPin = function(self)
  GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
  local player = self.Player

  local text = ""

  if (player.Zone ~= nil) then
    text = player.Zone..NEW_LINE
  end

  text = text..formatPlayerTooltip(player)

  for _, otherPlayer in pairs(players) do
    -- TODO distance needs to increase as map zooms out
    if (otherPlayer ~= player and otherPlayer.X ~= nil and otherPlayer.Y ~= nil and player.X ~= nil and player.Y ~= nil and (abs(player.X - otherPlayer.X) + abs(player.Y - otherPlayer.Y) < 50)) then
      text = text..NEW_LINE..formatPlayerTooltip(otherPlayer)
    end
  end

  GameTooltip:SetText(text)
  GameTooltip:Show()
end

local onLeavePin = function(self)
  GameTooltip:Hide()
end

local createBufferPins = function()
  for i = 1, BUFFER_STEP do
    local pin = CreateFrame(FRAME_TYPE, nil, WorldFrame)
    pin:SetWidth(PIN_SIZE)
    pin:SetHeight(PIN_SIZE)
    local texture = pin:CreateTexture(nil, BACKGROUND)
    texture:SetTexture(PIN_TEXTURE)
    texture:SetTexCoord(0.51, 0.76, 0.00, 0.26) -- Green
    texture:SetAllPoints()
    pin:EnableMouse(true)
    pin:SetScript(SCRIPT_ENTER, onEnterPin)
    pin:SetScript(SCRIPT_LEAVE, onLeavePin)
    bufferPins[i] = {pin, texture}
  end
end

local findPin = function()
  for i = 1, VGT.Count(bufferPins) do
    if (bufferPins[i] ~= nil and bufferPins[i][1] and bufferPins[i][2]) then
      local pin = bufferPins[i][1]
      local texture = bufferPins[i][2]
      bufferPins[i][1] = nil
      bufferPins[i][2] = nil
      return pin, texture
    end
  end
  createBufferPins()
end

local findNextPin = function()
  local pin, texture
  while (pin == nil) do
    pin, texture = findPin()
  end
  return pin, texture
end

local getClass = function(name)
  if (UnitPlayerOrPetInParty(name)) then
    for i = 1, 5 do
      local unitId = "party"..i
      if (UnitName(unitId) == name) then
        local _, class = UnitClass(unitId)
        if class then return class end
      end
    end
  end

  if (UnitPlayerOrPetInRaid(name)) then
    for i = 1, 40 do
      local unitId = "raid"..i
      if (UnitName(unitId) == name) then
        local _, class = UnitClass(unitId)
        if class then return class end
      end
    end
  end

  local numTotalMembers = GetNumGuildMembers()
  for i = 1, numTotalMembers do
    local fullname, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
    if (fullname ~= nil) then
      local memberName = strsplit(NAME_SEPERATOR, fullname)
      if (memberName == name) then return class end
    end
  end
end

local isDungeonCoords = function(x, y, instanceMapId, decimals)
  for key, value in pairs(VGT.raids) do
    if (value and not tonumber(value) and x == VGT.Round(value[2], decimals or 0) and y == VGT.Round(value[3], decimals or 0) and instanceMapId == value[4]) then
      return true
    end
  end
  for key, value in pairs(VGT.dungeons) do
    if (value and not tonumber(value) and x == VGT.Round(value[2], decimals or 0) and y == VGT.Round(value[3], decimals or 0) and instanceMapId == value[4]) then
      return true
    end
  end
  return false
end

local getInGuild = function(name)
  local numTotalMembers = GetNumGuildMembers()
  for i = 1, numTotalMembers do
    local fullname, _, _, level, _, zone, _, _, online, status, class = GetGuildRosterInfo(i)
    if (fullname ~= nil) then
      local memberName = strsplit(NAME_SEPERATOR, fullname)
      if (name == memberName) then
        return true
      end
    end
  end
  return false
end

local addOrUpdatePlayer = function(name, x, y, continentId, hp, fromMessage)
  local player = players[name]
  if (not player) then
    player = {}
    local pin, texture = findNextPin()
    pin.Player = player
    player.WorldmapPin = pin
    player.WorldmapTexture = texture
    pin = nil
    texture = nil
    pin, texture = findNextPin()
    pin.Player = player
    player.MinimapPin = pin
    player.MinimapTexture = texture
    player.X = 0
    player.Y = 0
    player.ContinentId = nil
    player.Class = getClass(name)
    player.Name = name
    player.InGuild = getInGuild(name)
    players[name] = player
  end
  player.HP = hp

  if (player.LastChangeFromMessage and not fromMessage and isDungeonCoords(player.X, player.Y, player.ContinentID)) then
    return -- skip updates from blizzard coords when dungeon coordinates are present.
  end

  player.LastChangeFromMessage = fromMessage
  player.PendingLocationChange = (x ~= player.X or y ~= player.Y or continentId ~= player.ContinentId)
  player.X = x 
  player.Y = y
  player.ContinentId = continentId
end

local destroyPlayer = function(name)
  local player = players[name]
  if (player ~= nil) then
    players[name] = nil
    VGT.LIBS.HBDP:RemoveWorldMapIcon(MODULE_NAME, player.WorldmapPin)
    VGT.LIBS.HBDP:RemoveMinimapIcon(MODULE_NAME, player.MinimapPin)
  end
end

local worldPosition = function(decimals)
  local x, y, instanceMapId = VGT.LIBS.HBD:GetPlayerWorldPosition()
  local dungeon = (VGT.dungeons[instanceMapId] or VGT.raids[instanceMapId])
  if (dungeon ~= nil and dungeon[2] ~= nil and dungeon[3] ~= nil and dungeon[4] ~= nil) then
    x = dungeon[2]
    y = dungeon[3]
  end
  return VGT.Round(x, decimals or 0), VGT.Round(y, decimals or 0), instanceMapId
end

local sendMyLocation = function()
  if (VGT.OPTIONS.MAP.sendMyLocation) then
    local x, y, instanceMapId = worldPosition()
    local hp = UnitHealth(PLAYER) / UnitHealthMax(PLAYER)
    if (instanceMapId ~= nil and x ~= nil and y ~= nil and hp ~= nil) then
      local data = instanceMapId..DELIMITER..x..DELIMITER..y..DELIMITER..hp
      if (IsInGuild()) then
        VGT.LIBS:SendCommMessage(MODULE_NAME, data, COMM_CHANNEL, nil, COMM_PRIORITY)
      end
    end
  end
end

local updatePins = function()
  for bpin in VGT.LIBS.HBDP.worldmapProvider:GetMap():EnumeratePinsByTemplate("GroupMembersPinTemplate") do
    bpin.unitAppearanceData["raid"] = hiddenAppearanceData
    bpin.unitAppearanceData["party"] = hiddenAppearanceData
  end

  for name, player in pairs(players) do
    if (player.PendingLocationChange) then
      VGT.LIBS.HBDP:RemoveWorldMapIcon(MODULE_NAME, player.WorldmapPin)
      VGT.LIBS.HBDP:RemoveMinimapIcon(MODULE_NAME, player.MinimapPin)
      if (UnitInParty(name)) then
        player.MinimapTexture:SetTexCoord(0.00, 0.26, 0.26, 0.51) -- Blue
        player.WorldmapTexture:SetTexCoord(0.00, 0.26, 0.26, 0.51) -- Blue
      else
        player.MinimapTexture:SetTexCoord(0.51, 0.76, 0.00, 0.26) -- Green
        player.WorldmapTexture:SetTexCoord(0.51, 0.76, 0.00, 0.26) -- Green
      end
      if (player.ContinentId ~= nil and player.X ~= nil and player.Y ~= nil) then
        if (VGT.OPTIONS.MAP.mode ~= "minimap") then
          VGT.LIBS.HBDP:AddWorldMapIconWorld(MODULE_NAME, player.WorldmapPin, player.ContinentId, player.X, player.Y, 3, "PIN_FRAME_LEVEL_GROUP_MEMBER")
        end
        if (VGT.OPTIONS.MAP.mode ~= "map" and not UnitIsUnit(name, "player")) then
          VGT.LIBS.HBDP:AddMinimapIconWorld(MODULE_NAME, player.MinimapPin, player.ContinentId, player.X, player.Y, false)
        end
      end
      player.PendingLocationChange = false
    end
  end
  VGT.LIBS.HBDP.worldmapProvider:RefreshAllData()
end

local addOrUpdatePartyMember = function(unit)
  local name = UnitName(unit)
  if (name ~= nil) then
    local x, y, continentId = VGT.LIBS.HBD:GetUnitWorldPosition(name)
    addOrUpdatePlayer(name, x, y, continentId, UnitHealth(name) / UnitHealthMax(name), false)
  end
end

local updatePartyMembers = function()
  if (VGT.OPTIONS.MAP.showMe) then
    addOrUpdatePartyMember("player")
  else
    destroyPlayer(UnitName(PLAYER))
  end
  if (UnitPlayerOrPetInRaid("player")) then
    for i = 1, 40 do
      addOrUpdatePartyMember("raid"..i)
    end
  else
    if (UnitPlayerOrPetInParty("player")) then
      for i = 1, 5 do
        addOrUpdatePartyMember("party"..i)
      end
    end
  end
  for name, player in pairs(players) do
    if (not UnitPlayerOrPetInParty(name) and not UnitPlayerOrPetInRaid(name) and not player.InGuild) then
      destroyPlayer(name)
    end
  end
end

local parseMessage = function(message)
  local continentIdString, xString, yString, hpString = strsplit(DELIMITER, message)
  return tonumber(continentIdString), tonumber(xString), tonumber(yString), tonumber(hpString)
end

local handleMapMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local playerName = UnitName(PLAYER)
  if (not VGT.OPTIONS.MAP.showMe and sender == playerName) then
    destroyPlayer(playerName)
    return
  end

  local continentId, x, y, hp = parseMessage(message)

  if (continentId ~= nil and x ~= nil and y ~= nil) then
    if (sender ~= playerName and not UnitInParty(sender)) then
      addOrUpdatePlayer(sender, x, y, continentId, hp, true)
    end
  end
end

local updateFromGuildRoster = function()
  local numTotalMembers = GetNumGuildMembers()
  for i = 1, numTotalMembers do
    local fullname, _, _, level, _, zone, _, _, online, status, class = GetGuildRosterInfo(i)
    if (fullname ~= nil) then
      local name = strsplit(NAME_SEPERATOR, fullname)
      local player = players[name]

      if (player ~= nil) then
        if (not online) then
          destroyPlayer(name)
        else
          player.InGuild = true
          player.Zone = zone
          if (player.Zone ~= nil) then
            local dungeonId = (VGT.dungeons[player.Zone] or VGT.raids[player.Zone])
            if (dungeonId ~= nil) then
              local dungeon = (VGT.dungeons[dungeonId] or VGT.raids[dungeonId])
              if (dungeon ~= nil and dungeon[2] ~= nil and dungeon[3] ~= nil and dungeon[4] ~= nil) then
                addOrUpdatePlayer(name, dungeon[2], dungeon[3], dungeon[4], player.HP, true)
              end
            end
          end
        end
      end
    end
  end
end

local onEvent = function(_, event)
  if (event == "GUILD_ROSTER_UPDATE") then
    updateFromGuildRoster()
  end
end

local lastUpdate = GetTime()
local main = function()
  local now = GetTime()
  local delay = 3
  if (UnitAffectingCombat(PLAYER)) then
    delay = 6
  end
  if (select(1, IsInInstance())) then
    delay = 60
  end
  if (UnitIsAFK(PLAYER)) then
    delay = 120
  end
  updatePartyMembers()
  updateFromGuildRoster()
  updatePins()
  if (now - lastUpdate >= delay) then
    sendMyLocation()
    lastUpdate = now
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

local initialized = false
function VGT.Map_Initialize()
  if (VGT.OPTIONS.MAP.enabled) then
    if (not initialized) then
      createBufferPins()
      VGT.LIBS:RegisterComm(MODULE_NAME, handleMapMessageReceivedEvent)
      initialized = true
    end
  end
end
FRAME:RegisterEvent("GUILD_ROSTER_UPDATE")
FRAME:SetScript("OnEvent", onEvent)
FRAME:SetScript("OnUpdate", main)