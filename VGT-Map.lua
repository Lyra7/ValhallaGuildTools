local MODULE_NAME = "VGT-Map"

local BUFFER_STEP = 10
local bufferPins = {}
local players = {}
local pins = {}
local isMapVisible = false

local FRAME = "Frame"
local PLAYER = "player"
local GUILD = "GUILD"
local BULK = "BULK"
local PERCENT = "%"
local NEW_LINE = "\n"
local DELIMITER = ":"
local NAME_SEPERATOR = "-"
local HP_SEPERATOR = " - "
local ANCHOR_LEFT = "ANCHOR_LEFT"
local ANCHOR_RIGHT = "ANCHOR_RIGHT"
local BACKGROUND = "BACKGROUND"
local SCRIPT_ENTER = "OnEnter"
local SCRIPT_LEAVE = "OnLeave"
local PIN_TEXTURE = "Interface\\MINIMAP\\ObjectIcons.blp"

local PIN_SIZE = 10

-- PLAYERS INDEXING
local ACTIVE_INDEX = 1
local PIN_INDEX = 2
local TEXTURE_INDEX = 3
local MAP_ID_INDEX = 4
local X_INDEX = 5
local Y_INDEX = 6
local HP_INDEX = 7

-- PINS INDEXING
local NAME_INDEX = 1

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local sendMyLocation = function()
  if (VGT.OPTIONS.MAP.sendMyLocation) then
    local playerName = UnitName(PLAYER)
    local _, _, _, _, _, _, _, instanceMapId = GetInstanceInfo()
    local x, y = VGT.LIBS.HBD:GetPlayerWorldPosition()
    local hp = UnitHealth(PLAYER) / UnitHealthMax(PLAYER)
    if (playerName ~= nil and instanceMapId ~= nil and x ~= nil and y ~= nil and hp ~= nil) then
      local data = playerName..DELIMITER..instanceMapId..DELIMITER..x..DELIMITER..y..DELIMITER..hp
      if (IsInGuild()) then
        VGT.LIBS:SendCommMessage(MODULE_NAME, data, GUILD, nil, BULK)
      end
    end
  end
end

local findClosePlayers = function(x, y, name)
  local closePlayers = NEW_LINE
  for k, v in pairs(players) do
    if (name == nil or name ~= k) then
      if (abs(x - v[X_INDEX]) + abs(y - v[Y_INDEX]) < 50) then
        closePlayers = closePlayers..k..HP_SEPERATOR..VGT.Round(v[HP_INDEX] * 100, 0)..PERCENT..NEW_LINE
      end
    end
  end
  return closePlayers
end

local onEnterPin = function(self)
  local uiX, uiY = self:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if (uiX > parentX) then
    GameTooltip:SetOwner(self, ANCHOR_LEFT)
  else
    GameTooltip:SetOwner(self, ANCHOR_RIGHT)
  end

  local name = pins[self][NAME_INDEX]
  GameTooltip:SetText(name..HP_SEPERATOR..VGT.Round(players[name][HP_INDEX] * 100, 0)..PERCENT..findClosePlayers(players[name][X_INDEX], players[name][Y_INDEX], name))
  GameTooltip:Show()
end

local onLeavePin = function(self)
  GameTooltip:Hide()
end

local cleanPins = function()
  local guildMembersOnline = {}
  local numTotalMembers = GetNumGuildMembers()
  for i = 1, numTotalMembers do
    local fullname, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
    local name = strsplit(NAME_SEPERATOR, fullname)
    guildMembersOnline[name] = online
  end

  for k, v in pairs(players) do
    if (not guildMembersOnline[k]) then
      local pin = players[k][PIN_INDEX]
      VGT.LIBS.HBDP:RemoveWorldMapIcon(MODULE_NAME, pin)
      players[k][NAME_INDEX] = false
    end
  end
end

local validate = function(data)
  if ((data[ACTIVE_INDEX] == nil or data[ACTIVE_INDEX])
    and data[PIN_INDEX] ~= nil
    and data[TEXTURE_INDEX] ~= nil
    and data[MAP_ID_INDEX] ~= nil
    and data[X_INDEX] ~= nil
  and data[Y_INDEX] ~= nil) then
    return true
  end
  return false
end

local updatePins = function()
  sendMyLocation()
  if (isMapVisible) then
    cleanPins()
    for k, v in pairs(players) do
      if (validate(v)) then
        local texture = v[TEXTURE_INDEX]
        if (UnitInParty(k)) then
          texture:SetTexCoord(0.00, 0.26, 0.26, 0.51) -- Blue
        else
          texture:SetTexCoord(0.51, 0.76, 0.00, 0.26) -- Green
        end
        VGT.LIBS.HBDP:AddWorldMapIconWorld(MODULE_NAME, v[PIN_INDEX], tonumber(v[MAP_ID_INDEX]), tonumber(v[X_INDEX]), tonumber(v[Y_INDEX]), 3, "PIN_FRAME_LEVEL_WORLD_QUEST")
      end
    end
    HBD_GetPins().worldmapProvider:RefreshAllData()
  end
end

local createBufferPins = function()
  for i = 1, BUFFER_STEP do
    local pin = CreateFrame(FRAME, nil, WorldFrame)
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

local handleMapMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local playerName = UnitName(PLAYER)
  if (sender == playerName) then
    return
  end

  local playerName, instanceMapId, x, y, hp = strsplit(DELIMITER, message)
  local pin, texture
  if (players[playerName] == nil) then
    pin, texture = findNextPin()
  else
    pin = players[playerName][PIN_INDEX]
    texture = players[playerName][TEXTURE_INDEX]
  end
  players[playerName] = {true, pin, texture, instanceMapId, x, y, hp}
  pins[pin] = {playerName}
end

local updateMapVisibility = function()
  if (WorldMapFrame:IsVisible()) then
    isMapVisible = true
  else
    isMapVisible = false
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function VGT.Map_Initialize()
  if (VGT.OPTIONS.MAP.enabled) then
    createBufferPins()
    VGT.LIBS:RegisterComm(MODULE_NAME, handleMapMessageReceivedEvent)
    VGT.LIBS:ScheduleRepeatingTimer(updateMapVisibility, 0.1)
    VGT.LIBS:ScheduleRepeatingTimer(updatePins, VGT.OPTIONS.MAP.updateSpeed)
  end
end
