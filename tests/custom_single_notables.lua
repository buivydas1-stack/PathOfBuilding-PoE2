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

-- EHP and combined mode agree with independent complete single-node calculations.
report.miscCalculator[1] = function(override, fullDPS, options)
	local count = 0
	for node in pairs(override.addNodes or {}) do
		count = count + 1
		assert(node.type == "Notable")
	end
	assert(count == 1 and not override.removeNodes)
	assert(not options.skipEHP, "EHP must be calculated for these modes")
	assert((not not fullDPS) == (not not report.powerStat.combinedReport))
	return calcFunc(override, fullDPS, options)
end
for _, metric in ipairs({ {stat="TotalEHP", label="Effective Hit Pool"}, {stat="FullDPSAndEHP", label="Full DPS / EHP", combinedReport=true} }) do
	report.powerStat = metric
	report:PowerBuilder()
	local rows = reportTree:BuildPowerReportList(metric)
	if metric.combinedReport then
		assert(report.powerMax.ehpStat == math.max(0, selected[1].power.ehpStat, selected[2].power.ehpStat))
	end
	for _, node in ipairs(selected) do
		local complete = calcFunc({ addNodes = { [node] = true } }, true, { noEnvReuse=true })
		local ehp = calcs:CalculatePowerStat({stat="TotalEHP"}, complete, calcBase)
		local dps = calcs:CalculatePowerStat({stat="FullDPS"}, complete, calcBase)
		assert(math.abs(node.power.singleStat - (metric.combinedReport and dps or ehp)) < 1e-7)
		if metric.combinedReport then assert(math.abs(node.power.ehpStat - ehp) < 1e-7) end
	end
	for _, row in ipairs(rows) do
		assert(row.pathDist == 1 and row.powerStr:find("%%"))
		if metric.combinedReport then assert(row.ehpPowerStr:find("%%")) end
	end
end
assert(tree.normalPowerStatList[1].stat == "FullDPS" and tree.normalPowerStatList[2].stat == "TotalEHP")
assert(tree.notablePowerStatList[3].combinedReport)
tree.controls.nodePowerMaxDepthSelect:SetSel(1)
tree:SetPowerCalc(tree.notablePowerStatList[3])
tree.viewer.showHeatMap = false
tree.controls.nodePowerMaxDepthSelect:SetSel(2)
assert(calcs.powerStat.stat == "FullDPS" and not tree.viewer.showHeatMap and calcs.powerBuildFlag)
assert(not tree.powerStatList[3].combinedReport, "Combined option leaked outside Notables")
tree:SetPowerCalc(nil, true)
assert(calcs.powerStat.stat == "FullDPS", "Default calculation must match the first visible metric")
assert(tree:FormatPowerPercent(10, 100):find("+10.00%", 1, true))
assert(tree:FormatPowerPercent(-20, 200):find("-10.00%", 1, true))
assert(tree:FormatPowerPercent(1, 0) == "N/A")
assert(tree:FormatPowerPercent(math.huge, 100) == "N/A")
assert(tree:FormatPowerPercent(0/0, 100) == "N/A")
local combined = tree.notablePowerStatList[3]
list.allocated, list.showClusters = false, false
list:SetReport(combined, {
	{id=901, type="Notable", power=10, ehpPower=-20, pathDist=1, powerStr="+10.00%", ehpPowerStr="-10.00%"},
	{id=902, type="Notable", power=0, ehpPower=50, pathDist=1, powerStr="+0.00%", ehpPowerStr="+25.00%"},
	{id=903, type="Notable", power=-5, ehpPower=0, pathDist=1, powerStr="-5.00%", ehpPowerStr="+0.00%"},
	{id=904, type="Notable", power=0, ehpPower=0, pathDist=1},
	{id=905, type="Notable", power=20, ehpPower=100, pathDist=1, isCluster=true},
}, true)
assert(#list.list == 3, "Defence-only and negative trade-offs must remain visible; zero effects and hidden clusters must not")
list:ReSort(3)
assert(list.list[1].id == 901 and list.powerColumn.label == "Full DPS %")
list:ReSort(5)
assert(list.list[1].id == 902 and list.colList[5].label == "EHP %")
assert(list:GetRowValue(5, 1, list.list[1]) == "+25.00%")
tree:IgnorePowerNode(list.list[1])
assert(#list.list == 2)
tree:RestorePowerNode(902)
assert(list.list[1].id == 902, "Restore must preserve EHP sort")
list:SetReport({stat="TotalEHP",label="Effective Hit Pool"}, {}, true)
assert(not list.combinedReport and list.powerColumn.label == "EHP %" and list.colList[5].label == "% / Point")
list:SetReport({stat="FullDPS",label="Full DPS"}, {}, false)
assert(list.powerColumn.label == "Full DPS" and list.colList[5].label == "Per Point")
print("PASS: EHP and combined parity, percentage signs and undefined bases, both column sorts, trade-offs, and hidden-mode switching")

local function color(dps, ehp, theme, maximum)
	return tree.viewer:GetCombinedPowerColor({singleStat=dps, ehpStat=ehp}, maximum or {singleStat=100, ehpStat=100}, theme or "RED/BLUE")
end
local r, g, b = color(100, 0)
assert(r == 1 and g == 0 and b == 0)
r, g, b = color(0, 100)
assert(r == 0 and g == 0 and b == 1)
r, g, b = color(100, 100)
assert(r == 1 and g == 0 and b == 1)
r, g, b = color(-100, 100)
assert(r == 0 and g == 0 and b == 1)
r, g, b = color(0, 0, nil, {singleStat=0, ehpStat=0})
assert(r == 0 and g == 0 and b == 0)
r, g, b = color(100, 100, "RED/GREEN")
assert(r == 1 and g == 1 and b == 0)
r, g, b = color(100, 100, "GREEN/BLUE")
assert(r == 0 and g == 1 and b == 1)
print("PASS: combined tree colours, mixed gains, negative trade-offs, zero maxima, and alternative themes")
