local MODULE_NAME = "VGT-Douse"

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

local isTiming = false
local douses = {}
local PrintDouseCount = function()
	Log(LOG_LEVEL.SYSTEM, "The raid has %s Aqual Quintessences.", TableSize(douses))
	isTiming = false
end

function HandleDouseMessageReceivedEvent(prefix, message, distribution, sender)
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
			ACE:SendCommMessage(MODULE_NAME, MODULE_NAME..":HAS_DOUSE", "WHISPER", sender)
		elseif (event == "HAS_DOUSE") then
			douses[sender] = 1
		end
	end
end

function CheckForDouse()
	douseCount = {}
	Log(LOG_LEVEL.SYSTEM, "Checking the raid for Aqual Quintessences, please wait...")
	ACE:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST", "RAID")
	if (not isTiming) then
		ACE:ScheduleTimer(PrintDouseCount, 5)
	end
	isTiming = true

	if (HasDouse()) then
		local playerName = UnitName("player")
		douses[playerName] = 1
	end
end

function HasDouse()
  for bagIndex=0,4 do
    local slots = GetContainerNumSlots(bagIndex)
    for slotIndex=0,slots do
      local _, _, _, _, _, _, itemLink = GetContainerItemInfo(bagIndex, slotIndex)
      if (itemLink ~= nil) then
        local itemId = select(3, strfind(itemLink, "item:(%d+)"))
        if (itemId == 17333) then
          return true
        end
      end
    end
  end
  return false
end

function VGT_Douse_Initialize()
	ACE:RegisterComm(MODULE_NAME, HandleDouseMessageReceivedEvent)
end
