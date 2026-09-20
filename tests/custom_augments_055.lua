-- Exercise every changed/new 0.5.5 core through clipboard import and the editor.
if not build then arg = {}; dofile("HeadlessWrapper.lua") end
newBuild()
local testDir = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local fixtures = dofile(testDir.."fixtures/augments_055.lua")
local bases = {
	weapon = "Crude Bow", caster = "Withered Wand", bow = "Crude Bow",
	armour = "Rusted Cuirass", ["body armour"] = "Rusted Cuirass",
	helmet = "Rusted Greathelm", gloves = "Linen Wraps", boots = "Rawhide Boots",
	focus = "Woven Focus", shield = "Splintered Tower Shield", buckler = "Leather Buckler",
}
local function raw(base, lines, extra)
	local tagged = {}
	for _, line in ipairs(lines) do table.insert(tagged, line.." (rune)") end
	return "Rarity: Rare\nAugment Test\n"..base.."\n--------\nSockets: S S S\n--------\nItem Level: 80\n--------\n"..table.concat(tagged,"\n").."\n--------\n"..(extra or "")
end
local count = 0
for _, fixture in ipairs(fixtures) do
	local label = fixture.name.." / "..fixture.slot
	local item = new("Item", raw(assert(bases[fixture.slot], fixture.slot), fixture.lines))
	assert(item.base, label..": fixture base missing")
	assert(item.runes[1] == fixture.name, label..": inferred "..tostring(item.runes[1]))
	item:BuildModList()
	for _, line in ipairs(item.runeModLines) do
		-- Unchanged Thesis glove/boot mechanics are outside this patch's helmet update.
		if fixture.name ~= "Jiquani's Thesis" or fixture.slot == "helmet" or fixture.slot == "body armour" then
			assert(line.modList and not line.extra, label..": unsupported modifier "..line.line)
		end
	end
	build.itemsTab:SetDisplayItem(item)
	local dropdown = build.itemsTab.controls.displayItemRune1
	assert(dropdown.list[dropdown.selIndex].name == fixture.name, label..": editor lost selection")
	item:UpdateRunes()
	item:BuildAndParseRaw()
	for _, expected in ipairs(fixture.lines) do
		assert(item:BuildRaw():find(expected, 1, true), label..": rebuild lost "..expected)
	end
	local saved = new("Item", item:BuildRaw())
	assert(saved.runes[1] == fixture.name, label..": round-trip lost selection")
	count = count + 1
end
print("PASS: "..count.." augment/slot fixtures import, parse, select, rebuild and round-trip")

local function frame()
	build.buildFlag = true
	runCallback("OnFrame")
	runCallback("OnFrame")
	return build.calcsTab.mainOutput, build.calcsTab.mainEnv.player.modDB
end
local function equip(base, name, slot, extra)
	local item = new("Item", raw(base, {}, extra))
	item.runes = name and {name} or {}
	item:UpdateRunes()
	item:BuildAndParseRaw()
	build.itemsTab:AddItem(item, true)
	build.itemsTab.slots[slot]:SetSelItemId(item.id)
	return item
end
local families = {
	Automation = "totem", Malediction = "curse", Targeting = "mark", Rallying = "warcry",
	Radiance = "herald", Severing = "strike", Rippling = "nova", Quaking = "slam",
	Munitions = "grenade", Snares = "hazard", Abundance = "plant", Squalls = "wind", Thundering = "storm",
}
for suffix, tag in pairs(families) do
	newBuild()
	local candidates = {}
	for _, gem in pairs(data.gems) do
		if gem.tags[tag] and gem.tags.grants_active_skill and not gem.tags.support then table.insert(candidates, gem.name) end
	end
	table.sort(candidates)
	local name = assert(candidates[1], "Missing gem fixture for "..tag)
	build.skillsTab:PasteSocketGroup(name.." 20/0 1")
	local item = equip("Withered Wand", "Jiquani's Soul Core of "..suffix, "Weapon 1")
	frame()
	local gem = build.skillsTab.socketGroupList[1].gemList[1]
	assert(gem.displayEffect and gem.displayEffect.level == 21, suffix..": "..name.." must gain one effective level")
	item.runes = {}
	item:UpdateRunes(); item:BuildModList(); frame()
	assert(gem.displayEffect.level == 20, suffix..": removing core must restore gem level")
end
print("PASS: all thirteen Jiquani families change effective skill level 20 -> 21 -> 20")

newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
equip("Crude Bow", nil, "Weapon 1", "Adds 10 to 20 Lightning Damage\nCorrupted")
local original, originalMods = frame()
local originals = { Life = original.Life, Spirit = original.Spirit, Speed = original.Speed, ChaosResist = original.ChaosResist, LifeInc = originalMods:Sum("INC", nil, "Life") }
equip("Rusted Greathelm", "Atziri's Soul Core of Devotion", "Helmet", "Corrupted")
equip("Rusted Cuirass", "Atziri's Soul Core of Vitality", "Body Armour", "Corrupted")
equip("Linen Wraps", "Atziri's Soul Core of Alacrity", "Gloves", "Corrupted")
equip("Rawhide Boots", "Atziri's Soul Core of Inoculation", "Boots", "Corrupted")
local output, mods = frame()
assert(mods:Sum("INC", nil, "Life") == originals.LifeInc + 5, "Vitality must count all five corrupted equipped items")
assert(mods:Sum("INC", nil, "Spirit") == 5, "Devotion must count all five corrupted equipped items")
assert(output.ChaosResist == originals.ChaosResist + 10, "Inoculation must grant ten chaos resistance")
assert(output.Life > originals.Life and output.Speed > originals.Speed, "Vitality and Alacrity must change calculated Life and attack speed")
local saved = build:SaveDB("0.5.5 augments")
loadBuildFromXML(saved, "Augments round-trip")
output = frame()
assert(output.ChaosResist == originals.ChaosResist + 10, "Corrupted scalar lost after build save/load")
print("PASS: all four Atziri corrupted-item scalars and saved-build persistence")

newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
equip("Crude Bow", "Soul Core of Xopec", "Weapon 1")
equip("Crude Bow", "Soul Core of Xopec", "Weapon 1 Swap")
frame()
assert(not build.calcsTab.mainEnv.itemWarnings.augmentLimitWarning, "Inactive weapon must not count towards limit")
local boots = equip("Rawhide Boots", "Soul Core of Xopec", "Boots")
frame()
assert(#build.calcsTab.mainEnv.itemWarnings.augmentLimitWarning == 1, "One-copy limit must span equipped slots")
boots.runes = {}; boots:UpdateRunes(); boots:BuildModList(); frame()
assert(not build.calcsTab.mainEnv.itemWarnings.augmentLimitWarning, "Removing duplicate must clear warning")
local bow = build.itemsTab.items[build.itemsTab.slots["Weapon 1"].selItemId]
bow.runes = {"Soul Core of Xopec", "Soul Core of Xopec"}; bow:UpdateRunes(); bow:BuildModList(); frame()
assert(#build.calcsTab.mainEnv.itemWarnings.augmentLimitWarning == 1, "Duplicate sockets on one item must warn")
build.itemsTab.activeItemSet.useSecondWeaponSet = true; frame()
assert(not build.calcsTab.mainEnv.itemWarnings.augmentLimitWarning, "Weapon swap must recalculate limits")
print("PASS: character-wide limits, duplicate sockets, inactive weapon exclusion and warning clearing")

newBuild()
equip("Rusted Greathelm", "Jiquani's Thesis", "Helmet")
equip("Rawhide Boots", "Guatelitzi's Thesis", "Boots")
frame()
local warnings = build.calcsTab.mainEnv.itemWarnings.augmentLimitWarning
assert(warnings and #warnings == 1 and warnings[1]:find("Jiquani",1,true) and warnings[1]:find("Guatelitzi",1,true), "Different Ancient augments must share one limit")
build:InsertItemWarnings()
assert(table.concat(build.controls.warnings.lines,"\n"):find("exceeding augment limit",1,true), "Build warning must be visible")
print("PASS: shared Ancient augment limit and build warning display")

local function near(actual, expected, label)
	assert(type(actual) == "number", label..": missing calculated output")
	assert(math.abs(actual - expected) < 0.0001, label..": expected "..expected..", got "..tostring(actual))
end
newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
equip("Crude Bow", nil, "Weapon 1", "Adds 10 to 20 Lightning Damage")
local base = frame()
local baseDps = base.TotalDPS
local bow = equip("Crude Bow", "Soul Core of Citaqualotl", "Weapon 1", "Adds 10 to 20 Lightning Damage")
output = frame()
assert(output.TotalDPS > baseDps, "Citaqualotl must increase elemental attack DPS")
bow.runes = {"Soul Core of Topotante"}; bow:UpdateRunes(); bow:BuildModList()
output, mods = frame()
near(build.calcsTab.calcs.buildOutput(build, "CALCS").player.output.MainHand.LightningResistancePenetration,25,"Topotante penetration")
equip("Rawhide Boots", "Soul Core of Topotante", "Boots")
output = frame()
near(output.SelfShockEffect,75,"Topotante incoming Shock effect")
near(output.SelfChillEffect,75,"Topotante incoming Chill effect")
equip("Rusted Greathelm", "Soul Core of Opiloti", "Helmet")
output = frame()
near(output.PinDurationMod,1.25,"Opiloti Pin duration multiplier")
equip("Rawhide Boots", "Estazunti's Soul Core of Convalescence", "Boots")
equip("Rusted Greathelm", "Estazunti's Soul Core of Convalescence", "Helmet")
output = frame()
near(output.LifeRecoup,10,"Convalescence Life Recoup")
near(output.LifeRecoupDuration,8/1.15,"Convalescence Recoup duration")
local recoupTotal, recoupRate = output.TotalLifeRecoupRecovery, output.LifeRecoupRecoveryMax
local recoupBoots = build.itemsTab.items[build.itemsTab.slots.Boots.selItemId]
recoupBoots.runes = {}; recoupBoots:UpdateRunes(); recoupBoots:BuildModList()
output = frame()
near(output.LifeRecoupDuration,8,"Unmodified Recoup duration")
near(output.TotalLifeRecoupRecovery,recoupTotal,"Recoup speed must preserve total recovery")
near(recoupRate,output.LifeRecoupRecoveryMax*1.15,"Recoup recovery rate")
print("PASS: elemental attack damage, penetration, incoming ailments, Pin duration and Recoup speed")

newBuild()
local helmet = equip("Rusted Greathelm", "Jiquani's Thesis", "Helmet", "+300 to Armour")
output, mods = frame()
local mana, baseMana = output.Mana, mods:Sum("BASE", nil, "Mana")
local armour = helmet.armourData.Armour
helmet.runes = {}; helmet:UpdateRunes(); helmet:BuildModList()
output, mods = frame()
near(baseMana-mods:Sum("BASE", nil, "Mana"),math.floor(armour/3),"Thesis Mana from helmet Armour")
assert(mana > output.Mana, "Thesis must increase calculated Mana")
equip("Withered Wand", nil, "Weapon 1")
equip("Woven Focus", nil, "Weapon 2", "+100 to maximum Energy Shield")
local body = equip("Rusted Cuirass", "Atmohua's Soul Core of Retreat", "Body Armour")
output = frame()
local es = output.EnergyShield
body.runes = {}; body:UpdateRunes(); body:BuildModList()
output = frame()
assert(es > output.EnergyShield, "Retreat must scale Energy Shield from equipped Focus")
print("PASS: Thesis item-Armour scaling and Retreat equipped-Focus scaling")
