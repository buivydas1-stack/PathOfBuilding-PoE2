-- Exercise Barrier coupling, component selection, culling and real gem hover UI.
arg = {}
dofile("HeadlessWrapper.lua")
newBuild()
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nRapid Attacks II 1/0 1")
build.skillsTab:PasteSocketGroup("Voltaic Barrier 18/20 1\nCulling Strike II 1/0 1\nConcentrated Area 1/0 1")
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nRapid Attacks III 1/0 1")
local bow = new("Item", "Rarity: Rare\nBarrier Test Bow\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true)
build.itemsTab.slots["Weapon 1"].selItemId = bow.id
local arrow, barrier = build.skillsTab.socketGroupList[1], build.skillsTab.socketGroupList[2]
arrow.includeInFullDPS, barrier.includeInFullDPS = true, true
build.mainSocketGroup = 1
build.configTab.input.enemyIsBoss = "Boss"
build.configTab:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
local calcs = build.calcsTab.calcs
local function close(actual, expected, message)
	assert(actual and math.abs(actual - expected) <= math.max(1e-7, math.abs(expected) * 1e-7),
		message .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function skillOutput(id, mode, override)
	local env = calcs.initEnv(build, mode or "CALCULATOR", override)
	for _, skill in ipairs(env.player.activeSkillList) do
		if skill.activeEffect.grantedEffect.id == id and (id ~= "LightningArrowPlayer" or skill.socketGroup == arrow) then
			env.player.mainSkill = skill
			calcs.perform(env, true)
			return env.player.output, skill, env
		end
	end
	error("Missing test skill " .. id)
end
local function fullDPS(selection)
	barrier.voltaicBarrierDps = selection
	local result = calcs.calcFullDPS(build, "CALCULATOR")
	local parts = {}
	for _, part in ipairs(result.skills) do parts[part.name] = part.dps * part.count end
	return result, parts
end
local beamId, wallId = "VoltaicBarrierTriggeredChainLightningPlayer", "VoltaicBarrierPlayer"
local source = skillOutput("LightningArrowPlayer")
local beam, beamSkill = skillOutput(beamId)
local wall = skillOutput(wallId)
close(beam.SkillTriggerRate, source.Speed * source.AccuracyHitChance / 100, "Beam source rate")
close(beam.TotalDPS, beam.AverageDamage * beam.SkillTriggerRate, "Beam DPS")
close(wall.HitSpeed, 4, "Wall hit interval")
close(wall.TotalDPS, wall.AverageDamage * 4, "Wall DPS")
close(beam.CullPercent, 5, "Standard Boss cull threshold")
assert(bit.band(beamSkill.skillCfg.flags, ModFlag.Area) == 0, "Target search radius is not area damage")
local both, bothParts = fullDPS("Both")
local wallOnly, wallParts = fullDPS("Wall")
local beamOnly, beamParts = fullDPS("Beam")
assert(bothParts["Voltaic Barrier Beam"] and bothParts["Voltaic Barrier"], "Both components must be named")
assert(not wallParts["Voltaic Barrier Beam"] and not beamParts["Voltaic Barrier"], "Component filtering")
close(both.combinedDPS - wallOnly.combinedDPS, beam.TotalDPS / 0.95, "Beam contribution with one global cull")
close(both.combinedDPS - beamOnly.combinedDPS, wall.TotalDPS / 0.95, "Wall contribution with one global cull")
close(both.cullingDPS, (both.combinedDPS - both.cullingDPS) / 19, "Cull applies once")
print("PASS: wall interval, selected source rate, named components and Standard Boss cull")

arrow.gemList[2].enabled = false
local slowerSource = skillOutput("LightningArrowPlayer")
local slowerBeam = skillOutput(beamId)
close(slowerBeam.SkillTriggerRate, slowerSource.Speed * slowerSource.AccuracyHitChance / 100, "Source support speed changes beam rate")
assert(slowerBeam.TotalDPS < beam.TotalDPS, "Faster alternative group must not override selected source")
close(slowerBeam.AverageDamage, beam.AverageDamage, "Source supports cannot change beam hit damage")
close(skillOutput(wallId).TotalDPS, wall.TotalDPS, "Source speed cannot change wall tick DPS")
arrow.gemList[2].enabled = true
barrier.gemList[3].enabled = false
close(skillOutput(beamId).TotalDPS, beam.TotalDPS, "Concentrated Area cannot support direct beam damage")
assert(skillOutput(wallId).TotalDPS < wall.TotalDPS, "Concentrated Area must affect wall damage")
close(skillOutput("LightningArrowPlayer").TotalDPS, source.TotalDPS, "Barrier support changes cannot change Lightning Arrow")
barrier.gemList[3].enabled = true
arrow.includeInFullDPS = false
close(skillOutput(beamId).SkillTriggerRate, beam.SkillTriggerRate, "Source need not contribute to Full DPS")
arrow.includeInFullDPS = true
build.calcsTab.input.skill_number = 2
close(skillOutput(beamId, "CALCS").SkillTriggerRate, beam.SkillTriggerRate, "Calcs tab must retain Build source selection")
print("PASS: source and Barrier supports stay separate; Calcs tab and Full DPS use Build selection")

barrier.gemList[2].enabled = false
assert(not fullDPS("Both").cullingDPS, "Disabled Culling Strike must not contribute cull")
barrier.gemList[2].enabled = true
for _, case in ipairs({ { "None", true, 10 }, { "None", false, 0 }, { "Boss", false, 5 } }) do
	build.configTab.input.enemyIsBoss = case[1]
	build.configTab.input.conditionEnemyRareOrUnique = case[2]
	build.configTab:BuildModList()
	close(skillOutput(beamId).CullPercent or 0, case[3], "Enemy rarity cull")
end
arrow.enabled = false
close(skillOutput(beamId).SkillTriggerRate, 0, "Disabled source cannot trigger beams")
assert(not fullDPS("Beam").cullingDPS, "Inactive beam must not provide phantom cull")
arrow.enabled = true
build.mainSocketGroup = 2
local unsupportedBeam = skillOutput(beamId)
close(unsupportedBeam.SkillTriggerRate, 0, "Wall cannot trigger beams")
close(unsupportedBeam.TotalDPS or 0, 0, "No generic weapon speed fallback")
barrier.mainActiveSkill = 2
close(skillOutput(beamId).SkillTriggerRate, 0, "Selecting beam cannot recurse")
barrier.mainActiveSkill, build.mainSocketGroup = 1, 1
print("PASS: base cull by rarity; disabled or ineligible source has no beam DPS or cull")

build.skillsTab:SetDisplayGroup(barrier)
local control = build.skillsTab.controls.voltaicBarrierDps
assert(control:IsShown(), "Barrier selector must be shown on Barrier group")
build.skillsTab:ResetUndo()
control.selFunc(2, control.list[2])
assert(barrier.voltaicBarrierDps == "Wall", "Barrier selector callback")
build.skillsTab:Undo()
barrier = build.skillsTab.socketGroupList[2]
assert(barrier.voltaicBarrierDps == "Beam", "Selection undo")
build.skillsTab:Redo()
barrier = build.skillsTab.socketGroupList[2]
assert(barrier.voltaicBarrierDps == "Wall", "Selection redo")
local xml = { attrib = {} }
build.skillsTab:Save(xml)
local skillNode
for _, node in ipairs(xml) do
	if node.elem == "SkillSet" then skillNode = node[2] end
end
assert(skillNode and skillNode.attrib.voltaicBarrierDps == "Wall", "Selection XML save")
local restoredTab = new("SkillsTab", build)
restoredTab:Load(xml)
assert(restoredTab.socketGroupList[2].voltaicBarrierDps == "Wall", "Selection XML load")
skillNode.attrib.voltaicBarrierDps = nil
restoredTab:Load(xml)
assert((restoredTab.socketGroupList[2].voltaicBarrierDps or "Both") == "Both", "Old builds default to both")
build.skillsTab:SetDisplayGroup(build.skillsTab.socketGroupList[1])
assert(not control:IsShown(), "Barrier selector must be hidden on Lightning Arrow")
print("PASS: component selector visibility, undo/redo, XML round-trip and old-build default")

barrier.voltaicBarrierDps = "Both"
build.buildFlag = true
runCallback("OnFrame")
local speedSelector = build.skillsTab.gemSlots[2].nameSpec
local fasterGem = build.data.gems[build.data.gemForSkill[build.data.skills.SupportRapidAttacksPlayerThree]]
local calculator, baseline = build.calcsTab:GetMiscCalculator()
local faster = speedSelector:CalcOutputWithThisGem(calculator, fasterGem, true)
local expectedChange = (faster.TotalDPS - baseline.TotalDPS + beam.AverageDamage * (faster.Speed - baseline.Speed) * baseline.AccuracyHitChance / 100) / 0.95
close(faster.FullDPS - baseline.FullDPS, expectedChange, "Full DPS comparison must recalculate beam dependency")
print("PASS: support comparison recalculates source attack speed and dependent beam DPS")
local selector = build.skillsTab.gemSlots[3].nameSpec
local gem
for _, data in pairs(selector.gems) do
	if data.name == "Elemental Armament II" then gem = data break end
end
assert(gem, "Missing test support gem")
selector.list = { "Default:" .. gem.id }
selector.sortCache = { dpsColor = {}, canSupport = {} }
selector.dropped = true
selector.IsMouseOver = function() return true, "DROP" end
local x, y = selector:GetPos()
GetCursorPos = function() return x + 5, y + selector.height + 5 end
for _, sort in ipairs({ "CombinedDPS", "FullDPS" }) do
	build.skillsTab.sortGemsByDPSField = sort
	selector.tooltip:Clear()
	selector:Draw({ x = 0, y = 0, width = 1920, height = 1080 })
	local foundFullDPS = false
	for _, line in ipairs(selector.tooltip.lines) do
		if line.text and line.text:find("Full DPS", 1, true) then foundFullDPS = true end
	end
	assert(foundFullDPS, "Support hover must include Full DPS when sorted by " .. sort)
	assert(#build.skillsTab.displayGroup.gemList == 2, "Hover must restore original gems")
end
print("PASS: real support hover includes Full DPS under Combined DPS and Full DPS sorting")
