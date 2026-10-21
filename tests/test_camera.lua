-- The client sets the zoom-out limits from the MCM settings: at the session load, at once after a change, and again
-- when the game writes its own value.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.InstallMCM({ exploration_max_distance = 25, combat_max_distance = 30 })

Ext.Require("BootstrapClient.lua")
local Camera = Ext.Require("Client/Camera.lua")

local switches = Harness.GlobalSwitches.CameraSwitches

local function ClientLog()
    Harness.RunTimers()
    return Harness.Files["bg3_extendedcamera/client.log"] or ""
end

--- Moves the monotonic clock past the check interval and runs one tick.
local function TickAfterInterval()
    Harness.Monotonic = Harness.Monotonic + Camera.CheckIntervalMs
    Harness.RunTick()
end

Test("the session load logs the game's values and sets the MCM values", function()
    Ext.Events.SessionLoaded:Fire()
    AssertEq(switches[1].DefaultDistanceMax, 25, "exploration limit")
    AssertEq(switches[2].DefaultDistanceMax, 30, "combat limit")
    AssertEq(switches[3].DefaultDistanceMax, 12, "entry 3 unchanged")
    AssertEq(switches[4].DefaultDistanceMax, 12, "entry 4 unchanged")
    local log = ClientLog()
    AssertTrue(string.find(log, "Camera switches: [1] max 12, min 3.5, tactical 10-50; [2] max 15, min 4,", 1, true),
        "switches line")
    AssertTrue(string.find(log, "Session loaded: zoom-out limit exploration 12 -> 25, combat 15 -> 30.", 1, true),
        "apply line")
end)

Test("a saved setting applies at once", function()
    Harness.FireMCMSettingSaved("exploration_max_distance", 18)
    AssertEq(switches[1].DefaultDistanceMax, 18, "exploration limit")
    AssertEq(switches[2].DefaultDistanceMax, 30, "combat limit unchanged")
    AssertTrue(string.find(ClientLog(), "Setting changed: zoom-out limit exploration 25 -> 18, combat 30 -> 30.", 1,
        true), "apply line")
end)

Test("slider values between the steps are rounded and clamped to the slider range", function()
    Harness.FireMCMSettingSaved("exploration_max_distance", 23.4)
    AssertEq(switches[1].DefaultDistanceMax, 23, "rounded")
    Harness.FireMCMSettingSaved("exploration_max_distance", 99)
    AssertEq(switches[1].DefaultDistanceMax, Camera.MaxDistance, "clamped to the maximum")
    Harness.FireMCMSettingSaved("exploration_max_distance", 3)
    AssertEq(switches[1].DefaultDistanceMax, Camera.MinDistance, "clamped to the minimum")
    Harness.FireMCMSettingSaved("exploration_max_distance", 25)
end)

Test("a value the game writes back is set again, and the log tells it once", function()
    switches[2].DefaultDistanceMax = 15
    TickAfterInterval()
    AssertEq(switches[2].DefaultDistanceMax, 30, "set again")
    local log = ClientLog()
    AssertTrue(string.find(log, "The game set the combat limit to 15; it is set again.", 1, true), "reset line")
    AssertTrue(string.find(log, "Game reset: zoom-out limit exploration 25 -> 25, combat 15 -> 30.", 1, true),
        "apply line")
    switches[2].DefaultDistanceMax = 15
    TickAfterInterval()
    AssertEq(switches[2].DefaultDistanceMax, 30, "set again the second time")
    local _, count = string.gsub(ClientLog(), "The game set the combat limit", "")
    AssertEq(count, 1, "reset lines")
end)

Test("the check waits for the interval", function()
    TickAfterInterval()
    switches[1].DefaultDistanceMax = 12
    Harness.Monotonic = Harness.Monotonic + Camera.CheckIntervalMs - 1
    Harness.RunTick()
    AssertEq(switches[1].DefaultDistanceMax, 12, "no check before the interval")
    Harness.Monotonic = Harness.Monotonic + 1
    Harness.RunTick()
    AssertEq(switches[1].DefaultDistanceMax, 25, "check after the interval")
end)

Test("a setting change without an MCM event is caught by the check", function()
    Harness.MCMValues.combat_max_distance = 35
    TickAfterInterval()
    AssertEq(switches[2].DefaultDistanceMax, 35, "combat limit")
end)

Test("the slider range in the blueprint matches Camera.MinDistance and Camera.MaxDistance", function()
    local found = 0
    for _, tab in ipairs(MCM_BLUEPRINT.Tabs) do
        for _, section in ipairs(tab.Sections or {}) do
            for _, setting in ipairs(section.Settings or {}) do
                for _, mode in ipairs(Camera.Modes) do
                    if setting.Id == mode.Setting then
                        found = found + 1
                        AssertEq(setting.Options.Min, Camera.MinDistance, setting.Id .. " Min")
                        AssertEq(setting.Options.Max, Camera.MaxDistance, setting.Id .. " Max")
                    end
                end
            end
        end
    end
    AssertEq(found, #Camera.Modes, "settings of the modes in the blueprint")
end)
