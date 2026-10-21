local Common = Ext.Require("Shared/Common.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")
local Camera = Ext.Require("Client/Camera.lua")

-- The camera belongs to the client: every player's game sets its own limits.
Ext.Events.SessionLoaded:Subscribe(function()
    ClientLog.Add("Extended Camera " .. Common.ModVersion() .. " loaded.")
    ClientLog.Add("Camera switches: " .. Camera.Describe() .. ".")
    Camera.Apply("Session loaded")
end)

-- A changed setting applies at once; Camera.Check sets only the values that differ.
Settings.OnChange(function()
    Camera.Check()
end)

-- Brings back the limits when the game writes its own values, and catches setting changes without an MCM event.
Ext.Events.Tick:Subscribe(Camera.OnTick)
