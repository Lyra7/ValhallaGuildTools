local MODULE_NAME = "VGT-Map"
local FRAME = CreateFrame("Frame")

local bufferSize = 0
local bufferPins = {}
local players = {}
local zoneCache = {}

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

local originalPinsHidden = false
local originalPartyAppearanceData
local originalRaidAppearanceData
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

local formatTooltip = function(player, distance)
  local text = ""

  if (player.Zone ~= nil) then
    text = player.Zone..NEW_LINE
  end

  text = text..formatPlayerTooltip(player)
  
  for _, otherPlayer in pairs(players) do
    if (otherPlayer ~= player and otherPlayer.X ~= nil and otherPlayer.Y ~= nil and player.X ~= nil and player.Y ~= nil and (abs(player.X - otherPlayer.X) + abs(player.Y - otherPlayer.Y) < distance)) then
      text = text..NEW_LINE..formatPlayerTooltip(otherPlayer)
    end
  end

  return text
end

local onLeavePin = function(self)
  GameTooltip:Hide()
end

local createNewPin = function()
  local pin = CreateFrame(FRAME_TYPE, nil, WorldFrame)
  pin:SetWidth(PIN_SIZE)
  pin:SetHeight(PIN_SIZE)
  local texture = pin:CreateTexture(nil, BACKGROUND)
  texture:SetTexCoord(0.51, 0.76, 0.00, 0.26) -- Green
  texture:SetAllPoints()
  pin:EnableMouse(true)
  pin.Texture = texture
  return pin
end

local takeFromBufferPool = function()
  if (bufferSize == 0) then
    return createNewPin()
  end
  local pin = bufferPins[bufferSize]
  bufferSize = bufferSize - 1
  return pin
end

local returnToBufferPool = function(pin)
  bufferSize = bufferSize + 1
  bufferPins[bufferSize] = pin
end

local createWorldmapPin = function(player)
  local onEnterPin = function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    local distance = 50
    local mapId = VGT.LIBS.HBDP.worldmapProvider:GetMap():GetMapID()
    if (mapId) then
      local mapData = VGT.LIBS.HBD.mapData[mapId]
      if (mapData and mapData.mapType) then
        --todo: these are just my best guesses of distances. Probably should be tweaked.
        if (mapData.mapType == 1) then --world
          distance = 300
        end
        if (mapData.mapType == 2) then --continent
          distance = 100
        end
        if (mapData.mapType == 3) then --zone or city
          distance = 25
        end
      end
    end
    GameTooltip:SetText(formatTooltip(self.Player, distance))
    GameTooltip:Show()
  end
  local pin = takeFromBufferPool()
  pin:SetScript(SCRIPT_ENTER, onEnterPin)
  pin:SetScript(SCRIPT_LEAVE, onLeavePin)
  pin.Texture:SetTexture(PIN_TEXTURE)
  pin.Player = player
  player.WorldmapPin = pin
  player.WorldmapTexture = pin.Texture
end

local createMinimapPin = function(player)
  local onEnterPin = function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    local distance = 15
    --todo set distance for minimap based on zoom level
    GameTooltip:SetText(formatTooltip(self.Player, distance))
    GameTooltip:Show()
  end
  local pin = takeFromBufferPool()
  pin:SetScript(SCRIPT_ENTER, onEnterPin)
  pin:SetScript(SCRIPT_LEAVE, onLeavePin)
  pin.Texture:SetTexture(PIN_TEXTURE)
  pin.Player = player
  player.MinimapPin = pin
  player.MinimapTexture = pin.Texture
end

local getClass = function(name)
  if (UnitPlayerOrPetInParty(name)) then
    for i = 1, 5 do
      local unitId = "party"..i
      if (UnitName(unitId) == name) then
        local class = select(2, UnitClass(unitId))
        if class then return class end
      end
    end
  end
  if (UnitPlayerOrPetInRaid(name)) then
    for i = 1, 40 do
      local unitId = "raid"..i
      if (UnitName(unitId) == name) then
        local class = select(2, UnitClass(unitId))
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

local getInGuild = function(name, fromCommMessage)
  if (fromCommMessage) then return true end
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

local addOrUpdatePlayer = function(name, x, y, continentId, hp, fromCommMessage, zone)
  local player = players[name]
  if (not player) then
    player = {}
    createMinimapPin(player)
    createWorldmapPin(player)
    player.X = 0
    player.Y = 0
    player.ContinentId = nil
    player.Class = getClass(name)
    player.Name = name
    player.InGuild = getInGuild(name, fromCommMessage)
    player.HasCommMessages = false
    player.LastCommReceived = 0
    players[name] = player
  end

  if (fromCommMessage) then
    player.HasCommMessages = true
    player.LastCommReceived = GetTime()
  end

  player.HP = hp
  player.Zone = zone
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
    returnToBufferPool(player.WorldmapPin)
    returnToBufferPool(player.MinimapPin)
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
  if (C_PvP.IsPVPMap()) then
    if (originalPinsHidden and originalPartyAppearanceData and originalRaidAppearanceData) then
      for bpin in VGT.LIBS.HBDP.worldmapProvider:GetMap():EnumeratePinsByTemplate("GroupMembersPinTemplate") do
        bpin.unitAppearanceData["raid"] = originalRaidAppearanceData
        bpin.unitAppearanceData["party"] = originalPartyAppearanceData
        originalPinsHidden = false
      end
    end
  else
    if (not originalPinsHidden) then
      for bpin in VGT.LIBS.HBDP.worldmapProvider:GetMap():EnumeratePinsByTemplate("GroupMembersPinTemplate") do
        if (not originalRaidAppearanceData) then
          originalPartyAppearanceData = bpin.unitAppearanceData["raid"]
        end
        if (not originalPartyAppearanceData) then
          originalRaidAppearanceData = bpin.unitAppearanceData["party"]
        end
        bpin.unitAppearanceData["raid"] = hiddenAppearanceData
        bpin.unitAppearanceData["party"] = hiddenAppearanceData
        originalPinsHidden = true
      end
    end
  end

  for name, player in pairs(players) do
    if (player.PendingLocationChange) then
      --VGT.LIBS.HBDP:RemoveWorldMapIcon(MODULE_NAME, player.WorldmapPin)
      --VGT.LIBS.HBDP:RemoveMinimapIcon(MODULE_NAME, player.MinimapPin)
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
          VGT.LIBS.HBDP:AddMinimapIconWorld(MODULE_NAME, player.MinimapPin, player.ContinentId, player.X, player.Y, VGT.OPTIONS.MAP.showMinimapOutOfBounds and UnitInParty(name))
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
    local x, y, continentOrInstanceId = VGT.LIBS.HBD:GetUnitWorldPosition(name)

    if (x == nil or y == nil) then
      local dungeon = (VGT.dungeons[continentOrInstanceId] or VGT.raids[continentOrInstanceId])
      if (dungeon ~= nil and dungeon[2] ~= nil and dungeon[3] ~= nil and dungeon[4] ~= nil) then
        addOrUpdatePlayer(name, dungeon[2], dungeon[3], dungeon[4], UnitHealth(unit) / UnitHealthMax(unit), false, dungeon[1])
        return
      else
        --destroyPlayer(name) -- Unit is in an unknown instance. Don't show a pin.
      end
    end

    local zone
    local mapId = C_Map.GetBestMapForUnit(unit)
    if (mapId) then
      local mapInfo = C_Map.GetMapInfo(mapId)
      if (mapInfo) then
        zone = mapInfo.name
      end
    end
    
    addOrUpdatePlayer(name, x, y, continentOrInstanceId, UnitHealth(unit) / UnitHealthMax(unit), false, zone)
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
          zoneCache[name] = nil
          destroyPlayer(name)
        else
          zoneCache[name] = zone
          player.InGuild = true
          player.Zone = zone
          player.Class = class
        end
      end
    end
  end
end

local getZoneFromGuild = function(name)
  local zone = zoneCache[name]

  if not zone then
    updateFromGuildRoster()
    zone = zoneCache[name]
  end

  return zone
end

local parseMessage = function(message)
  local continentIdString, xString, yString, hpString = strsplit(DELIMITER, message)
  return tonumber(continentIdString), tonumber(xString), tonumber(yString), tonumber(hpString)
end

local handleMapMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local continentId, x, y, hp = parseMessage(message)

  if (continentId ~= nil and x ~= nil and y ~= nil and not UnitIsUnit(sender, PLAYER) and not UnitInParty(sender)) then
    addOrUpdatePlayer(sender, x, y, continentId, hp, true, getZoneFromGuild(sender))
  end
end

local onEvent = function(_, event)
  if (event == "GUILD_ROSTER_UPDATE") then
    updateFromGuildRoster()
  end
end

local cleanUnusedPins = function()
  for name, player in pairs(players) do
    local destroy = false

    if (not UnitInParty(name) and not player.HasCommMessages and not UnitIsUnit(name, PLAYER)) then
      destroyPlayer(name) -- remove non-party members that aren't sending comm messages
    end

    if (player.HasCommMessages and player.LastCommReceived and (GetTime() - player.LastCommReceived) > 180) then
      destroyPlayer(name) -- remove pins that haven't had a new comm message in 3 minutes. (happens if a user disables reporting, or if the addon crashes)
    end
  end
end

local initialized = false
local lastUpdate = GetTime()
local main = function()
  if (initialized) then
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
    cleanUnusedPins()
    updatePins()
    if (now - lastUpdate >= delay) then
      sendMyLocation()
      lastUpdate = now
    end
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function VGT.Map_Initialize()
  if (VGT.OPTIONS.MAP.enabled) then
    if (not initialized) then
      VGT.LIBS:RegisterComm(MODULE_NAME, handleMapMessageReceivedEvent)
      initialized = true
    end
  end
end
FRAME:RegisterEvent("GUILD_ROSTER_UPDATE")
FRAME:SetScript("OnEvent", onEvent)
FRAME:SetScript("OnUpdate", main)