-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_augment_conditions.lua
if not build then arg = { }; dofile("HeadlessWrapper.lua") end
newBuild()
local report = LoadModule("Modules/AugmentReport")
local calcs = LoadModule("Modules/Calcs")
local function equip(raw, slot)
	local item = new("Item", raw)
	build.itemsTab:AddItem(item, true); build.itemsTab.slots[slot]:SetSelItemId(item.id)
	return item
end
local function frame()
	build.configTab:BuildModList(); build.buildFlag = true
	runCallback("OnFrame"); runCallback("OnFrame")
end
local function find(result, name)
	for _, row in ipairs(result.rows) do if row.name == name then return row end end
end
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
build.skillsTab:PasteSocketGroup("Voltaic Mark 20/0 1")
local mark = build.skillsTab.socketGroupList[2]
build.configTab.input.voltaicMarkApplied = true
equip("Rarity: Rare\nCondition Bow\nCrude Bow\n--------\nAdds 100 to 200 Physical Damage", "Weapon 1")
local helmet = equip("Rarity: Rare\nCondition Helmet\nRusted Greathelm\n--------\nSockets: S S\n--------\n+100 to maximum Life", "Helmet")
frame()
local names = { ["Idol of Egrin"] = true, ["Perfect Body Rune"] = true }
local function calculate() return report.Calculate(build, helmet:BuildRaw(), "Helmet", names) end
local result = calculate()
local idol = find(result, "Idol of Egrin")
assert(build.calcsTab.mainEnv.enemy.modDB:GetCondition("Marked"), "Mark fixture must actually be active")
assert(not build.calcsTab.mainEnv.enemy.modDB:GetCondition("Cursed"), "A PoE2 mark must not make the enemy cursed")
assert(build.calcsTab.mainEnv.player.modDB:GetMultiplier("CurseOnEnemy") == 0)
assert(idol.inactive and #idol.inactiveEffects == 1)
assert(idol.values.FullDPS == result.baseline.FullDPS, "Mark-only Egrin must contribute zero DPS")
assert(not find(result, "Perfect Body Rune").inactive, "Inactive Bonded effects must not hide ordinary Life")
print("PASS: active mark is separate from curses; mark-only Egrin is inactive; mixed ordinary/Bonded rune remains visible")

build.skillsTab:PasteSocketGroup("Enfeeble 20/0 1")
local curse = build.skillsTab.socketGroupList[3]
frame(); local cursed = calculate()
assert(build.calcsTab.mainEnv.enemy.modDB:GetCondition("Cursed"), "A real enabled curse must activate automatically")
assert(build.calcsTab.mainEnv.enemy.modDB:GetCondition("Marked"), "Curse and mark may coexist")
assert(build.calcsTab.mainEnv.player.modDB:GetMultiplier("CurseOnEnemy") == 1)
assert(not build.configTab.input.conditionEnemyCursed, "Automatic curse test must not rely on Configuration")
assert(not find(cursed, "Idol of Egrin").inactive and find(cursed, "Idol of Egrin").values.FullDPS > cursed.baseline.FullDPS)
curse.enabled = false; mark.enabled = false; frame()
build.configTab.input.conditionEnemyCursed = true; frame()
local forced = calculate()
assert(not find(forced, "Idol of Egrin").inactive and find(forced, "Idol of Egrin").values.FullDPS > forced.baseline.FullDPS, "Explicit Configuration assumptions must remain respected")
build.configTab.input.conditionEnemyCursed = false; frame()
local inactive = calculate()
assert(find(inactive, "Idol of Egrin").inactive)
print("PASS: real curse activates without a checkbox; explicit Configuration is respected; disabled curse is inactive")

-- Generic player and enemy condition tags, including negation and OR lists,
-- use the real ModStore evaluator rather than a separate activation rule table.
local env = calcs.initEnv(build, "CALCULATOR"); calcs.perform(env)
local function effect(text)
	local mods, extra = modLib.parseMod(text)
	assert(mods and not extra, "Fixture must be parsed: " .. text)
	return { runeModLines = { {line = text, modList = mods} } }
end
local conditional = effect("20% increased Damage if you've Killed Recently")
assert(report.InactiveEffects(conditional, env))
env.player.modDB.conditions.KilledRecently = true
assert(not report.InactiveEffects(conditional, env))
local shock = effect("Adds 1 to 60 Lightning Damage against Shocked Enemies")
assert(report.InactiveEffects(shock, env))
env.enemy.modDB.conditions.Shocked = true
assert(not report.InactiveEffects(shock, env))
local tags = { runeModLines = { {line = "Negated OR condition", modList = {
	{name = "Damage", type = "INC", value = 10, {type = "Condition", varList = {"TestA", "TestB"}, neg = true}}
}} } }
env.player.modDB.conditions.TestA = true
assert(report.InactiveEffects(tags, env))
env.player.modDB.conditions.TestA = false
assert(not report.InactiveEffects(tags, env))
assert(not report.InactiveEffects({runeModLines = {{line = "Unknown mechanic", modList = {}, extra = "Unknown"}}}, env), "Unknown mechanics must not be presumed inactive")
print("PASS: generic player/enemy conditions, negation, OR lists and unknown-effect preservation")

local control = build.itemsTab.controls.augmentReport
build.itemsTab:SetDisplayItem(helmet); control:Update()
for _, stat in ipairs(control.controls.stat.list) do if stat.stat == "FullDPS" then control.stat = stat end end
local oldReveal, reveal = main.IsComparisonRevealHeld, false
main.IsComparisonRevealHeld = function() return reveal end
control.result = inactive; control:Update(); control:Refresh()
assert(#control.list == 1 and control.list[1].row.name == "Perfect Body Rune")
assert(control.label:find("1 inactive (ALT)", 1, true))
local generation = control.generation
reveal = true; control:Update()
assert(#control.list == 2 and control.result == inactive and control.generation == generation, "Alt must reveal cached rows without restarting calculations")
local idolEntry
for _, entry in ipairs(control.list) do if entry.row.name == "Idol of Egrin" then idolEntry = entry end end
assert(idolEntry.delta == 0, "Alt must not manufacture hypothetical damage")
local lines = { }
control:AddValueTooltip({CheckForUpdate = function() return true end, AddLine = function(_, _, text) lines[#lines+1] = text end, AddSeparator = function() end}, 1, idolEntry)
assert(table.concat(lines, "\n"):find("Inactive under current skills, gear and Configuration", 1, true))
reveal = false; control:Update(); assert(#control.list == 1)
-- A retained socket's loss must not make an inactive replacement look applicable.
control.result = {slot = "Helmet", excluded = 0, baseline = {FullDPS = 100}, rows = {
	{name = "Inactive replacement", lines = {}, inactive = true, values = {FullDPS = 90}},
	{name = "Indirect real gain", lines = {}, inactive = true, values = {FullDPS = 110}}
}}
control:Refresh(); assert(#control.list == 1 and control.list[1].row.name == "Indirect real gain")
main.IsComparisonRevealHeld = oldReveal
print("PASS: hide/reveal and explanation, cached Alt toggle, unchanged numeric values and indirect real gains")

-- Abyssal Eyes participate in the existing shared Ancient cap across slots.
for _, name in ipairs({"Amanamu's Gaze", "Kurgal's Gaze", "Tecrod's Gaze", "Ulaman's Gaze"}) do
	for _, variant in pairs(data.itemMods.Runes[name]) do
		assert(variant.limit == 1 and variant.limitId == "AncientAugment", name .. " must share the Ancient cap in every supported slot")
	end
end
local boots = equip("Rarity: Rare\nEye Boots\nRawhide Boots\n--------\nSockets: S\n--------\n+100 to maximum Life", "Boots")
boots.runes[1] = "Tecrod's Gaze"; boots:UpdateRunes(); boots:BuildAndParseRaw(); boots:BuildModList(); frame()
local blocked = report.Calculate(build, helmet:BuildRaw(), "Helmet", {["Amanamu's Gaze"] = true, ["Jiquani's Thesis"] = true}, true, 1)
assert(#blocked.rows == 0 and blocked.excluded == 2, "A retained Eye must exclude both other Eyes and Ancient augments")
local replacements = report.Calculate(build, boots:BuildRaw(), "Boots", {["Amanamu's Gaze"] = true, ["Tecrod's Gaze"] = true}, true, 1)
assert(#replacements.rows == 2, "Replacing the existing Eye must release the shared cap")
local secondEye = new("Item", helmet:BuildRaw()); secondEye.runes[1] = "Amanamu's Gaze"
secondEye:UpdateRunes(); secondEye:BuildAndParseRaw(); secondEye:BuildModList()
local invalid = calcs.initEnv(build, "CALCULATOR", {repSlotName = "Helmet", repItem = secondEye})
assert(invalid.itemWarnings.augmentLimitWarning, "Equipped Eye duplicates must trigger the existing cap warning")
print("PASS: all four Eyes share the Ancient cap; retained Eyes block recommendations; replacement releases it; equipped invalid combinations warn")
