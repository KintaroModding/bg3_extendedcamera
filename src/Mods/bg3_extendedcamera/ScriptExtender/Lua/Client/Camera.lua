-- Sets the camera's limits. The game keeps them in four camera definitions of the same layout, which the Script
-- Extender exposes as Ext.Utils.GetGlobalSwitches().CameraSwitches. DefaultDistanceMax is the zoom-out limit with
-- mouse and keyboard; MaxDistFromChar is how far the camera can move away from the character, and from SlowDownDist
-- on the camera slows down (the game: 50 and 45, game test). Native Camera Tweaks
-- (ersh1) changes the same values in memory; its offsets put the exploration camera first and the combat camera
-- second.
--
-- The values belong to the game process, not to the Lua state: they stay when a save loads. So the mod always sets
-- the values from the settings, and never changes them relative to what it finds.

local Settings = Ext.Require("Shared/Settings.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")

local Camera = {}

-- The camera slows down this far before its move limit, as in the game (MaxDistFromChar 50, SlowDownDist 45).
Camera.SlowDownGap = 5

-- The values that the mod sets: the entry in CameraSwitches (1 exploration, 2 combat), the field, the setting that
-- gives the value, an optional Offset added to the setting, and a name for the log.
Camera.Targets = {
    { Index = 1, Field = "DefaultDistanceMax", Setting = "exploration_max_distance", Name = "exploration zoom" },
    { Index = 2, Field = "DefaultDistanceMax", Setting = "combat_max_distance", Name = "combat zoom" },
    { Index = 1, Field = "MaxDistFromChar", Setting = "move_max_distance", Name = "exploration move range" },
    { Index = 2, Field = "MaxDistFromChar", Setting = "move_max_distance", Name = "combat move range" },
    { Index = 1, Field = "SlowDownDist", Setting = "move_max_distance", Offset = -Camera.SlowDownGap,
        Name = "exploration slow-down" },
    { Index = 2, Field = "SlowDownDist", Setting = "move_max_distance", Offset = -Camera.SlowDownGap,
        Name = "combat slow-down" },
}

-- The range of each MCM slider. A value outside it (for example from an edited profile file) is clamped.
Camera.Ranges = {
    exploration_max_distance = { Min = 10, Max = 40 },
    combat_max_distance = { Min = 10, Max = 40 },
    move_max_distance = { Min = 10, Max = 200 },
}

-- How often the check runs that brings back the values when the game or a setting changed them, in milliseconds.
Camera.CheckIntervalMs = 2000

-- [target name] = the value this Lua state set last.
local applied = {}
-- [target name] = true after the log told once that the game reset this value.
local resetLogged = {}
local failed = false
local lastCheck = nil
-- The log tells once per Lua state the values of the camera entities, and once that the camera reached its limit.
local entitiesLogged = false
local leashLogged = false

local function Format(value)
    if type(value) ~= "number" then
        return tostring(value)
    end
    -- %g: 20 and 3.5, not the "20." that the Script Extender's tostring gives for 20.0.
    return string.format("%g", value)
end

local function Fail(message)
    if failed then
        return
    end
    failed = true
    ClientLog.Add("ERROR: " .. message .. ". The camera keeps the game's limits.")
    _PE("[bg3_extendedcamera] " .. message)
end

--- Returns the CameraSwitches list of the game, or nil and an error text.
local function CameraSwitches()
    local ok, switches = pcall(function()
        return Ext.Utils.GetGlobalSwitches().CameraSwitches
    end)
    if not ok then
        return nil, "Ext.Utils.GetGlobalSwitches failed: " .. tostring(switches)
    end
    if switches == nil then
        return nil, "the global switches have no CameraSwitches"
    end
    return switches
end

--- Returns the camera definition of a target, or nil and an error text.
local function Definition(target)
    local switches, err = CameraSwitches()
    if switches == nil then
        return nil, err
    end
    local ok, definition = pcall(function() return switches[target.Index] end)
    if not ok or definition == nil then
        return nil, "CameraSwitches has no entry " .. target.Index .. " (" .. target.Name .. ")"
    end
    return definition
end

--- Returns the value that the settings ask for: a whole number in the slider range, plus the target's Offset. MCM
--- saves values between the steps while the player drags a slider.
function Camera.Wanted(target)
    local range = Camera.Ranges[target.Setting]
    local value = math.floor(Settings.Get(target.Setting) + 0.5)
    return math.max(range.Min, math.min(range.Max, value)) + (target.Offset or 0)
end

--- Returns every camera definition with its limits, for the log:
--- "[1] max 12, min 3.5, tactical 10-50, move 30, slow down 5; [2] ...".
function Camera.Describe()
    local switches, err = CameraSwitches()
    if switches == nil then
        return "not available: " .. err
    end
    local parts = {}
    for index = 1, 4 do
        local ok, text = pcall(function()
            local definition = switches[index]
            return string.format("[%d] max %s, min %s, tactical %s-%s, move %s, slow down %s", index,
                Format(definition.DefaultDistanceMax), Format(definition.DefaultDistanceMin),
                Format(definition.TacticalDistanceMin), Format(definition.TacticalDistanceMax),
                Format(definition.MaxDistFromChar), Format(definition.SlowDownDist))
        end)
        if ok then
            parts[#parts + 1] = text
        end
    end
    return table.concat(parts, "; ")
end

--- Returns the game camera entities (component GameCameraBehavior) and whether one of them is at its move limit:
--- "MovementDistanceMax 30, AtLeashLimit false; ...", or "none".
function Camera.DescribeEntities()
    local ok, text, atLimit = pcall(function()
        local parts = {}
        local limit = false
        for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("GameCameraBehavior") or {}) do
            local behavior = entity.GameCameraBehavior
            parts[#parts + 1] = string.format("MovementDistanceMax %s, AtLeashLimit %s",
                Format(behavior.MovementDistanceMax), tostring(behavior.AtLeashLimit))
            limit = limit or behavior.AtLeashLimit == true
        end
        return #parts > 0 and table.concat(parts, "; ") or "none", limit
    end)
    if not ok then
        return "not available: " .. tostring(text), false
    end
    return text, atLimit
end

--- Writes the camera entities to the log once they exist, and once when the camera reached its move limit.
local function WatchEntities()
    if entitiesLogged and leashLogged then
        return
    end
    local text, atLimit = Camera.DescribeEntities()
    if text == "none" then
        return
    end
    if not entitiesLogged then
        entitiesLogged = true
        ClientLog.Add("Camera entities: " .. text .. ".")
    end
    if atLimit and not leashLogged then
        leashLogged = true
        ClientLog.Add("The camera reached its move limit: " .. text .. ". Camera switches: " .. Camera.Describe() .. ".")
    end
end

--- Sets every target from the settings. The log line names the reason and each change. Returns true when all values
--- are set.
function Camera.Apply(reason)
    if failed then
        return false
    end
    local changes = {}
    for _, target in ipairs(Camera.Targets) do
        local definition, err = Definition(target)
        if definition == nil then
            Fail(err)
            return false
        end
        local wanted = Camera.Wanted(target)
        local ok, old = pcall(function()
            local before = definition[target.Field]
            definition[target.Field] = wanted
            return before
        end)
        if not ok then
            Fail("could not set the " .. target.Name .. ": " .. tostring(old))
            return false
        end
        local now = definition[target.Field]
        if math.abs(now - wanted) > 0.01 then
            Fail("the game did not keep the " .. target.Name .. ": set " .. Format(wanted) .. ", read " .. Format(now))
            return false
        end
        applied[target.Name] = wanted
        changes[#changes + 1] = target.Name .. " " .. Format(old) .. " -> " .. Format(wanted)
    end
    ClientLog.Add(reason .. ": " .. table.concat(changes, ", ") .. ".")
    return true
end

--- Sets the values again when they differ from what the settings ask for: after a setting changed, or when the game
--- wrote its own value. The log tells once per target that the game reset a value.
function Camera.Check()
    if failed then
        return
    end
    WatchEntities()
    for _, target in ipairs(Camera.Targets) do
        local definition, err = Definition(target)
        if definition == nil then
            Fail(err)
            return
        end
        local current = definition[target.Field]
        local wanted = Camera.Wanted(target)
        if applied[target.Name] ~= wanted then
            Camera.Apply(applied[target.Name] == nil and "Start" or "Setting changed")
            return
        end
        if math.abs(current - wanted) > 0.01 then
            if not resetLogged[target.Name] then
                resetLogged[target.Name] = true
                ClientLog.Add("The game set the " .. target.Name .. " to " .. Format(current) .. "; it is set again.")
            end
            Camera.Apply("Game reset")
            return
        end
    end
end

--- Runs Camera.Check every CheckIntervalMs, from the Tick event.
function Camera.OnTick()
    local now = Ext.Timer.MonotonicTime()
    if lastCheck ~= nil and now - lastCheck < Camera.CheckIntervalMs then
        return
    end
    lastCheck = now
    Camera.Check()
end

return Camera
