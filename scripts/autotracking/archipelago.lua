
require("scripts/autotracking/item_mapping")
require("scripts/autotracking/location_mapping")

CUR_INDEX = -1

ALL_LOCATIONS = {}
SLOT_DATA = {}

MANUAL_CHECKED = true
ROOM_SEED = "default"
TROLL_PLAYER = false

if Highlight then
    HIGHLIGHT_LEVEL= {
        [0] = Highlight.Unspecified,
        [10] = Highlight.NoPriority,
        [20] = Highlight.Avoid,
        [30] = Highlight.Priority,
        [40] = Highlight.None,
        [100] = Highlight.Unspecified, --Filler
        [101] = Highlight.Priority, --Progression
        [102] = Highlight.NoPriority, --Useful
        [103] = Highlight.Priority, -- Prog + Useful
        [104] = Highlight.Avoid, --Trap
        [105] = Highlight.Priority, -- Prog + Trap
        [106] = Highlight.NoPriority, -- Useful + Trap
        [107] = Highlight.Priority, -- Prog + Useful + Trap
    }
end

Troll_Lookup = {}

-- ===== Progression "received / max" overlays =====
-- AP item id -> tracker code for the progression items
PROG_ID_TO_CODE = {
    [1] = "progressivefairness",
    [2] = "headsplus",
    [3] = "flipplus",
    [4] = "comboplus",
    [5] = "coinplus",
    [6] = "autoflipplus",
}
PROG_COUNT = {}   -- code -> number received this seed
PROG_MAX = {}     -- code -> max possible this seed (from slot_data)

-- Pool maxes mirror the apworld's create_items():
--   gate_count = ceil((RequiredHeads + 1) / 2)
function ComputeProgMax(slot_data)
    local rh = (slot_data and tonumber(slot_data.RequiredHeads)) or 0
    local gate = math.ceil((rh + 1) / 2)
    local autoflip_on = slot_data and (slot_data.AutoFlipEnabled == 1 or slot_data.AutoFlipEnabled == true)
    PROG_MAX = {
        progressivefairness = math.max(gate - 1, 0),
        headsplus = math.max(gate - 1, 0),
        flipplus = gate,
        comboplus = gate,
        coinplus = 4,
        autoflipplus = autoflip_on and math.floor(gate * 0.7 + 0.5) or 0,
    }
end

function UpdateProgOverlay(code)
    local obj = Tracker:FindObjectForCode(code)
    if not obj then
        return
    end
    local cnt = PROG_COUNT[code] or 0
    local mx = PROG_MAX[code]
    obj:SetOverlayFontSize(22)
    obj:SetOverlayBackground("#000000")
    if mx and mx > 0 then
        obj:SetOverlay(cnt .. "/" .. mx)
    elseif cnt > 0 then
        obj:SetOverlay(tostring(cnt))
    else
        obj:SetOverlay("")
    end
end

function ResetProgOverlays(slot_data)
    ComputeProgMax(slot_data)
    for _, code in pairs(PROG_ID_TO_CODE) do
        PROG_COUNT[code] = 0
        UpdateProgOverlay(code)
    end
end

function dump_table(o, depth)
    if depth == nil then
        depth = 0
    end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. tabs2 .. '[' .. k .. '] = ' .. dump_table(v, depth + 1) .. ',\n'
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end

function LocationHandler(location)
    if MANUAL_CHECKED then
        local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
        if not custom_storage_item then
            return
        end
        if Archipelago.PlayerNumber == -1 then
            if ROOM_SEED ~= "default" then
                ROOM_SEED = "default"
                custom_storage_item.MANUAL_LOCATIONS["default"] = {}
            end
        end
        local full_path = location.FullID
        if not custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] then
            custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] = {}
        end
        if location.AvailableChestCount < location.ChestCount then
            custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][full_path] = location.AvailableChestCount
        else
            custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][full_path] = nil
        end
    end
    ForceUpdate()
end

function ForceUpdate()
    local update = Tracker:FindObjectForCode("update")
    if update == nil then
        return
    end
    update.Active = not update.Active
end

function onClearHandler(slot_data)
    local clear_timer = os.clock()
    ScriptHost:RemoveWatchForCode("StateChange")
    Tracker.BulkUpdate = true
    local ok, err = pcall(onClear, slot_data)
    if ok then
        local handlerName = "AP onClearHandler"
        local function frameCallback()
            ScriptHost:AddWatchForCode("StateChange", "*", StateChanged)
            ScriptHost:RemoveOnFrameHandler(handlerName)
            Tracker.BulkUpdate = false
            ForceUpdate()
            print(string.format("Time taken total: %.2f", os.clock() - clear_timer))
        end
        ScriptHost:AddOnFrameHandler(handlerName, frameCallback)
    else
        Tracker.BulkUpdate = false
        print("Error: onClear failed:")
        print(err)
    end
end

function preOnClear()
    PLAYER_ID = Archipelago.PlayerNumber or -1
    TEAM_NUMBER = Archipelago.TeamNumber or 0
    if Archipelago.PlayerNumber > -1 then
        for key, _ in pairs(Troll_Lookup) do
            if string.find(string.lower(Archipelago:GetPlayerAlias(PLAYER_ID)), key, 1, true) ~= nil then
                TROLL_PLAYER = true
                break
            end
        end
        if #ALL_LOCATIONS > 0 then
            ALL_LOCATIONS = {}
        end
        for _, value in pairs(Archipelago.MissingLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end
        for _, value in pairs(Archipelago.CheckedLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end
        HINTS_ID = "_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID
        Archipelago:SetNotify({HINTS_ID})
        Archipelago:Get({HINTS_ID})
    end
    local seed_base = (Archipelago.Seed or tostring(#ALL_LOCATIONS)).."_"..Archipelago.TeamNumber.."_"..Archipelago.PlayerNumber
    if ROOM_SEED == "default" or ROOM_SEED ~= seed_base then
        ROOM_SEED = seed_base
        for _, custom_item_code in pairs({"manual_location_storage"}) do
            local custom_storage_item = Tracker:FindObjectForCode(custom_item_code).ItemState
            if custom_storage_item then
                if #custom_storage_item.MANUAL_LOCATIONS > 10 then
                    custom_storage_item.MANUAL_LOCATIONS[custom_storage_item.MANUAL_LOCATIONS_ORDER[1]] = nil
                    table.remove(custom_storage_item.MANUAL_LOCATIONS_ORDER, 1)
                end
                if custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] == nil then
                    custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] = {}
                    table.insert(custom_storage_item.MANUAL_LOCATIONS_ORDER, ROOM_SEED)
                end
            end
        end
    end
end

function onClear(slot_data)
    MANUAL_CHECKED = false
    local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
    if custom_storage_item == nil then
        CreateLuaManualStorageItem("manual_location_storage")
        custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
    end
    preOnClear()
    ScriptHost:RemoveWatchForCode("StateChanged")
    ScriptHost:RemoveOnLocationSectionHandler("location_section_change_handler")
    CUR_INDEX = -1
    for _, location_array in pairs(LOCATION_MAPPING) do
        for _, location in pairs(location_array) do
            if location then
                local location_obj = Tracker:FindObjectForCode(location)
                if location_obj then
                    if location:sub(1, 1) == "@" then
                        if custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][location_obj.FullID] then
                            location_obj.AvailableChestCount = custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][location_obj.FullID]
                        else
                            location_obj.AvailableChestCount = location_obj.ChestCount
                        end
                    else
                        location_obj.Active = false
                    end
                end
            end
        end
    end
    for _, item_array in pairs(ITEM_MAPPING) do
        for _, item_pair in pairs(item_array) do
            item_code = item_pair[1]
            item_type = item_pair[2]
            local item_obj = Tracker:FindObjectForCode(item_code)
            if item_obj then
                if item_obj.Type == "toggle" then
                    item_obj.Active = false
                elseif item_obj.Type == "progressive" then
                    item_obj.CurrentStage = 0
                elseif item_obj.Type == "consumable" then
                    if item_obj.MinCount then
                        item_obj.AcquiredCount = item_obj.MinCount
                    else
                        item_obj.AcquiredCount = 0
                    end
                elseif item_obj.Type == "progressive_toggle" then
                    item_obj.CurrentStage = 0
                    item_obj.Active = false
                end
            end
        end
    end
    PLAYER_ID = Archipelago.PlayerNumber or -1
    TEAM_NUMBER = Archipelago.TeamNumber or 0
    SLOT_DATA = slot_data
    -- Utility indicators derived from slot_data / received items
    local deathlink_obj = Tracker:FindObjectForCode("deathlink_enabled")
    if deathlink_obj then
        local dl = slot_data and slot_data.DeathLink
        deathlink_obj.Active = (dl == 1 or dl == true)
    end
    -- Traps are not sent in slot_data; reset here and light up in onItem when one is received
    local traps_obj = Tracker:FindObjectForCode("traps_enabled")
    if traps_obj then
        traps_obj.Active = false
    end
    local autoflip_obj = Tracker:FindObjectForCode("autoflip_enabled")
    if autoflip_obj then
        local af = slot_data and slot_data.AutoFlipEnabled
        autoflip_obj.Active = (af == 1 or af == true)
    end
    -- Numeric seed-info readouts (count overlay shows the slot_data value)
    local function set_info(code, value)
        local obj = Tracker:FindObjectForCode(code)
        if obj then
            obj.AcquiredCount = tonumber(value) or 0
        end
    end
    set_info("reqheads_info", slot_data and slot_data.RequiredHeads)
    set_info("startodds_info", slot_data and slot_data.StartingHeadsChance)
    set_info("flipdiff_info", slot_data and slot_data.FlipDifficulty)
    set_info("dlchance_info", slot_data and slot_data.DeathLinkChance)
    set_info("dlstreak_info", slot_data and slot_data.DeathLinkMinStreak)
    -- progression counters reset to 0/max for this seed
    ResetProgOverlays(slot_data)
    if Archipelago.PlayerNumber > -1 then
        if #ALL_LOCATIONS > 0 then
            ALL_LOCATIONS = {}
        end
        for _, value in pairs(Archipelago.MissingLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end
        for _, value in pairs(Archipelago.CheckedLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end
        HINTS_ID = "_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID
        Archipelago:SetNotify({HINTS_ID})
        Archipelago:Get({HINTS_ID})
    end
    ScriptHost:AddOnFrameHandler("load handler", OnFrameHandler)
    MANUAL_CHECKED = true
end

function onItem(index, item_id, item_name, player_number)
    if index <= CUR_INDEX then
        return
    end
    local is_local = player_number == Archipelago.PlayerNumber
    CUR_INDEX = index;
    local item = ITEM_MAPPING[item_id]
    if not item or not item[1] then
        return
    end
    for _, item_pair in pairs(item) do
        item_code = item_pair[1]
        item_type = item_pair[2]
        local item_obj = Tracker:FindObjectForCode(item_code)
        if item_obj then
            if item_obj.Type == "toggle" then
                item_obj.Active = true
            elseif item_obj.Type == "progressive" then
                if item_obj.Active == true then
                    item_obj.CurrentStage = item_obj.CurrentStage + 1
                else
                    item_obj.Active = true
                end
            elseif item_obj.Type == "consumable" then
                item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment * (tonumber(item_pair[3]) or 1)
            elseif item_obj.Type == "progressive_toggle" then
                if item_obj.Active then
                    item_obj.CurrentStage = item_obj.CurrentStage + 1
                else
                    item_obj.Active = true
                end
            end
        else
            print(string.format("onItem: could not find object for code %s", item_code[1]))
        end
    end
    -- Light up the Traps utility indicator once any trap item is received
    if item_id == 16 or item_id == 17 or item_id == 18 or item_id == 19 then
        local traps_obj = Tracker:FindObjectForCode("traps_enabled")
        if traps_obj then
            traps_obj.Active = true
        end
    end
    -- Progression items: bump the received count and refresh the "received / max" overlay
    if PROG_ID_TO_CODE[item_id] then
        local code = PROG_ID_TO_CODE[item_id]
        PROG_COUNT[code] = (PROG_COUNT[code] or 0) + 1
        UpdateProgOverlay(code)
        -- toggles only fire a state change on the first copy; force a refresh so
        -- streak access logic re-evaluates as counts climb
        ForceUpdate()
    end
end

function onLocation(location_id, location_name)
    MANUAL_CHECKED = false
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then
        print(string.format("onLocation: could not find location mapping for id %s", location_id))
        return
    end
    for _, location in pairs(location_array) do
        local location_obj = Tracker:FindObjectForCode(location)
        if location_obj then
            if location:sub(1, 1) == "@" then
                location_obj.AvailableChestCount = location_obj.AvailableChestCount - 1
            else
                location_obj.Active = true
            end
        else
            print(string.format("onLocation: could not find location_object for code %s", location))
        end
    end
    MANUAL_CHECKED = true
end

function OnNotify(key, value, old_value)
    if value ~= old_value and key == HINTS_ID then
        Tracker.BulkUpdate = true
        for _, hint in ipairs(value) do
            if hint.finding_player == Archipelago.PlayerNumber then
                if hint.status == 0 then
                    UpdateHints(hint.location, 100+hint.item_flags)
                else
                    UpdateHints(hint.location, hint.status)
                end
            end
        end
        Tracker.BulkUpdate = false
    end
end

function OnNotifyLaunch(key, value)
    if key == HINTS_ID then
        Tracker.BulkUpdate = true
        for _, hint in ipairs(value) do
            if hint.finding_player == Archipelago.PlayerNumber then
                if hint.status == 0 then
                    UpdateHints(hint.location, 100+hint.item_flags)
                else
                    UpdateHints(hint.location, hint.status)
                end
            end
        end
        Tracker.BulkUpdate = false
    end
end

function UpdateHints(locationID, status)
    if Highlight then
        local location_table = LOCATION_MAPPING[locationID]
        for _, location in ipairs(location_table) do
            if location:sub(1, 1) == "@" then
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    if TROLL_PLAYER and HIGHLIGHT_LEVEL[status] == Highlight.Avoid then
                        obj.Highlight = HIGHLIGHT_LEVEL[30]
                    else
                        obj.Highlight = HIGHLIGHT_LEVEL[status]
                    end
                else
                    print(string.format("No object found for code: %s", location))
                end
            end
        end
    end
end
