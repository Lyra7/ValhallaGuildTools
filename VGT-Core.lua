ADDON_NAME, VGT = ...
ACE = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceComm-3.0")
VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
FRAME = CreateFrame("Frame")
VGT.debug = false

-- ############################################################
-- ##### HELPERS ##############################################
-- ############################################################

LOG = function(str, debug)
	if (debug == true) then
		if (VGT.debug == true) then
			print(str)
		end
	else
		print(str)
	end
end

function StringAppend(...)
	local args = {...}
	local str = ""
	for k,v in ipairs(args) do
		if (v ~= nil) then
			str = str..tostring(v)
		end
	end
	return str
end

function TableJoinToArray(a, b)
	local nt = {}
	for k,v in pairs(a) do
		nt[v] = v
	end
	for k,v in pairs(b) do
		nt[v] = v
	end
	return nt
end

function TableToString(t, d, sort)
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
    for k,v in pairs(t) do
        table.insert(nt, v)
    end
		table.sort(nt)
		t = nt
	end

	for k,v in pairs(t) do
			s = s..","..v
	end

	return string.sub(s, 2)
end

function TableContains(t, m)
	if (t == nil) then
		return false
	end

	for k,v in pairs(t) do
		if (v == m) then
			return true
		end
	end

	return false
end

function RandomUUID()
    local template ='xxxxxxxx'
    return string.gsub(template, '[xy]', function (c) local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb) return string.format('%x', v) end)
end

function GetMyGuildName()
	if (IsInGuild()) then
		return GetGuildInfo("player")
	else
		return nil
	end
end

function IsInMyGuild(playerName)
	if (playerName == nil) then
		return false
	end

	local playerGuildName = GetGuildInfo(playerName)
	if (playerGuildName == nil) then
		return false
	end

	local myGuildName = GetMyGuildName()
	if (myGuildName == nil) then
		return false
	end

	if (myGuildName == playerGuildName) then
		return true
	end

	return false
end

function CheckGroupForGuildies()
	if (IsInGroup() ~= true) then
		return nil
	end

	local groupMembers = GetHomePartyInfo()
	local guildGroupMembers = {}
	local p = 0
	for i = 0, GetNumGroupMembers() do
		local groupMember = groupMembers[i]
		if (IsInMyGuild(groupMember)) then
			guildGroupMembers[p] = groupMember
			p = p + 1
			LOG(format("[%s] %s is in my guild", ADDON_NAME, groupMember), true)
		end
	end
	return guildGroupMembers
end

-- ############################################################
-- ##### SLASH COMMANDS #######################################
-- ############################################################

SLASH_VGT1 = "/vgt"
SlashCmdList["VGT"] = function(message)
	local command, arg1, arg2 = strsplit(" ", message)

	if (command == "debug") then
		VGT.debug = not VGT.debug
		LOG(format("[%s] debug mode toggled (value=%s)", ADDON_NAME, tostring(VGT.debug)))
		return
	end
	if (command == "eptest") then
		HandleUnitDeath("TEST"..RandomUUID(), "TestDungeon", "TestBoss")
		return
	end
	if (command == "dungeons") then
		PrintDungeonList(tonumber(arg1), VGT.debug)
		return
	end
	LOG(format("[%s] Command List:", ADDON_NAME))
	LOG(format("%s - %s", "/vgt debug", "enables debug mode"))
	LOG(format("%s - %s", "/vgt eptest", "sends an EP test event"))
	LOG(format("%s - %s", "/vgt dungeons <timeframe>", "prints the list of EP award candidates based on dungeon activity"))
end
