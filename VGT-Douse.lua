local MODULE_NAME = "VGT-Douse"

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local isTiming = false
local douses = {}
local printDouseCount = function()
  VGT.Log("Raid members with Aqual Quintessences:")
  VGT.Log("%s", VGT.TableToString(douses))
  VGT.Log("The raid has %s Aqual Quintessences.", VGT.TableSize(douses))
  isTiming = false
end

local handleDouseMessageReceivedEvent = function(prefix, message, distribution, sender)
  if (prefix ~= MODULE_NAME) then
    return
  end

  local module, event = strsplit(":", message)
  if (module ~= MODULE_NAME) then
    return
  end

  local playerName = UnitName("player")
  if (sender == playerName) then
    return
  end

  if (distribution == "RAID") then
    if (event == "SYNCHRONIZATION_REQUEST") then
      if (hasDouse()) then
        VGT.LIBS:SendCommMessage(MODULE_NAME, MODULE_NAME..":HAS_DOUSE", "WHISPER", sender)
      end
    end
  end
  if (distribution == "WHISPER") then
    if (event == "HAS_DOUSE") then
      douses[sender] = sender
    end
  end
end

local hasDouse = function()
  for bagIndex = 0, 4 do
    local slots = GetContainerNumSlots(bagIndex)
    for slotIndex = 0, slots do
      local _, _, _, _, _, _, itemLink = GetContainerItemInfo(bagIndex, slotIndex)
      if (itemLink ~= nil) then
        local itemId = select(3, strfind(itemLink, "item:(%d+)"))
        if (itemId == "17333") then
          return true
        end
      end
    end
  end
  return false
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

VGT.CheckForDouse = function ()
  if (VGT.OPTIONS.DOUSE.enabled) then
    douses = {}
    VGT.Log(VGT.LOG_LEVEL.SYSTEM, "Checking the raid for Aqual Quintessences, please wait...")
    VGT.LIBS:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST", "RAID")
    if (not isTiming) then
      VGT.LIBS:ScheduleTimer(printDouseCount, 5)
    end
    isTiming = true

    if (hasDouse()) then
      local playerName = UnitName("player")
      douses[playerName] = playerName
    end
  end
end

VGT.Douse_Initialize = function()
  if (VGT.OPTIONS.DOUSE.enabled) then
    VGT.LIBS:RegisterComm(MODULE_NAME, handleDouseMessageReceivedEvent)
  end
end
