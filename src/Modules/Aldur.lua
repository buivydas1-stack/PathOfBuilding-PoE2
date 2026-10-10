-- Aldur changes affix families, rather than converting outgoing damage.
-- Keep original item text as the reversible input; derive average-roll preview
-- modifiers for calculations and display. Game-forged copies use actual rolls.
local aldur = { }
local families = LoadModule("Data/AldurConversions")
local elements = { "Fire", "Cold", "Lightning", "Chaos" }
aldur.Targets = { ["Ire of Aldur"] = 3, ["Passion of Aldur"] = 1, ["Breath of Aldur"] = 2, ["Betrayal of Aldur"] = 4 }
aldur.ForgedLines = {
	["Forged by the Ire of Aldur"] = "Transforms all Fire and Cold modifiers on the item into equivalent Lightning modifiers",
	["Forged by the Passion of Aldur"] = "Transforms all Cold and Lightning modifiers on the item into equivalent Fire modifiers",
	["Forged by the Breath of Aldur"] = "When socketed, transforms all Fire and Lightning modifiers to equivalent Cold modifiers",
	["Forged by the Betrayal of Aldur"] = "Transforms all Fire, Cold and Lightning modifiers on the item into equivalent Chaos modifiers",
}

function aldur.Normalise(line)
	return line:gsub("%-?%d+%.?%d*%(%-?%d+%.?%d*%-%-?%d+%.?%d*%)", "#")
		:gsub("%(%-?%d+%.?%d*%-%-?%d+%.?%d*%)", "#"):gsub("%-?%d+%.?%d*", "#")
end

local byId = { }
for _, family in ipairs(families) do
	for index, id in ipairs(family) do if id then byId[id] = { family = family, index = index } end end
end

local function lookup(id)
	return data.itemMods.Item[id] or data.itemMods.Desecrated[id] or data.itemMods.Jewel[id]
end

local function parsed(line, original)
	local result = copyTable(original or { })
	result.line, result.range = line, nil
	result.modList, result.extra = modLib.parseMod(line)
	result.modList = result.modList or { }
	return result
end

local function eligible(line, target)
	for index = 1, 3 do
		if index ~= target and line:find(elements[index], 1, true) then return true end
	end
	return false
end

local function matches(line, template)
	if aldur.Normalise(line) ~= aldur.Normalise(template) then return false end
	local values = { }
	for n in line:gmatch("%-?%d+%.?%d*") do values[#values+1] = tonumber(n) end
	local i, valid = 0, true
	template:gsub("%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)", function(lo, hi)
		i = i + 1
		if not values[i] or values[i] < tonumber(lo) or values[i] > tonumber(hi) then valid = false end
		return "#"
	end):gsub("%-?%d+%.?%d*", function(n)
		i = i + 1
		if values[i] ~= tonumber(n) then valid = false end
	end)
	return valid and i == #values
end

local function targetLines(id, target)
	local entry = byId[id]
	if not entry or entry.index == target or entry.index == 4 then return end
	local mod = lookup(entry.family[target])
	if not mod then return nil, "Equivalent target affix is missing from PoB's data." end
	local lines = { }
	for _, line in ipairs(mod) do
		line = itemLib.applyRange(line, 0.5)
		local modifiers, extra = modLib.parseMod(line)
		if not modifiers or extra then return nil, "Equivalent target modifier is not supported: " .. line end
		lines[#lines+1] = line
	end
	return lines
end

function aldur.Transform(item)
	local target
	for _, name in ipairs(item.runes or { }) do
		if aldur.Targets[name] then
			if target and target ~= aldur.Targets[name] then return nil, false, "Multiple different Aldur transformations cannot be previewed together." end
			target = aldur.Targets[name]
		end
	end
	if not target then return end
	if item.aldurForged then
		if not aldur.Targets[item.aldurForgedRune] then return nil, false, "The original Aldur forging rune is unknown." end
		if aldur.Targets[item.aldurForgedRune] ~= target then
			return nil, false, "This item was already forged by " .. item.aldurForgedRune .. "; a different Aldur transformation cannot be previewed."
		end
		return -- Actual game-forged modifiers already include this rune's result.
	end
	local result, changed, unavailable = { }, false, nil
	-- Known crafted/imported affixes retain their identities, even when two
	-- prefixes have been combined into one displayed damage line.
	local known, covered, order = { }, { }, { }
	if item.crafted then
		for _, list in ipairs({ item.prefixes, item.suffixes }) do
			for _, affix in ipairs(list) do
				local mod = item.affixes[affix.modId]
				if mod then
					local converted, reason
					if not affix.fractured then converted, reason = targetLines(affix.modId, target) end
					local modLines = { }
					for i, template in ipairs(mod) do
						local source = affix.copied and affix.copiedRange == affix.range and affix.copied[i] or itemLib.applyRange(template, affix.range or 0.5)
						covered[aldur.Normalise(source)] = true
						modLines[i] = parsed(converted and converted[i] or source, { fractured = affix.fractured, desecrated = affix.desecrated, crafted = affix.crafted, unscalable = affix.unscalable })
						if not affix.fractured and eligible(source, target) and not converted then unavailable = reason or "Cannot identify the equivalent affix for: " .. source end
					end
					if converted then changed = true end
					for i, line in ipairs(modLines) do
						local key = aldur.Normalise(line.line)
						if order[key] then
							local start = 1
							order[key].line = order[key].line:gsub("%-?%d+%.?%d*", function(n)
								local _, finish, other = line.line:find("(%-?%d+%.?%d*)", start)
								start = finish+1; return tonumber(n)+tonumber(other)
							end)
							order[key] = parsed(order[key].line, order[key])
							known[key] = order[key]
						else order[key], known[key] = line, line end
					end
				end
			end
		end
	end
	for _, original in ipairs(item.explicitModLines) do
		local line = original.line
		if not covered[aldur.Normalise(line)] or original.custom then
			local converted, options
			if not original.fractured and eligible(line, target) then
				options = { }
				if item.rarity ~= "UNIQUE" and item.rarity ~= "RELIC" then
					for id, mod in pairs(item.affixes) do
						if #mod == 1 and item:GetModSpawnWeight(mod) > 0 and matches(line, mod[1]) then
							local lines = targetLines(id, target)
							if lines then options[table.concat(lines, "\n")] = lines end
						end
					end
				end
				local key, lines = next(options)
				if key and not next(options, key) then converted = lines
				else unavailable = "Equivalent affix is unknown or ambiguous for: " .. line end
			end
			if converted then
				changed = true
				for _, text in ipairs(converted) do result[#result+1] = parsed(text, original) end
			else result[#result+1] = original end
		end
	end
	local keys = { }; for key in pairs(known) do keys[#keys+1] = key end; table.sort(keys)
	for _, key in ipairs(keys) do result[#result+1] = known[key] end
	-- A partial transformation must never look like a complete numerical result.
	if unavailable then return nil, changed, unavailable end
	return changed and result or nil, changed
end

return aldur
