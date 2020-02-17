VGT_ADDON_NAME, VGT = ...
local MODULE_NAME = "VGT-Config"

VGT.OPTIONS = {}
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

-- ############################################################
-- ##### LOCAL FUNCTIONS ######################################
-- ############################################################

local function default(value, default)
  if (value == nil) then
    value = default
    return value
  end
  return value
end

-- ############################################################
-- ##### GLOBAL FUNCTIONS #####################################
-- ############################################################

VGT.DefaultConfig = function(VGT_OPTIONS)
  VGT_OPTIONS = default(VGT_OPTIONS, {})
  VGT_OPTIONS.enabled = default(VGT_OPTIONS.enabled, true)
  VGT_OPTIONS.DOUSE = default(VGT_OPTIONS.DOUSE, {})
  VGT_OPTIONS.DOUSE.enabled = default(VGT_OPTIONS.DOUSE.enabled, true)
  VGT_OPTIONS.EP = default(VGT_OPTIONS.EP, {})
  VGT_OPTIONS.LOG = default(VGT_OPTIONS.LOG, {})
  VGT_OPTIONS.MAP = default(VGT_OPTIONS.MAP, {})
  VGT_OPTIONS.DOUSE.enabled = default(VGT_OPTIONS.DOUSE.enabled, true)
  VGT_OPTIONS.EP.enabled = default(VGT_OPTIONS.EP.enabled, true)
  VGT_OPTIONS.LOG.enabled = default(VGT_OPTIONS.LOG.enabled, true)
  VGT_OPTIONS.LOG.logLevel = default(VGT_OPTIONS.LOG.logLevel, VGT.LOG.LEVELS[VGT.LOG_LEVEL.INFO])
  VGT_OPTIONS.MAP.enabled = default(VGT_OPTIONS.MAP.enabled, true)
  VGT_OPTIONS.MAP.sendMyLocation = default(VGT_OPTIONS.MAP.sendMyLocation, true)
  VGT_OPTIONS.MAP.showMinimapOutOfBounds = default(VGT_OPTIONS.MAP.showMinimapOutOfBounds, false)
  if (VGT_OPTIONS.MAP.mode == nil) then
    VGT_OPTIONS.MAP.mode = "both"
    VGT_OPTIONS.MAP.showMe = false
  else
    VGT_OPTIONS.MAP.showMe = default(VGT_OPTIONS.MAP.showMe, false)
  end
  return VGT_OPTIONS
end

-- ############################################################
-- ##### SLASH COMMANDS #######################################
-- ############################################################

SLASH_VGT1 = "/vgt"
SlashCmdList["VGT"] = function(message)
  InterfaceOptionsFrame_OpenToCategory(VGT.menu)
  InterfaceOptionsFrame_OpenToCategory(VGT.menu)
end

-- ############################################################
-- ##### OPTIONS ##############################################
-- ############################################################

--https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables
local options = {
  type = "group",
  args = {
    enable = {
      name = "Enable",
      desc = "REQUIRES RELOAD",
      type = "toggle",
      set = function(info, val) VGT.OPTIONS.enabled = val end,
      get = function(info) return VGT.OPTIONS.enabled end
    },
    vgt_douse = {
      name = "VGT-Douse",
      type = "group",
      args = {
        enable = {
          name = "Enable",
          desc = "REQUIRES RELOAD",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.DOUSE.enabled = val end,
          get = function(info) return VGT.OPTIONS.DOUSE.enabled end
        },
      }
    },
    vgt_ep = {
      name = "VGT-EP",
      type = "group",
      args = {
        enable = {
          name = "Enable",
          desc = "REQUIRES RELOAD",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.EP.enabled = val end,
          get = function(info) return VGT.OPTIONS.EP.enabled end
        },
      }
    },
    vgt_logging = {
      name = "VGT-Logging",
      type = "group",
      args = {
        enable = {
          name = "Enable",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.LOG.enabled = val end,
          get = function(info) return VGT.OPTIONS.LOG.enabled end
        },
        log_level = {
          name = "Log Level",
          desc = "verbosity of the addon",
          type = "select",
          values = VGT.LOG_LEVELS,
          set = function(info, val) VGT.OPTIONS.LOG.logLevel = val end,
          get = function(info) return VGT.OPTIONS.LOG.logLevel end
        },
      }
    },
    vgt_map = {
      name = "VGT-Map",
      type = "group",
      args = {
        enable = {
          order = 0,
          name = "Enable",
          desc = "REQUIRES RELOAD",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.MAP.enabled = val end,
          get = function(info) return VGT.OPTIONS.MAP.enabled end
        },
        send_my_location = {
          order = 1,
          name = "Send My Location",
          desc = "sends your location to other addon users",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.MAP.sendMyLocation = val end,
          get = function(info) return VGT.OPTIONS.MAP.sendMyLocation end
        },
        show_me = {
          order = 2,
          name = "Show My Pin",
          desc = "shows your own pin on the map",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.MAP.showMe = val end,
          get = function(info) return VGT.OPTIONS.MAP.showMe end
        },
        show_minimap_oob = {
          order = 3,
          name = "Show Distant Players on Minimap",
          desc = "shows party member pins on the minimap borders if they are out of range",
          type = "toggle",
          set = function(info, val) VGT.OPTIONS.MAP.showMinimapOutOfBounds = val end,
          get = function(info) return VGT.OPTIONS.MAP.showMinimapOutOfBounds end
        },
        map_mode = {
          order = 4,
          name = "Display Mode",
          desc = "choose where pins are shown",
          values = {
            ["map"] = "Only World Map",
            ["minimap"] = "Only Minimap",
            ["both"] = "World Map and Minimap"
          },
          type = "select",
          style = "dropdown",
          get = function(info) return VGT.OPTIONS.MAP.mode end,
          set = function(info, val) VGT.OPTIONS.MAP.mode = val end
        }
      }
    }
  }
}
LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(VGT_ADDON_NAME, options, SLASH_VGT1)
VGT.menu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(VGT_ADDON_NAME, VGT_ADDON_NAME)
