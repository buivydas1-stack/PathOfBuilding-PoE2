-- Exercise the renderer inputs and report failure/retry lifecycle, not just a formula.
newBuild()
runCallback("OnFrame")
local tab, tree = build.calcsTab, build.treeTab
local oldBuildPower, oldColor = tab.BuildPower, SetDrawColor
tab.BuildPower = function() end
tab.powerMax = { singleStat = 0, offence = 0, defence = 0, ehpStat = 0 }
tree.viewer.showHeatMap = true
local colorCalls = 0
SetDrawColor = function(...)
	colorCalls = colorCalls + 1
	for _, value in ipairs({ ... }) do
		assert(type(value) ~= "number" or value == value and math.abs(value) ~= math.huge, "Nonfinite renderer color")
	end
end
for _, metric in ipairs({ { stat = "FullDPS" }, { stat = "FullDPSAndEHP", combinedReport = true }, {} }) do
	tab.powerStat = metric
	tree.viewer:Draw(build, { x = 1, y = 1, width = 1920, height = 1080 }, {})
end
SetDrawColor, tab.BuildPower = oldColor, oldBuildPower
assert(colorCalls > 0, "Tree rendering was not exercised")
print("PASS: incomplete and zero-gain heatmaps pass only finite colors to the renderer")

local oldBuilder, oldMessage, oldDevMode = tab.PowerBuilder, main.ShowMessage, launch.devMode
launch.devMode = false
local message
main.ShowMessage = function(_, title, text) message = text end
tree.controls.powerReportList:SetReport({ stat = "Life" }, { { id = 1, name = "Stale result", power = 1, pathPower = 1, pathDist = 1 } })
tab.PowerBuilder = function(self)
	self.powerMax = { singleStat = 0 }
	coroutine.yield()
	error("isolated calculation failure")
end
tab.powerStat, tab.powerBuildFlag = { stat = "Life" }, true
tab:BuildPower()
assert(tab.powerBuilder)
tab:BuildPower()
assert(not tab.powerBuilder and not tab.powerBuilderInitialized)
assert(message:find("isolated calculation failure", 1, true))
assert(tree.controls.powerReportList.label == "Power Report failed" and #tree.controls.powerReportList.originalList == 0)
tab.PowerBuilder = function(self) self.powerBuilderInitialized = true end
tab.powerBuildFlag = true
tab:BuildPower()
assert(tab.powerBuilderInitialized and not tab.powerBuilder and tree.controls.powerReportList.label ~= "Power Report failed")
tab.PowerBuilder, main.ShowMessage, launch.devMode = oldBuilder, oldMessage, oldDevMode
print("PASS: a failed report clears partial results, reports the error and can be retried")

-- Two allocated nodes on the same branch can have the same dependent set.
-- Different dependent sets must remain separate even when modifiers match.
local a = { id = 101, alloc = true, modKey = "a", power = {}, pathDist = 0 }
local b = { id = 102, alloc = true, modKey = "b", power = {}, pathDist = 0 }
local c = { id = 103, alloc = true, modKey = "c", power = {}, pathDist = 0 }
a.depends, b.depends, c.depends = { a, b }, { b, a }, { a, b, c }
local passes = 0
local report = setmetatable({
	build = { spec = { nodes = { a, b, c }, tree = { clusterNodeMap = {} } } },
	mainEnv = { grantedPassives = {} }, powerStat = { stat = "FullDPS" },
	miscCalculator = { function(override)
		passes = passes + 1
		local size = 0; for _ in pairs(override.removeNodes) do size = size + 1 end
		return { FullDPS = 100 - size }
	end, { FullDPS = 100 } },
}, { __index = tab })
report:PowerBuilder()
assert(passes == 5 and a.power.pathPower == -2 and b.power.pathPower == -2 and c.power.pathPower == -3)
print("PASS: identical removals share a calculation while distinct paths retain their own result")
