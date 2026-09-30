arg = {}
dofile("HeadlessWrapper.lua")
newBuild()

local function near(actual, expected, label)
	assert(math.abs(actual - expected) < 0.01, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local function recalc(mods)
	build.configTab.input.customMods = mods or ""
	build.configTab:BuildModList()
	build.buildFlag = true
	runCallback("OnFrame")
	return build.calcsTab.mainOutput
end

local flask = new("Item", "Rarity: UNIQUE\nLavianga's Spirits\nGargantuan Mana Flask\nQuality: 23\nImplicits: 0\nThis Flask cannot be Used but applies its Effect constantly\n70% reduced Amount Recovered")
build.itemsTab:AddItem(flask, true)
build.itemsTab.slots["Flask 2"].selItemId = flask.id
build.itemsTab.slots["Flask 2"].active = false
local baseline = recalc()
assert(baseline.ManaFlaskRecoveryPerSecond > 0, "Equipped Lavianga should apply constantly")
near(flask.flaskData.manaBase, 185 * 1.23 * 0.30, "Quality and unique roll")
near(baseline.ManaFlaskRecoveryPerSecond, flask.flaskData.manaBase / 2, "Flask recovery per second")
near(baseline.ManaRecovery, baseline.ManaFlaskRecoveryPerSecond, "Mana recovery source")
assert(build.calcsTab.mainEnv.flasks[flask] == "recoveryOnly", "Constant recovery must not imply manual flask activation")
assert(not build.calcsTab.mainEnv.modDB.conditions.UsingFlask, "Constant recovery must not enable flask-use conditions")
assert(not build.calcsTab.mainEnv.modDB.conditions.UsingManaFlask, "Constant recovery must not force mana flask conditions")

build.configTab.configSets[build.configTab.activeConfigSetId].input.conditionUsingFlask = true
recalc()
assert(build.calcsTab.mainEnv.modDB:Flag(nil, "Condition:UsingManaFlask"), "Manually active Lavianga should enable mana flask effect conditions")
local wellspring
for _, node in pairs(build.spec.nodes) do
	for _, line in ipairs(node.sd or {}) do
		if line == "8% increased Attack and Cast Speed during Effect of any Mana Flask" then wellspring = node; break end
	end
	if wellspring then break end
end
assert(wellspring, "Need the current Wellspring Disgust passive")
local flaskCalc, withoutWellspring = build.calcsTab:GetMiscCalculator()
local withWellspring = flaskCalc({ addNodes = { [wellspring] = true } }, false, { noEnvReuse = true })
assert(withWellspring.Speed > withoutWellspring.Speed, "Wellspring Disgust should increase speed during Lavianga's effect")
build.configTab.configSets[build.configTab.activeConfigSetId].input.conditionUsingFlask = false
recalc()

for _, variant in ipairs({ {20,70,67}, {20,80,44}, {23,70,68}, {13,72,59}, {23,72,64} }) do
	local item = new("Item", string.format("Rarity: UNIQUE\nLavianga's Spirits\nGargantuan Mana Flask\nQuality: %d\nImplicits: 0\nThis Flask cannot be Used but applies its Effect constantly\n%d%% reduced Amount Recovered\nCorrupted", variant[1], variant[2]))
	item:BuildModList()
	near(item.flaskData.manaBase, 185 * (1 + variant[1] / 100) * (1 - variant[2] / 100), "Variant base recovery")
	assert(math.floor(item.flaskData.manaBase + 0.5) == variant[3], "Variant displayed recovery mismatch")
end

local ten = recalc("10% increased Mana Recovery from Flasks")
near(ten.ManaFlaskRecoveryPerSecond, baseline.ManaFlaskRecoveryPerSecond * 1.10, "Mana flask passive")
local thirty = recalc("10% increased Mana Recovery from Flasks\n20% increased Life and Mana Recovery from Flasks\n10% chance for Flasks you use to not consume Charges")
near(thirty.ManaFlaskRecoveryPerSecond, baseline.ManaFlaskRecoveryPerSecond * 1.30, "Combat Alchemy recovery")
near(thirty.ManaRegenRecovery - baseline.ManaRegenRecovery, thirty.ManaFlaskRecoveryPerSecond - baseline.ManaFlaskRecoveryPerSecond, "Recovery report includes flask change")

local reportStat
local displayStat
for _, stat in ipairs(data.powerStatList) do
	if stat.label == "Mana recovery" then reportStat = stat end
end
for _, stat in ipairs(build.displayStats) do
	if stat.stat == "ManaFlaskRecoveryPerSecond" then displayStat = stat end
end
assert(reportStat and reportStat.stat == "ManaRegenRecovery", "Tree report should compare ongoing mana recovery")
assert(displayStat and displayStat.label == "Mana from Flasks/s", "Sidebar and hover comparison should expose flask recovery")
near(data.powerStatList.GetFromOutput(thirty, reportStat) - data.powerStatList.GetFromOutput(baseline, reportStat), thirty.ManaFlaskRecoveryPerSecond - baseline.ManaFlaskRecoveryPerSecond, "Power report metric")
local passive
for _, node in pairs(build.spec.nodes) do
	for _, line in ipairs(node.sd or {}) do
		if line == "10% increased Mana Recovery from Flasks" and not node.alloc then passive = node; break end
	end
	if passive then break end
end
assert(passive, "Need a current mana flask recovery passive")
local calc, base = build.calcsTab:GetMiscCalculator()
local changed = calc({ addNodes = { [passive] = true } }, false, { noEnvReuse = true })
assert(changed.ManaFlaskRecoveryPerSecond > base.ManaFlaskRecoveryPerSecond and changed.ManaRegenRecovery > base.ManaRegenRecovery, "Passive calculation should increase flask recovery")
local report = setmetatable({
	build = { spec = { nodes = { [passive.id] = passive }, tree = { clusterNodeMap = {} } } },
	mainEnv = build.calcsTab.mainEnv, powerStat = reportStat,
	miscCalculator = { calc, base },
}, { __index = build.calcsTab })
report:PowerBuilder()
near(passive.power.singleStat, changed.ManaRegenRecovery - base.ManaRegenRecovery, "Actual node report")

local chargeOnly = recalc("10% chance for Flasks you use to not consume Charges")
near(chargeOnly.ManaFlaskRecoveryPerSecond, baseline.ManaFlaskRecoveryPerSecond, "Charge retention is not recovery rate")
build.itemsTab.slots["Flask 2"].selItemId = 0
near(recalc().ManaFlaskRecoveryPerSecond, 0, "Unequipped Lavianga")
print("PASS: constant flask, amount, passives, report, and charge distinction")
