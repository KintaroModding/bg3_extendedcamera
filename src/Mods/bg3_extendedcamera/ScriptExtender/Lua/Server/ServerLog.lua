-- Messages and errors of the server side, readable outside the game: Script Extender\bg3_extendedcamera\server.log.

local FileWriter = Ext.Require("Shared/FileWriter.lua")

return FileWriter.NewLineFile("bg3_extendedcamera/server.log", 500)
