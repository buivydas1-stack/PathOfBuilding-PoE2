arg = {}
dofile("HeadlessWrapper.lua")
newBuild()

local function modValues(item)
	local values = {}
	for _, mod in ipairs(item.modList or {}) do
		values[#values + 1] = mod.name .. ":" .. mod.type .. ":" .. tostring(mod.value) .. ":" .. tostring(mod.flags)
	end
	table.sort(values)
	return table.concat(values, "|")
end

local imported = table.concat({
	"Rarity: RARE", "Loath Eye", "Emerald", "Implicits: 0",
	"13% increased Critical Damage Bonus for Attack Damage",
	"14% increased Attack Damage", "17% increased Damage with Bows",
	"22% increased Elemental Damage", "51% increased Effect of Prefixes",
}, "\n")
local parsed = new("Item", imported)
assert(parsed.type == "Jewel", "Fixture must parse as a jewel")
assert(not parsed.explicitModLines[#parsed.explicitModLines].extra, "Prefix effect must be supported")
assert(not modValues(parsed):find("LocalJewelPrefixEffect", 1, true), "Local effect must not leak into global stats")
local withoutEffect = new("Item", imported:gsub("\n51%% increased Effect of Prefixes", ""))
assert(modValues(parsed) == modValues(withoutEffect), "Imported prefix values are already scaled and must not be doubled")

local function craft(effectId, withQuality)
	local lines = {
		"Rarity: RARE", "Crafted Eye", "Emerald", "Crafted: true",
		"Prefix: {range:0.5}JewelBowDamage",
		"Prefix: {range:0.5}JewelAttackDamage",
		"Suffix: {range:0.5}JewelAttackCriticalDamage",
	}
	if effectId then
		lines[#lines + 1] = (effectId == "CraftedJewelPrefixEffect" and "Suffix" or "Prefix") .. ": {range:0.55}" .. effectId
	end
	if withQuality then
		lines[#lines + 1] = "Catalyst: Reaver"
		lines[#lines + 1] = "CatalystQuality: 10"
	end
	local raw = table.concat(lines, "\n")
	local item = new("Item", raw)
	item:Craft()
	return item
end

local plain, prefix, suffix = craft(), craft("CraftedJewelPrefixEffect"), craft("CraftedJewelSuffixEffect")
local function value(item, label)
	for _, modLine in ipairs(item.explicitModLines) do
		if modLine.line:find(label, 1, true) then
			return tonumber(modLine.line:match("^(%d+)"))
		end
	end
end
assert(value(prefix, "increased Damage with Bows") > value(plain, "increased Damage with Bows"), "Prefix effect must scale bow damage")
assert(value(prefix, "increased Attack Damage") > value(plain, "increased Attack Damage"), "Prefix effect must scale attack damage")
assert(modValues(prefix) ~= modValues(plain), "Scaled crafted values must reach the calculation modifier list")
assert(value(prefix, "increased Critical Damage Bonus") == value(plain, "increased Critical Damage Bonus"), "Prefix effect must leave suffixes alone")
assert(value(suffix, "increased Critical Damage Bonus") > value(plain, "increased Critical Damage Bonus"), "Suffix effect must scale suffixes")
assert(value(suffix, "increased Damage with Bows") == value(plain, "increased Damage with Bows"), "Suffix effect must leave prefixes alone")
local qualityOnly, qualityAndEffect = craft(nil, true), craft("CraftedJewelPrefixEffect", true)
assert(value(qualityAndEffect, "increased Attack Damage") == tonumber(itemLib.applyRange("(5-15)% increased Attack Damage", 0.5, 1.61):match("^(%d+)")), "Attack quality and prefix effect must add")
assert(value(qualityOnly, "increased Attack Damage") < value(qualityAndEffect, "increased Attack Damage"), "Prefix effect must stack with attack quality")
local before = modValues(prefix)
prefix:Craft()
assert(modValues(prefix) == before, "Recrafting must not compound the effect")
print("PASS: imported jewels avoid double scaling; crafted prefix and suffix effects stay local")
