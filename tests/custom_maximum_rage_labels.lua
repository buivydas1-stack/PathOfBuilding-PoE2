arg = {}
dofile("HeadlessWrapper.lua")
newBuild()
build.characterLevel = 90
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab:PasteSocketGroup("Eternal Rage 20/20 1")
local bow = new("Item", "Rarity: Rare\nRage Test Bow\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true)
build.itemsTab.slots["Weapon 1"].selItemId = bow.id
build.mainSocketGroup = 1
build.skillsTab.socketGroupList[1].includeInFullDPS = true
local function frame()
	build.configTab:BuildModList(); build.buildFlag = true; runCallback("OnFrame")
	return build.calcsTab.mainOutput
end
local function close(a, b, message)
	assert(a and b and math.abs(a-b) < math.max(1, math.abs(b))*1e-7, message .. ": " .. tostring(a) .. " / " .. tostring(b))
end
build.configTab.input.multiplierRage = 7
local manual = frame()
close(manual.Rage, 7, "Existing manual Rage")
build.configTab.input.assumeMaximumRage = true
local maximum = frame()
close(maximum.Rage, maximum.MaximumRage, "Maximum overrides manual input")
build.configTab.input.multiplierRage = nil
local blank = frame()
close(blank.TotalDPS, maximum.TotalDPS, "Blank manual input must retain maximum Rage")
assert(build.configTab.varControls.assumeMaximumRage:IsShown(), "Maximum option visible with Rage source")
local battleTrance
for _, node in pairs(build.spec.nodes) do if node.dn == "Battle Trance" then battleTrance = node; break end end
assert(battleTrance, "Battle Trance fixture missing")
local calculator, base = build.calcsTab:GetMiscCalculator()
local added = calculator({addNodes={[battleTrance]=true}}, true, {noEnvReuse=true})
assert(added.MaximumRage > base.MaximumRage, "Battle Trance must change maximum in this fixture")
close(added.Rage, added.MaximumRage, "Addition preview follows changed maximum")
assert(added.TotalDPS > base.TotalDPS, "Addition preview includes maximum Rage damage")
local calcs = build.calcsTab.calcs
local fullAdded = calcs.calcFullDPS(build, "CALCULATOR", {addNodes={[battleTrance]=true}})
assert(fullAdded.combinedDPS > calcs.calcFullDPS(build, "CALCULATOR").combinedDPS, "Full DPS preview follows maximum")
build.spec:AllocNode(battleTrance)
local allocated = frame()
close(allocated.Rage, allocated.MaximumRage, "Allocation including travel follows its calculated maximum")
local removal = build.calcsTab:GetMiscCalculator()
local removed = removal({removeNodes={[battleTrance]=true}}, true, {noEnvReuse=true})
close(removed.Rage, removed.MaximumRage, "Removal preview follows maximum")
assert(removed.Rage < allocated.Rage, "Removal must reduce assumed Rage")
build.configTab.input.assumeMaximumRage = false
build.configTab.input.multiplierRage = 7
close(frame().Rage, 7, "Unchecked option restores manual input")
build.configTab.input.multiplierRage = nil
close(frame().Rage, 0, "Unchecked blank input retains existing zero Rage behavior")
build.configTab.input.assumeMaximumRage = true
frame()
print("PASS: blank/manual Rage, Battle Trance addition/removal, Full DPS previews and unchecked behavior")

build.skillsTab:PasteSocketGroup("Berserk 20/20 DISABLED 1\nRapid Attacks II 1/0 1")
local disabled = build.skillsTab.socketGroupList[3]
disabled.enabled = false
frame()
assert(disabled.displayLabel == "Berserk", "Disabled Berserk must retain its name")
local row = build.skillsTab.controls.groupList:GetRowValue(1, 3, disabled)
assert(row:find("Berserk",1,true) and row:find("(Disabled)",1,true), "Actual list row retains name and Disabled suffix")
build.skillsTab:PasteSocketGroup("Mirage Archer 20/0 DISABLED 1\nLightning Arrow 20/0 DISABLED 1")
local multi = build.skillsTab.socketGroupList[4]
multi.enabled = false
frame()
assert(multi.displayLabel == "Mirage Archer, Lightning Arrow", "Disabled group must list all active gem names")
multi.label = "My inactive group"
frame()
assert(multi.displayLabel == multi.label, "Explicit group labels retain precedence")
multi.label = ""
multi.enabled = true
multi.gemList[1].enabled = true
frame()
assert(multi.displayLabel == "Mirage Archer", "Enabled group retains enabled-gem naming")
build.skillsTab:PasteSocketGroup("Rapid Attacks II 1/0 1")
local supportOnly = build.skillsTab.socketGroupList[5]
frame()
assert(supportOnly.displayLabel == "<No active skills>", "Support-only group keeps its placeholder")
local saved = build:SaveDB("Maximum Rage and disabled labels")
loadBuildFromXML(saved, "Maximum Rage round trip"); runCallback("OnFrame")
assert(build.configTab.input.assumeMaximumRage and not build.configTab.input.multiplierRage, "Maximum option and blank input persist")
close(build.calcsTab.mainOutput.Rage, build.calcsTab.mainOutput.MaximumRage, "Reloaded maximum Rage")
assert(build.skillsTab.socketGroupList[3].displayLabel == "Berserk" and not build.skillsTab.socketGroupList[3].enabled, "Named disabled group persists without activation")
print("PASS: disabled Berserk/multiple gems, explicit labels, enabled naming, support-only placeholder and round trip")
newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.configTab.input.assumeMaximumRage = true
local noSource = frame()
assert((noSource.Rage or 0) == 0, "Maximum assumption must not grant a Rage source")
print("PASS: maximum assumption does not create Rage generation")
