-- ############################################################
-- ##### CONSTANTS ############################################
-- ############################################################

VGT.LOG_LEVEL = {}
VGT.LOG_LEVEL.ALL = "ALL"
VGT.LOG_LEVEL.TRACE = "TRACE"
VGT.LOG_LEVEL.DEBUG = "DEBUG"
VGT.LOG_LEVEL.INFO = "INFO"
VGT.LOG_LEVEL.WARN = "WARN"
VGT.LOG_LEVEL.ERROR = "ERROR"
VGT.LOG_LEVEL.SYSTEM = "SYSTEM"
VGT.LOG_LEVEL.OFF = "OFF"
VGT.LOG_LEVELS = {
  VGT.LOG_LEVEL.ALL,
  VGT.LOG_LEVEL.TRACE,
  VGT.LOG_LEVEL.DEBUG,
  VGT.LOG_LEVEL.INFO,
  VGT.LOG_LEVEL.WARN,
  VGT.LOG_LEVEL.ERROR,
  VGT.LOG_LEVEL.SYSTEM,
  VGT.LOG_LEVEL.OFF
}
VGT.LOG = {
  LEVELS = {
    [VGT.LOG_LEVEL.ALL] = -1, [ - 1] = VGT.LOG_LEVEL.ALL,
    [VGT.LOG_LEVEL.TRACE] = 2, [2] = VGT.LOG_LEVEL.TRACE,
    [VGT.LOG_LEVEL.DEBUG] = 3, [3] = VGT.LOG_LEVEL.DEBUG,
    [VGT.LOG_LEVEL.INFO] = 4, [4] = VGT.LOG_LEVEL.INFO,
    [VGT.LOG_LEVEL.WARN] = 5, [5] = VGT.LOG_LEVEL.WARN,
    [VGT.LOG_LEVEL.ERROR] = 6, [6] = VGT.LOG_LEVEL.ERROR,
    [VGT.LOG_LEVEL.SYSTEM] = 7, [7] = VGT.LOG_LEVEL.SYSTEM,
    [VGT.LOG_LEVEL.OFF] = 8, [8] = VGT.LOG_LEVEL.OFF
  },
  COLORS = {
    [VGT.LOG_LEVEL.ALL] = "|cff000000", [ - 1] = "|cff000000", -- black
    [VGT.LOG_LEVEL.TRACE] = "|cff00ffff", [2] = "|cff00ffff", -- cyan
    [VGT.LOG_LEVEL.DEBUG] = "|cffff00ff", [3] = "|cffff00ff", -- purple
    [VGT.LOG_LEVEL.INFO] = "|cffffff00", [4] = "|cffffff00", -- yellow
    [VGT.LOG_LEVEL.WARN] = "|cffff8800", [5] = "|cffff8800", -- orange
    [VGT.LOG_LEVEL.ERROR] = "|cffff0000", [6] = "|cffff0000", -- red
    [VGT.LOG_LEVEL.SYSTEM] = "|cffffff00", [7] = "|cffffff00", -- yellow
    [VGT.LOG_LEVEL.OFF] = "|cff000000", [8] = "|cff000000" -- black
  }
}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

-- Coverts a log level to its corresponding number or nil
--  level: the log level to convert
local logLevelToNumber = function(level)

  -- Ignore converting log level if it doesn't exist
  if (level ~= nil and VGT.TableContains(VGT.LOG.LEVELS, level) == true) then

    -- Immediately return the log level if it's already a number
    if (type(level) == "number") then
      return level
    end
    return VGT.LOG.LEVELS[level]
  end
  return nil
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

-- Logs (prints) a given message at the specified log level
--  level: the log level to print at
--  message: the unformatted message
--  ...: values to format the message with
VGT.Log = function(level, message, ...)
  local logLevelNumber = logLevelToNumber(level)

  -- Defaulting the log level to SYSTEM if none was provided
  if (logLevelNumber == nil) then
    logLevelNumber = VGT.LOG.LEVELS[VGT.LOG_LEVEL.SYSTEM]
  end

  -- Print the message if the log level is within bounds or if its a system log
  if (logLevel <= logLevelNumber or logLevelNumber == VGT.LOG.LEVELS[VGT.LOG_LEVEL.SYSTEM]) then
    print(format(VGT.LOG.COLORS[logLevelNumber].."[%s] "..message, VGT_ADDON_NAME, ...))
  end
end

-- Sets the global log level to the specified level
--  level: the log level to set to
VGT.SetLogLevel = function(level)

  -- Force upper any string passed as the log level
  if (type(level) == "string") then
    level = string.upper(level)
  end

  -- Set the log level if it's valid otherwise print an error message
  if (VGT.TableContains(VGT.LOG.LEVELS, level) == true) then
    logLevel = logLevelToNumber(level)
    VGT.Log(VGT.LOG_LEVEL.SYSTEM, "log level set to %s", VGT.LOG.LEVELS[logLevel])
  else

    -- Replace nil log levels as a ' ' for better indication
    if (level == nil) then
      level = "' '"
    end
    VGT.Log(VGT.LOG_LEVEL.ERROR, "%s is not a valid log level", level)
  end
end
