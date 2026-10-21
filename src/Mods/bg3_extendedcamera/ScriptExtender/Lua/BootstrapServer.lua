local Common = Ext.Require("Shared/Common.lua")
local Settings = Ext.Require("Shared/Settings.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    ServerLog.Add("Extended Camera " .. Common.ModVersion() .. " loaded.")
    ServerLog.Add("Settings: " .. Settings.Describe() .. ".")
end)

-- In multiplayer, the host's server holds the values that count: apply rules that change the game here.
Settings.OnChange(function(settingId)
    local reason = settingId and ("Setting changed (" .. tostring(settingId) .. ")") or "MCM profile changed"
    ServerLog.Add(reason .. ": " .. Settings.Describe() .. ".")
end)
