-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_megalomaniac_maim.lua.
arg = {}; dofile("HeadlessWrapper.lua")
local detailed = [[Item Class: Jewels
Rarity: Unique
Megalomaniac
Diamond
--------
Limited to: 1
--------
Item Level: 81
--------
{ Enhancement }
Allocates Saqawal's Guidance() — Unscalable Value
{ Enhancement }
Allocates Pure Power() — Unscalable Value
--------
If you're going to act like you're better
than everyone else, make sure you are.
--------
Place into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.
--------
Corrupted]]
local market = [[Item Class: Jewels
Rarity: Unique
Megalomaniac
Diamond
--------
Limited to: 1
--------
Item Level: 80
--------
Allocates Pure Power (enchant)
Allocates Shifted Strikes (enchant)
--------
If you're going to act like you're better
than everyone else, make sure you are.
--------
Place into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.
--------
Corrupted
--------
Note: ~b/o 4 divine]]
newBuild()
local advanced, trade = new("Item", detailed), new("Item", market)
local plain = new("Item", detailed:gsub("{ Enhancement }\n", ""):gsub("%(%) — Unscalable Value", " (enchant)"))
local function grants(item, expected)
	assert(#item.enchantModLines == 2, "Enchant count " .. #item.enchantModLines .. " / " .. item:BuildRaw())
	for i, line in ipairs(item.enchantModLines) do
		assert(not line.line:find("()", 1, true), "Empty parentheses retained")
		assert(line.modList[1].name == "GrantedPassive" and line.modList[1].value == expected[i]:lower(), tostring(line.modList[1].value) .. " vs " .. expected[i])
		assert(#build.spec:ResolveGrantedPassiveNodes(line.modList[1].value) > 0, "Allocation unresolved")
	end
end
grants(advanced, {"Saqawal's Guidance", "Pure Power"})
grants(trade, {"Pure Power", "Shifted Strikes"})
grants(plain, {"Saqawal's Guidance", "Pure Power"})
grants(new("Item", advanced:BuildRaw()), {"Saqawal's Guidance", "Pure Power"})

build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
local bow = new("Item", "Rarity: Rare\nTest Bow\nCrude Bow\nAdds 20 to 100 Lightning Damage\n+1000 to Accuracy Rating")
build.itemsTab:AddItem(bow, true); build.itemsTab.slots["Weapon 1"].selItemId = bow.id
build.mainSocketGroup = 1
build.skillsTab.socketGroupList[1].includeInFullDPS = true
build.configTab.input.customMods = "+200 to Intelligence"
local function frame()
	build.configTab:BuildModList(); build.buildFlag = true; runCallback("OnFrame")
	return build.calcsTab.mainOutput
end
frame()
local socket
for _, node in pairs(build.spec.nodes) do
	if node.type == "Socket" and node.path and not node.ascendancyName and not node.charmSocket and not node.sinister then socket = node; break end
end
assert(socket); build.spec:AllocNode(socket); build.itemsTab:UpdateSockets(); frame()
local baseline = build.calcsTab.mainOutput.FullDPS
local function equip(item)
	build.itemsTab:AddItem(item, true)
	build.itemsTab.sockets[socket.id]:SetSelItemId(item.id)
	return frame().FullDPS
end
local detailedDPS = equip(advanced)
assert(detailedDPS > baseline, "Resolved Pure Power should improve fixture DPS")
assert(math.abs(equip(plain) - detailedDPS) < 1e-7, "Clipboard formats produce different DPS")
assert(equip(trade) > baseline, "Market allocations failed")
print("PASS: both exact clipboard formats, resolved grants, clean names, round trip and equipped DPS parity")

newBuild()
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.itemsTab:AddItem(bow, true); build.itemsTab.slots["Weapon 1"].selItemId = bow.id
build.mainSocketGroup = 1
assert(frame().MaimChance == 0)
build.spec:AllocNode(build.spec.nodes[41580])
assert(frame().MaimChance == 25, "Maiming Strike not counted")
local sectionData = LoadModule("Modules/CalcSections")
local maimRow
for _, section in ipairs(sectionData) do
	for _, sub in ipairs(section[5]) do for _, row in ipairs(sub.data) do if row.label == "Maim Chance" then maimRow = row end end end
end
assert(maimRow)
local breakdown = build.calcsTab.controls.breakdown
breakdown:SetBreakdownData(maimRow[1])
local foundSource = false
for _, section in ipairs(breakdown.sectionList) do
	for _, row in ipairs(section.rowList or {}) do
		if row.mod and row.mod.name == "MaimChance" and row.mod.source:match("Tree:41580") then foundSource = true end
	end
end
assert(foundSource, "Hover breakdown omits Maiming Strike source")
build.configTab.input.customMods = "10% chance to Maim on Hit"
assert(frame().MaimChance == 35, "Multiple sources do not add")
build.configTab.input.customMods = "100% chance to Maim on Hit"
assert(frame().MaimChance == 100, "Chance not capped")
build.configTab.input.customMods = "100% chance to Maim on Hit\nCannot inflict Maim"
assert(frame().MaimChance == 0, "Cannot Maim not respected")
build.configTab.input.customMods = "Maim on Critical Hit"
local output = frame()
assert(math.abs(output.MaimChance - (25 + 75 * output.CritChance / 100)) < 1e-7, "Critical sources not weighted")
build.configTab.input.customMods = nil
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1\nMaim 1/0 1")
build.mainSocketGroup = 2
assert(frame().MaimChance == 100, "Maim support not counted")
build.skillsTab:PasteSocketGroup("Spark 20/0 1")
build.mainSocketGroup = 3
assert(frame().MaimChance == 0, "Attack-only source leaked to spell")
assert(not build.configTab.input.conditionEnemyMaimed, "Chance must not enable enemy-Maimed assumption")
print("PASS: no source, passive/source hover, addition, cap, prohibition, critical weighting, support and spell isolation")
