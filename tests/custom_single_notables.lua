-- Real calculations on a bounded candidate set; no timing benchmark.
newBuild()
build.skillsTab:PasteSocketGroup("Spark 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
runCallback("OnFrame")
local tree, calcs = build.treeTab, build.calcsTab
local selected, candidates, normal = {}, {}, nil
for id, node in pairs(build.spec.nodes) do
	if node.type == "Notable" and not node.ascendancyName and not node.alloc and node.modKey ~= "" and #selected < 2 then
		selected[#selected + 1] = node
		candidates[id] = node
	elseif node.type == "Normal" and node.modKey ~= "" and not normal then
		normal = node
		candidates[id] = node
	end
end
assert(#selected == 2 and normal)
local calcFunc, calcBase = calcs:GetMiscCalculator()
local calls = 0
local report = setmetatable({
	build = { spec = { nodes = candidates, tree = { clusterNodeMap = {} } } },
	mainEnv = calcs.mainEnv, powerStat = { stat = "FullDPS", label = "Full DPS" },
	nodePowerSingleNotables = true,
	miscCalculator = { function(override, fullDPS, options)
		local count = 0
		for node in pairs(override.addNodes or {}) do
			count = count + 1
			assert(node.type == "Notable" and not node.alloc and not node.ascendancyName)
		end
		assert(count == 1 and not override.removeNodes, "Single-notable mode included travel/removal nodes")
		assert(fullDPS, "Full DPS calculation was disabled")
		calls = calls + 1
		return calcFunc(override, fullDPS, options)
	end, calcBase },
}, { __index = calcs })
report:PowerBuilder()
assert(calls > 0 and normal.power.singleStat == nil)
for _, node in ipairs(selected) do
	local expected = calcs:CalculatePowerStat(report.powerStat, calcFunc({ addNodes = { [node] = true } }, true, { noEnvReuse = true }), calcBase)
	assert(math.abs(node.power.singleStat - expected) < 1e-7)
	assert(node.power.distance == 1 and node.power.pathPower == node.power.singleStat)
end
local reportTree = setmetatable({ build = {
	spec = report.build.spec, calcsTab = report, displayStats = build.displayStats,
} }, { __index = tree })
local rows = reportTree:BuildPowerReportList(report.powerStat)
assert(#rows == 2)
for _, row in ipairs(rows) do
	assert(row.type == "Notable" and row.pathDist == 1 and row.pathPower == row.power)
end
local select = tree.controls.nodePowerMaxDepthSelect
assert(select.list[1] == "Notables" and select.list[2] == "All")
select:SetSel(1)
assert(calcs.nodePowerSingleNotables and calcs.nodePowerMaxDepth == nil)
select:SetSel(2)
assert(not calcs.nodePowerSingleNotables and calcs.powerBuildFlag)
-- Both metric columns remain sortable, with one point per candidate.
local list = tree.controls.powerReportList
rows[1].power, rows[1].pathPower = 10, 10
rows[2].power, rows[2].pathPower = 20, 20
list:SetReport(report.powerStat, rows)
list:ReSort(3)
assert(list.list[1].power == 20 and list.powerColumn.sortable)
list:ReSort(5)
assert(list.list[1].pathPower == 20)
assert(list:GetRowValue(4, 1, list.list[1]) == 1)
print("PASS: single notable calculations, no travel nodes, one-point report, sorting, and mode switching")
