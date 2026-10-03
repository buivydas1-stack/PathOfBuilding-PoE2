-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_augment_worker_snapshot.lua
arg = {}; dofile("HeadlessWrapper.lua")
newBuild()
local report = LoadModule("Modules/AugmentReport")
local json = require("dkjson")
local function equip(raw, slot)
	local item = new("Item", raw)
	build.itemsTab:AddItem(item, true); build.itemsTab.slots[slot]:SetSelItemId(item.id)
	return item
end
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
equip("Rarity: Rare\nSnapshot Bow\nCrude Bow\n--------\nAdds 100 to 200 Physical Damage", "Weapon 1")
local helmet = equip("Rarity: Rare\nSnapshot Helmet\nRusted Greathelm\n--------\nSockets: S S\n--------\n+100 to maximum Life", "Helmet")
equip("Rarity: UNIQUE\nLavianga's Spirits\nGargantuan Mana Flask\n--------\nThis Flask cannot be Used but applies its Effect constantly\n70% reduced Amount Recovered", "Flask 2")
build.configTab.input.conditionUsingFlask = true
build.configTab.input.customMods = "8% increased Attack and Cast Speed during Effect of any Mana Flask"
build.configTab:BuildModList(); build.buildFlag = true
runCallback("OnFrame"); runCallback("OnFrame")
local raw = helmet:BuildRaw()
local expected = report.Calculate(build, raw, "Helmet", { ["Idol of Egrin"] = true })
assert(build.calcsTab.mainEnv.modDB:GetCondition("UsingManaFlask"), "Fixture must use the equipment-dependent flask condition")
local parsed = common.xml.ParseXML(build:SaveDB("snapshot test"))
local config
for i, node in ipairs(parsed[1]) do
	if type(node) == "table" and node.elem == "Config" then config = table.remove(parsed[1], i); break end
end
assert(config)
table.insert(parsed[1], 1, config) -- Reproduce SaveDB's unordered section output.
local snapshot = common.xml.ComposeXML(parsed[1])
loadBuildFromXML(snapshot, "Configuration before Items")
runCallback("OnFrame")
assert(build.calcsTab.mainEnv.modDB:GetCondition("UsingManaFlask"), "Configuration must be rebuilt after all equipment loads")
local direct = report.Calculate(build, raw, "Helmet", { ["Idol of Egrin"] = true })
local worker = json.decode(assert(loadfile("Modules/AugmentReportWorker.lua"))(".", snapshot, raw, "Helmet", '{"Idol of Egrin":true}'))
for key, value in pairs(expected.baseline) do
	local tolerance = math.max(0.000001, math.abs(value) * 0.000000001)
	assert(math.abs(direct.baseline[key] - value) <= tolerance, "Reload changed " .. key)
	assert(math.abs(worker.baseline[key] - value) <= tolerance, "Worker changed " .. key)
end
assert(worker.rows[1].inactive and worker.rows[1].values.FullDPS == worker.baseline.FullDPS)
print("PASS: Configuration-before-Items reload and worker preserve every report baseline metric and inactive curse effects")
