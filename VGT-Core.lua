VGT_ADDON_NAME, VGT = ...
VGT.VERSION = GetAddOnMetadata(VGT_ADDON_NAME, "Version")
VGT.LIBS = LibStub("AceAddon-3.0"):NewAddon(VGT_ADDON_NAME,
"AceComm-3.0", "AceTimer-3.0", "AceEvent-3.0")
VGT.LIBS.HBD = LibStub("HereBeDragons-2.0")
VGT.LIBS.HBDP = LibStub("HereBeDragons-Pins-2.0")
VGT.CORE_FRAME = CreateFrame("Frame")
local MODULE_NAME = "VGT-Core"

local REQUEST_VERSION_MESSAGE = "ReqV";
local RESPOND_VERSION_MESSAGE = "ResV";
local RESPOND_VERSION_MESSAGE_LENGTH = string.len(RESPOND_VERSION_MESSAGE);
local EnumeratingUsers = false;
local users = {};

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local handleInstanceChangeEvent = function()
  local _, instanceType, _, _, _, _, _, instanceID, _, _ = GetInstanceInfo()
  if (instanceType == "party" or instanceType == "raid") then
    local dungeonData = nil
    if (VGT.trackedRaids[tonumber(instanceID)]) then
      dungeonData = VGT.raids[tonumber(instanceID)]
    else
      dungeonData = VGT.dungeons[tonumber(instanceID)]
    end
    if (dungeonData ~= nil) then
      local dungeonName = dungeonData[1]
      if (dungeonName ~= nil) then
        VGT.Log(VGT.LOG_LEVEL.INFO, "Started logging for %s, goodluck!", dungeonName)
        VGT.CORE_FRAME:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
      else
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "Entered %s(%s) but it is not a tracked dungeon.", (dungeonName or "?"), (instanceID or "?"))
      end
    end
  else
    VGT.CORE_FRAME:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

local warned = false
local warnedPlayers = {}
local handleCoreMessageReceivedEvent = function(prefix, message, _, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  if (message == REQUEST_VERSION_MESSAGE) then
    VGT.LIBS:SendCommMessage(MODULE_NAME, RESPOND_VERSION_MESSAGE..VGT.VERSION, "WHISPER", sender);
  elseif (string.sub(message, 1, RESPOND_VERSION_MESSAGE_LENGTH) == RESPOND_VERSION_MESSAGE) then
    users[sender] = string.sub(message, RESPOND_VERSION_MESSAGE_LENGTH + 1);
  else
    local playerName = UnitName("player")
    if (sender == playerName) then
      return
    end

    local event, version = strsplit(":", message)
    if (event == "SYNCHRONIZATION_REQUEST") then
      if (not warnedPlayers[sender] and version ~= nil and tonumber(version) < tonumber(VGT.VERSION)) then
        VGT.LIBS:SendCommMessage(MODULE_NAME, "VERSION:"..VGT.VERSION, "WHISPER", sender)
        warnedPlayers[sender] = true
      end
    elseif (event == "VERSION") then
      local myVersion = tonumber(VGT.VERSION)
      local theirVersion = tonumber(version)
      if (not warned and myVersion < theirVersion) then
        VGT.Log(VGT.LOG_LEVEL.WARN, "there is a newer version of this addon (%s < %s)", myVersion, theirVersion)
        warned = true
      end
    end
  end
end

local loaded = false
local entered = false
local rostered = false
local function onEvent(_, event)
  if (not loaded and event == "ADDON_LOADED") then
    VGT.OPTIONS = VGT.DefaultConfig(VGT_OPTIONS)
    loaded = true
  end

  if (VGT.OPTIONS.enabled) then
    if (loaded and event == "ADDON_LOADED") then
      VGT.Map_Initialize()
      VGT.LIBS:RegisterComm(MODULE_NAME, handleCoreMessageReceivedEvent)
    end
    if (loaded) then
      if (event == "PLAYER_ENTERING_WORLD") then
        handleInstanceChangeEvent(event)
        if (not entered) then
          GuildRoster()
          if (IsInGuild()) then
            VGT.LIBS:SendCommMessage(MODULE_NAME, "SYNCHRONIZATION_REQUEST:"..VGT.VERSION, "GUILD")
          end
          VGT.Log(VGT.LOG_LEVEL.TRACE, "initialized with version %s", VGT.VERSION)
          entered = true
        end
      end
      if (not rostered and event == "GUILD_ROSTER_UPDATE") then

        if (IsInGuild()) then
          VGT.EP_Initialize()
          rostered = true
        end
      end
      if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
        VGT.HandleCombatLogEvent(event)
      end
    end
  end
  if (loaded and event == "PLAYER_LOGOUT") then
    VGT_OPTIONS = VGT.OPTIONS
  end
end
VGT.CORE_FRAME:RegisterEvent("ADDON_LOADED")
VGT.CORE_FRAME:RegisterEvent("PLAYER_ENTERING_WORLD")
VGT.CORE_FRAME:RegisterEvent("GUILD_ROSTER_UPDATE")
VGT.CORE_FRAME:RegisterEvent("PLAYER_LOGOUT")
VGT.CORE_FRAME:SetScript("OnEvent", onEvent)
