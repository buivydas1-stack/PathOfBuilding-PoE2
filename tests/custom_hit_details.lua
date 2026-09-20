-- Real calculation checks for the Calcs presentation; no damage formula changes.
newBuild()
build.skillsTab:PasteSocketGroup("Spark 20/0 1\nLightning Exposure 1/0 1")
local input = build.configTab.input
input.enemyIsBoss = "None"
local function calculate(mods, resist, exposed)
	input.customMods = mods
	input.enemyLightningResist = resist
	input.conditionEnemyLightningExposure = exposed
	build.configTab:BuildModList()
	build.buildFlag = true
	runCallback("OnFrame")
	return build.calcsTab.calcs.buildOutput(build, "CALCS").player.output
end
local floorMod = "Your Hits can Penetrate Elemental Resistances down to a minimum of -50%"
local mods = "Damage Penetrates 10% Elemental Resistances\n28% chance for Lightning Damage with Hits to be Lucky"
local out = calculate(mods, 0, false)
assert(math.abs((out.LightningHitLuckyChance or -1) - 28) < 1e-8 and math.abs((out.LightningCritLuckyChance or -1) - 28) < 1e-8, tostring(out.LightningHitLuckyChance).." / "..tostring(out.LightningCritLuckyChance))
assert((out.FireHitLuckyChance or 0) == 0)
assert(out.LightningResistancePenetration == 10 and out.LightningPenetrationFloor == 0)
assert(out.LightningEffectiveResistance == 0)
out = calculate(mods.."\n"..floorMod, 0, false)
assert(out.LightningPenetrationFloor == -50 and out.LightningEffectiveResistance == -10)
out = calculate(mods.."\n"..floorMod, -45, false)
assert(out.LightningEffectiveResistance == -50)
out = calculate(mods.."\n"..floorMod, -60, false)
assert(out.LightningEffectiveResistance == -60, "Floor must not raise already lower resistance")
out = calculate(mods.."\n"..floorMod, 40, true)
assert(out.LightningResistanceReduction == 20, "Enabled Exposure must be included: "..tostring(out.LightningResistanceReduction).." res="..tostring(out.LightningEnemyResistance).." input="..tostring(input.conditionEnemyLightningExposure))
assert(out.LightningEnemyResistance == 20 and out.LightningEffectiveResistance == 10)
out = calculate(mods.."\n"..floorMod, 40, false)
assert(out.LightningResistanceReduction == 0 and out.LightningEffectiveResistance == 30)
print("PASS: Lucky chance, penetration totals, Leopold floor at zero/negative resistances, and applied Exposure")
input.enemyIsBoss = "Pinnacle"
out = calculate(mods.."\n"..floorMod, 40, true)
assert(out.LightningResistanceReduction == 10 and out.LightningEffectiveResistance == 20, "Boss exposure effect must remain applied")
-- Attack values must live under the corresponding hand, not the spell output.
newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
local bow = new("Item", "Rarity: RARE\nTest Bow\nShortbow\nAdds 1 to 100 Lightning Damage")
build.itemsTab:AddItem(bow, true)
build.itemsTab.slots["Weapon 1"].selItemId = bow.id
build.configTab.input.customMods = mods.."\n"..floorMod
build.configTab:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
local attack = build.calcsTab.calcs.buildOutput(build, "CALCS").player.output
assert(attack.MainHand and math.abs(attack.MainHand.LightningHitLuckyChance - 28) < 1e-8)
assert(attack.MainHand.LightningResistancePenetration == 10 and attack.MainHand.LightningPenetrationFloor == -50)
print("PASS: boss Exposure scaling and attack hand-specific displayed values")
