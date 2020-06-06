local MODULE_NAME = "VGT-Reminder"
local REMINDERFRAME = CreateFrame("Frame");

local MIN_DUNGEON_LEVEL = 15
local MAX_DUNGEON_KILL = 5
local MIN_RAID_LEVEL = 60
local MAX_RAID_KILL = 1

local function pluralize(count, single, plural)
  if (count == 1) then
    return single
  else
    return plural
  end
end

local function onEvent(_, event, arg1, arg2)
  if (event == "ADDON_LOADED") then
    if (not VGT_REMINDERS) then
      VGT_REMINDERS = {}
    end
  elseif (event == "GUILD_ROSTER_UPDATE") then
    local active = false
    local guildInfo = GetGuildInfoText()
    for charnamex in gmatch(guildInfo, 'VGTx:('..UnitName("player")..')') do
      active = true
      for name, rosterInfo in pairs(VGT.GuildCache()) do
        if (not VGT_REMINDERS[name] or type(VGT_REMINDERS[name]) ~= "table") then
          VGT_REMINDERS[name] = {}
        end
        if (not VGT_REMINDERS[name][2] and (not VGT_REMINDERS[name][1] or not VGT.withinDays(VGT_REMINDERS[name][1], 1))) then
          local killCount = (VGT.getBossCountForPlayer(VGT.GetMyGuildName(), name, false) or 0)
          local raidKillCount = (VGT.getBossCountForPlayer(VGT.GetMyGuildName(), name, true) or 0)
          local level = rosterInfo[2][1]
          if (rosterInfo[5][1] and rosterInfo[5][2] == 0) then
            if (level >= MIN_DUNGEON_LEVEL and killCount < MAX_DUNGEON_KILL) then
              VGT_REMINDERS[name][1] = GetServerTime()
              local remaining = MAX_DUNGEON_KILL - killCount
              local message = "(AUTOMATED) Hello "..name..", this is a daily reminder that you still need to complete your weekly guild dungeons. You currently need to kill "..remaining.." more "
              message = message..pluralize(remaining, "boss", "bosses")
              message = message.." this week. Have a nice day! Respond with 'stop' to remove this reminder."
              SendChatMessage(message, "WHISPER", nil, name)
            end
            if (level >= MIN_RAID_LEVEL and raidKillCount < MAX_RAID_KILL) then
              VGT_REMINDERS[name][1] = GetServerTime()
              local remaining = MAX_RAID_KILL - raidKillCount
              local message = "(AUTOMATED) Hello "..name..", this is a daily reminder that you still need to complete your weekly guild 20-man raids. You currently need to kill "..remaining.." more "
              message = message..pluralize(remaining, "boss", "bosses")
              message = message.." this week. Have a nice day! Respond with 'stop' to remove this reminder."
              SendChatMessage(message, "WHISPER", nil, name)
            end
          end
        end
      end
    end
    if (guildInfo and guildInfo ~= "" and not active) then
      REMINDERFRAME:UnregisterAllEvents()
    end
  elseif (event == "CHAT_MSG_WHISPER") then
    if (arg2) then
      local name = strsplit("-", arg2)
      if (VGT.GuildCache(name)) then
        if (arg1) then
          local command = strlower(arg1)
          if (command == "stop" or command == "'stop'") then
            VGT_REMINDERS[name][2] = true
            local message = "(AUTOMATED) You have unsubscribed from all <Valhalla> reminders. Respond with 'remindme' to resubscribe."
            SendChatMessage(message, "WHISPER", nil, name)
          elseif (command == "remindme" or command == "'remindme'") then
            VGT_REMINDERS[name][2] = false
            local message = "(AUTOMATED) You have subscribed to <Valhalla> reminders."
            SendChatMessage(message, "WHISPER", nil, name)
          end
        end
      end
    end
  end
end

REMINDERFRAME:RegisterEvent("ADDON_LOADED")
REMINDERFRAME:RegisterEvent("GUILD_ROSTER_UPDATE")
REMINDERFRAME:RegisterEvent("CHAT_MSG_WHISPER")
REMINDERFRAME:SetScript("OnEvent", onEvent)
GuildRoster()
