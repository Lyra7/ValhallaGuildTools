VGT_ADDON_NAME, VGT = ...
VGT.VERSION = GetAddOnMetadata(VGT_ADDON_NAME, "Version")

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

function VGT.CommAvailability()
  return (floor(_G.ChatThrottleLib:UpdateAvail()) / 4000) * 100
end

function VGT.IsInRaid()
  if(select(2, IsInInstance()) == "raid") then
    return true
  else
    return false
  end
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
    if (type(v) == "table") then
      if (v[1] == m) then
        return true
      end
    else
      if (v == m) then
        return true
      end
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
  if (IsInGroup()) then
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

  if (IsInRaid()) then
    local raidList = {}
    local p = 0
    for i = 1, 40 do
      local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
      if (VGT.IsInMyGuild(name)) then
        guildGroupMembers[p] = name
        VGT.Log(VGT.LOG_LEVEL.TRACE, "%s is in my guild", guildGroupMembers[p])
        p = p + 1
      end
    end
    return guildGroupMembers
  end

  return nil
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

function VGT.EnumerateUsers(callback, wait)
  if (EnumeratingUsers) then
    return;
  end
  EnumeratingUsers = true;

  if (IsInGuild()) then
    VGT.LIBS:SendCommMessage(MODULE_NAME, REQUEST_VERSION_MESSAGE, "GUILD");
  end
  VGT.Log(VGT.LOG_LEVEL.SYSTEM, "Requesting addon user info...");

  if (not wait) then
    wait = 3;
  end

  C_Timer.After(wait, function()
    callback(users);
    EnumeratingUsers = false;
    users = {};
  end);
end
