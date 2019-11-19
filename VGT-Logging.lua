ADDON_NAME, VGT = ...
VERSION = GetAddOnMetadata(ADDON_NAME, "Version")

-- ############################################################
-- ##### CONSTANTS ############################################
-- ############################################################

LOG_LEVEL = {}
LOG_LEVEL.ALL = "ALL"
LOG_LEVEL.TRACE = "TRACE"
LOG_LEVEL.DEBUG = "DEBUG"
LOG_LEVEL.INFO = "INFO"
LOG_LEVEL.WARN = "WARN"
LOG_LEVEL.ERROR = "ERROR"
LOG_LEVEL.SYSTEM = "SYSTEM"
LOG_LEVEL.OFF = "OFF"
LOG_LEVELS={
    LOG_LEVEL.ALL,
    LOG_LEVEL.TRACE,
    LOG_LEVEL.DEBUG,
    LOG_LEVEL.INFO,
    LOG_LEVEL.WARN,
    LOG_LEVEL.ERROR,
    LOG_LEVEL.SYSTEM,
    LOG_LEVEL.OFF
}
LOG={
    LEVELS={
      [LOG_LEVEL.ALL]=-1,[-1]=LOG_LEVEL.ALL,
      [LOG_LEVEL.TRACE]=2,[2]=LOG_LEVEL.TRACE,
      [LOG_LEVEL.DEBUG]=3,[3]=LOG_LEVEL.DEBUG,
      [LOG_LEVEL.INFO]=4,[4]=LOG_LEVEL.INFO,
      [LOG_LEVEL.WARN]=5,[5]=LOG_LEVEL.WARN,
      [LOG_LEVEL.ERROR]=6,[6]=LOG_LEVEL.ERROR,
      [LOG_LEVEL.SYSTEM]=7,[7]=LOG_LEVEL.SYSTEM,
      [LOG_LEVEL.OFF]=8,[8]=LOG_LEVEL.OFF
    },
    COLORS={
      [LOG_LEVEL.ALL]="|cff000000",[-1]="|cff000000", -- black
      [LOG_LEVEL.TRACE]="|cff00ffff",[2]="|cff00ffff", -- cyan
      [LOG_LEVEL.DEBUG]="|cffff00ff",[3]="|cffff00ff", -- purple
      [LOG_LEVEL.INFO]="|cffffff00",[4]="|cffffff00", -- yellow
      [LOG_LEVEL.WARN]="|cffff8800",[5]="|cffff8800", -- orange
      [LOG_LEVEL.ERROR]="|cffff0000",[6]="|cffff0000", -- red
      [LOG_LEVEL.SYSTEM]="|cffffff00",[7]="|cffffff00", -- yellow
      [LOG_LEVEL.OFF]="|cff000000",[8]="|cff000000" -- black
    }
}

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

-- Coverts a log level to its corresponding number or nil
--  level: the log level to convert
local LogLevelToNumber = function(level)

  -- Ignore converting log level if it doesn't exist
  if (level ~= nil and TableContains(LOG.LEVELS, level) == true) then

    -- Immediately return the log level if it's already a number
    if (type(level) == "number") then
        return level
    end
    return LOG.LEVELS[level]
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
Log = function(level, message, ...)
    local logLevelNumber = LogLevelToNumber(level)

    -- Defaulting the log level to SYSTEM if none was provided
    if (logLevelNumber == nil) then
        logLevelNumber = LOG.LEVELS[LOG_LEVEL.SYSTEM]
    end

    -- Print the message if the log level is within bounds or if its a system log
    if (logLevel <= logLevelNumber or logLevelNumber == LOG.LEVELS[LOG_LEVEL.SYSTEM]) then
        print(format(LOG.COLORS[logLevelNumber].."[%s] "..message, ADDON_NAME, ...))
    end
end

-- Sets the global log level to the specified level
--  level: the log level to set to
SetLogLevel = function(level)

    -- Force upper any string passed as the log level
    if (type(level) == "string") then
        level = string.upper(level)
    end

    -- Set the log level if it's valid otherwise print an error message
    if (TableContains(LOG.LEVELS, level) == true) then
        logLevel = LogLevelToNumber(level)
        Log(LOG_LEVEL.SYSTEM, "log level set to %s", LOG.LEVELS[logLevel])
    else

        -- Replace nil log levels as a ' ' for better indication
        if (level == nil) then
            level = "' '"
        end
        Log(LOG_LEVEL.ERROR, "%s is not a valid log level", level)
    end
end
