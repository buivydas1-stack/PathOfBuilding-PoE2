-- Mark application and its triggered buff are independent; clone uptime only averages Full DPS.
arg = {}
dofile("HeadlessWrapper.lua")
newBuild()
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nRapid Attacks II 1/0 1")
build.skillsTab:PasteSocketGroup("Mirage Archer 20/0 1\nLightning Arrow 20/0 1\nRapid Attacks III 1/0 1\nCulling Strike II 1/0 1")
build.skillsTab:PasteSocketGroup("Voltaic Mark 20/20 1\nEternal Mark 1/0 1")
build.skillsTab:PasteSocketGroup("Electrocuting Arrow 5/20 1")
local bow = new("Item", "Rarity: Rare\nMark Test Bow\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true)
build.itemsTab.slots["Weapon 1"].selItemId = bow.id
local arrow, mirage, mark = unpack(build.skillsTab.socketGroupList)
arrow.includeInFullDPS, mirage.includeInFullDPS = true, true
build.mainSocketGroup = 1
build.configTab.input.enemyIsBoss = "Boss"
build.configTab.input.electrocutingArrowApplied = true
local function rebuild()
	build.configTab:BuildModList()
	build.buildFlag = true
	runCallback("OnFrame")
end
rebuild()
local calcs = build.calcsTab.calcs
local function close(actual, expected, message)
	assert(actual and math.abs(actual - expected) <= math.max(1e-7, math.abs(expected) * 1e-7),
		message .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function output(group, mode)
	local env = calcs.initEnv(build, mode or "CALCULATOR")
	for _, skill in ipairs(env.player.activeSkillList) do
		if skill.socketGroup == group and skill.activeEffect.grantedEffect.id == "LightningArrowPlayer" then
			env.player.mainSkill = skill
			calcs.perform(env, true)
			return env.player.output, skill, env
		end
	end
	error("Missing Lightning Arrow")
end
local off, _, offEnv = output(arrow)
local gainOff = offEnv.player.modDB:Sum("BASE", nil, "DamageGainAsLightning")
assert(not offEnv.enemyDB.conditions.Marked, "Enabled Mark must not silently Mark the enemy")
build.configTab.input.voltaicMarkApplied = true
rebuild()
local applied, _, appliedEnv = output(arrow)
close(applied.TotalDPS, off.TotalDPS, "Applying the Mark alone cannot grant damage")
assert(applied.ElectrocuteBuildupAvg > off.ElectrocuteBuildupAvg, "Applied Mark must improve buildup")
assert(appliedEnv.enemyDB.conditions.Marked, "Applied Mark must mark the target")
assert(not appliedEnv.enemyDB.conditions.Cursed, "A Mark must not activate Cursed bonuses")
build.configTab.input.voltaicMarkBuffActive = true
rebuild()
local both, _, bothEnv = output(arrow)
close(bothEnv.player.modDB:Sum("BASE", nil, "DamageGainAsLightning") - gainOff, 30, "Triggered gain as Lightning")
assert(both.TotalDPS > off.TotalDPS, "Triggered buff must improve damage")
build.configTab.input.voltaicMarkApplied = false
rebuild()
local buff = output(arrow)
close(buff.TotalDPS, both.TotalDPS, "Consumed Mark may leave its damage buff")
close(buff.ElectrocuteBuildupAvg, both.ElectrocuteBuildupAvg / (applied.ElectrocuteBuildupAvg / off.ElectrocuteBuildupAvg), "Consumed Mark removes only buildup bonus")
mark.includeInFullDPS = true
close(output(arrow).TotalDPS, buff.TotalDPS, "Include in Full DPS must not control buffs")
mark.includeInFullDPS = false
mark.gemList[1].enabled = false
build.skillsTab:ProcessSocketGroup(mark)
close(output(arrow).TotalDPS, off.TotalDPS, "Disabled Mark gem removes its buff despite checked condition")
mark.gemList[1].enabled = true
build.skillsTab:ProcessSocketGroup(mark)
close(output(arrow, "CALCS").TotalDPS, buff.TotalDPS, "Calcs mode applies the same buff condition")
print("PASS: independent applied/activated Mark states, buildup, damage, gem enable, Full DPS selection and Calcs mode")

build.configTab.input.mirageArcherUptime = 100
rebuild()
local player, clone = output(arrow), output(mirage)
assert(math.abs(player.Speed - clone.Speed) > 1e-5, "Fixture must exercise different nested supports")
local full100 = calcs.calcFullDPS(build, "CALCULATOR")
build.configTab.input.mirageArcherUptime = 90
rebuild()
local full90 = calcs.calcFullDPS(build, "CALCULATOR")
close(full100.combinedDPS - full90.combinedDPS, clone.TotalDPS * 0.1 / 0.95, "90% clone uptime with one shared cull")
close(output(arrow).TotalDPS, player.TotalDPS, "Clone uptime cannot change player damage")
close(output(mirage).Speed, clone.Speed, "Clone uptime cannot change active clone attack rate")
build.configTab.input.mirageArcherUptime = 0
rebuild()
local full0 = calcs.calcFullDPS(build, "CALCULATOR")
close(full0.combinedDPS, player.TotalDPS, "Absent clone cannot supply damage or culling")
build.configTab.input.mirageArcherUptime = 150
rebuild()
close(calcs.calcFullDPS(build, "CALCULATOR").combinedDPS, full100.combinedDPS, "Uptime capped at 100%")
build.configTab.input.mirageArcherUptime = 90
build.configTab.input.voltaicMarkApplied = true
rebuild()
local saved = build:SaveDB("Mark and Mirage configuration")
loadBuildFromXML(saved, "Mark and Mirage round trip")
runCallback("OnFrame")
assert(build.configTab.input.voltaicMarkApplied and build.configTab.input.voltaicMarkBuffActive, "Mark conditions persist independently")
close(build.configTab.input.mirageArcherUptime, 90, "Uptime round trip")
for _, name in ipairs({ "voltaicMarkApplied", "voltaicMarkBuffActive", "mirageArcherUptime" }) do
	assert(build.configTab.varControls[name]:IsShown(), "Relevant configuration control must be visible: " .. name)
end
print("PASS: nested clone supports, 0/90/100% uptime, cull exclusion, player isolation and configuration persistence")
