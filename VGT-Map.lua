local MODULE_NAME = "VGT-Map"
local FRAME = CreateFrame("Frame")

local BUFFER_STEP = 10
local guildMembers = {}
local bufferPins = {}
local players = {}
local pins = {}
local isMapVisible = false

local FRAME_TYPE = "Frame"
local PLAYER = "player"
local COMM_CHANNEL = "GUILD"
local COMM_PRIORITY = "NORMAL"
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

local worldPosition = function(decimals)
  local x, y, instanceMapId = VGT.LIBS.HBD:GetPlayerWorldPosition()
  local dungeon = (VGT.dungeons[instanceMapId] or VGT.raids[instanceMapId])
  if (dungeon ~= nil and dungeon[2] ~= nil and dungeon[3] ~= nil and dungeon[4] ~= nil) then
    x = dungeon[2]
    y = dungeon[3]
    --instanceMapId = dungeon[4]
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

local colorString = function(colorHex, str)
  return "|c"..colorHex..str.."|r"
end

local findClosePlayers = function(x, y, name, active)
  local closePlayers = NEW_LINE
  for k, v in pairs(players) do
    if (active and (name == nil or name ~= k)) then
      -- TODO distance needs to increase as map zooms out
      if (abs(x - v[X_INDEX]) + abs(y - v[Y_INDEX]) < 50) then
        closePlayers = closePlayers
        ..colorString(select(4, GetClassColor(guildMembers[k][6])), k)..HP_SEPERATOR
        ..colorString("ff"..VGT.RGBToHex(VGT.ColorGradient(tonumber(v[HP_INDEX]), 1, 0, 0, 1, 1, 0, 0, 1, 0)), VGT.Round(v[HP_INDEX] * 100, 0)..PERCENT)..NEW_LINE
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
  GameTooltip:SetText(guildMembers[name][3]..NEW_LINE
    ..colorString(select(4, GetClassColor(guildMembers[name][6])), name)..HP_SEPERATOR
    ..colorString("ff"..VGT.RGBToHex(VGT.ColorGradient(tonumber(players[name][HP_INDEX]), 1, 0, 0, 1, 1, 0, 0, 1, 0)), VGT.Round(players[name][HP_INDEX] * 100, 0)..PERCENT)
  ..findClosePlayers(players[name][X_INDEX], players[name][Y_INDEX], name, players[name][ACTIVE_INDEX]))
  GameTooltip:Show()
end

local onLeavePin = function(self)
  GameTooltip:Hide()
end

local removePin = function(name, pin)
  VGT.LIBS.HBDP:RemoveWorldMapIcon(MODULE_NAME, pin)
  players[name][ACTIVE_INDEX] = false
end

local cleanPins = function()
  local playerName = UnitName(PLAYER)
  for k, v in pairs(players) do
    if (k == playerName and VGT.OPTIONS.MAP.showMe == false) then
      removePin(k, players[k][PIN_INDEX])
    end
    if (not guildMembers[k][4]) then
      removePin(k, players[k][PIN_INDEX])
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
  if (isMapVisible) then
    cleanPins()
    for k, v in pairs(players) do
      if (validate(v)) then
		VGT.LIBS.HBDP:RemoveWorldMapIcon(MODULE_NAME, v[PIN_INDEX])
        local texture = v[TEXTURE_INDEX]
        if (UnitInParty(k)) then
          texture:SetTexCoord(0.00, 0.26, 0.26, 0.51) -- Blue
        else
          texture:SetTexCoord(0.51, 0.76, 0.00, 0.26) -- Green
        end
        local instanceMapId = tonumber(v[MAP_ID_INDEX])
        local instance = VGT.dungeons[instanceMapId] or VGT.raids[instanceMapId]
        if (instance ~= nil) then
          instanceMapId = instance[4]
        end
        VGT.LIBS.HBDP:AddWorldMapIconWorld(MODULE_NAME, v[PIN_INDEX], instanceMapId, tonumber(v[X_INDEX]), tonumber(v[Y_INDEX]), 3, "PIN_FRAME_LEVEL_GROUP_MEMBER")
      end
    end
  end
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

local handleMapMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local playerName = UnitName(PLAYER)
  if (not VGT.OPTIONS.MAP.showMe and sender == playerName) then
    return
  end

  local instanceMapId, x, y, hp = strsplit(DELIMITER, message)
  if (tonumber(instanceMapId)) then
    local pin, texture
    if (players[sender] == nil) then
      pin, texture = findNextPin()
    else
      pin = players[sender][PIN_INDEX]
      texture = players[sender][TEXTURE_INDEX]
    end
    players[sender] = {true, pin, texture, instanceMapId, x, y, hp}
    pins[pin] = {sender}
  end
end

local updateMapVisibility = function()
  if (WorldMapFrame:IsVisible()) then
    if (not isMapVisible) then
      isMapVisible = true
      updatePins()
    end
    isMapVisible = true
  else
    isMapVisible = false
  end
end

local onEvent = function(_, event)
  if (event == "GUILD_ROSTER_UPDATE") then
    local numTotalMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
      local fullname, _, _, level, _, zone, _, _, online, status, class = GetGuildRosterInfo(i)
      if (fullname ~= nil) then
        local name = strsplit(NAME_SEPERATOR, fullname)
        guildMembers[name] = {name, level, zone, online, status, class}
      end
    end
  end
end

local lastUpdate = GetTime()
local main = function(timer)
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
  updateMapVisibility()
  if (now - lastUpdate >= delay) then
    sendMyLocation()
    updatePins()
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
      VGT.LIBS:ScheduleRepeatingTimer(main, 0.05)
      initialized = true
    end
  end
end
FRAME:RegisterEvent("GUILD_ROSTER_UPDATE")
FRAME:SetScript("OnEvent", onEvent)
