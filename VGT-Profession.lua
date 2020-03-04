local MODULE_NAME = "VGT-Profession"
local FRAME = CreateFrame("Frame")

local DELIMITER = ";"

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local skillsLoaded = false
local onEvent = function(_, event)
  if (event == "ADDON_LOADED") then
    if (VGT_PROFESSIONS == nil) then
      VGT_PROFESSIONS = {}
    end
    VGT.LIBS:SendCommMessage(MODULE_NAME, MODULE_NAME, "GUILD")
  end

  if (event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE") then
    local player = GetUnitName("player")
    VGT_PROFESSIONS[player] = {}
    VGT_PROFESSIONS[player].timestamp = GetServerTime()
    for i = 0, GetNumTradeSkills() do
      local recipe = GetTradeSkillInfo(i);
      if (recipe == "Transmute: Arcanite") then
        VGT_PROFESSIONS[player][recipe] = floor((GetTradeSkillCooldown(i) or 0))
      end
    end
    skillsLoaded = true
  end
end

local getPlayerTimestamp = function(player)
  local playerData = VGT_PROFESSIONS[player]
  if (playerData) then
    for k, v in pairs(playerData) do
      if (k == "timestamp") then
        return v
      end
    end
  end
end

local onMessage = function(prefix, message, distribution, sender)
  if (sender == GetUnitName("player")) then
    return
  end

  if (prefix ~= MODULE_NAME) then
    return
  end

  if (message == MODULE_NAME) then
    if (skillsLoaded) then
      for player, playerData in pairs(VGT_PROFESSIONS) do
        if (playerData) then
          local timestamp = getPlayerTimestamp(player)
          if (timestamp) then
            for k, v in pairs(playerData) do
              if (k ~= "timestamp") then
                VGT.LIBS:SendCommMessage(MODULE_NAME, player..DELIMITER..timestamp..DELIMITER..k..DELIMITER..v, "WHISPER", sender, "BULK")
              end
            end
          end
        end
      end
    end
  else
    local player, timestamp, recipe, cooldown = strsplit(DELIMITER, message)
    if (player and timestamp and recipe and cooldown) then
      local savedTimestamp = (getPlayerTimestamp(player) or 0)
      if (timestamp and timestamp > savedTimestamp) then
        if (not VGT_PROFESSIONS[player]) then
          VGT_PROFESSIONS[player] = {}
        end
        VGT_PROFESSIONS[player].timestamp = timestamp
        VGT_PROFESSIONS[player][recipe] = cooldown
      end
    end
  end
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

--TODO ADD OPTIONS FOR TURNING OFF
FRAME:RegisterEvent("ADDON_LOADED")
FRAME:RegisterEvent("TRADE_SKILL_SHOW")
FRAME:RegisterEvent("TRADE_SKILL_UPDATE")
FRAME:RegisterEvent("PLAYER_LOGOUT")
FRAME:SetScript("OnEvent", onEvent);
VGT.LIBS:RegisterComm(MODULE_NAME, onMessage)
