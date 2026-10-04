-- Synthetic builds only; no saved user data.
if not build then arg = {}; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/AugmentReport")
local function make(base, name, extra)
	local item = new("Item", "Rarity: Rare\nDamage Idol Fixture\n" .. base .. "\n--------\nSockets: S S\n--------\nItem Level: 80\n--------\n" .. (extra or "+100 to maximum Life"))
	item.runes = name and {name} or {}; item:UpdateRunes(); item:BuildAndParseRaw(); item:BuildModList()
	return item
end
local function equip(item, slot)
	build.itemsTab:AddItem(item, true); build.itemsTab.slots[slot]:SetSelItemId(item.id)
end
local function frame()
	build.configTab:BuildModList(); build.buildFlag = true
	runCallback("OnFrame"); runCallback("OnFrame")
end
local function close(a, b, message) assert(math.abs(a - b) < 0.00001, message .. ": " .. a .. " vs " .. b) end
local damage = "Adds 100 to 200 Physical Damage\nAdds 30 to 50 Fire Damage\nAdds 20 to 30 Cold Damage\nAdds 40 to 60 Lightning Damage\nAdds 10 to 20 Chaos Damage"
local bow = make("Crude Bow", nil, damage)
equip(bow, "Weapon 1")
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
build.skillsTab:PasteSocketGroup("Voltaic Mark 20/0 1")
frame()
assert(build.configTab.varControls.conditionMarkActivatedRecently.shown(), "Enabled Mark exposes activation scenario before Cunning is equipped")
assert(build.configTab.varControls.multiplierCurrentManaPercentage.shown(), "Socketed weapon exposes mana scenario before Pharisee is equipped")
build.configTab.input.conditionCastMarkRecently = true
local boots = make("Rawhide Boots", "Carved Cunning")
equip(boots, "Boots"); frame()
assert(not build.calcsTab.mainEnv.player.modDB:Flag(nil, "Onslaught"), "Casting a Mark is not activation")
local inactiveDPS = build.calcsTab.mainOutput.FullDPS
local emptyBoots = make("Rawhide Boots")
local function bootReport() return report.Calculate(build, emptyBoots:BuildRaw(), "Boots", {["Carved Cunning"] = true}) end
local inactive = bootReport()
close(inactive.rows[1].values.FullDPS, inactive.baseline.FullDPS, "No activation contributes no DPS")
build.configTab.input.conditionMarkActivatedRecently = true; frame()
assert(build.calcsTab.mainEnv.player.modDB:GetCondition("Onslaught"))
assert(build.calcsTab.mainOutput.FullDPS > inactiveDPS)
local activeDPS = build.calcsTab.mainOutput.FullDPS
local active = bootReport()
local direct = build.calcsTab:GetMiscCalculator()({repSlotName = "Boots", repItem = boots}, true, {noEnvReuse = true})
close(active.rows[1].values.FullDPS, direct.FullDPS, "Mark Onslaught recommendation parity")
build.configTab.input.buffOnslaught = true; frame()
close(build.calcsTab.mainOutput.FullDPS, activeDPS, "Manual Onslaught must not stack with Cunning")
build.configTab.input.buffOnslaught = false
build.configTab.input.conditionMarkActivatedRecently = false; frame()
close(build.calcsTab.mainOutput.FullDPS, inactiveDPS, "Activation scenario reverses")
build.configTab.input.conditionMarkActivatedRecently = true
equip(emptyBoots, "Boots"); frame()
assert(not build.calcsTab.mainEnv.player.modDB:Flag(nil, "Onslaught"), "Activation alone cannot grant Onslaught")
print("PASS: Mark activation differs from casting; manual scenario appears before equipping; Onslaught gains, non-stacking and recommendation parity")

for _, base in ipairs({"Crude Bow", "Withered Wand", "Ashen Staff"}) do
	local item = make(base, "Idol of the Pharisee", damage)
	for _, line in ipairs(item.runeModLines) do assert(not line.extra and #line.modList > 0, line.line) end
	build.itemsTab:SetDisplayItem(item)
	assert(build.itemsTab.controls.displayItemRune1.list[build.itemsTab.controls.displayItemRune1.selIndex].name == "Idol of the Pharisee")
	assert(new("Item", item:BuildRaw()).runes[1] == "Idol of the Pharisee")
end
local pharisee = make("Crude Bow", "Idol of the Pharisee", damage)
equip(pharisee, "Weapon 1")
for _, case in ipairs({{100, 0}, {91, 0}, {90, 2}, {31, 12}, {30, 14}, {0, 20}, {-5, 20}, {110, 0}}) do
	build.configTab.input.multiplierCurrentManaPercentage = case[1]; frame()
	local skill = build.calcsTab.mainEnv.player.mainSkill
	close(skill.skillModList:Sum("BASE", skill.skillCfg, "DamageGainAsPhysical"), case[2], "Missing mana scaling at " .. case[1])
end
build.configTab.input.multiplierCurrentManaPercentage = nil; frame()
local skill = build.calcsTab.mainEnv.player.mainSkill
close(skill.skillModList:Sum("BASE", skill.skillCfg, "DamageGainAsPhysical"), 0, "Blank mana scenario defaults to no missing Mana")
build.configTab.input.multiplierCurrentManaPercentage = 30; frame()
local reference = make("Crude Bow", nil, damage .. "\n30% reduced maximum Mana\nGain 14% of Damage as Extra Physical Damage")
local expected = build.calcsTab:GetMiscCalculator()({repSlotName = "Weapon 1", repItem = reference}, true, {noEnvReuse = true})
close(build.calcsTab.mainOutput.FullDPS, expected.FullDPS, "70% missing mana equals independent fixed 14% gain across all damage types")
close(build.calcsTab.mainOutput.Mana, expected.Mana, "Pharisee retains reduced maximum Mana")
local result = report.Calculate(build, bow:BuildRaw(), "Weapon 1", {["Idol of the Pharisee"] = true})
close(result.rows[1].values.FullDPS, expected.FullDPS, "Pharisee recommendation parity")
assert(result.rows[1].values.FullDPS > result.baseline.FullDPS)
assert(result.rows[1].values.Mana < result.baseline.Mana)
print("PASS: Pharisee weapon/wand/staff import/editor/round trip; zero/full/blank/boundary mana; independent 14% gain, Mana penalty and recommendation parity")

-- The background report reloads configuration from an in-memory build snapshot.
local expectedBoots = report.Calculate(build, emptyBoots:BuildRaw(), "Boots", {["Carved Cunning"] = true})
local snapshot = build:SaveDB("Idol damage worker fixture")
local json = require("dkjson")
local function workerParity(raw, slot, name, expectedReport)
	local worker = json.decode(assert(loadfile("Modules/AugmentReportWorker.lua"))(".", snapshot, raw, slot, json.encode({[name] = true})))
	assert(#worker.rows == 1, "Worker must retain " .. name)
	for key, value in pairs(expectedReport.baseline) do close(worker.baseline[key], value, name .. " worker baseline " .. key) end
	for key, value in pairs(expectedReport.rows[1].values) do close(worker.rows[1].values[key], value, name .. " worker result " .. key) end
end
workerParity(bow:BuildRaw(), "Weapon 1", "Idol of the Pharisee", result)
workerParity(emptyBoots:BuildRaw(), "Boots", "Carved Cunning", expectedBoots)
print("PASS: background snapshot preserves Current Mana % and Mark activation; every candidate and baseline metric matches direct calculations")
