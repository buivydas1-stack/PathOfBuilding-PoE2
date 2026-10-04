-- Synthetic items exercise imports, manual conditions and complete calculations.
if not build then arg = {}; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/AugmentReport")
local function make(base, idol, extra)
	local item = new("Item", "Rarity: Rare\nCombat Idol Fixture\n" .. base .. "\n--------\nSockets: S S\n--------\nItem Level: 80\n--------\n" .. (extra or "+100 to maximum Life"))
	item.runes = idol and {idol} or {}; item:UpdateRunes(); item:BuildAndParseRaw(); item:BuildModList()
	return item
end
local function equip(item, slot)
	build.itemsTab:AddItem(item, true); build.itemsTab.slots[slot]:SetSelItemId(item.id)
end
local function frame()
	build.configTab:BuildModList(); build.buildFlag = true
	runCallback("OnFrame"); runCallback("OnFrame")
end
local function close(a, b, message) assert(math.abs(a - b) < 0.00001, message .. ": " .. a .. " vs " .. b) end
local function checkRecommendation(base, slot, idol, stat, extra)
	local empty = make(base, nil, extra)
	local result = report.Calculate(build, empty:BuildRaw(), slot, {[idol] = true})
	assert(#result.rows == 1, "Missing " .. idol)
	local direct = build.calcsTab:GetMiscCalculator()({repSlotName = slot, repItem = make(base, idol, extra)}, true, {noEnvReuse = true})
	close(result.rows[1].values[stat], direct[stat], idol .. " recommendation parity")
	return result
end
local cunningHelmet = make("Rusted Greathelm", "Carved Cunning")
local chestExtra = "+1000 to Armour\nGain Deflection Rating equal to 100% of Armour"
local cunningChest = make("Rusted Cuirass", "Carved Cunning", chestExtra)
local mischief = make("Stocky Mitts", "Carved Mischief")
for _, item in ipairs({cunningHelmet, cunningChest, mischief}) do
	for _, line in ipairs(item.runeModLines) do assert(not line.extra and #line.modList > 0, line.line) end
	build.itemsTab:SetDisplayItem(item)
	assert(build.itemsTab.controls.displayItemRune1.list[build.itemsTab.controls.displayItemRune1.selIndex].name == item.runes[1])
	assert(new("Item", item:BuildRaw()).runes[1] == item.runes[1])
end
-- Game copies wrap this single modifier; preserve inference and later explicit lines.
local copied = new("Item", "Rarity: Rare\nWrapped Cunning\nRusted Cuirass\n--------\nSockets: S\n--------\nPrevent +5% of Damage from Deflected Hits if you've (rune)\nDeflected no Hits Recently (rune)\nBonded: 8% increased Deflection Rating (rune)\n--------\n+123 to maximum Life")
assert(copied.runes[1] == "Carved Cunning", "Wrapped game copy must infer Cunning")
assert(#copied.runeModLines == 2 and #copied.explicitModLines == 1, "Wrapped line must remain a single effect")
for _, line in ipairs(copied.runeModLines) do assert(not line.extra and #line.modList > 0, line.line) end
assert(new("Item", copied:BuildRaw()).runes[1] == "Carved Cunning", "Wrapped copy round trip")
-- Previously saved editor items counted the two wrapped fragments separately.
local oldRaw = cunningChest:BuildRaw():gsub("Implicits: 2", "Implicits: 3"):gsub("if you've Deflected no Hits Recently", "if you've\nDeflected no Hits Recently {rune}")
local legacy = new("Item", oldRaw)
assert(#legacy.explicitModLines == #cunningChest.explicitModLines, "Legacy wrapped item must preserve explicit classification")
print("PASS: all three effects parse, survive editor/import, and wrapped Cunning preserves explicit modifiers")

build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
equip(make("Crude Bow", nil, "Adds 100 to 200 Physical Damage"), "Weapon 1")
equip(cunningHelmet, "Helmet")
build.configTab.input.enemyEvasion = 10000
frame()
local normal = build.calcsTab.mainOutput
assert(normal.AccuracyHitChance < 100, "Fixture must be evadable")
local normalDPS = normal.FullDPS
checkRecommendation("Rusted Greathelm", "Helmet", "Carved Cunning", "FullDPS")
build.configTab.input.conditionEnemyFullLife = true; frame()
assert(build.calcsTab.mainOutput.AccuracyHitChance == 100)
assert(build.calcsTab.mainOutput.FullDPS > normalDPS)
checkRecommendation("Rusted Greathelm", "Helmet", "Carved Cunning", "FullDPS")
build.configTab.input.conditionEnemyFullLife = false; frame()
close(build.calcsTab.mainOutput.FullDPS, normalDPS, "Full Life condition reverses")
print("PASS: Cunning helmet guarantees hits only under enemy Full Life; recommendation matches complete DPS")

equip(make("Rusted Greathelm"), "Helmet")
equip(cunningChest, "Body Armour"); frame()
local boosted = build.calcsTab.mainOutput.DeflectEffect
assert(build.configTab.varControls.conditionDeflectedRecently, "Manual deflection control exists")
assert(build.calcsTab.mainOutput.DeflectChance > 0, "Deflection fixture must have actual deflection chance")
local chestResult = checkRecommendation("Rusted Cuirass", "Body Armour", "Carved Cunning", "TotalEHP", chestExtra)
assert(chestResult.rows[1].values.TotalEHP > chestResult.baseline.TotalEHP, "Active deflection bonus improves EHP")
build.configTab.input.conditionDeflectedRecently = true; frame()
close(build.calcsTab.mainOutput.DeflectEffect, boosted - 5, "Recent deflection disables bonus")
chestResult = checkRecommendation("Rusted Cuirass", "Body Armour", "Carved Cunning", "TotalEHP", chestExtra)
close(chestResult.rows[1].values.TotalEHP, chestResult.baseline.TotalEHP, "Inactive deflection contributes no EHP")
build.configTab.input.conditionDeflectedRecently = false; frame()
close(build.calcsTab.mainOutput.DeflectEffect, boosted, "No recent deflection restores bonus")
print("PASS: Cunning chest adds five percentage points only without recent deflection; recommendation parity")

equip(make("Rusted Cuirass"), "Body Armour")
equip(mischief, "Gloves")
equip(make("Wooden Club", nil, "Adds 100 to 200 Physical Damage"), "Weapon 1")
equip(make("Splintered Tower Shield", nil, "1000% increased Block chance"), "Weapon 2")
frame()
local ordinaryCap = build.calcsTab.mainOutput.BlockChanceMax
close(build.calcsTab.mainOutput.BlockChance, ordinaryCap, "Block fixture is capped")
build.configTab.input.conditionBlockedRecently = true; frame()
close(build.calcsTab.mainOutput.BlockChanceMax, ordinaryCap, "Ordinary block does not activate raised-shield effect")
build.configTab.input.conditionActiveBlockedRecently = true; frame()
close(build.calcsTab.mainOutput.BlockChanceMax, ordinaryCap + 5, "Raised shield raises cap")
close(build.calcsTab.mainOutput.BlockChance, ordinaryCap + 5, "Extra cap affects actual block")
checkRecommendation("Stocky Mitts", "Gloves", "Carved Mischief", "TotalEHP")
build.configTab.input.conditionActiveBlockedRecently = false; frame()
close(build.calcsTab.mainOutput.BlockChanceMax, ordinaryCap, "Raised-shield condition reverses")
checkRecommendation("Stocky Mitts", "Gloves", "Carved Mischief", "TotalEHP")
print("PASS: Mischief raised-shield condition adds five block-cap points, ordinary blocking does not; recommendation parity")
