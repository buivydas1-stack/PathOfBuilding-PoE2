-- Focused backport checks against the shipped PoB2 LuaJIT runtime.
arg = {}
dofile("HeadlessWrapper.lua")
newBuild()

local function near(actual, expected, message)
	assert(math.abs(actual - expected) < 0.01, (message or "Unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local raw = table.concat({
	"Rarity: Rare", "Sorrow Road", "Runeforged Daggerfoot Shoes",
	"Quality: 20", "Evasion Rating: 156", "Energy Shield: 42", "Runic Ward: 284",
	"Sockets: S", "Implicits: 2", "5% increased Movement Speed",
	"Bonded: 10% increased Cooldown Recovery Rate",
	"40% increased Movement Speed", "+40% to Cold Resistance",
	"+30% to Lightning Resistance", "16.1 Life Regeneration per second",
	"+74 to Evasion Rating", "+18 to maximum Energy Shield",
	"22% increased Runic Ward",
}, "\n")
local boots = new("Item", raw)
assert(boots.base and boots.baseName == "Runeforged Daggerfoot Shoes")
assert(boots.armourData.Ward == 284, "Copied Runic Ward property was not imported")
boots:BuildModList()
assert(boots.baseModList:Sum("INC", nil, "Ward") == 22, "Local Runic Ward modifier was not parsed")
assert(boots.armourData.Ward == 284, "Local Runic Ward must match 194 base * 1.2 quality * 1.22 modifier")
local restored = new("Item", boots:BuildRaw())
restored:BuildModList()
assert(restored.armourData.Ward == 284, "Runic Ward changed during item save/load")
print("PASS: copied boots and local Runic Ward round-trip")

build.configTab.input.customMods = "+100 to maximum Runic Ward\n100% increased maximum Runic Ward\n100% increased maximum Energy Shield\nIncreases and Reductions to maximum Energy Shield instead apply to Ward"
build.configTab:BuildModList()
runCallback("OnFrame")
near(build.calcsTab.mainOutput.Ward, 300, "Energy Shield increase redirected to Runic Ward")
build.configTab.input.customMods = "+100 to maximum Runic Ward\n100% more maximum Energy Shield\nIncreases and Reductions to maximum Energy Shield instead apply to Ward"
build.configTab:BuildModList()
runCallback("OnFrame")
near(build.calcsTab.mainOutput.Ward, 100, "Energy Shield more should not scale Runic Ward")
print("PASS: global and redirected Runic Ward scaling")

build.configTab.input.customMods = ""
build.configTab.input.enemyDamageType = "DamageOverTime"
build.configTab.input.enemyFireDamage = 100
build.configTab:BuildModList()
runCallback("OnFrame")
local withoutWard = build.calcsTab.calcsOutput.FireTotalPool
build.configTab.input.customMods = "+100 to maximum Runic Ward"
build.configTab:BuildModList()
runCallback("OnFrame")
near(build.calcsTab.calcsOutput.FireTotalPool, withoutWard + 100, "DoT hit pool")
local output = build.calcsTab.calcsOutput
local pools = build.calcsTab.calcs.reducePoolsByDamage(nil, { Physical = 1 }, build.calcsTab.calcsEnv.player)
near(pools.hitPoolRemaining, output.PhysicalTotalHitPool - 1, "Hit pool after physical damage")
local crossingLife = build.calcsTab.calcs.reducePoolsByDamage(nil, { Physical = output.Life + 20 }, build.calcsTab.calcsEnv.player)
near(crossingLife.Life, 1, "Runic Ward must protect the last point of Life")
near(crossingLife.Ward, 79, "Runic Ward must take damage only after Life reaches one")
build.configTab.input.customMods = "+100 to maximum Runic Ward\nAll damage taken bypasses Runic Ward"
build.configTab:BuildModList()
runCallback("OnFrame")
near(build.calcsTab.calcsOutput.FireTotalPool, withoutWard, "Bypassed Runic Ward must not add to DoT pool")
print("PASS: Runic Ward hit pool, DoT pool, and bypass")

local missingMods, missingExtra = modLib.parseMod("10% increased Attack Speed while missing Runic Ward")
assert(missingExtra == nil and missingMods and missingMods[1])
local missingCondition
for _, tag in ipairs(missingMods[1]) do
	if tag.type == "Condition" then missingCondition = tag end
end
assert(missingCondition and missingCondition.var == "MissingRunicWard")
local emptyMods, emptyExtra = modLib.parseMod("Lose 5% Life per second while you have no Runic Ward during Effect")
assert(emptyExtra == nil and emptyMods and emptyMods[1])
local emptyCondition
for _, tag in ipairs(emptyMods[1]) do
	if tag.type == "Condition" and tag.var == "NoRunicWard" then emptyCondition = tag end
end
assert(emptyCondition, "No Runic Ward must remain distinct from missing Runic Ward")
print("PASS: distinct Runic Ward condition parsing")

newBuild()
build.importTab:ImportItem({
	id = "runic-ward-test", frameType = 0, name = "",
	typeLine = "Runeforged Sentinel Greathelm", inventoryId = "Helm", ilvl = 52,
	properties = { { name = "[Ward|Runic Ward]", values = { { "180", 0 } } } },
})
local imported = build.itemsTab.items[build.itemsTab.slots["Helmet"].selItemId]
assert(imported and imported.raw:find("Runic Ward: 180", 1, true), "Account import lost Runic Ward")
print("PASS: account-import Runic Ward property")

newBuild()
build.skillsTab:PasteSocketGroup("Ball Lightning 1/0  1\nScouring Flame 1/0  1")
runCallback("OnFrame")
near(build.calcsTab.mainOutput.WardCost, 2, "Scouring Flame Runic Ward cost")
build.configTab.input.customMods = "100% increased Runic Ward Cost Efficiency"
build.configTab:BuildModList()
runCallback("OnFrame")
near(build.calcsTab.mainOutput.WardCost, 1, "Runic Ward cost efficiency")

newBuild()
build.skillsTab:PasteSocketGroup("Runic Reprieve 1/0  1")
runCallback("OnFrame")
near(build.calcsTab.mainOutput.WardPerSecondCost, 3, "Runic Reprieve ongoing cost")
print("PASS: Runic Ward skill costs and efficiency")
