-- Support comparisons run against the worker's in-memory build using PoB's
-- existing calculation engine. Saved builds and settings are never accessed.
local shared = LoadModule("Modules/AugmentReport")
local calcs = LoadModule("Modules/Calcs")
local report = { }

function report.GetStats()
	local stats = shared.GetStats()
	table.insert(stats, 2, { stat = "ManaCost", label = "Mana Cost", transform = function(v) return -v end })
	table.insert(stats, 3, { stat = "ManaPerSecondCost", label = "Mana Cost per second", transform = function(v) return -v end })
	return stats
end

function report.Snapshot(output)
	local values = shared.Snapshot(output)
	for _, key in ipairs({ "ManaCost", "ManaPerSecondCost" }) do
		if shared.IsFinite(output[key]) then values[key] = output[key] end
	end
	return values
end

function report.GetTargets(group)
	local targets = { }
	for skillIndex, skill in ipairs(group and group.displaySkillList or { }) do
		local effect = skill.activeEffect
		local gemIndex
		for index, gem in ipairs(group.gemList) do
			if gem == effect.srcInstance then gemIndex = index; break end
		end
		if gemIndex then
			for statSetIndex, statSet in ipairs(effect.grantedEffect.statSets) do
				local name = effect.grantedEffect.name
				local label = statSet.label and statSet.label ~= "" and statSet.label or name
				if label ~= name then label = name .. ": " .. label end
				table.insert(targets, { label = label, skillIndex = skillIndex, gemIndex = gemIndex,
					effectId = effect.grantedEffect.id, statSetIndex = statSetIndex,
					key = gemIndex .. ":" .. effect.grantedEffect.id .. ":" .. statSetIndex })
			end
		end
	end
	return targets
end

local function isSupport(gem)
	return gem.gemData and gem.gemData.grantedEffect.support
end

function report.Conflicts(a, b)
	if a.id == b.id or a.plusVersionOf == b.id or b.plusVersionOf == a.id then return true end
	for _, family in ipairs(a.gemFamily or { }) do
		for _, other in ipairs(b.gemFamily or { }) do if family == other then return true end end
	end
	return false
end

local function candidateGem(tab, gemData)
	local level = tab:ProcessGemLevel(gemData)
	return { gemId = gemData.id, nameSpec = gemData.name, skillId = gemData.grantedEffectId,
		level = level, quality = tab.defaultGemQuality or 0, count = 1, enabled = true,
		enableGlobal1 = true, enableGlobal2 = true, gemData = gemData,
		corrupted = tab.defaultCorruptionState, corruptLevel = tab.defaultCorruptionLevel }
end

local function describe(build, gem, env)
	local lines, unsupported = { }, false
	if gem.gemData.grantedEffect.description then table.insert(lines, gem.gemData.grantedEffect.description) end
	for _, statSet in ipairs(gem.gemData.grantedEffect.statSets) do
		local stats = calcLib.buildSkillInstanceStats(gem, gem.gemData.grantedEffect, statSet, env.modDB:Flag(nil, "GemlingQuality"))
		local descriptions, lineMap = build.data.describeStats(stats, statSet.statDescriptionScope)
		for _, line in ipairs(descriptions) do
			table.insert(lines, line)
			local stat = lineMap[line]
			if stat and not (statSet.statMap[stat] or build.data.skillStatMap[stat]) then unsupported = true end
		end
	end
	return lines, unsupported
end

function report.Calculate(build, options, candidateNames)
	local tab = build.skillsTab
	local group = assert(tab.socketGroupList[options.groupIndex], "Select a socket group.")
	assert(group.enabled and group.slotEnabled ~= false, "Enable this socket group before comparing supports.")
	assert(not group.source and not group.noSupports, "This group cannot be edited to add supports.")
	local target = assert(options.target, "Select an active skill.")
	local original = group.gemList
	assert(original[target.gemIndex] and original[target.gemIndex].enabled, "Select an enabled active skill.")
	local slotIndex = options.considerExisting and options.slotIndex or #original + 1
	assert(slotIndex and slotIndex >= 1 and slotIndex <= #original + 1, "Choose a support or empty slot.")
	assert(not options.considerExisting or not original[slotIndex] or isSupport(original[slotIndex]), "An active skill cannot be replaced by a support.")
	local originalMain, originalActive = build.mainSocketGroup, group.mainActiveSkill
	local oldCorruptLevel, oldCorruptState = tab.defaultCorruptionLevel, tab.defaultCorruptionState
	local displays = { }
	for _, other in ipairs(tab.socketGroupList) do displays[other] = other.displayGemList end
	-- Display effects point back to their source gem and contain calculation
	-- graphs. Clone instances shallowly; stat-set maps are copied on selection.
	group.gemList = { }
	for index, gem in ipairs(original) do group.gemList[index] = copyTable(gem, true) end
	local working = group.gemList
	local activeGem = working[target.gemIndex]
	local originalSets = copyTable(activeGem.statSet or { })
	local function setTarget(selected)
		build.mainSocketGroup = selected and options.groupIndex or originalMain
		group.mainActiveSkill = selected and target.skillIndex or originalActive
		activeGem.statSet = copyTable(originalSets)
		if selected then activeGem.statSet[target.effectId] = target.statSetIndex end
	end
	local function calculate()
		setTarget(true)
		local env = calcs.initEnv(build, "CALCULATOR")
		calcs.perform(env)
		-- Component selection affects local stats, while Full DPS retains the
		-- original included skills/components, Count and uptime settings.
		setTarget(false)
		local full = calcs.calcFullDPS(build, "CALCULATOR", { })
		if #full.skills > 0 then env.player.output.FullDPS = full.combinedDPS end
		setTarget(true)
		return env.player.output, env
	end
	local ok, result = pcall(function()
		if not options.considerExisting then
			for _, gem in ipairs(working) do if isSupport(gem) then gem.enabled = false end end
		end
		local baseline, env = calculate()
		local skill = assert(env.player.mainSkill, "This group has no active skill.")
		assert(skill.activeEffect.grantedEffect.id == target.effectId, "The selected skill changed. Calculate again.")
		local result = { baseline = report.Snapshot(baseline), baselineComparison = shared.ComparisonSnapshot(baseline),
			rows = { }, excluded = 0, group = group.displayLabel, target = target.label,
			considerExisting = options.considerExisting, slotIndex = slotIndex }
		local retained, count = { }, 0
		for index, gem in ipairs(working) do
			if index ~= slotIndex and gem.enabled and isSupport(gem) then
				table.insert(retained, gem.gemData.grantedEffect); count = count + 1
			end
		end
		assert(count < 5, "All five support slots are occupied. Choose a support to replace.")
		for _, gemData in pairs(build.data.gems) do
			local effect = gemData.grantedEffect
			local wanted = not candidateNames or candidateNames[gemData.name] or candidateNames[gemData.id]
			local typeMatches = tab.showSupportGemTypes == "ALL" or
				(tab.showSupportGemTypes == "LINEAGE" and effect.isLineage) or
				(tab.showSupportGemTypes == "NORMAL" and not effect.isLineage)
			local levelMatches = tab.defaultGemLevel ~= "characterLevel" or
				((effect.levels[1] or { }).levelRequirement or 1) <= build.characterLevel
			if wanted and effect.support and not effect.hidden and typeMatches and levelMatches and
				(tab.showLegacyGems or not effect.legacy) and calcLib.canGrantedEffectSupportActiveSkill(effect, skill) then
				local conflict = false
				for _, other in ipairs(retained) do if report.Conflicts(effect, other) then conflict = true; break end end
				if conflict then result.excluded = result.excluded + 1 else
					local gem = candidateGem(tab, gemData)
					working[slotIndex] = gem
					local output, candidateEnv = calculate()
					local lines, unsupported = describe(build, gem, candidateEnv)
					local instance = copyTable(gem, true); instance.gemData = nil
					table.insert(result.rows, { name = gemData.name, gem = instance, lines = lines, unsupported = unsupported,
						values = report.Snapshot(output), comparison = shared.ComparisonChanges(result.baselineComparison, shared.ComparisonSnapshot(output)) })
				end
			end
		end
		return result
	end)
	group.gemList, build.mainSocketGroup, group.mainActiveSkill = original, originalMain, originalActive
	tab.defaultCorruptionLevel, tab.defaultCorruptionState = oldCorruptLevel, oldCorruptState
	for _, other in ipairs(tab.socketGroupList) do other.displayGemList = displays[other] end
	if not ok then error(result) end
	return result
end

return report
