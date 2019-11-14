ADDON_NAME, VGT = ...
VERSION = GetAddOnMetadata(ADDON_NAME, "Version")


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
      [LOG_LEVEL.ALL]=0,[0]=LOG_LEVEL.ALL,
      [LOG_LEVEL.TRACE]=1,[1]=LOG_LEVEL.TRACE,
      [LOG_LEVEL.DEBUG]=2,[2]=LOG_LEVEL.DEBUG,
      [LOG_LEVEL.INFO]=3,[3]=LOG_LEVEL.INFO,
      [LOG_LEVEL.WARN]=4,[4]=LOG_LEVEL.WARN,
      [LOG_LEVEL.ERROR]=5,[5]=LOG_LEVEL.ERROR,
      [LOG_LEVEL.SYSTEM]=6,[6]=LOG_LEVEL.SYSTEM,
      [LOG_LEVEL.OFF]=7,[7]=LOG_LEVEL.OFF
    },
    COLORS={
      [LOG_LEVEL.ALL]="|cff000000",[0]="|cff000000", -- black
      [LOG_LEVEL.TRACE]="|cff00ffff",[1]="|cff00ffff", -- cyan
      [LOG_LEVEL.DEBUG]="|cffff00ff",[2]="|cffff00ff", -- purple
      [LOG_LEVEL.INFO]="|cffffff00",[3]="|cffffff00", -- yellow
      [LOG_LEVEL.WARN]="|cffff8800",[4]="|cffff8800", -- orange
      [LOG_LEVEL.ERROR]="|cffff0000",[5]="|cffff0000", -- red
      [LOG_LEVEL.SYSTEM]="|cffffff00",[6]="|cffffff00", -- yellow
      [LOG_LEVEL.OFF]="|cff000000",[7]="|cff000000" -- black
    }
}


local LogLevelToNumber = function(level)
  if (type(level) == "number") then
      return level
  else
      return LOG.LEVELS[level]
  end
end

Log = function(level, message, ...)
    local logLevelNumber = LogLevelToNumber(level)
    if (LOG.LEVELS[logLevelNumber] == LOG.LEVELS[LOG_LEVEL.SYSTEM] or logLevel <= logLevelNumber) then
        print(format(LOG.COLORS[logLevelNumber].."[%s] "..message, ADDON_NAME, ...))
    end
end

SetLogLevel = function(level)
    if (type(level) == "string") then
      level = string.upper(level)
    end
    if (TableContains(LOG.LEVELS, level)) then
        logLevel = LogLevelToNumber(level)
        Log(LOG_LEVEL.SYSTEM, "log level set to %s", LOG.LEVELS[logLevel])
    else
        Log(LOG_LEVEL.SYSTEM, "%s is not a valid log level", level)
    end
end
