-- Check report totals against real whole-path calculations, retaining single-node mode.
newBuild()
local fixture = os.getenv("POB_REPORT_BUILD")
if fixture then
	local file = assert(io.open(fixture, "r"))
	local text = file:read("*a")
	file:close()
	loadBuildFromXML(text, "Path report regression")
else
	build.skillsTab:PasteSocketGroup("Spark 20/0 1")
	build.skillsTab.socketGroupList[1].includeInFullDPS = true
	build.spec:AllocNode(assert(build.spec.nodes[1755]))
end
build.buildFlag = true
runCallback("OnFrame")
local calcs, tree = build.calcsTab, build.treeTab
local removed, added
for _, node in pairs(build.spec.nodes) do
	if node.alloc and node.type == "Normal" and not node.ascendancyName and #node.depends > 1 then
		removed = removed or node
		if node.dn == "Attack Damage" and #node.depends == 3 then removed = node; break end
	end
end
for _, node in pairs(build.spec.nodes) do
	if not node.alloc and node.type == "Notable" and not node.ascendancyName and node.path and #node.path > 1 and #node.path <= 5 then
		added = node; break
	end
end
assert(removed and added, "Need an allocated branch and an unallocated path")
local calcFunc, base = calcs:GetMiscCalculator()
local candidates = {[removed.id]=removed, [added.id]=added}
local report = setmetatable({build={spec={nodes=candidates, tree={clusterNodeMap={}}}},
	mainEnv=calcs.mainEnv, nodePowerSingleNotables=false, nodePowerMaxDepth=5,
	miscCalculator={calcFunc, base}}, {__index=calcs})
local reportTree = setmetatable({build={spec=report.build.spec, calcsTab=report, displayStats=build.displayStats}}, {__index=tree})
local function close(a,b) return math.abs(a-b) <= math.max(1,math.abs(a))*1e-9 end
for _, metric in ipairs({{stat="FullDPS",label="Full DPS"}, {stat="TotalEHP",label="Effective Hit Pool"}}) do
	report.powerStat = metric
	report:PowerBuilder()
	local rows = reportTree:BuildPowerReportList(metric)
	assert(#rows == 2)
	for _, row in ipairs(rows) do
		local node = candidates[row.id]
		local nodes = node.alloc and node.depends or node.path
		local override = {}
		for _, part in ipairs(nodes) do override[part] = true end
		local output = calcFunc(node.alloc and {removeNodes=override} or {addNodes=override}, true, {noEnvReuse=true})
		local expected = calcs:CalculatePowerStat(metric,output,base)
		assert(row.pathDist == #nodes and close(row.pathPower,expected/#nodes), "Point count or per-point total differs")
		print(string.format("PATH: %s %s (%d): single=%.4f total=%.4f report=%.4f perPoint=%.4f", node.alloc and "remove" or "add", node.dn, #nodes, node.power.singleStat, expected, row.power, row.pathPower))
		assert(close(row.power,expected), "Main report column must show the whole path/branch change")
		assert(close(row.power,row.pathPower*row.pathDist), "Total and per-point columns disagree")
		local displayValue = tonumber((StripEscapes(row.powerStr):gsub(",", "")))
		assert(displayValue and math.abs(displayValue-expected) <= 0.5, "Displayed total differs")
	end
	local list = tree.controls.powerReportList
	list:SetReport(metric,rows,false)
	list.controls.filterSelect:SetSel(3)
	assert(#list.list == 1 and list.list[1].id == removed.id)
	list:ReSort(3)
	list.controls.filterSelect:SetSel(1)
	assert(not list.list[1] or not list.list[1].allocated)
end
print("PASS: range-mode Full DPS/EHP totals, branch removals, path additions, points, formatting and filters")
