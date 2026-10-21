-- The client sets the zoom-out limits and the move range from the MCM settings: at the session load, at once after a
-- change, and again when the game writes its own value.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.InstallMCM({ exploration_max_distance = 25, combat_max_distance = 30, move_max_distance = 80 })

Ext.Require("BootstrapClient.lua")
local Camera = Ext.Require("Client/Camera.lua")

local switches = Harness.GlobalSwitches.CameraSwitches

local function ClientLog()
    Harness.RunTimers()
    return Harness.Files["bg3_extendedcamera/client.log"] or ""
end

local function Count(text, pattern)
    local _, count = string.gsub(text, pattern, "")
    return count
end

--- Moves the monotonic clock past the check interval and runs one tick.
local function TickAfterInterval()
    Harness.Monotonic = Harness.Monotonic + Camera.CheckIntervalMs
    Harness.RunTick()
end

Test("the session load logs the game's values and sets the MCM values", function()
    Ext.Events.SessionLoaded:Fire()
    AssertEq(switches[1].DefaultDistanceMax, 25, "exploration zoom")
    AssertEq(switches[2].DefaultDistanceMax, 30, "combat zoom")
    AssertEq(switches[1].MaxDistFromChar, 80, "exploration move range")
    AssertEq(switches[2].MaxDistFromChar, 80, "combat move range")
    AssertEq(switches[1].SlowDownDist, 80 - Camera.SlowDownGap, "exploration slow-down")
    AssertEq(switches[2].SlowDownDist, 80 - Camera.SlowDownGap, "combat slow-down")
    AssertEq(switches[3].DefaultDistanceMax, 12, "entry 3 unchanged")
    AssertEq(switches[3].MaxDistFromChar, 50, "entry 3 move range unchanged")
    AssertEq(switches[3].SlowDownDist, 45, "entry 3 slow-down unchanged")
    AssertEq(switches[4].DefaultDistanceMax, 12, "entry 4 unchanged")
    local log = ClientLog()
    AssertTrue(string.find(log, "Camera switches: [1] max 12, min 3.5, tactical 10-50, move 50, slow down 45; [2] max 15,",
        1, true), "switches line")
    AssertTrue(string.find(log, "Session loaded: exploration zoom 12 -> 25, combat zoom 15 -> 30, "
        .. "exploration move range 50 -> 80, combat move range 50 -> 80, exploration slow-down 45 -> 75, "
        .. "combat slow-down 45 -> 75.", 1, true), "apply line")
end)

Test("a saved setting applies at once", function()
    Harness.FireMCMSettingSaved("exploration_max_distance", 18)
    AssertEq(switches[1].DefaultDistanceMax, 18, "exploration zoom")
    AssertEq(switches[2].DefaultDistanceMax, 30, "combat zoom unchanged")
    AssertTrue(string.find(ClientLog(), "Setting changed: exploration zoom 25 -> 18, combat zoom 30 -> 30,", 1, true),
        "apply line")
    Harness.FireMCMSettingSaved("move_max_distance", 120)
    AssertEq(switches[1].MaxDistFromChar, 120, "exploration move range")
    AssertEq(switches[2].MaxDistFromChar, 120, "combat move range")
    AssertEq(switches[2].SlowDownDist, 115, "combat slow-down")
    Harness.FireMCMSettingSaved("exploration_max_distance", 25)
end)

Test("slider values between the steps are rounded and clamped to the slider range", function()
    Harness.FireMCMSettingSaved("exploration_max_distance", 23.4)
    AssertEq(switches[1].DefaultDistanceMax, 23, "rounded")
    Harness.FireMCMSettingSaved("exploration_max_distance", 99)
    AssertEq(switches[1].DefaultDistanceMax, Camera.Ranges.exploration_max_distance.Max, "clamped to the maximum")
    Harness.FireMCMSettingSaved("exploration_max_distance", 3)
    AssertEq(switches[1].DefaultDistanceMax, Camera.Ranges.exploration_max_distance.Min, "clamped to the minimum")
    Harness.FireMCMSettingSaved("move_max_distance", 999)
    AssertEq(switches[1].MaxDistFromChar, Camera.Ranges.move_max_distance.Max, "move range clamped")
    AssertEq(switches[1].SlowDownDist, Camera.Ranges.move_max_distance.Max - Camera.SlowDownGap, "slow-down clamped")
    Harness.FireMCMSettingSaved("exploration_max_distance", 25)
    Harness.FireMCMSettingSaved("move_max_distance", 80)
end)

Test("a value the game writes back is set again, and the log tells it once", function()
    switches[2].DefaultDistanceMax = 15
    TickAfterInterval()
    AssertEq(switches[2].DefaultDistanceMax, 30, "set again")
    local log = ClientLog()
    AssertTrue(string.find(log, "The game set the combat zoom to 15; it is set again.", 1, true), "reset line")
    AssertTrue(string.find(log, "Game reset: exploration zoom 25 -> 25, combat zoom 15 -> 30,", 1, true), "apply line")
    switches[2].DefaultDistanceMax = 15
    TickAfterInterval()
    AssertEq(switches[2].DefaultDistanceMax, 30, "set again the second time")
    AssertEq(Count(ClientLog(), "The game set the combat zoom"), 1, "reset lines")
    switches[1].MaxDistFromChar = 30
    TickAfterInterval()
    AssertEq(switches[1].MaxDistFromChar, 80, "move range set again")
    AssertTrue(string.find(ClientLog(), "The game set the exploration move range to 30; it is set again.", 1, true),
        "move range reset line")
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
    AssertEq(switches[2].DefaultDistanceMax, 35, "combat zoom")
end)

Test("the log tells the camera entities once, and once when the camera reached its move limit", function()
    local behavior = { MovementDistanceMax = 30, AtLeashLimit = false }
    Harness.AddObject("ca000000-0000-0000-0000-000000000001", "camera", "Camera",
        { Components = { GameCameraBehavior = behavior } })
    TickAfterInterval()
    TickAfterInterval()
    local log = ClientLog()
    AssertEq(Count(log, "Camera entities: MovementDistanceMax 30, AtLeashLimit false%."), 1, "entities line")
    AssertEq(Count(log, "reached its move limit"), 0, "no limit line yet")
    behavior.AtLeashLimit = true
    TickAfterInterval()
    TickAfterInterval()
    log = ClientLog()
    AssertEq(Count(log, "The camera reached its move limit: MovementDistanceMax 30, AtLeashLimit true%. Camera switches: "
        .. "%[1%] max 25"), 1, "limit line")
    Harness.RemoveObject("ca000000-0000-0000-0000-000000000001")
end)

Test("the slider ranges in the blueprint match Camera.Ranges", function()
    local found = 0
    for _, tab in ipairs(MCM_BLUEPRINT.Tabs) do
        for _, section in ipairs(tab.Sections or {}) do
            for _, setting in ipairs(section.Settings or {}) do
                local range = Camera.Ranges[setting.Id]
                if range ~= nil then
                    found = found + 1
                    AssertEq(setting.Options.Min, range.Min, setting.Id .. " Min")
                    AssertEq(setting.Options.Max, range.Max, setting.Id .. " Max")
                end
            end
        end
    end
    local count = 0
    for _ in pairs(Camera.Ranges) do
        count = count + 1
    end
    AssertEq(found, count, "settings of Camera.Ranges in the blueprint")
    for _, target in ipairs(Camera.Targets) do
        AssertTrue(Camera.Ranges[target.Setting] ~= nil, target.Name .. " has a range")
    end
end)
