-- Compare catalyst types on a copy of the edited item. Item scores use printed,
-- rounded modifier values; build results reuse the augment report calculator.
local shared = LoadModule("Modules/AugmentReport")
local report = { }

-- These uniques are inherently corrupted, including imported copies that omit
-- that property. Do not infer a blanket restriction from Unique rarity or base.
local corruptedJewels = {
	["Megalomaniac"] = true, ["Voices"] = true, ["Split Personality"] = true,
	["From Nothing"] = true, ["Prism of Belief"] = true,
	["Flesh Crucible"] = true, ["The Adorned"] = true,
}

function report.UnavailableReason(item)
	if not item or item.type ~= "Jewel" then return end
	if (item.rarity == "UNIQUE" or item.rarity == "RELIC") and corruptedJewels[item.title] then
		return "This unique jewel is always corrupted; catalysts cannot be applied."
	end
	if item.corrupted then return "Catalysts cannot be applied to a corrupted jewel." end
	if item.mirrored then return "Catalysts cannot be applied to a mirrored jewel." end
	if item.base.subType == "Timeless" then
		-- Undying Hate can have additional Desecrated modifiers. Keep those
		-- comparisons available rather than disabling every Timeless Jewel.
		for _, field in ipairs({ "implicitModLines", "explicitModLines", "enchantModLines", "runeModLines" }) do
			for _, line in ipairs(item[field]) do
				if item:CheckModLineVariant(line) then
					local text = line.line
					if not text:match("^Remembrancing ") and not text:match("^Glorifying the defilement of ")
						and not text:match("^Passives in radius are Conquered by ") and text ~= "Historic"
						and text ~= "Desecration makes this item unstable" then return end
				end
			end
		end
		return "Timeless jewel seeds and conquered passives cannot be scaled by catalysts."
	end
end

local function printed(line, scalar)
	return itemLib.applyRange(line.line, line.range or main.defaultItemAffixQuality,
		scalar or line.valueScalar or 1, line.corruptedRange)
end

local function numbers(line)
	local values = { }
	for value in line:gmatch("%-?%d+%.?%d*") do table.insert(values, tonumber(value)) end
	return values
end

local lowerIsBetter = {
	ManaCost = true, LifeCost = true, EnergyShieldCost = true, Cost = true,
	ManaReserved = true, LifeReserved = true, Reservation = true,
	DamageTaken = true, PhysicalDamageTaken = true, FireDamageTaken = true,
	ColdDamageTaken = true, LightningDamageTaken = true, ChaosDamageTaken = true,
}

-- Group a damage range or an all-resistance line into one modifier score.
-- The scalability table distinguishes amounts from fixed condition thresholds.
local function scoreLine(before, after)
	local beforeText, afterText = printed(before), printed(after)
	if beforeText == afterText then return end
	local old, new = numbers(beforeText), numbers(afterText)
	local probe = numbers(printed(before, 2 * (before.valueScalar or 1)))
	if #old ~= #new or #old ~= #probe then return end
	local changed = false
	for index, value in ipairs(old) do if new[index] ~= value then changed = true end end
	if not changed then return end
	local base, change = 0, 0
	for index, value in ipairs(old) do
		if probe[index] ~= value then
			base = base + math.abs(value)
			change = change + new[index] - value
		end
	end
	local percent = base > 0 and change / base * 100 or nil
	-- Keep explicit penalties negative. Parsed values also encode "reduced" and
	-- "less"; reducing a cost or incoming damage is a positive modifier change.
	local semantic, displayed = 0, 0
	for _, mod in ipairs(before.modList or { }) do
		if type(mod.value) == "number" then
			semantic = semantic + (lowerIsBetter[mod.name] and -mod.value or mod.value)
		end
	end
	for _, value in ipairs(old) do displayed = displayed + value end
	if percent and semantic * displayed < 0 then percent = -percent end
	return { before = beforeText, after = afterText, percent = percent, unsupported = before.extra or after.extra or nil }
end

function report.ModifierChanges(before, after)
	local changes, score, unscored = { }, 0, 0
	for _, field in ipairs({ "implicitModLines", "explicitModLines", "enchantModLines", "runeModLines" }) do
		for index, line in ipairs(before[field]) do
			if before:CheckModLineVariant(line) and after[field][index] then
				local change = scoreLine(line, after[field][index])
				if change then
					table.insert(changes, change)
					if change.percent then score = score + change.percent else unscored = unscored + 1 end
				end
			end
		end
	end
	return changes, score, unscored
end

local function localEffects(item)
	local effects = { Prefix = 0, Suffix = 0 }
	if item.type == "Jewel" then
		for _, line in ipairs(item.explicitModLines) do
			local value, kind = line.line:match("^(%d+)%% increased Effect of (Prefix)es")
			if not value then value, kind = line.line:match("^(%d+)%% increased Effect of (Suffix)es") end
			if value then effects[kind] = effects[kind] + tonumber(value) / 100 end
		end
	end
	return effects
end

-- A normal game copy contains already-catalysed printed numbers without tags.
-- Find rolls that reproduce those numbers with the existing quality/effects,
-- then use the same item formatter at the requested quality. Never guess rolls.
local function recoverPrintedLine(item, line, implicit, oldId, oldQuality, newId, quality, effects)
	local text = printed(line)
	local target, outcomes = numbers(text), { }
	for _, affix in ipairs(item:GetCatalystAffixes(line, implicit)) do
		local effect = effects[affix.mod.type] or 0
		local scalar = item:GetCatalystScalar(affix.mod, oldId, oldQuality) + effect
		local nextScalar = item:GetCatalystScalar(affix.mod, newId, quality) + effect
		local minimum = numbers(itemLib.applyRange(affix.line, 0, scalar))
		local maximum = numbers(itemLib.applyRange(affix.line, 1, scalar))
		local recovered = { }
		if #minimum == #target and #maximum == #target then
			-- A copied damage range can roll each endpoint independently; a
			-- single crafting-slider position need not reproduce both values.
			for index, value in ipairs(target) do
				local low, high = 0, 1
				local increasing = maximum[index] >= minimum[index]
				for _ = 1, 40 do
					local range = (low + high) / 2
					local current = numbers(itemLib.applyRange(affix.line, range, scalar))[index]
					if current == value then
						recovered[index] = numbers(itemLib.applyRange(affix.line, range, nextScalar))[index]
						break
					elseif (current < value) == increasing then low = range else high = range end
				end
				if recovered[index] == nil then break end
			end
		end
		if #recovered == #target then
			local index = 0
			local outcome = text:gsub("%-?%d+%.?%d*", function()
				index = index + 1
				return tostring(recovered[index])
			end)
			outcomes[outcome] = true
		end
	end
	local outcome = next(outcomes)
	assert(outcome and not next(outcomes, outcome), "Cannot recover this item's existing catalyst rolls. Import its advanced item copy: " .. printed(line))
	-- This text already includes the requested quality; keep it unscaled on parse.
	line.line, line.range, line.valueScalar, line.modTags = outcome, nil, 1, { }
end

function report.Prepare(raw, catalyst, quality)
	local item = new("Item", raw)
	assert(item:CanUseCatalysts(), "Choose a ring, amulet or jewel.")
	local oldId, oldQuality = item.catalyst, item.catalystQuality
	local effects, inferred = localEffects(item), { }
	for _, field in ipairs({ "implicitModLines", "explicitModLines" }) do
		for _, line in ipairs(item[field]) do
			if not line.modTags or #line.modTags == 0 then inferred[line] = field == "implicitModLines" end
		end
	end
	local craft = false
	if item.crafted and (item.rarity == "RARE" or item.rarity == "MAGIC") then
		for _, affixes in ipairs({ item.prefixes, item.suffixes }) do
			for _, affix in ipairs(affixes) do
				if item.affixes[affix.modId] then craft = true end
			end
		end
	end
	item:InferCatalystTags()
	if not craft and ((oldId and oldQuality and oldQuality > 0) or effects.Prefix > 0 or effects.Suffix > 0) then
		for line, implicit in pairs(inferred) do
			if not line.unscalable and #line.modTags > 0 then
				local affected = item:GetCatalystScalar(line, oldId, oldQuality) ~= 1
				for _, affix in ipairs(item:GetCatalystAffixes(line, implicit)) do
					if (effects[affix.mod.type] or 0) > 0 then affected = true end
				end
				if affected then recoverPrintedLine(item, line, implicit, oldId, oldQuality, catalyst, quality, effects) end
			end
		end
	end
	item.catalyst, item.catalystQuality = catalyst, catalyst and quality or nil
	-- Crafted text already contains quality and local prefix/suffix effects.
	-- Rebuild its saved rolls instead of scaling those printed values twice.
	if craft then item:Craft() else item:BuildAndParseRaw() end
	item:BuildModList()
	return item
end

function report.ItemResult(raw, quality, candidateNames)
	quality = math.floor(tonumber(quality) or 20)
	assert(quality >= 0 and quality <= 100, "Quality must be between 0% and 100%.")
	local baseline = report.Prepare(raw)
	local result = { baseline = { }, rows = { }, quality = quality }
	for id = 1, 13 do
		local name = baseline:GetCatalystName(id)
		if not candidateNames or candidateNames[name] then
			local item = report.Prepare(raw, id, quality)
			local changes, score, unscored = report.ModifierChanges(baseline, item)
			local lines = { }
			for _, change in ipairs(changes) do table.insert(lines, change.after) end
			table.insert(result.rows, { id = id, name = name, score = score, changes = changes,
				lines = lines, unscored = unscored })
		end
	end
	return result, baseline
end

function report.Calculate(build, raw, slotName, quality, candidateNames)
	local result, baseline = report.ItemResult(raw, quality, candidateNames)
	result.slot = slotName
	-- Item-only results remain useful even when no allocated jewel socket exists.
	if not slotName or not build.itemsTab:IsItemValidForSlot(baseline, slotName) then
		result.buildUnavailable = "No active, usable comparison slot for this item."
		return result
	end
	local calculator = build.calcsTab:GetMiscCalculator()
	local output, env = calculator({ repSlotName = slotName, repItem = baseline }, true, { noEnvReuse = true, includeEnv = true })
	local equipped = false
	for _, item in pairs(env.player.itemList) do if item == baseline then equipped = true end end
	if not equipped then
		result.buildUnavailable = "Choose an item in an active, allocated equipment or jewel slot."
		return result
	end
	result.baseline = shared.Snapshot(output)
	result.baselineComparison = shared.ComparisonSnapshot(output)
	for _, row in ipairs(result.rows) do
		local candidate = report.Prepare(raw, row.id, result.quality)
		local after = calculator({ repSlotName = slotName, repItem = candidate }, true, { noEnvReuse = true })
		row.values = shared.Snapshot(after)
		row.comparison = shared.ComparisonChanges(result.baselineComparison, shared.ComparisonSnapshot(after))
	end
	return result
end

return report
