
-- Graph-based logic for Unfair Flips.
-- Connect regions via unfair_flips_location:connect_one_way() or connect_two_ways().

unfair_flips_location = {}
unfair_flips_location.__index = unfair_flips_location

accessLVL= {
    [0] = "none",
    [1] = "partial",
    [3] = "inspect",
    [5] = "sequence break",
    [6] = "normal",
    [7] = "cleared",
    [false] = "none",
    [true] = "normal",
}

NAMED_LOCATIONS = {}
local stale = true
local accessibilityCache = {}
local accessibilityCacheComplete = false
local currentParent = nil
local currentLocation = nil
local indirectConnections = {}

function Table_insert_at(er_table, key, value)
    if er_table[key] == nil then
        er_table[key] = {}
    end
    table.insert(er_table[key], value)
end

function CanReach(name)
    local location
    if stale then
        stale = false
        accessibilityCacheComplete = false
        accessibilityCache = {}
        indirectConnections = {}
        while not accessibilityCacheComplete do
            accessibilityCacheComplete = true
            entry_point:discover(ACCESS_NORMAL, 0, nil)
            for dst, parents in pairs(indirectConnections) do
                if dst:accessibility() < ACCESS_NORMAL then
                    for parent, src in pairs(parents) do
                        parent:discover(parent:accessibility(), parent.keys, parent.worldstate)
                    end
                end
            end
        end
    end
    location = NAMED_LOCATIONS[name]
    if location == nil then
        return ACCESS_NONE
    end
    return location:accessibility()
end

function unfair_flips_location.new(name)
    local self = setmetatable({}, unfair_flips_location)
    if name then
        NAMED_LOCATIONS[name] = self
        self.name = name
    else
        NAMED_LOCATIONS[name] = self
        self.name = tostring(self)
    end
    self.worldstate = origin
    self.exits = {}
    self.keys = math.huge
    return self
end

local function always()
    return ACCESS_NORMAL
end

function unfair_flips_location:connect_one_way(exit, rule)
    if type(exit) == "string" then
        local existing = NAMED_LOCATIONS[exit]
        if existing then
            exit = existing
        else
            exit = unfair_flips_location.new(exit)
        end
    end
    if rule == nil then
        rule = always
    end
    self.exits[#self.exits + 1] = { exit, rule }
end

function unfair_flips_location:connect_two_ways(exit, rule)
    self:connect_one_way(exit, rule)
    exit:connect_one_way(self, rule)
end

function unfair_flips_location:connect_one_way_entrance(name, exit, rule)
    if rule == nil then
        rule = always
    end
    self.exits[#self.exits + 1] = { exit, rule }
end

function unfair_flips_location:connect_two_ways_entrance(name, exit, rule)
    if exit == nil then
        return
    end
    self:connect_one_way_entrance(name, exit, rule)
    exit:connect_one_way_entrance(name, self, rule)
end

function unfair_flips_location:connect_two_ways_entrance_door_stuck(name, exit, rule1, rule2)
    self:connect_one_way_entrance(name, exit, rule1)
    exit:connect_one_way_entrance(name, self, rule2)
end

function unfair_flips_location:connect_two_ways_stuck(exit, rule1, rule2)
    self:connect_one_way(exit, rule1)
    exit:connect_one_way(self, rule2)
end

function unfair_flips_location:accessibility()
    if currentLocation ~= nil and currentParent ~= nil then
        if indirectConnections[currentLocation] == nil then
            indirectConnections[currentLocation] = {}
        end
        indirectConnections[currentLocation][currentParent] = self
    end
    local res = accessibilityCache[self]
    if res == nil then
        res = ACCESS_NONE
        accessibilityCache[self] = res
    end
    return res
end

function unfair_flips_location:discover(accessibility, keys)
    if accessibility > self:accessibility() then
        self.keys = math.huge
        accessibilityCache[self] = accessibility
        accessibilityCacheComplete = false
    end
    if keys < self.keys then
        self.keys = keys
    end
    if accessibility > 0 then
        for _, exit in pairs(self.exits) do
            local location
            local location_name = self.name
            if location == nil then
                location = exit[1] or empty_location
            end
            local oldAccess = location:accessibility()
            local oldKey = location.keys or 0
            if oldAccess < accessibility then
                local rule = exit[2]
                currentParent, currentLocation = self, location
                local access, key = rule(keys)
                local parent_access = currentParent:accessibility()
                if type(access) == "boolean" then
                    access = A(access)
                end
                if access > parent_access then
                    access = parent_access
                end
                currentParent, currentLocation = nil, nil
                if access == nil then
                    print("Warning: " .. self.name .. " -> " .. location.name .. " rule returned nil")
                    access = ACCESS_NONE
                end
                if key == nil then
                    key = keys
                end
                if access > oldAccess or (access == oldAccess and key < oldKey) then
                    location:discover(access, key)
                end
            end
        end
    end
end

entry_point = unfair_flips_location.new("entry_point")

function StateChanged()
    stale = true
end

ScriptHost:AddWatchForCode("StateChanged", "*", StateChanged)
