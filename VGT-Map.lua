local MODULE_NAME = "VGT-Map"
local DELIMITER = ":"
local players = {}
local pins = {}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

function round(number, decimals)
  return (("%%.%df"):format(decimals)):format(number)
end

local sendMyLocation = function()
  local playerName = UnitName("player")
  local _, _, _, _, _, _, _, instanceMapId, _ = GetInstanceInfo()
  local x, y = HBD:GetPlayerWorldPosition()
  local hp = UnitHealth("player") / UnitHealthMax("player")
  if (playerName ~= nil and instanceMapId ~= nil and x ~= nil and y ~= nil and hp ~= nil) then
    local data = playerName..DELIMITER..instanceMapId..DELIMITER..x..DELIMITER..y..DELIMITER..hp
    ACE:SendCommMessage(MODULE_NAME, data, "GUILD")
  end
end

local showPin = function(self)
  local x, y = self:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if (x > parentX) then
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  else
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  end

  local name = pins[self][1]
  local hp = round(tonumber(players[name][5]) * 100, 0)
  GameTooltip:SetText(name.." - "..hp.."%")
  GameTooltip:Show()
end

local hidePin = function(self)
  GameTooltip:Hide()
end

local updatePins = function()
  sendMyLocation()
  if (WorldFrame ~= nil and WorldMapFrame:IsVisible()) then
    local w, h = WorldFrame:GetWidth(), WorldFrame:GetHeight()
    for k, v in pairs(players) do
      if (v[1] ~= nil and v[2] ~= nil and v[3] ~= nil and v[4] ~= nil) then
        PINS:AddWorldMapIconWorld(MODULE_NAME, v[1], tonumber(v[2]), tonumber(v[3]), tonumber(v[4]), 3)
      end
    end
  end
end

local handleMapMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local playerName = UnitName("player")
  if (sender == playerName) then
    return
  end

  local playerName, instanceMapId, x, y, hp = strsplit(DELIMITER, message)
  local pin
  if (players[playerName] == nil) then
    pin = CreateFrame("Frame", nil, WorldFrame)
    pin:SetWidth(10)
    pin:SetHeight(10)
    local texture = pin:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\MINIMAP\\ObjectIcons.blp")
    texture:SetTexCoord(0.51, 0.76, 0.00, 0.26)
    texture:SetAllPoints()
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", showPin)
    pin:SetScript("OnLeave", hidePin)
  else
    pin = players[playerName][1]
  end
  players[playerName] = {pin, instanceMapId, x, y, hp}
  pins[pin] = {playerName}
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function VGT_Map_Initialize()
  ACE:RegisterComm(MODULE_NAME, handleMapMessageReceivedEvent)
  ACE:ScheduleRepeatingTimer(updatePins, 1)
end
