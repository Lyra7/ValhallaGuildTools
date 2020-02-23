local MODULE_NAME = "VGT-Force"
local FRAME = CreateFrame("Frame")

local currentRaid = {}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local function getRaidIndex(player)
  for i = 1, 40 do
    local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
    if (player == name) then
      return i
    end
  end
  return nil
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

SLASH_VGT_FORCE1 = "/vgtforce"
SlashCmdList["VGT_FORCE"] = function(message)
  local command, arg1 = strsplit(" ", message)

  if (command == "save") then
    for i = 1, 40 do
      local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
      if (name ~= nil) then
        currentRaid[name] = {class, subgroup}
      end
    end
  elseif (command == "load") then
    for k, v in pairs(currentRaid) do
      local index = getRaidIndex(k)
      local _, _, subgroup, _, _, class = GetRaidRosterInfo(index)
      local savedData = currentRaid[k]
      if (savedData ~= nil) then
        local savedSubgroup = savedData[2]
        if (savedSubgroup ~= subgroup) then
          SetRaidSubgroup(index, savedSubgroup)
          --SwapRaidSubgroup(1, savedSubgroup)
        end
      end
    end
  elseif (command == "show") then
    for k, v in pairs(currentRaid) do
      local index = getRaidIndex(k)
      print (k.." ("..currentRaid[k][2].." / "..index..")")
    end
  end
  -- for k, v in pairs(currentRaid) do
  --   local index = getRaidIndex(k)
  --   local _, _, subgroup, _, _, class = GetRaidRosterInfo(index)
  --   local savedData = currentRaid[k]
  --   if (savedData ~= nil) then
  --     local savedSubgroup = savedData[2]
  --     if (savedSubgroup ~= subgroup) then
  --       SwapRaidSubgroup(getRaidIndex(UnitName("player")), savedSubgroup)
  --     end
  --   end
  -- end
end
