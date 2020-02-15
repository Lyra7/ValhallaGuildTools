VGT_ADDON_NAME, VGT = ...
VGT.VERSION = GetAddOnMetadata(VGT_ADDON_NAME, "Version")
VGT.LIBS = LibStub("AceAddon-3.0"):NewAddon(VGT_ADDON_NAME,
"AceComm-3.0", "AceTimer-3.0", "AceEvent-3.0")
VGT.LIBS.HBD = LibStub("HereBeDragons-2.0")
VGT.LIBS.HBDP = LibStub("HereBeDragons-Pins-2.0")
VGT.CORE_FRAME = CreateFrame("Frame")
local MODULE_NAME = "VGT-Core"

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local handleInstanceChangeEvent = function()
  local _, instanceType, _, _, _, _, _, instanceID, _, _ = GetInstanceInfo()
  if (instanceType == "party" or instanceType == "raid") then
    local dungeonData = VGT.dungeons[tonumber(instanceID)]
    if (dungeonData ~= nil) then
      local dungeonName = dungeonData[1]
      if (dungeonName ~= nil) then
        VGT.Log(VGT.LOG_LEVEL.INFO, "Started logging for %s, goodluck!", dungeonName)
        VGT.CORE_FRAME:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
      else
        VGT.Log(VGT.LOG_LEVEL.DEBUG, "Entered %s(%s) but it is not a tracked dungeon.", dungeonName, instanceID)
      end
    end
  else
    VGT.CORE_FRAME:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function VGT.CommAvailability()
  return (floor(_G.ChatThrottleLib:UpdateAvail()) / 4000) * 100
end

function VGT.ColorGradient(perc, ...)
  if perc >= 1 then
    local r, g, b = select(select('#', ...) - 2, ...)
    return r, g, b
  elseif perc <= 0 then
    local r, g, b = ...
    return r, g, b
  end
  local num = select('#', ...) / 3
  local segment, relperc = math.modf(perc * (num - 1))
  local r1, g1, b1, r2, g2, b2 = select((segment * 3) + 1, ...)
  return r1 + (r2 - r1) * relperc, g1 + (g2 - g1) * relperc, b1 + (b2 - b1) * relperc
end

function VGT.RGBToHex(r, g, b)
  r = r <= 1 and r >= 0 and r or 0
  g = g <= 1 and g >= 0 and g or 0
  b = b <= 1 and b >= 0 and b or 0
  return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

function VGT.Round(number, decimals)
  if (number == nil) then
    number = 0
  end
  if (decimals == nil) then
    decimals = 0
  end
  return (("%%.%df"):format(decimals)):format(number)
end

function VGT.Safe(s)
  if (s == nil) then
    return ""
  end
  return s
end

function VGT.Count(t)
  local c = 0
  if (t == nil) then
    return c
  end
  if (type(t) ~= "table") then
    return c
  end
  for _, _ in pairs(t) do
    c = c + 1
  end
  return c
end

function VGT.ArrayToSet(array)
  local t = {}
  for _, item in pairs(array) do
    t[item] = true
  end
  return t
end

function VGT.SubsetCount(a, b)
  local c = 0
  for k, _ in pairs(a) do
    if (b[k]) then
      c = c + 1
    end
  end
  return c
end

function VGT.StringAppend(...)
  local args = {...}
  local str = ""
  for _, v in ipairs(args) do
    if (v ~= nil) then
      str = str..tostring(v)
    end
  end
  return str
end

function VGT.TableJoinToArray(a, b)
  local nt = {}
  for _, v in pairs(a) do
    nt[v] = v
  end
  for _, v in pairs(b) do
    nt[v] = v
  end
  return nt
end

function VGT.TableKeysToString(t, d)
  return VGT.TableToString(t, d, true)
end

function VGT.TableToString(t, d, keys, sort, line)
  local s = ""

  if (t == nil) then
    return s
  end

  if (d == nil) then
    d = ","
  end

  if (sort == true) then
    table.sort(t)
    local nt = {}
    for _, v in pairs(t) do
      table.insert(nt, v)
    end
    table.sort(nt)
    t = nt
  end

  for k, v in pairs(t) do
    s = s..d
    if (type(v) == "table") then
      s = s..VGT.TableToString(v, d, keys, sort, line)
    else
      local c = nil
      if (keys) then
        c = k
      else
        c = v
      end
      if (line) then
        s = s..c.."\n"
      else
        s = s..c
      end
    end
  end

  if (d ~= nil and d ~= "") then
    return string.sub(s, 2)
  else
    return s
  end
end

function VGT.TableContains(t, m)
  if (t == nil) then
    return false
  end

  for _, v in pairs(t) do
    if (v == m) then
      return true
    end
  end

  return false
end

function VGT.RandomUUID()
  local template = 'xxxxxxxx'
  return string.gsub(template, '[xy]', function (c) local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb) return string.format('%x', v) end)
end

function VGT.GetMyGuildName()
  if (IsInGuild()) then
    return GetGuildInfo("player")
  else
    return nil
  end
end

function VGT.IsInMyGuild(playerName)
  if (playerName == nil) then
    return false
  end

  local playerGuildName = GetGuildInfo(playerName)
  if (playerGuildName == nil) then
    return false
  end

  local myGuildName = VGT.GetMyGuildName()
  if (myGuildName == nil) then
    return false
  end

  if (myGuildName == playerGuildName) then
    return true
  end

  return false
end

function VGT.CheckGroupForGuildies()
  if (IsInGroup() ~= true) then
    return nil
  end

  local groupMembers = GetHomePartyInfo()
  local guildGroupMembers = {}
  local p = 0
  for i = 0, GetNumGroupMembers() do
    local groupMember = groupMembers[i]
    if (VGT.IsInMyGuild(groupMember)) then
      guildGroupMembers[p] = groupMember
      VGT.Log(VGT.LOG_LEVEL.TRACE, "%s is in my guild", guildGroupMembers[p])
      p = p + 1
    end
  end
  return guildGroupMembers
end

function VGT.TableSize(t)
  if (t == nil) then
    return 0
  end

  if (type(t) ~= "table") then
    return 0
  end

  local c = 0
  for k, v in pairs(t) do
    if (v ~= nil) then
      c = c + 1
    end
  end
  return c
end

function VGT.PrintAbout()
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, "installed version: %s", VGT.VERSION)
end

function VGT.PrintHelp()
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, "Command List:")
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, "/vgt about - version information")
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, "/vgt dungeons [timeframeInDays:7] - list of players that killed a dungeon boss within the timeframe")
end

local warned = false
local warnedPlayers = {}
local handleCoreMessageReceivedEvent = function(prefix, message, _, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

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
    if (not warned and tonumber(VGT.VERSION) < tonumber(version)) then
      VGT.Log(VGT.LOG_LEVEL.WARN, "there is a newer version of this addon")
      warned = true
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
      VGT.Douse_Initialize()
      VGT.Map_Initialize()
      VGT.LIBS:RegisterComm(MODULE_NAME, handleCoreMessageReceivedEvent)
    end
    if (loaded) then
      if (event == "PLAYER_ENTERING_WORLD") then
        handleInstanceChangeEvent(event)
        if (not entered) then
          GuildRoster()
          VGT.LIBS:SendCommMessage(MODULE_NAME, "SYNCHRONIZATION_REQUEST:"..VGT.VERSION, "GUILD")
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

-- ############################################################
-- ##### SLASH COMMANDS #######################################
-- ############################################################

--SLASH_VGT1 = "/vgt"
--SlashCmdList["VGT"] = function(message)
--   local command, arg1 = strsplit(" ", message)
--   if (command == "" or command == "help") then
--     VGT.PrintHelp()
--     return
--   end
--
--   if (command == "about") then
--     VGT.PrintAbout()
--   elseif (command == "loglevel") then
--     VGT.SetLogLevel(arg1)
--   elseif (command == "dungeons") then
--     VGT.PrintDungeonList(tonumber(arg1), false)
--   elseif (command == "douse") then
--     VGT.CheckForDouse()
--   else
--     VGT.Log(VGT.LOG_LEVEL.ERROR, "invalid command - type `/vgt help` for a list of commands")
--   end
--end
