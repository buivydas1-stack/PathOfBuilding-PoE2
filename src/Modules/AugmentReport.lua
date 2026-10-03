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
	local order = { }
	for index, key in ipairs(main.powerStatOrder or { }) do order[key] = index end
	local fallback = { }
	for index, stat in ipairs(stats) do fallback[stat.stat] = index end
	table.sort(stats, function(a, b)
		return (order[a.stat] or (1000 + fallback[a.stat])) < (order[b.stat] or (1000 + fallback[b.stat]))
	end)
	return stats
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

function report.Compare(baseline, values, stat)
	local base, value = baseline[stat.stat], values[stat.stat]
	if not report.IsFinite(base) or not report.IsFinite(value) then return end
	local delta = value - base
	local benefit = stat.transform and (stat.transform(value) - stat.transform(base)) or delta
	local percent = base ~= 0 and delta / math.abs(base) * 100 or nil
	if not report.IsFinite(delta) or not report.IsFinite(benefit) then return end
	return delta, benefit, report.IsFinite(percent) and percent or nil, value
end

function report.Calculate(build, raw, slotName, candidateNames, considerExisting, socketIndex)
	local item = considerExisting and new("Item", raw) or report.EmptyItem(raw)
	socketIndex = considerExisting and (socketIndex or 1) or 1
	assert(item.base and socketIndex >= 1 and socketIndex <= item.itemSocketCount, "Choose an existing augment socket.")
	item:BuildModList()
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
	local result = { baseline = report.Snapshot(calculator(override, true, { noEnvReuse = true })), rows = { }, slot = slotName, excluded = 0, considerExisting = considerExisting or false, socketIndex = socketIndex }
	local emptyRaw = item:BuildRaw()
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
				local output = calculator({ repSlotName = slotName, repItem = candidate }, true, { noEnvReuse = true })
				table.insert(result.rows, { name = augment.name, type = augment.type, lines = augment.lines, values = report.Snapshot(output) })
			end
		end
	end
	return result
end

return report
