local MODULE_NAME = "VGT-Guild"
local GUILDFRAME = CreateFrame("Frame");
local guildCache = {}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

--[1]index
--[2]characterData
--  [1]level
--  [2]class
--  [3]zone
--[3]
--  [1]note
--  [2]officernote
--[4]
--  [1]rankIndex
--  [2]rank
--[5]
--  [1]online
--  [2]status
local function updateGuildCache()
  guildCache = {}
  for i = 1, GetNumGuildMembers() do
    local name, rank, rankIndex, level, _, zone, note, officernote, online, status, class = GetGuildRosterInfo(i)
    name = strsplit("-", name)
    if (name) then

      guildCache[name] = {i, {level, class, zone}, {note, officernote}, {rankIndex, rank}, {online, status}}
    end
  end
end

local function onEvent(_, event)
  if (event == "GUILD_ROSTER_UPDATE") then
    updateGuildCache()
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

VGT.GuildCache = function(name)
  if (name) then
    return guildCache[name]
  end
  return guildCache
end

GUILDFRAME:RegisterEvent("GUILD_ROSTER_UPDATE")
GUILDFRAME:SetScript("OnEvent", onEvent)
