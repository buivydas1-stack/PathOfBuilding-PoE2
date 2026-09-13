-- Loaded after custom_power_report.lua's headless startup. These are correctness
-- comparisons and branch checks, not timing benchmarks.
local function close(a, b, label)
	assert(a == b or type(a) == "number" and type(b) == "number"
		and math.abs(a - b) <= math.max(1, math.abs(a)) * 1e-9,
		label..": "..tostring(a).." vs "..tostring(b))
end
local function sameOutput(a, b, fields)
	for _, key in ipairs(fields) do
		close(a[key], b[key], key)
		if a.Minion then
			assert(b.Minion, "Minion output lost")
			close(a.Minion[key], b.Minion[key], "Minion "..key)
		end
	end
end
local damageFields = { "TotalDPS", "AverageDamage", "CombinedDPS", "TotalDot", "CritChance", "Speed", "Life", "Mana", "Armour", "Evasion", "EnergyShield" }
local defenceFields = { "TotalEHP", "PhysicalMaximumHitTaken", "LightningMaximumHitTaken" }
local options = { noEnvReuse = true, skipEHP = true }

for _, skill in ipairs({ "Spark", "Skeletal Sniper" }) do
	newBuild()
	local calcs = build.calcsTab.calcs
	build.skillsTab:PasteSocketGroup(skill.." 20/0 1")
	build.skillsTab:PasteSocketGroup("Fireball 20/0 1")
	runCallback("OnFrame")
	for _, group in ipairs(build.skillsTab.socketGroupList) do group.includeInFullDPS = true end
	build.mainSocketGroup = 1
	build.spec:AllocNode(assert(build.spec.nodes[1755]))
	build.buildFlag = true
	runCallback("OnFrame")
	build.viewMode = "TREE"
	local calcFunc, calcBase = build.calcsTab:GetMiscCalculator()
	local added
	for _, node in pairs(build.spec.nodes) do
		if not node.alloc and node.path and #node.path > 1 and #node.path < 4 and node.modKey ~= "" then added = node; break end
	end
	assert(added, "Need an unallocated path")
	local path = { }
	for _, node in pairs(added.path) do path[node] = true end
	local overrides = {
		{}, { addNodes = { [added] = true } }, { addNodes = path },
		{ removeNodes = { [build.spec.nodes[1755]] = true } },
	}
	for _, override in ipairs(overrides) do
		local expected = calcFunc(override, true)
		local actual = calcFunc(override, false, options)
		sameOutput(expected, actual, damageFields)
		assert(actual.TotalEHP == nil and actual.FullDPS == nil, "Damage report calculated unused totals")
		-- A normal tooltip after a reduced calculation must still have all its fields.
		local tooltip = calcFunc(override)
		sameOutput(expected, tooltip, defenceFields)
		close(expected.FullDPS, tooltip.FullDPS, "Full DPS tooltip")
	end
	-- Count calls to verify dispatch; no elapsed-time assertions or measurements.
	local oldEHP, oldFullDPS = calcs.buildDefenceEstimations, calcs.calcFullDPS
	local ehpCalls, fullDPSCalls = 0, 0
	calcs.buildDefenceEstimations = function(...)
		ehpCalls = ehpCalls + 1
		return oldEHP(...)
	end
	calcs.calcFullDPS = function(...)
		fullDPSCalls = fullDPSCalls + 1
		return oldFullDPS(...)
	end
	calcFunc({}, false, options)
	assert(ehpCalls == 0 and fullDPSCalls == 0, "Hit report did unnecessary calculations")
	local defence = calcFunc({}, false, { noEnvReuse = true })
	assert(ehpCalls > 0 and fullDPSCalls == 0 and defence.TotalEHP > 0, "Defence check: EHP calls="..ehpCalls..", Full DPS calls="..fullDPSCalls..", EHP="..tostring(defence.TotalEHP)..", same calculation module="..tostring(calcs == build.calcsTab.calcs))
	calcFunc({}, true, { noEnvReuse = true })
	assert(fullDPSCalls > 0, "Full DPS report lost its roll-up")
	calcs.buildDefenceEstimations, calcs.calcFullDPS = oldEHP, oldFullDPS

	-- Exercise the real builder on a small candidate set while calculations still
	-- use the complete build. Include allocation, removal, and a multi-node path.
	local candidates = { [added.id] = added, [1755] = build.spec.nodes[1755] }
	local function runReport(metric, baseline, scheduled)
		local progress = { }
		local report = setmetatable({
			build = { spec = { nodes = candidates, tree = { clusterNodeMap = {} } },
				powerBuilderProgressCallback = function(percent) progress[#progress + 1] = percent end },
			mainEnv = build.calcsTab.mainEnv, powerStat = metric,
			miscCalculator = { baseline and function(override) return calcFunc(override, true) end or calcFunc, calcBase },
		}, { __index = build.calcsTab })
		if scheduled then
			local oldTime, clock = GetTime, 0
			GetTime = function() clock = clock + 26; return clock end
			local co = coroutine.create(function() report:PowerBuilder() end)
			local yields = 0
			repeat
				local ok, err = coroutine.resume(co)
				assert(ok, err)
				if coroutine.status(co) ~= "dead" then yields = yields + 1 end
			until coroutine.status(co) == "dead"
			GetTime = oldTime
			assert(yields == 3 and #progress == 2 and progress[2] == 100, "Builder did not yield between nodes")
		else
			report:PowerBuilder()
		end
		local result = { }
		for id, node in pairs(candidates) do result[id] = copyTable(node.power) end
		return result
	end
	for _, metric in ipairs({ { stat = "TotalDPS" }, { stat = "TotalEHP" }, { stat = "FullDPS" }, { stat = "AverageDamage" }, { stat = "TotalDPS" } }) do
		local expected = runReport(metric, true)
		local actual = runReport(metric, false, true)
		for id, powers in pairs(expected) do
			for key, value in pairs(powers) do close(value, actual[id][key], metric.stat.." node "..id.." "..key) end
		end
	end
	-- Full DPS's existing fallback remains available when no groups are included.
	for _, group in ipairs(build.skillsTab.socketGroupList) do group.includeInFullDPS = false end
	build.buildFlag = true
	runCallback("OnFrame")
	calcFunc = build.calcsTab:GetMiscCalculator()
	local expected = calcFunc({}, true)
	local actual = calcFunc({}, true, { noEnvReuse = true })
	close(data.powerStatList.GetFromOutput(expected, { stat = "FullDPS" }), data.powerStatList.GetFromOutput(actual, { stat = "FullDPS" }), "Full DPS fallback")
	print("PASS: "..skill.." report parity, metric switches, tooltip completeness, and cooperative scheduling")
end
