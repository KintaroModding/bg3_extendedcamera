-- Sets the camera's zoom-out limit. The game keeps its camera limits in four camera definitions of the same layout,
-- which the Script Extender exposes as Ext.Utils.GetGlobalSwitches().CameraSwitches. DefaultDistanceMax is the
-- zoom-out limit with mouse and keyboard. Native Camera Tweaks (ersh1) changes the same values in memory; its offsets
-- put the exploration camera first and the combat camera second.
--
-- The values belong to the game process, not to the Lua state: they stay when a save loads. So the mod always sets
-- the values from the settings, and never changes them relative to what it finds.

local Settings = Ext.Require("Shared/Settings.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")

local Camera = {}

-- The camera definitions that the mod changes: Index in CameraSwitches, a name for the log, the setting, and the
-- game's own limit (for the texts only).
Camera.Modes = {
    { Index = 1, Name = "exploration", Setting = "exploration_max_distance", Vanilla = 12 },
    { Index = 2, Name = "combat", Setting = "combat_max_distance", Vanilla = 15 },
}

-- The range of the MCM sliders. A value outside it (for example from an edited profile file) is clamped.
Camera.MinDistance = 10
Camera.MaxDistance = 40

-- How often the check runs that brings back the values when the game or a setting changed them, in milliseconds.
Camera.CheckIntervalMs = 2000

-- [mode name] = the value this Lua state set last.
local applied = {}
-- [mode name] = true after the log told once that the game reset this value.
local resetLogged = {}
local failed = false
local lastCheck = nil

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

--- Returns the camera definition of a mode, or nil and an error text.
local function Definition(mode)
    local switches, err = CameraSwitches()
    if switches == nil then
        return nil, err
    end
    local ok, definition = pcall(function() return switches[mode.Index] end)
    if not ok or definition == nil then
        return nil, "CameraSwitches has no entry " .. mode.Index .. " (" .. mode.Name .. ")"
    end
    return definition
end

--- Returns the limit that the settings ask for: a whole number in the slider range. MCM saves values between the
--- steps while the player drags a slider.
function Camera.Wanted(mode)
    local value = Settings.Get(mode.Setting)
    value = math.floor(value + 0.5)
    return math.max(Camera.MinDistance, math.min(Camera.MaxDistance, value))
end

--- Returns every camera definition with its zoom limits, for the log:
--- "[1] max 12, min 3.5, tactical 10-50; [2] ...".
function Camera.Describe()
    local switches, err = CameraSwitches()
    if switches == nil then
        return "not available: " .. err
    end
    local parts = {}
    for index = 1, 4 do
        local ok, text = pcall(function()
            local definition = switches[index]
            return string.format("[%d] max %s, min %s, tactical %s-%s", index, Format(definition.DefaultDistanceMax),
                Format(definition.DefaultDistanceMin), Format(definition.TacticalDistanceMin),
                Format(definition.TacticalDistanceMax))
        end)
        if ok then
            parts[#parts + 1] = text
        end
    end
    return table.concat(parts, "; ")
end

--- Sets the zoom limit of every mode from the settings. The log line names the reason and each change.
--- Returns true when all values are set.
function Camera.Apply(reason)
    if failed then
        return false
    end
    local changes = {}
    for _, mode in ipairs(Camera.Modes) do
        local definition, err = Definition(mode)
        if definition == nil then
            Fail(err)
            return false
        end
        local wanted = Camera.Wanted(mode)
        local ok, old = pcall(function()
            local before = definition.DefaultDistanceMax
            definition.DefaultDistanceMax = wanted
            return before
        end)
        if not ok then
            Fail("could not set the " .. mode.Name .. " limit: " .. tostring(old))
            return false
        end
        local now = definition.DefaultDistanceMax
        if math.abs(now - wanted) > 0.01 then
            Fail("the game did not keep the " .. mode.Name .. " limit: set " .. Format(wanted) .. ", read "
                .. Format(now))
            return false
        end
        applied[mode.Name] = wanted
        changes[#changes + 1] = mode.Name .. " " .. Format(old) .. " -> " .. Format(wanted)
    end
    ClientLog.Add(reason .. ": zoom-out limit " .. table.concat(changes, ", ") .. ".")
    return true
end

--- Sets the limits again when they differ from what the mode needs: after a setting changed, or when the game wrote
--- its own value. The log tells once per mode that the game reset a value.
function Camera.Check()
    if failed then
        return
    end
    for _, mode in ipairs(Camera.Modes) do
        local definition, err = Definition(mode)
        if definition == nil then
            Fail(err)
            return
        end
        local current = definition.DefaultDistanceMax
        local wanted = Camera.Wanted(mode)
        if applied[mode.Name] ~= wanted then
            Camera.Apply(applied[mode.Name] == nil and "Start" or "Setting changed")
            return
        end
        if math.abs(current - wanted) > 0.01 then
            if not resetLogged[mode.Name] then
                resetLogged[mode.Name] = true
                ClientLog.Add("The game set the " .. mode.Name .. " limit to " .. Format(current) .. "; it is set again.")
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
