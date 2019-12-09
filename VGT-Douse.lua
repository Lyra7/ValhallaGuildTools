local MODULE_NAME = "VGT-Douse"

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

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

	if (distribution == "GUILD") then
		if (event == "SYNCHRONIZATION_REQUEST") then
		else
		end
	end
end

function CheckForDouse()
  for bagIndex=0,4 do
    slots = GetContainerNumSlots(bagIndex)
    for slotIndex=0,slots do
      _, _, _, _, _, _, itemLink = GetContainerItemInfo(bagIndex, slotIndex)
      if (itemLink ~= nil) then
        itemId = select(3, strfind(itemLink, "item:(%d+)"))
        if (itemId == 17333) then
          return true
        end
      end
    end
  end
  return false
end

function VGT_Douse_Initialize()
	-- ACE:RegisterComm(MODULE_NAME, HandleEPMessageReceivedEvent)
	-- ACE:SendCommMessage(MODULE_NAME, MODULE_NAME..":SYNCHRONIZATION_REQUEST", "GUILD")
end
