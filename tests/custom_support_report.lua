if not build then arg = { }; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/SupportReport")
local shared = LoadModule("Modules/AugmentReport")
local calcs = LoadModule("Modules/Calcs")
local json = require("dkjson")
local function frame()
	build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
end
local function near(a, b, label)
	assert(a and b and math.abs(a - b) <= math.max(0.000001, math.abs(b) * 0.000001), label .. ": " .. tostring(a) .. " / " .. tostring(b))
end
local function find(result, name)
	for _, row in ipairs(result.rows) do if row.name == name then return row end end
end
local function gem(name)
	for _, data in pairs(build.data.gems) do
		if data.name == name then return {gemId=data.id, gemData=data, nameSpec=name, skillId=data.grantedEffectId,
			level=data.naturalMaxLevel, quality=0, enabled=true, count=1, enableGlobal1=true, enableGlobal2=true} end
	end
	error("Missing gem " .. name)
end
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nRapid Attacks II 1/0 1\nElemental Armament II 1/0 1")
build.skillsTab:PasteSocketGroup("Lightning Rod 20/0 3")
local bow = new("Item", "Rarity: Rare\nSupport Fixture\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true); build.itemsTab.slots["Weapon 1"]:SetSelItemId(bow.id)
for _, group in ipairs(build.skillsTab.socketGroupList) do group.includeInFullDPS = true end
build.mainSocketGroup = 2
frame()
local group = build.skillsTab.socketGroupList[1]
build.skillsTab:SetDisplayGroup(group)
local options = {groupIndex=1, target=report.GetTargets(group)[1], considerExisting=true, slotIndex=2}
local names = {["Rapid Attacks II"]=true, ["Efficiency II"]=true, ["Magnified Area II"]=true, ["Elemental Armament II"]=true}
local before = build:SaveDB("fixture")
local original, mainIndex, revision = group.gemList, build.mainSocketGroup, build.outputRevision
local result = report.Calculate(build, options, names)
assert(group.gemList == original and build.mainSocketGroup == mainIndex and build.outputRevision == revision)
assert(build:SaveDB("fixture") == before, "Calculation changed the build or selected skill")
assert(find(result, "Rapid Attacks II") and find(result, "Efficiency II") and find(result, "Magnified Area II"))
assert(not find(result, "Elemental Armament II") and result.excluded == 1, "Retained support family conflict must be excluded")
near(find(result, "Rapid Attacks II").values.FullDPS, result.baseline.FullDPS, "Same support Full DPS")
near(find(result, "Rapid Attacks II").values.Speed, result.baseline.Speed, "Same support rate")

-- Oracle uses the ordinary complete engine after an actual fixture edit, with
-- the original Full DPS selection retained. No report calculator or cache.
local function oracle(name, alone, target)
	local priorList, priorMain, priorActive = group.gemList, build.mainSocketGroup, group.mainActiveSkill
	group.gemList = { }
	for index, value in ipairs(priorList) do
		group.gemList[index] = copyTable(value, true)
		if alone and value.gemData.grantedEffect.support then group.gemList[index].enabled = false end
	end
	if name then group.gemList[alone and #group.gemList+1 or options.slotIndex] = gem(name) end
	local full = calcs.calcFullDPS(build, "CALCULATOR", { })
	build.mainSocketGroup, group.mainActiveSkill = 1, target.skillIndex
	local active = group.gemList[target.gemIndex]
	active.statSet = copyTable(active.statSet or { }); active.statSet[target.effectId] = target.statSetIndex
	local env = calcs.initEnv(build, "CALCULATOR"); calcs.perform(env)
	env.player.output.FullDPS = full.combinedDPS
	local values = report.Snapshot(env.player.output)
	group.gemList, build.mainSocketGroup, group.mainActiveSkill = priorList, priorMain, priorActive
	return values
end
for _, row in ipairs(result.rows) do
	local expected = oracle(row.name, false, options.target)
	for _, key in ipairs({"FullDPS", "CombinedDPS", "AverageDamage", "Speed", "ManaCost", "ManaPerSecondCost", "TotalEHP"}) do
		near(row.values[key], expected[key], row.name .. " " .. key)
	end
end
assert(find(result,"Efficiency II").values.ManaCost < result.baseline.ManaCost, "Efficiency must reduce mana cost")
options.considerExisting = false
local alone = report.Calculate(build, options, names)
local bare = oracle(nil, true, options.target)
near(alone.baseline.FullDPS, bare.FullDPS, "Bare baseline Full DPS")
for _, row in ipairs(alone.rows) do near(row.values.FullDPS, oracle(row.name,true,options.target).FullDPS, "Single support " .. row.name) end
assert(find(alone,"Elemental Armament II"), "Single mode must release retained support conflicts")
print("PASS: real support replacement/single baselines, retained support conflicts, ordinary engine parity, mana costs and no saved-build changes")

options.considerExisting, options.slotIndex = true, #group.gemList+1
local added = report.Calculate(build, options, names)
assert(not find(added,"Rapid Attacks II") and not find(added,"Elemental Armament II"), "Adding must retain both existing support families")
assert(find(added,"Efficiency II"), "Empty slot must support addition")
local targets = report.GetTargets(group)
assert(#targets > 1, "Lightning Arrow component selector missing")
options.target = targets[#targets]
local component = report.Calculate(build, options, {["Efficiency II"]=true})
near(component.baseline.FullDPS, result.baseline.FullDPS, "Changing local component preserves Full DPS")
assert(component.target == targets[#targets].label)
group.enabled = false
assert(not pcall(report.Calculate,build,options,names), "Disabled groups must not calculate")
group.enabled = true
options.slotIndex = 1
assert(not pcall(report.Calculate,build,options,names), "Active gems cannot be replaced")
assert(group.gemList == original and build.mainSocketGroup == mainIndex)
print("PASS: empty-slot addition, component selection independent of Full DPS, disabled groups and invalid slots")

options.target, options.slotIndex = targets[1], 2
build.skillsTab.showSupportGemTypes = "LINEAGE"
local lineage = report.Calculate(build,options,names)
assert(#lineage.rows == 0, "Non-Lineage supports leaked through filter")
build.skillsTab.showSupportGemTypes = "ALL"
build.skillsTab.defaultGemQuality = 20
local quality = report.Calculate(build,options,{["Efficiency II"]=true})
assert(quality.rows[1].gem.quality == 20)
build.skillsTab.defaultGemQuality = 0
assert(report.Conflicts({id="a",gemFamily={"f"}}, {id="b",gemFamily={"f"}}))
assert(report.Conflicts({id="a"}, {id="b",plusVersionOf="a"}))
print("PASS: support-type and quality options, shared support families and versions")

local control = build.skillsTab.controls.supportReport
build.skillsTab.defaultGemQuality = nil
control:Update(); assert(control.key, "A missing default quality must use zero")
build.skillsTab.defaultGemQuality = 0
control:Update(); assert(control.key and control.controls.existing.state)
control.result = result; control:Refresh()
local function stat(key)
	for _, value in ipairs(report.GetStats()) do if value.stat == key then return value end end
end
control.stat = stat("ManaCost"); control:Refresh()
assert(control.list[1].row.name == "Efficiency II", "Lower cost must rank as a gain")
control.controls.filter:SetSel(4); assert(#control.list > 0)
control.controls.filter:SetSel(1)
control.controls.search:SetText("cost"); control:Refresh(); assert(#control.list > 0)
control.controls.search:SetText("")
control.stat = stat("FullDPS"); control:Refresh()
local unchanged
for _, entry in ipairs(control.list) do if entry.row.name=="Rapid Attacks II" then unchanged=entry end end
control:AddValueTooltip(control.tooltip,1,unchanged)
local text = ""
for _, line in ipairs(control.tooltip.lines) do text=text .. (line.text or "") .. "\n" end
assert(text:find("No modelled change",1,true), "Unchanged tooltip must explain its limitation")

local oldLaunch, oldAbort, oldPath = LaunchSubScript, AbortSubScript, GetScriptPath
local launched, aborted = 0, 0
GetScriptPath=function() return "." end
LaunchSubScript=function(script,_,_,root,xml,encoded)
	assert(xml:find("<PathOfBuilding2",1,true) and json.decode(encoded).groupIndex==1)
	launched=launched+1; return launched
end
AbortSubScript=function() aborted=aborted+1 end
control.key=nil; control:Update(); assert(launched==0)
control:Calculate(); assert(launched==1)
local stale=launch.subScripts[1].callback
control.controls.existing.state=false; control:Update(); assert(aborted==1 and not control.result)
stale(json.encode(result)); assert(not control.result,"Stale callback delivered cancelled results")
control:Calculate(); assert(launched==2)
launch:OnSubFinished(2,json.encode(alone)); assert(control.result and #control.list>0)
control.controls.filter:SetSel(2); control:ReSort(1); control.controls.search:SetText("Attacks"); control:Refresh()
assert(launched==2,"Metric/filter/sorting must reuse completed results")
build.skillsTab.defaultGemQuality=20; control:Update(); assert(not control.result and launched==2)
control:Calculate(); assert(launched==3)
launch:OnSubError(3,"fixture failure"); assert(control.failed and not control.worker)
control:Calculate(); assert(launched==4); control.controls.cancel.onClick(); assert(not control.worker and aborted==2)
LaunchSubScript,AbortSubScript,GetScriptPath=oldLaunch,oldAbort,oldPath
print("PASS: cost ordering, unchanged/search filters and tooltips, explicit calculation, cancellation, stale delivery, retry and cache invalidation")

build.skillsTab:PasteSocketGroup("Mirage Archer 20/0 1\nLightning Arrow 20/0 1\nRapid Attacks II 1/0 1")
local cloneGroup=build.skillsTab.socketGroupList[3]
cloneGroup.includeInFullDPS=true
frame()
local cloneTarget
for _,target in ipairs(report.GetTargets(cloneGroup)) do
	if target.effectId==options.target.effectId and target.statSetIndex==1 then cloneTarget=target;break end
end
assert(cloneTarget and cloneTarget.skillIndex>1,"Multi-skill group must expose the socketed attack")
local cloneResult=report.Calculate(build,{groupIndex=3,target=cloneTarget,considerExisting=true,slotIndex=3},{["Rapid Attacks II"]=true})
near(cloneResult.baseline.FullDPS,calcs.calcFullDPS(build,"CALCULATOR",{}).combinedDPS,"Mirage original Count and uptime")
near(cloneResult.rows[1].values.FullDPS,cloneResult.baseline.FullDPS,"Mirage same-support replacement")
assert(cloneGroup.gemList[2].count==1 and build.mainSocketGroup==mainIndex)
print("PASS: multi-skill Mirage target selection and preserved Full DPS Count/uptime")

-- Execute the actual worker bootstrap and XML/JSON transport on the live
-- fixture snapshot, including unsaved skill changes. This is intentionally last
-- because the isolated bootstrap replaces the headless global callbacks.
build.skillsTab.defaultGemQuality=0
options.considerExisting,options.target,options.slotIndex=true,targets[1],2
local snapshot=build:SaveDB("support worker fixture")
local expected=report.Calculate(build,options,names)
local worker=json.decode(assert(loadfile("Modules/AugmentReportWorker.lua"))(".",snapshot,nil,nil,json.encode(names),nil,nil,"support",json.encode(options)))
assert(#worker.rows==#expected.rows)
for _, value in ipairs(expected.rows) do
	local actual=assert(find(worker,value.name))
	for key,amount in pairs(value.values) do near(actual.values[key],amount,value.name .. " worker " .. key) end
end
print("PASS: real worker bootstrap, unsaved open-build snapshot and complete numeric transport parity")
