-- Actual socket comparisons, shared by the background worker and functional checks.
local report = { }
local calcs = LoadModule("Modules/Calcs")

function report.IsFinite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function report.GetStats()
	local stats = { }
	-- Use the tree's numeric metrics and its saved ordering; node-only composite
	-- metrics and item names cannot describe an augment's numeric change.
	for _, preferred in ipairs({ "FullDPS", "TotalEHP" }) do
		for _, stat in ipairs(data.powerStatList) do
			if stat.stat == preferred then table.insert(stats, stat) end
		end
	end
	for _, stat in ipairs(data.powerStatList) do
		if stat.stat and stat.stat ~= "FullDPS" and stat.stat ~= "TotalEHP" and not stat.ignoreForNodes then
			table.insert(stats, stat)
		end
	end
	return LoadModule("Modules/PowerStatOrder").Apply(stats)
end

function report.EmptyItem(raw)
	local item = new("Item", raw)
	assert(item.base and item.itemSocketCount > 0, "This item has no augment sockets.")
	for i = 1, item.itemSocketCount do item.runes[i] = "None" end
	item:UpdateRunes()
	item:BuildAndParseRaw()
	item:BuildModList()
	return item
end

function report.Snapshot(output)
	local values = { }
	for _, stat in ipairs(data.powerStatList) do
		if stat.stat then
			local value = data.powerStatList.GetFromOutput(output, stat, true)
			if report.IsFinite(value) then values[stat.stat] = value end
		end
	end
	return values
end

-- Preserve the scalar output used by the shared tree/item comparison formatter,
-- including condition flags and before/after chances. Never send environments,
-- modifier databases, skill lists or other calculation graphs to the UI thread.
function report.ComparisonSnapshot(output)
	local values, unavailable = { }, { }
	for key, value in pairs(output) do
		if type(value) == "number" then
			if report.IsFinite(value) then values[key] = value else unavailable[key] = true end
		elseif type(value) == "boolean" or type(value) == "string" then
			values[key] = value
		end
	end
	if next(unavailable) then values.unavailableStats = unavailable end
	if output.Minion then values.Minion = report.ComparisonSnapshot(output.Minion) end
	return values
end

-- Most outputs are identical for every augment. Send one baseline and only the
-- changed/deleted fields per candidate, avoiding a large decode on the UI thread.
function report.ComparisonChanges(baseline, values)
	local changes, removed = { }, { }
	for key, value in pairs(values) do
		if key == "Minion" then
			changes.Minion = report.ComparisonChanges(baseline.Minion or { }, value)
		elseif value ~= baseline[key] then
			changes[key] = value
		end
	end
	for key in pairs(baseline) do if values[key] == nil then removed[key] = true end end
	if next(removed) then changes.removedStats = removed end
	return changes
end

function report.ComparisonOutput(baseline, changes)
	local output = { }
	for key, value in pairs(baseline) do output[key] = value end
	for key in pairs(changes.removedStats or { }) do output[key] = nil end
	for key, value in pairs(changes) do
		if key == "Minion" then
			output.Minion = report.ComparisonOutput(baseline.Minion or { }, value)
		elseif key ~= "removedStats" then
			output[key] = value
		end
	end
	return output
end

function report.Compare(baseline, values, stat)
	local base, value = baseline[stat.stat], values[stat.stat]
	if not report.IsFinite(base) or not report.IsFinite(value) then return end
	local delta = value - base
	local benefit = stat.transform and (stat.transform(value) - stat.transform(base)) or delta
	local percent = base ~= 0 and delta / math.abs(base) * 100 or nil
	if not report.IsFinite(delta) or not report.IsFinite(benefit) then return end
	return delta, benefit, report.IsFinite(percent) and percent or nil, value
end

-- Read parsed condition tags using the same evaluator as tree/item comparisons.
-- Inspect only this augment, so retained sockets cannot make it look applicable.
-- Unknown effects stay visible; an inactive Bonded bonus never hides a useful
-- ordinary bonus. No hypothetical conditions or extra calculation passes are used.
function report.InactiveEffects(item, env, localBondedIdols)
	local inactive, hasActive = { }, false
	local function conditionsMatch(mod, db)
		if not db then return true end -- Cannot establish inactivity for this actor.
		local test = { name = "AugmentCondition", type = "FLAG", value = true, flags = 0, keywordFlags = 0, source = "" }
		for _, tag in ipairs(mod) do
			if (tag.type == "Condition" or tag.type == "ActorCondition") and
				not (localBondedIdols and tag.type == "Condition" and tag.var == "CanUseBondedModifiers") then table.insert(test, tag) end
		end
		if db:EvalMod(test) then return true end
		-- Some conditions belong to a particular skill rather than the global DB.
		for _, skill in ipairs(env.player.activeSkillList) do
			if db:EvalMod(test, skill.skillCfg) then return true end
		end
		return false
	end
	local function active(mod, db)
		if not conditionsMatch(mod, db) then return false end
		if type(mod.value) == "table" and mod.value.mod then
			local target = mod.name == "EnemyModifier" and env.enemy.modDB or
				mod.name == "MinionModifier" and env.minion and env.minion.modDB or db
			return active(mod.value.mod, target)
		end
		return true
	end
	for _, line in ipairs(item.runeModLines) do
		local bonded = line.line:match("^Bonded:")
		if not bonded or localBondedIdols or env.player.modDB:GetCondition("CanUseBondedModifiers") then
			if line.extra or #line.modList == 0 then
				hasActive = true
			else
				local lineActive = false
				for _, mod in ipairs(line.modList) do lineActive = active(mod, env.player.modDB) or lineActive end
				if lineActive then hasActive = true else table.insert(inactive, line.line) end
			end
		end
	end
	return not hasActive and #inactive > 0, inactive
end

function report.Calculate(build, raw, slotName, candidateNames, considerExisting, socketIndex)
	local item = considerExisting and new("Item", raw) or report.EmptyItem(raw)
	socketIndex = considerExisting and (socketIndex or 1) or 1
	assert(item.base and socketIndex >= 1 and socketIndex <= item.itemSocketCount, "Choose an existing augment socket.")
	item:BuildModList()
	assert(not item.aldurUnavailable, item.aldurUnavailable)
	assert(not considerExisting or not build.itemsTab:IsSocketBoundRune(item, item.runes[socketIndex]), "The augment in this socket is socket-bound and cannot be replaced.")
	local override = { repSlotName = slotName, repItem = item }
	-- Check limits with the replaced socket cleared, so its current augment does
	-- not consume the limit when comparing replacements (including itself).
	local limitItem = new("Item", item:BuildRaw())
	limitItem.runes[socketIndex] = "None"
	limitItem:UpdateRunes()
	limitItem:BuildAndParseRaw()
	limitItem:BuildModList()
	local env = calcs.initEnv(build, "CALCULATOR", { repSlotName = slotName, repItem = limitItem })
	local equipped = false
	local used = { }
	for _, equippedItem in pairs(env.player.itemList) do
		if equippedItem == limitItem then equipped = true end
		for i = 1, equippedItem.itemSocketCount or 0 do
			local name = equippedItem.runes[i]
			local _, augment = next(data.itemMods.Runes[name] or { })
			if augment and augment.limit then
				local key = augment.limitId or name
				used[key] = (used[key] or 0) + 1
			end
		end
	end
	assert(equipped, "Select an item in an active, usable equipment slot.")
	assert(not env.itemWarnings.augmentLimitWarning, "Other retained augments already exceed an equipped limit. Fix those sockets before comparing replacements.")
	local calculator = build.calcsTab:GetMiscCalculator()
	local baselineOutput = calculator(override, true, { noEnvReuse = true })
	local result = { baseline = report.Snapshot(baselineOutput), baselineComparison = report.ComparisonSnapshot(baselineOutput), rows = { }, slot = slotName, excluded = 0, considerExisting = considerExisting or false, socketIndex = socketIndex }
	local emptyRaw = item:BuildRaw()
	local effectItem = report.EmptyItem(emptyRaw)
	for _, augment in ipairs(build.itemsTab:GetValidRunesForItem(item)) do
		if augment.name ~= "None" and (not candidateNames or candidateNames[augment.name]) then
			if augment.limit and (used[augment.limitId or augment.name] or 0) >= augment.limit then
				result.excluded = result.excluded + 1
			else
				local candidate = new("Item", emptyRaw)
				candidate.runes[socketIndex] = augment.name
				candidate:UpdateRunes()
				candidate:BuildAndParseRaw()
				candidate:BuildModList()
				local output, candidateEnv = calculator({ repSlotName = slotName, repItem = candidate }, true, { noEnvReuse = true, includeEnv = true })
				effectItem.runes[1] = augment.name
				effectItem:UpdateRunes()
				local inactive, inactiveEffects = report.InactiveEffects(effectItem, candidateEnv, augment.type == "Idol" and candidate.baseModList:Flag(nil, "LocalBondedIdols"))
				table.insert(result.rows, { name = augment.name, type = augment.type, lines = augment.lines, estimated = candidate.aldurEstimate or item.aldurEstimate, unavailable = candidate.aldurUnavailable, values = candidate.aldurUnavailable and { } or report.Snapshot(output), comparison = report.ComparisonChanges(result.baselineComparison, report.ComparisonSnapshot(output)), inactive = not candidate.aldurUnavailable and inactive, inactiveEffects = inactiveEffects })
			end
		end
	end
	return result
end

return report
