-- Isolated builds only. Also runnable directly with Test-CustomPowerReport.ps1.
if not build then
	arg = {}
	dofile("HeadlessWrapper.lua")
end

local function close(actual, expected, label)
	assert(actual == expected or type(actual) == "number" and type(expected) == "number"
		and math.abs(actual - expected) <= math.max(1, math.abs(expected)) * 1e-9,
		label..": "..tostring(actual).." vs "..tostring(expected))
end
local function frame()
	build.buildFlag = true
	runCallback("OnFrame")
end
local function snapshot(output)
	local result = {}
	for key, value in pairs(output) do
		if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then result[key] = value end
	end
	if output.Minion then result.Minion = snapshot(output.Minion) end
	return result
end
local function same(actual, expected, label)
	for key, value in pairs(expected) do
		if type(value) == "table" then
			assert(type(actual[key]) == "table", label.." missing "..key)
			same(actual[key], value, label.."."..key)
		else close(actual[key], value, label.."."..key) end
	end
	for key in pairs(actual) do assert(expected[key] ~= nil, label.." extra "..key) end
end

-- The optional calculator remains callable and is recreated after a rebuild.
-- Compare every scalar output with an independently constructed eager instance.
for _, skill in ipairs({ "Spark", "Skeletal Sniper" }) do
	newBuild()
	build.skillsTab:PasteSocketGroup(skill.." 20/0 1")
	build.skillsTab:PasteSocketGroup("Fireball 20/0 1")
	for _, group in ipairs(build.skillsTab.socketGroupList) do group.includeInFullDPS = true end
	build.mainSocketGroup = 1
	local tab, calcs = build.calcsTab, build.calcsTab.calcs
	local original = calcs.getNodeCalculator
	local calls = 0
	calcs.getNodeCalculator = function(...)
		calls = calls + 1
		return original(...)
	end
	frame()
	assert(calls == 0 and tab.nodeCalculator == nil, "Rebuild constructed an unused node calculator")
	local mainBefore, calcsBefore = snapshot(tab.mainOutput), snapshot(tab.calcsOutput)
	local misc, miscBase = tab:GetMiscCalculator()
	local node = assert(build.spec.nodes[1755])
	local overrideBefore = snapshot(misc({ addNodes = { [node] = true } }, true, { noEnvReuse = true }))
	local eager, eagerBase = original(build)
	local lazy, lazyBase = tab:GetNodeCalculator()
	assert(calls == 1 and lazy == tab:GetNodeCalculator(), "First request must construct once and reuse")
	same(snapshot(lazyBase), snapshot(eagerBase), skill.." lazy baseline")
	same(snapshot(lazy({ node })), snapshot(eager({ node })), skill.." lazy node override")
	same(snapshot(tab.mainOutput), mainBefore, skill.." MAIN after lazy construction")
	same(snapshot(tab.calcsOutput), calcsBefore, skill.." CALCS after lazy construction")
	frame()
	assert(calls == 1 and tab.nodeCalculator == nil, "Rebuild did not invalidate the calculator")
	same(snapshot(tab.mainOutput), mainBefore, skill.." MAIN after rebuild")
	same(snapshot(tab.calcsOutput), calcsBefore, skill.." CALCS after rebuild")
	local miscAfter, baseAfter = tab:GetMiscCalculator()
	same(snapshot(baseAfter), snapshot(miscBase), skill.." misc baseline")
	same(snapshot(miscAfter({ addNodes = { [node] = true } }, true, { noEnvReuse = true })), overrideBefore, skill.." misc override")
	build.spec:AllocNode(node)
	frame()
	local fresh, freshBase = tab:GetNodeCalculator()
	local reference, referenceBase = original(build)
	assert(calls == 2 and fresh ~= lazy, "Allocation rebuild retained a stale calculator")
	same(snapshot(freshBase), snapshot(referenceBase), skill.." rebuilt baseline")
	calcs.getNodeCalculator = original
	print("PASS: "..skill.." lazy calculator, invalidation, MAIN/CALCS/misc and player/minion scalar parity")
end

-- Real identical-text passives inside/outside a parsed jewel's radius.
newBuild()
build.skillsTab:PasteSocketGroup("Spark 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
frame()
local spec, tab = build.spec, build.calcsTab
local socket, inside, outside = assert(spec.nodes[54127]), assert(spec.nodes[38270]), assert(spec.nodes[64352])
assert(socket.nodesInRadius[2][inside.id] and not socket.nodesInRadius[2][outside.id], "Radius fixture changed")
assert(inside.modKey == outside.modKey and inside.modKey ~= "", "Fixture requires identical raw modifiers")
spec:AllocNode(socket)
if inside.alloc then spec:DeallocSingleNode(inside) end
local jewel = new("Item", "Rarity: RARE\nAccuracy Test Jewel\nTime-Lost Sapphire\n--------\nRadius: Medium\nItem Level: 80\n--------\n25% increased Effect of Small Passive Skills in Radius")
assert(jewel.jewelRadiusIndex and jewel.jewelData and #jewel.jewelData.funcList > 0)
build.itemsTab:AddItem(jewel, true)
spec.jewels[socket.id] = jewel.id
if build.itemsTab.sockets[socket.id] then build.itemsTab.sockets[socket.id]:SetSelItemId(jewel.id) end
spec:BuildAllDependsAndPaths()
frame()
assert(not inside.alloc and not outside.alloc)
local calculator, base = tab:GetMiscCalculator()
local directInside = calculator({ addNodes = { [inside] = true } }, true, { noEnvReuse = true })
local directOutside = calculator({ addNodes = { [outside] = true } }, true, { noEnvReuse = true })
assert(math.abs(directInside.TotalDPS - directOutside.TotalDPS) > 1e-6, "Jewel must create different effects")
local report = setmetatable({
	build = { spec = { nodes = { [inside.id] = inside, [outside.id] = outside }, tree = { clusterNodeMap = {} } } },
	mainEnv = tab.mainEnv, miscCalculator = { calculator, base }, nodePowerMaxDepth = 1000,
}, { __index = tab })
for _, metric in ipairs({ "TotalDPS", "FullDPS", "TotalEHP", "TotalDPS" }) do
	report.powerStat = { stat = metric }
	report:PowerBuilder()
	close(inside.power.singleStat, tab:CalculatePowerStat(report.powerStat, directInside, base), metric.." inside radius")
	close(outside.power.singleStat, tab:CalculatePowerStat(report.powerStat, directOutside, base), metric.." outside radius")
end
print("PASS: identical-text radius passives match separate complete calculations across metric switches")

-- Cover the separate cluster-candidate loop and preserve distinct contexts even
-- when all candidates have identical text. The real radius case above checks the
-- calculation model; this bounded fixture checks both report dispatch branches.
local a = { id = 101, modKey = "same", power = {}, pathDist = 1 }
local b = { id = 102, modKey = "same", power = {}, pathDist = 1 }
local cluster = { id = 103, modKey = "same", power = {} }
a.path, b.path = { a }, { b }
local values, calls = { [a] = 10, [b] = 20, [cluster] = 30 }, 0
local dispatch = setmetatable({
	build = { spec = { nodes = { a, b }, tree = { clusterNodeMap = { cluster } } } },
	mainEnv = { grantedPassives = {} }, powerStat = { stat = "TotalDPS" },
	miscCalculator = { function(override)
		calls = calls + 1
		return { TotalDPS = 100 + values[next(override.addNodes)] }
	end, { TotalDPS = 100 } },
}, { __index = tab })
dispatch:PowerBuilder()
assert(calls == 3 and a.power.singleStat == 10 and b.power.singleStat == 20 and cluster.power.singleStat == 30,
	"Normal and cluster candidates shared an unsafe raw-modifier cache entry")
print("PASS: normal/cluster candidate identities remain separate")

-- Parsed attack/spell restrictions and unscoped modifiers scale only the bonus
-- portion of critical damage. Conditions are checked independently as well.
for _, skill in ipairs({ "Default Attack", "Spark" }) do
	newBuild()
	if skill ~= "Default Attack" then build.skillsTab:PasteSocketGroup(skill.." 20/0 1") end
	frame()
	local baseline = build.calcsTab.mainOutput.CritMultiplier
	for _, scenario in ipairs({
		{ text = "50% more Critical Damage Bonus", applies = true },
		{ text = "50% more Critical Damage Bonus with Attacks", applies = skill == "Default Attack" },
		{ text = "50% more Critical Damage Bonus with Spells", applies = skill == "Spark" },
	}) do
		build.configTab.input.customMods = scenario.text
		build.configTab:BuildModList()
		frame()
		local expected = 1 + (baseline - 1) * (scenario.applies and 1.5 or 1)
		close(build.calcsTab.mainOutput.CritMultiplier, expected, skill.." "..scenario.text)
	end
	build.configTab.input.customMods = "50% more Critical Damage Bonus while on Full Life"
	for _, enabled in ipairs({ false, true, false }) do
		build.configTab.input.conditionFullLife = enabled
		build.configTab:BuildModList()
		frame()
		close(build.calcsTab.mainOutput.CritMultiplier, 1 + (baseline - 1) * (enabled and 1.5 or 1), skill.." Full Life condition")
	end
end
print("PASS: critical damage respects attack/spell scopes, unscoped bonuses and condition toggles")

-- Both supports, the exact boundary, explicit zero/positive overrides, and
-- repeated rebuilds. Manual reload assumptions must retain their precedence.
for _, support in ipairs({ { name = "Fresh Clip I", seconds = 6 }, { name = "Fresh Clip II", seconds = 8 } }) do
	newBuild()
	build.itemsTab:CreateDisplayItemFromRaw("Rarity: RARE\nAccuracy Test Crossbow\nMakeshift Crossbow\n--------\nAdds 100 to 200 Physical Damage")
	build.itemsTab:AddDisplayItem()
	build.skillsTab:PasteSocketGroup("Galvanic Shards 20/0 1\n"..support.name.." 1/0 1")
	for index, group in ipairs(build.skillsTab.socketGroupList) do
		if group.gemList[1] and group.gemList[1].nameSpec == "Galvanic Shards" then
			build.mainSocketGroup, group.mainActiveSkill, group.includeInFullDPS = index, 1, true
		end
	end
	local atBoundary, normal
	for _, scenario in ipairs({ { chance = 0 }, { chance = 99 }, { chance = 100 }, { chance = 101 },
		{ chance = 100, override = 0 }, { chance = 100, override = 10 }, { chance = 0 } }) do
		build.configTab.input.customMods = scenario.chance.."% chance to not expend ammunition"
		build.configTab.input.multiplierBoltsReloadedPer6Seconds = scenario.override
		build.configTab.input.multiplierBoltsReloadedPer8Seconds = scenario.override
		build.configTab:BuildModList()
		frame()
		local output, active = build.calcsTab.mainOutput, build.calcsTab.mainEnv.player.mainSkill
		assert(active.activeEffect.grantedEffect.name == "Galvanic Shards")
		local reloaded = active.skillModList:Sum("BASE", active.skillCfg, "Multiplier:BoltsReloadedPast"..(support.seconds == 6 and "Six" or "Eight").."Seconds")
		close(output.ChanceToNotConsumeAmmo, scenario.chance, "Ammo conservation")
		if scenario.override ~= nil then
			close(reloaded, scenario.override, support.name.." manual reload count")
		elseif scenario.chance >= 100 then
			close(reloaded, 0, support.name.." no automatic reloads")
			close(active.skillModList:More(active.skillCfg, "Damage"), 1, support.name.." no false damage bonus")
		else
			assert(reloaded > 0 and output.Speed > 0 and output.Speed < output.FiringRate, "Normal ammunition cycle was lost")
		end
		if scenario.chance >= 100 then close(output.Speed, output.FiringRate, "No-consumption firing speed") end
		if scenario.chance == 100 and scenario.override == nil then atBoundary = snapshot(output) end
		if scenario.chance == 101 or scenario.override == 0 then
			close(output.TotalDPS, atBoundary.TotalDPS, support.name.." zero-reload DPS")
			close(output.FullDPS, atBoundary.FullDPS, support.name.." zero-reload Full DPS")
		elseif scenario.override == 10 then
			assert(output.TotalDPS > atBoundary.TotalDPS, "Manual reload bonus disappeared")
			close(output.Speed, atBoundary.Speed, "Manual reload count changed firing speed")
		elseif scenario.chance == 0 then
			if normal then same(snapshot(output), normal, support.name.." repeated ordinary cycle") else normal = snapshot(output) end
		end
		local misc, miscBase = build.calcsTab:GetMiscCalculator()
		local complete = misc({}, true, { noEnvReuse = true })
		local reportOnly = misc({}, true, { noEnvReuse = true, fullDPSOnly = true })
		close(complete.FullDPS, output.FullDPS, support.name.." complete comparison")
		close(reportOnly.FullDPS, output.FullDPS, support.name.." report comparison")
	end
	print("PASS: "..support.name.." 0/99/100/101% conservation, manual overrides, repeat rebuilds and Full DPS parity")
end
