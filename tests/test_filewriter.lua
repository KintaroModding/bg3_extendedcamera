-- The log files keep their old lines: both Lua states start again on every save load, and the lines from before must
-- stay in the file.

local FileWriter = Ext.Require("Shared/FileWriter.lua")

Test("a new line file starts with the lines already in the file", function()
    Harness.Files["bg3_extendedcamera/test.log"] = "line 1\nline 2\n"
    local log = FileWriter.NewLineFile("bg3_extendedcamera/test.log", 10)
    log.Add("line 3")
    Harness.RunTimers()
    local text = Harness.Files["bg3_extendedcamera/test.log"]
    AssertTrue(string.find(text, "^line 1\nline 2\n"), "old lines first: " .. text)
    AssertTrue(string.find(text, " UTC  line 3\n$"), "new line last: " .. text)
end)

Test("the old lines count toward the line limit", function()
    Harness.Files["bg3_extendedcamera/full.log"] = "a\r\nb\r\nc\r\n"
    local log = FileWriter.NewLineFile("bg3_extendedcamera/full.log", 2)
    log.Add("d")
    Harness.RunTimers()
    local text = Harness.Files["bg3_extendedcamera/full.log"]
    AssertTrue(string.find(text, "^c\n"), "oldest lines dropped: " .. text)
    AssertTrue(not string.find(text, "b", 1, true), "b dropped: " .. text)
end)

Test("a missing file starts empty", function()
    local log = FileWriter.NewLineFile("bg3_extendedcamera/new.log", 5)
    log.Add("first")
    Harness.RunTimers()
    AssertTrue(string.find(Harness.Files["bg3_extendedcamera/new.log"], "^%d%d%d%d%-%d%d%-%d%d [%d:]+ UTC  first\n$"),
        "one line")
end)
