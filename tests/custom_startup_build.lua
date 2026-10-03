arg = {}; dofile("HeadlessWrapper.lua")
local oldOpen, oldSearch = io.open, NewFileSearch
local originalPath, originalMode, originalArgs = main.buildPath, main.newMode, main.newModeArgs
main.buildPath = "fixture/"
local paths, rememberedStatus = {}, "missing"
io.open = function(path)
	assert(path == "fixture/old.xml", "Unexpected user file read")
	if rememberedStatus == "exists" then return {close=function() end} end
	return nil, "fixture error", rememberedStatus == "missing" and 2 or 13
end
NewFileSearch = function(pattern, folders)
	local list = paths[pattern .. tostring(folders)] or {}
	if #list == 0 then return nil end
	local index = 1
	return { GetFileName=function() return list[index] end, NextFile=function() index=index+1; return index<=#list end }
end
local function resolve(mode)
	main:SetMode(mode or "BUILD", "fixture/old.xml", "Old")
	main:ResolveStartupBuild()
	return main.newModeArgs[1]
end
paths["fixture/*.xmlnil"] = {"LA.xml"}
assert(resolve() == "fixture/LA.xml" and main.newModeArgs[2] == "LA")
rememberedStatus = "exists"; assert(resolve() == "fixture/old.xml")
rememberedStatus = "unreadable"; assert(resolve() == "fixture/old.xml")
rememberedStatus = "missing"; assert(resolve("LIST") == "fixture/old.xml" and main.newMode == "LIST")
paths["fixture/*.xmlnil"] = {"LA.xml", "Other.xml"}; assert(resolve() == "fixture/old.xml")
paths = {}; assert(resolve() == "fixture/old.xml")
paths["fixture/*true"] = {"Subfolder"}; paths["fixture/Subfolder/*.xmlnil"] = {"Renamed.XML"}
assert(resolve() == "fixture/Subfolder/Renamed.XML" and main.newModeArgs[2] == "Renamed")
paths["fixture/*.xmlnil"] = {"Root.xml"}; assert(resolve() == "fixture/old.xml")
io.open, NewFileSearch = oldOpen, oldSearch
main.buildPath, main.newMode, main.newModeArgs = originalPath, originalMode, originalArgs
print("PASS: missing remembered file reopens a sole build; existing/unreadable/list/ambiguous/empty modes and subfolders are preserved")
