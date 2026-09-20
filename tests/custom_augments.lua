-- Run alone with Test-CustomPowerReport.ps1 -TestPath tests/custom_augments.lua,
-- or through the system spec. Exercise the real import/editor/calculation pipeline.
if not build then
	arg = {}
	dofile("HeadlessWrapper.lua")
end
newBuild()
local xopec = "Soul Core of Xopec"
local modifier = "25% increased Magnitude of Shock you inflict"
local function raw(base, runes, explicit)
	return "Rarity: Rare\nAugment Test\n"..(base or "Crude Bow")..
		"\n--------\nSockets: S S S\n--------\nItem Level: 80\n--------\n"..
		(runes or "Adds 9 to 15 Cold Damage (rune)\nLeeches 3% of Physical Damage as Life (rune)\n"..modifier.." (rune)")..
		"\n--------\n"..(explicit or "Adds 10 to 20 Lightning Damage")
end
local bow = new("Item", raw())
assert(bow.runes[3] == xopec, "Imported third augment must be Xopec, not None")
assert(bow.runes[1] == "Greater Glacial Rune" and bow.runes[2] == "Lesser Body Rune", "Other augments changed")
bow:BuildModList()
assert(bow.baseModList:Sum("INC", nil, "EnemyShockMagnitude") == 25, "Imported magnitude missing or duplicated")
build.itemsTab:SetDisplayItem(bow)
local dropdown = build.itemsTab.controls.displayItemRune3
assert(dropdown.list[dropdown.selIndex].name == xopec, "Rune #3 dropdown lost imported Xopec")
assert(dropdown.list[dropdown.selIndex].label == modifier)
local roundTrip = new("Item", bow:BuildRaw())
roundTrip:BuildModList()
assert(roundTrip.runes[3] == xopec and roundTrip.baseModList:Sum("INC",nil,"EnemyShockMagnitude") == 25)
dropdown:SetSel(1)
assert(build.itemsTab.displayItem.runes[3] == "None")
local index
for i, rune in ipairs(dropdown.list) do if rune.name == xopec then index = i end end
dropdown:SetSel(assert(index))
assert(build.itemsTab.displayItem.runes[3] == xopec)
assert(build.itemsTab.displayItem.baseModList:Sum("INC",nil,"EnemyShockMagnitude") == 25, "Editor selection must apply magnitude once")
print("PASS: Xopec third-slot import, dropdown selection, editor rebuild and item round-trip")

-- The generic weapon slot supports every martial weapon; caster slots stay separate.
for _, base in ipairs({"Crude Bow", "Makeshift Crossbow", "Wooden Club", "Long Quarterstaff"}) do
	local item = new("Item", raw(base, modifier.." (rune)"))
	assert(item.base, "Unknown fixture base: "..base)
	assert(item.runes[1] == xopec, "Xopec not inferred on "..base)
end
local wand = new("Item", "Rarity: Normal\nWithered Wand")
for _, rune in ipairs(build.itemsTab:GetValidRunesForItem(wand)) do
	assert(rune.name ~= xopec, "Martial Xopec leaked into caster dropdown")
end

-- Socketed Soul Core scaling must use the existing pipeline and must not double-apply.
local scaled = new("Item", raw(nil, "50% increased Magnitude of Shock you inflict (rune)", "100% increased effect of Socketed Soul Cores"))
assert(scaled.runes[1] == xopec)
scaled:BuildModList()
assert(scaled.baseModList:Sum("INC", nil, "EnemyShockMagnitude") == 50)
scaled:UpdateRunes()
scaled:BuildModList()
assert(scaled.baseModList:Sum("INC", nil, "EnemyShockMagnitude") == 50)
print("PASS: martial slot recognition, caster exclusion and existing Soul Core effect scaling")

newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
local equipped = new("Item", raw(nil, modifier.." (rune)"))
build.itemsTab:AddItem(equipped, true)
build.itemsTab.slots["Weapon 1"].selItemId = equipped.id
build.configTab.input.conditionEnemyShocked = true
build.configTab.input.conditionShockEffect = nil
build.configTab:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
local calcs = build.calcsTab
local with = calcs.mainOutput
assert(calcs.mainEnv.player.modDB:Sum("INC", nil, "EnemyShockMagnitude") == 25)
assert(with.CurrentShock == 25, "Automatic Shock should scale from 20 to 25")
local withDPS = with.FullDPS
equipped.runes = {"None"}
equipped:UpdateRunes()
equipped:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
assert(calcs.mainOutput.CurrentShock == 20 and withDPS > calcs.mainOutput.FullDPS, "Xopec must increase automatic Shock and DPS")
equipped.runes = {xopec}
equipped:UpdateRunes()
equipped:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
local passive
for _, node in pairs(build.spec.nodes) do
	if not node.alloc and node.type == "Normal" and #node.sd == 1 and node.sd[1] == "15% increased Magnitude of Shock you inflict" then passive = node; break end
end
assert(passive, "Missing shock-magnitude passive fixture")
local calculator, base = calcs:GetMiscCalculator()
local gained = calculator({addNodes={[passive]=true}},true,{noEnvReuse=true})
assert(gained.CurrentShock == 28 and gained.FullDPS > base.FullDPS, "Shock passive must affect calculated Shock and DPS")
assert(not build.configTab.input.conditionShockEffect, "Test must not use a manual Shock value")
print(string.format("PASS: automatic Shock 20 -> 25 -> 28; Full DPS %.3f -> %.3f with passive",base.FullDPS,gained.FullDPS))

build.spec:AllocNode(passive)
build.buildFlag = true
runCallback("OnFrame")
runCallback("OnFrame") -- Let tree-dependent skill state settle before the comparison.
calculator, base = calcs:GetMiscCalculator()
local lost = calculator({removeNodes={[passive]=true}},true,{noEnvReuse=true})
assert(lost.CurrentShock < base.CurrentShock and lost.FullDPS < base.FullDPS, string.format("Removing Shock passive %s (%s): Shock %s -> %s, DPS %s -> %s",passive.dn,passive.id,tostring(base.CurrentShock),tostring(lost.CurrentShock),tostring(base.FullDPS),tostring(lost.FullDPS)))
local saved = build:SaveDB("Xopec augment round-trip")
loadBuildFromXML(saved, "Xopec round-trip")
assert(build.itemsTab.items[equipped.id].runes[1] == xopec)
assert(not build.configTab.input.conditionShockEffect)
calcs = build.calcsTab
print("PASS: allocated Shock passive removal and saved-build Xopec persistence")

-- A user-supplied stronger manual shock remains authoritative.
build.configTab.input.conditionShockEffect = 60
build.configTab:BuildModList()
build.buildFlag = true
runCallback("OnFrame")
assert(calcs.mainOutput.CurrentShock == 60)
print("PASS: manual Shock override retained")
