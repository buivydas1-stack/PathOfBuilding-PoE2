-- Rune-only counting, clipboard/editor persistence and expected hit damage.
if not build then arg = {}; dofile("HeadlessWrapper.lua") end
local rune = "Emergent Possibility"
local gainText = "Gain 1% of Damage as Extra Damage of a random Element per Rune Socketed in Equipped Items"
local function approx(actual, expected, label, tolerance)
	assert(math.abs(actual - expected) <= (tolerance or 0.000001),
		string.format("%s: expected %.9f, got %.9f", label, expected, actual))
end
local function frame()
	build.buildFlag = true
	runCallback("OnFrame")
	runCallback("OnFrame")
	return build.calcsTab.mainOutput, build.calcsTab.mainEnv.player.modDB
end
local function config(mods, mode)
	local input = build.configTab.configSets[build.configTab.activeConfigSetId].input
	input.customMods = mods
	input.physMode = mode
	build.configTab:BuildModList()
	return frame()
end
local function equip(base, slot, runes, extra)
	local item = new("Item", "Rarity: Rare\nRune Test\n"..base.."\nSockets: S S S\n"..(extra or ""))
	assert(item.base, "Unknown base: "..base)
	item.runes = runes or {}
	item:UpdateRunes()
	item:BuildAndParseRaw()
	build.itemsTab:AddItem(item, true)
	build.itemsTab.slots[slot]:SetSelItemId(item.id)
	return item
end
local function gainMod(item)
	for _, line in ipairs(item.runeModLines) do
		for _, mod in ipairs(line.modList) do
			if mod.name == "DamageGainAsRandom" then return mod end
		end
	end
	error("Missing random gain modifier")
end

newBuild()
local parsed, extra = modLib.parseMod(gainText)
assert(parsed and not extra, "Complete modifier must parse")
assert(parsed[1].name == "DamageGainAsRandom" and parsed[1][1].var == "RunesInEquipment")
local gloves = new("Item", [[Rarity: Unique
Leopold's Applause
Embroidered Gloves
--------
Sockets: S S S
--------
Item Level: 80
--------
8% increased Attack Speed (rune)
Bonded: 15% increased Duration of Elemental Ailments on Enemies (rune)
Bonded: 20% increased Elemental Damage (rune)
Bonded: 20% reduced Slowing Potency of Debuffs on You (rune)
30% increased Magnitude of Non-Damaging Ailments you inflict (rune)
Gain 1% of Damage as Extra Damage of a random Element per (rune)
Rune Socketed in Equipped Items (rune)
--------
72% increased Energy Shield
+73 to maximum Mana
15% increased Rarity of Items found
Damage Penetrates 10% Elemental Resistances
Your Hits can Penetrate Elemental Resistances down to a minimum of -50%
Corrupted]])
local imported = {}
for _, name in ipairs(gloves.runes) do imported[name] = (imported[name] or 0) + 1 end
assert(imported[rune] == 1 and imported["Thane Grannell's Rune of Mastery"] == 1 and imported["Idol of Sirrius"] == 1,
	"Wrapped clipboard import must infer all three augments")
approx(gainMod(gloves).value, 1, "Imported coefficient")
for _, line in ipairs(gloves.runeModLines) do
	if line.line:find("random Element", 1, true) then assert(not line.extra, "Gain line remains unsupported") end
end
build.itemsTab:SetDisplayItem(gloves)
local dropdown = build.itemsTab.controls.displayItemRune1
assert(dropdown.list[dropdown.selIndex].name ~= "None", "Editor discarded the imported rune")
gloves:UpdateRunes()
gloves:BuildAndParseRaw()
approx(gainMod(gloves).value, 1, "Editor coefficient")
local restored = new("Item", gloves:BuildRaw())
approx(gainMod(restored).value, 1, "Item round-trip coefficient")
print("PASS: exact wrapped clipboard import, mixed augment inference, editor rebuild and item round-trip")

-- Existing item-effect scaling must apply once and remain Rune-specific.
for _, effect in ipairs({"100% increased effect of Socketed Runes", "100% increased effect of Socketed Augment Items", "100% increased effect of Socketed Soul Cores"}) do
	local item = equip("Linen Wraps", "Gloves", {rune}, effect)
	frame()
	local expected = effect:find("Soul Cores", 1, true) and 1 or 2
	approx(build.calcsTab.mainEnv.player.modDB:Sum("BASE", nil, "DamageGainAsRandom"), expected, effect)
	item:UpdateRunes()
	item:BuildAndParseRaw()
	frame()
	approx(build.calcsTab.mainEnv.player.modDB:Sum("BASE", nil, "DamageGainAsRandom"), expected, "Rebuilt "..effect)
end
print("PASS: Rune/Augment effect scaling once; Soul Core effect does not scale the rune")

newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
local weapon = equip("Crude Bow", "Weapon 1", {"Storm Rune", "Soul Core of Xopec", "None"})
equip("Crude Bow", "Weapon 1 Swap", {"Storm Rune", "Storm Rune", "Storm Rune"})
gloves = equip("Linen Wraps", "Gloves", {rune, "Thane Grannell's Rune of Mastery", "Idol of Sirrius"})
local output, db = frame()
assert(db.multipliers.RunesInEquipment == 3, "Only three active Runes should count, including Emergent Possibility itself")
assert(db.multipliers.IdolsInEquipment == 1 and db.multipliers.NonIdolAugmentsInEquipment == 4, "Existing counters changed")
approx(db:Sum("BASE", nil, "DamageGainAsRandom"), 3, "Equipped gain percentage")
assert(output.RandomElementGainEstimate, "Average-mode limitation must be visible")
build.itemsTab.activeItemSet.useSecondWeaponSet = true
frame()
db = build.calcsTab.mainEnv.player.modDB
assert(db.multipliers.RunesInEquipment == 5, "Weapon swap must recount only the active set")
build.itemsTab.activeItemSet.useSecondWeaponSet = false
frame()
print("PASS: Rune-only count, self-count, empty sockets, Soul Core/Idol exclusion and active weapon swap")

-- Keep the same items and conditions; compare only random selection with the
-- arithmetic mean of the full elemental outcomes. Rounding is allowed at the
-- engine's existing integer hit-damage boundaries.
local mods = table.concat({
	"Adds 10 to 300 Lightning Damage to Attacks",
	"Adds 50 to 100 Fire Damage to Attacks",
	"Adds 25 to 80 Cold Damage to Attacks",
	"Adds 5 to 40 Chaos Damage to Attacks",
	"120% increased Fire Damage",
	"60% increased Cold Damage",
	"240% increased Lightning Damage",
	"Nearby Enemies have 30% Fire Resistance",
	"Nearby Enemies have 55% Cold Resistance",
	"Nearby Enemies have 75% Lightning Resistance",
	"Damage Penetrates 10% Elemental Resistances",
	"Your Hits can Penetrate Elemental Resistances down to a minimum of -50%",
	"Cannot Ignite", -- Isolate hit DPS from persistent ailments.
}, "\n")
local function checkAverage(extraMods, label)
	for line in (extraMods or ""):gmatch("[^\n]+") do
		local list, extra = modLib.parseMod(line)
		assert(list and #list > 0 and not extra, "Inactive test modifier: "..line)
	end
	local average = copyTable(config(mods.."\n"..(extraMods or ""), "AVERAGE"))
	local expected = 0
	for _, mode in ipairs({"FIRE", "COLD", "LIGHTNING"}) do
		local branch = config(mods.."\n"..(extraMods or ""), mode)
		expected = expected + branch.TotalDPS / 3
		assert(not branch.RandomElementGainEstimate, "Forced element should not show an averaging warning")
	end
	approx(average.TotalDPS, expected, label.." Total DPS", 0.2)
	approx(average.FullDPS, expected, label.." Full DPS", 0.2)
	print(string.format("PASS: %s; average DPS %.3f, elemental-outcome mean %.3f", label, average.TotalDPS, expected))
end
checkAverage(nil, "unequal elemental scaling and mitigation")
checkAverage("30% chance for Lightning Damage with Hits to be Lucky", "Lightning Rod")
checkAverage("100% chance for Damage with Hits to be Lucky", "all damage Lucky")
checkAverage("Lightning Damage with Non-Critical Hits is Lucky", "non-critical lightning Lucky")
checkAverage("60% more Maximum Lightning Damage\n+25% to Critical Hit Chance\n100% increased Critical Damage Bonus", "maximum lightning rolls and critical hits")
checkAverage("Deal no Fire Damage", "blocked fire outcomes are not redistributed")
checkAverage("25% chance to deal Double Damage\n15% chance to deal Triple Damage", "double/triple damage")
checkAverage("50% of Lightning Damage Converted to Cold Damage\nGain 20% of Damage as Extra Fire Damage", "conversion and separate non-recursive gains")

-- A rune-only Fire/Cold roll can saturate an ailment chance or cross a Chill
-- threshold. Applying a cap/threshold to one-third damage gives the wrong result.
local input = build.configTab.configSets[build.configTab.activeConfigSetId].input
input.enemyLevel = 1
local function checkAilmentChances(extraMods, label)
	for line in extraMods:gmatch("[^\n]+") do
		local list, extra = modLib.parseMod(line)
		assert(list and #list > 0 and not extra, "Inactive ailment test modifier: "..line)
	end
	local average = copyTable(config(extraMods, "AVERAGE").MainHand)
	local expected = {}
	for _, mode in ipairs({"FIRE", "COLD", "LIGHTNING"}) do
		local branch = config(extraMods, mode).MainHand
		for _, stat in ipairs({"ShockChanceOnHit", "ShockChanceOnCrit", "IgniteChanceOnHit", "IgniteChanceOnCrit", "ChillChanceOnHit"}) do
			expected[stat] = (expected[stat] or 0) + branch[stat] / 3
		end
	end
	for stat, chance in pairs(expected) do approx(average[stat], chance, label.." "..stat) end
	return average
end
local saturated = checkAilmentChances("Adds 1000000 to 1000000 Lightning Damage to Attacks\nNever deal Critical Hits", "saturated rune outcomes")
approx(saturated.IgniteChanceOnHit, 100 / 3, "Ignite cap before averaging")
approx(saturated.ChillChanceOnHit, 100 / 3, "Chill threshold before averaging")
checkAilmentChances("Adds 1 to 100 Lightning Damage to Attacks\n100% increased chance to Shock\nDeal no Fire Damage", "unsaturated/blocked outcomes")
checkAilmentChances("Adds 1000000 to 1000000 Lightning Damage to Attacks\nAll Damage can Ignite", "alternate ailment source types")
checkAilmentChances("Adds 50 to 100 Lightning Damage to Attacks\n50% of Lightning Damage Converted to Cold Damage", "converted ailment sources")
checkAilmentChances("Adds 1000000 to 1000000 Lightning Damage to Attacks\nAilments never count as being from Critical Hits", "ailments excluded from critical hits")
local criticalChillMods = "Adds 10000 to 10000 Lightning Damage to Attacks\n+100% to Critical Hit Chance"
local coldRoll = copyTable(config(criticalChillMods, "COLD").MainHand)
local thresholdPerLevel = data.monsterAilmentThresholdTable[1]
local desiredThreshold = (coldRoll.ColdHitAverage + coldRoll.ColdCritAverage) / 2
local thresholdInc = 100 * (desiredThreshold * data.gameConstants.ChillEffectMultiplier / thresholdPerLevel - 1)
assert(thresholdInc > 0)
config(criticalChillMods, "AVERAGE")
build.configTab.enemyModList:NewMod("EnemyAilmentThreshold", "INC", thresholdInc, "Test")
local split = frame().MainHand
approx(split.ChillChanceOnHit, 0, "Regular hit stays below Chill threshold")
approx(split.ChillChanceOnCrit, 100 / 3, "Critical Cold outcome crosses Chill threshold")
input.conditionEnemyShocked = true
input.conditionShockEffect = 60
approx(config("Adds 1000000 to 1000000 Lightning Damage to Attacks", "AVERAGE").CurrentShock, 60, "Manual Shock override")
input.conditionShockEffect, input.conditionEnemyShocked = nil, nil
print("PASS: per-outcome Ignite/Shock caps, Chill threshold, critical/non-critical chances, blocked and alternate source types")
input.enemyLevel = nil

build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nEmbitter 1/0 1")
build.skillsTab.socketGroupList[#build.skillsTab.socketGroupList].includeInFullDPS = false
build.mainSocketGroup = #build.skillsTab.socketGroupList
local coldDPS
for _, mode in ipairs({"AVERAGE", "FIRE", "COLD", "LIGHTNING"}) do
	local out = config(mods, mode)
	if coldDPS then approx(out.TotalDPS, coldDPS, "Embitter "..mode) else coldDPS = out.TotalDPS end
	assert(not out.RandomElementGainEstimate, "Embitter has a deterministic gained damage type")
end
print("PASS: Embitter redirects the full gain to Cold in every random-element mode")

local saved = build:SaveDB("Emergent Possibility fixture")
loadBuildFromXML(saved, "Emergent Possibility round-trip")
frame()
assert(build.calcsTab.mainEnv.player.modDB.multipliers.RunesInEquipment == 3)
approx(build.calcsTab.mainEnv.player.modDB:Sum("BASE", nil, "DamageGainAsRandom"), 3, "Build round-trip gain")
print("PASS: saved fixture preserves the rune and equipped Rune count")
