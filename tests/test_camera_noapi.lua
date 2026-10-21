-- When the Script Extender gives no camera switches (an older or newer version), the mod logs one error and leaves the
-- camera alone.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }
Harness.GlobalSwitches = {}

Ext.Require("BootstrapClient.lua")
local Camera = Ext.Require("Client/Camera.lua")

Test("missing camera switches give one error line and no crash", function()
    Ext.Events.SessionLoaded:Fire()
    for _ = 1, 3 do
        Harness.Monotonic = Harness.Monotonic + Camera.CheckIntervalMs
        Harness.RunTick()
    end
    Harness.RunTimers()
    local log = Harness.Files["bg3_extendedcamera/client.log"] or ""
    AssertTrue(string.find(log, "Camera switches: not available: the global switches have no CameraSwitches.", 1, true),
        "switches line")
    local _, count = string.gsub(log, "ERROR: ", "")
    AssertEq(count, 1, "error lines")
    AssertTrue(string.find(log, "The camera keeps the game's limits.", 1, true), "error text")
    AssertEq(#Harness.Errors, 1, "console errors")
    -- The console error is expected here; it must not fail the test.
    Harness.Errors = {}
end)

Test("a GetGlobalSwitches error is caught", function()
    Ext.Utils.GetGlobalSwitches = function() error("no such function") end
    local text = Camera.Describe()
    AssertTrue(string.find(text, "Ext.Utils.GetGlobalSwitches failed", 1, true), "describe text")
end)
