local MODULE_NAME = "VGT-Map"
local UPDATE_SPEED = 6
local BUFFER_STEP = 10
local bufferPins = {}
local players = {}
local pins = {}

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

-- PLAYERS INDEXING
local ACTIVE_INDEX = 1
local PIN_INDEX = 2
local MAP_ID_INDEX = 3
local X_INDEX = 4
local Y_INDEX = 5
local HP_INDEX = 6

-- PINS INDEXING
local NAME_INDEX = 1

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local sendMyLocation = function()
  local playerName = UnitName(PLAYER)
  local _, _, _, _, _, _, _, instanceMapId = GetInstanceInfo()
  local x, y = HBD:GetPlayerWorldPosition()
  local hp = UnitHealth(PLAYER) / UnitHealthMax(PLAYER)
  if (playerName ~= nil and instanceMapId ~= nil and x ~= nil and y ~= nil and hp ~= nil) then
    local data = playerName..DELIMITER..instanceMapId..DELIMITER..x..DELIMITER..y..DELIMITER..hp
    if (IsInGuild()) then
      ACE:SendCommMessage(MODULE_NAME, data, GUILD, BULK)
    end
  end
end

local findClosePlayers = function(x, y)
  local closePlayers = NEW_LINE
  for k, v in pairs(players) do
    if (abs(x - v[X_INDEX]) + abs(y - v[Y_INDEX]) < 50) then
      closePlayers = closePlayers..k..HP_SEPERATOR..Round(v[HP_INDEX] * 100, 0)..PERCENT..NEW_LINE
    end
  end
  return closePlayers
end

local onEnterPin = function(self)
  local x, y = self:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if (x > parentX) then
    GameTooltip:SetOwner(self, ANCHOR_LEFT)
  else
    GameTooltip:SetOwner(self, ANCHOR_RIGHT)
  end

  local name = pins[self][NAME_INDEX]
  GameTooltip:SetText(name..HP_SEPERATOR..Round(players[name][6] * 100, 0)..PERCENT..findClosePlayers(x, y))
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
      PINS:RemoveWorldMapIcon(MODULE_NAME, pin)
      players[k][NAME_INDEX] = false
    end
  end
end

local updatePins = function()
  sendMyLocation()
  cleanPins()
  if (WorldFrame ~= nil and WorldMapFrame:IsVisible()) then
    local w, h = WorldFrame:GetWidth(), WorldFrame:GetHeight()
    for k, v in pairs(players) do
      if ((v[ACTIVE_INDEX] == nil or v[ACTIVE_INDEX]) and v[PIN_INDEX] ~= nil and v[MAP_ID_INDEX] ~= nil and v[X_INDEX] ~= nil and v[Y_INDEX] ~= nil) then
        PINS:AddWorldMapIconWorld(MODULE_NAME, v[PIN_INDEX], tonumber(v[MAP_ID_INDEX]), tonumber(v[X_INDEX]), tonumber(v[Y_INDEX]), 3)
      end
    end
  end
end

local createBufferPins = function()
  for i = 1, BUFFER_STEP do
    local pin = CreateFrame(FRAME, nil, WorldFrame)
    pin:SetWidth(10)
    pin:SetHeight(10)
    local texture = pin:CreateTexture(nil, BACKGROUND)
    texture:SetTexture(PIN_TEXTURE)
    texture:SetTexCoord(0.51, 0.76, 0.00, 0.26)
    texture:SetAllPoints()
    pin:EnableMouse(true)
    pin:SetScript(SCRIPT_ENTER, onEnterPin)
    pin:SetScript(SCRIPT_LEAVE, onLeavePin)
    bufferPins[i] = pin
  end
end

local findPin = function()
  for i = 1, Count(bufferPins) do
    if (bufferPins[i] ~= nil) then
      local pin = bufferPins[i]
      bufferPins[i] = nil
      return pin
    end
  end
  createBufferPins()
end

local findNextPin = function()
  local pin
  while (pin == nil) do
    pin = findPin()
  end
  return pin
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
  local pin
  if (players[playerName] == nil) then
    pin = findNextPin()
  else
    pin = players[playerName][PIN_INDEX]
  end
  players[playerName] = {true, pin, instanceMapId, x, y, hp}
  pins[pin] = {playerName}
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function VGT_Map_Initialize()
  createBufferPins()
  ACE:RegisterComm(MODULE_NAME, handleMapMessageReceivedEvent)
  ACE:ScheduleRepeatingTimer(updatePins, UPDATE_SPEED)
end
