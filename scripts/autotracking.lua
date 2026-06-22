
AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP = false

print("")
print("Active Auto-Tracker Configuration")
print("---------------------------------------------------------------------")
print("Enable Item Tracking:        ", AUTOTRACKER_ENABLE_ITEM_TRACKING)
print("Enable Location Tracking:    ", AUTOTRACKER_ENABLE_LOCATION_TRACKING)
print("---------------------------------------------------------------------")
print("")

require("scripts/settings")
require("scripts/autotracking/archipelago")
