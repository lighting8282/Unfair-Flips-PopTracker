
local function CanProvideCodeFunc(self, code)
    return code == self.Name
end

local function OnLeftClickFunc(self)
end

local function OnRightClickFunc(self)
end

local function OnMiddleClickFunc(self)
end

local function ProvidesCodeFunc(self, code)
    if CanProvideCodeFunc(self, code) then
        return 1
    end
    return 0
end

local function SaveManualLocationStorageFunc(self)
    return {
        MANUAL_LOCATIONS = self.ItemState.MANUAL_LOCATIONS,
        MANUAL_LOCATIONS_ORDER = self.ItemState.MANUAL_LOCATIONS_ORDER,
        Target = self.ItemState.Target,
        Name = self.Name,
        Icon = self.Icon
    }
end

local function LoadManualLocationStorageFunc(self, data)
    if data ~= nil and self.Name == data.Name then
        self.ItemState.MANUAL_LOCATIONS = data.MANUAL_LOCATIONS
        self.ItemState.MANUAL_LOCATIONS_ORDER = data.MANUAL_LOCATIONS_ORDER
        self.Icon = ImageReference:FromPackRelativePath(data.Icon)
    end
end

function CreateLuaManualStorageItem(name)
    local self = ScriptHost:CreateLuaItem()
    self.Name = name
    self.Icon = ImageReference:FromPackRelativePath("/images/items/closed_Chest.png")
    self.ItemState = {
        MANUAL_LOCATIONS = {
            ["default"] = {}
        },
        MANUAL_LOCATIONS_ORDER = {}
    }
    self.CanProvideCodeFunc = CanProvideCodeFunc
    self.OnLeftClickFunc = OnLeftClickFunc
    self.OnRightClickFunc = OnRightClickFunc
    self.OnMiddleClickFunc = OnMiddleClickFunc
    self.ProvidesCodeFunc = ProvidesCodeFunc
    self.SaveFunc = SaveManualLocationStorageFunc
    self.LoadFunc = LoadManualLocationStorageFunc
    return self
end
