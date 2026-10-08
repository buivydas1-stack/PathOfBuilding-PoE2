-- Isolated background calculation. No saved builds/settings or output files are
-- accessed: the complete live build arrives as an in-memory XML snapshot.
local root, xmlText, itemRaw, slotName, candidateJSON, considerExisting, socketIndex, reportType, quality = ...
root = root:gsub('\\', '/'):gsub('/$', '')
package.path = root .. '/?.lua;' .. package.path
local open = io.open
io.open = function(path, mode)
	mode = mode or 'r'
	assert(not mode:find('[wa+]'), 'Calculation workers cannot write files.')
	local normalized = path:gsub('\\', '/')
	if normalized:lower():match('settings%.xml$') or normalized:lower():match('first%.run$') or normalized:lower():find('/builds/', 1, true) then return nil, 'User data is unavailable in calculation workers.' end
	if not normalized:match('^%a:/') and not normalized:match('^/') then path = root .. '/' .. normalized end
	return open(path, mode)
end
os.remove = function() error('Calculation workers cannot remove files.') end
os.rename = function() error('Calculation workers cannot rename files.') end
os.execute = function() error('Calculation workers cannot launch processes.') end
arg = { }
APP_NAME = 'Path of Building (PoE2)'
jit.opt.start('maxtrace=4000', 'maxmcode=8192')
-- Callbacks
local callbackTable = { }
local mainObject
function runCallback(name, ...)
	if callbackTable[name] then
		return callbackTable[name](...)
	elseif mainObject and mainObject[name] then
		return mainObject[name](mainObject, ...)
	end
end
function SetCallback(name, func)
	callbackTable[name] = func
end
function GetCallback(name)
	return callbackTable[name]
end
function SetMainObject(obj)
	mainObject = obj
end

-- Image Handles
local imageHandleClass = { }
imageHandleClass.__index = imageHandleClass
function NewImageHandle()
	return setmetatable({ }, imageHandleClass)
end
function imageHandleClass:Load(fileName, ...)
	self.valid = true
end
function imageHandleClass:Unload()
	self.valid = false
end
function imageHandleClass:IsValid()
	return self.valid
end
function imageHandleClass:SetLoadingPriority(pri) end
function imageHandleClass:ImageSize()
	return 1, 1
end

-- Rendering
function RenderInit(flag, ...) end
function GetScreenSize()
	return 1920, 1080
end
function GetScreenScale()
	return 1
end
function GetVirtualScreenSize()
	return GetScreenSize()
end
function GetDPIScaleOverridePercent()
	return 1
end
function SetDPIScaleOverridePercent(scale) end
function SetClearColor(r, g, b, a) end
function SetDrawLayer(layer, subLayer) end
function SetViewport(x, y, width, height) end
function SetDrawColor(r, g, b, a) end
function GetDrawColor(r, g, b, a) end
function DrawImage(imgHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom) end
function DrawImageQuad(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4) end
function DrawString(left, top, align, height, font, text) end
function DrawStringWidth(height, font, text)
	return 1
end
function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
	return 0
end
function StripEscapes(text)
	return text:gsub("%^%d",""):gsub("%^x%x%x%x%x%x%x","")
end
function GetAsyncCount()
	return 0
end

-- Search Handles
function NewFileSearch() end

-- General Functions
function SetWindowTitle(title) end
function GetCursorPos()
	return 0, 0
end
function SetCursorPos(x, y) end
function ShowCursor(doShow) end
function IsKeyDown(keyName) end
function Copy(text) end
function Paste() end
function Deflate(data)
	-- TODO: Might need this
	return ""
end
function Inflate(data)
	-- TODO: And this
	return ""
end
function GetTime()
	return 0
end
function GetScriptPath()
	return ""
end
function GetRuntimePath()
	return ""
end
function GetUserPath()
	return ""
end
function MakeDir(path) end
function RemoveDir(path) end
function SetWorkDir(path) end
function GetWorkDir()
	return ""
end
function LaunchSubScript(scriptText, funcList, subList, ...) end
function AbortSubScript(ssID) end
function IsSubScriptRunning(ssID) end
function LoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	local func, err = loadfile(fileName)
	if func then
		return func(...)
	else
		error("LoadModule() error loading '"..fileName.."': "..err)
	end
end
function PLoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	local func, err = loadfile(fileName)
	if func then
		return PCall(func, ...)
	else
		error("PLoadModule() error loading '"..fileName.."': "..err)
	end
end
function PCall(func, ...)
	local ret = { pcall(func, ...) }
	if ret[1] then
		table.remove(ret, 1)
		return nil, unpack(ret)
	else
		return ret[2]
	end
end
function ConPrintf(fmt, ...)
	-- Optional
	print(string.format(fmt, ...))
end
function ConPrintTable(tbl, noRecurse) end
function ConExecute(cmd) end
function ConClear() end
function SpawnProcess(cmdName, args) end
function OpenURL(url) end
function SetProfiling(isEnabled) end
function Restart() end
function Exit() end
function TakeScreenshot() end

---@return string? provider
---@return string? version
---@return number? status
function GetCloudProvider(fullPath)
	return nil, nil, nil
end

local l_require = require
function require(name)
	-- Hack to stop it looking for lcurl, which we don't really need
	if name == "lcurl.safe" then
		return
	end
	return l_require(name)
end


-- Load application modules from the supplied installation, without changing the
-- process-wide working directory shared with the UI thread.
function GetScriptPath() return root end
function GetRuntimePath() return root end
local loadModule = LoadModule
function LoadModule(fileName, ...)
	return loadModule(root .. '/' .. fileName, ...)
end
function PLoadModule(fileName, ...) return PCall(LoadModule, fileName, ...) end
function ConPrintf() end
launch = { devMode = false, versionNumber = 'worker', subScripts = { }, startTime = 0 }
function launch:ShowErrMsg(fmt, ...) error(string.format(fmt, ...)) end
main = LoadModule('Modules/Main')
-- Skip Settings.xml, shared items, saved-build selection and user directories.
function main:ChangeUserPath()
	self.userPath = ''
	self.buildPath = ''
	self.defaultBuildPath = ''
end
main:Init()
main:SetMode('BUILD', false, 'Augment comparison', xmlText)
main:OnFrame()
local build = main.modes.BUILD
local report = LoadModule('Modules/AugmentReport')
local json = require('dkjson')
local candidates = candidateJSON and json.decode(candidateJSON) or nil
if reportType == 'catalyst' then
	return json.encode(LoadModule('Modules/CatalystReport').Calculate(build, itemRaw, slotName, quality, candidates))
end
if reportType == 'support' then
	return json.encode(LoadModule('Modules/SupportReport').Calculate(build, assert(json.decode(quality)), candidates))
end
return json.encode(report.Calculate(build, itemRaw, slotName, candidates, considerExisting, socketIndex))
