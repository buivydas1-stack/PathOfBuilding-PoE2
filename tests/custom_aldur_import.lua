-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_aldur_import.lua
if not build then arg = { }; dofile("HeadlessWrapper.lua") end
newBuild()
local aldur = LoadModule("Modules/Aldur")
local report = LoadModule("Modules/AugmentReport")
local calcs = LoadModule("Modules/Calcs")
local function near(a, b, label)
	assert(a and b and math.abs(a-b) <= math.max(1e-6, math.abs(b)*1e-6), (label or "Mismatch") .. ": " .. tostring(a) .. " / " .. tostring(b))
end
local function frame() build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame") end
local function text(t) local lines = { }; for _, line in ipairs(t.lines) do lines[#lines+1] = line.text end; return table.concat(lines, "\n") end
local function candidate(item, name, index)
	local c = new("Item", item:BuildRaw()); c.runes[index or 1] = name
	c:UpdateRunes(); c:BuildAndParseRaw(); c:BuildModList(); return c
end
local function oracle(item)
	local override = { repSlotName = "Weapon 1", repItem = item }
	local env = calcs.initEnv(build, "CALCULATOR", override); calcs.perform(env)
	local full = calcs.calcFullDPS(build, "CALCULATOR", override)
	if #full.skills > 0 then env.player.output.FullDPS = full.combinedDPS end
	return report.Snapshot(env.player.output), env
end

local spiritRaw = dofile((customTestRoot or "../tests") .. "/fixtures/aldur_spirit_reach.lua")
local function checkSpirit(item)
	assert((item.customCount or 0) == 0, "Game Desecrated suffix must not become custom")
	local amanamu
	for _, affix in ipairs(item.suffixes) do if affix.modId == "AbyssModBowSpearAmanamuSuffixCompanionAndLocalAttackSpeed" then amanamu = affix end end
	assert(amanamu and amanamu.desecrated)
	assert(item.prefixes[1].fractured)
	local w = item.weaponData[1]
	assert(w.PhysicalMin == 125 and w.PhysicalMax == 232 and w.LightningMin == 7 and w.LightningMax == 348)
	near(w.AttackRate, 1.48, "Copied local attack speed")
	local lines = { }; for _, line in ipairs(item.explicitModLines) do lines[line.line] = line end
	assert(lines["18% increased Attack Speed"] and not lines["18% increased Attack Speed"].custom)
	assert(lines["Companions have 13% increased Attack Speed"])
	assert(lines["+2 to Level of all Attack Skills"], "Legacy +2 roll must survive today's +3 template")
	assert(not lines["20% chance to gain Onslaught on Killing Hits with this Weapon"].extra)
	assert(not item.aldurEstimate and not item.aldurUnavailable, "Actual forged values must not be estimated")
end
local spirit = new("Item", spiritRaw); checkSpirit(spirit)
-- Recover the exact old fallback representation without touching a saved build.
local legacy = spirit:BuildRaw():gsub("{copied:[%da-f,]+}", "")
legacy = legacy:gsub("Suffix: [^\n]*AbyssModBowSpearAmanamuSuffixCompanionAndLocalAttackSpeed\n", "")
legacy = legacy:gsub("{desecrated}18%% increased Attack Speed", "{custom}{desecrated}18%% increased Attack Speed")
legacy = legacy:gsub("{desecrated}Companions have 13%% increased Attack Speed", "{custom}{desecrated}Companions have 13%% increased Attack Speed")
local recovered = new("Item", legacy); recovered:Craft(); checkSpirit(recovered)
for _ = 1, 3 do spirit = new("Item", spirit:BuildRaw()); spirit:Craft(); checkSpirit(spirit) end
build.itemsTab:SetDisplayItem(spirit)
local skillDrop = build.itemsTab.controls.displayItemAffix6
assert(skillDrop.list[skillDrop.selIndex].label:find("+2 to Level", 1, true), "Editor must show the actual copied skill roll")
for i = 1, 6 do
	local drop = build.itemsTab.controls["displayItemAffix" .. i]
	if drop:IsShown() then drop.selFunc(drop.selIndex, drop.list[drop.selIndex]); checkSpirit(spirit) end
end
-- Changing the roll intentionally must discard the copied override for that
-- affix while preserving every other independent roll.
local edited = new("Item", spirit:BuildRaw())
edited.prefixes[2].range = 1; edited:Craft()
assert(edited.weaponData[1].LightningMin == 11 and edited.weaponData[1].LightningMax == 379)
assert(edited.suffixes[1].copied[2] == "Companions have 13% increased Attack Speed")
assert(new("Item", "Rarity: Rare\nOrdinary Bow\nIronwood Shortbow\nAdds 3 to 5 Fire Damage").affixes.AbyssModBowSpearAmanamuSuffixCompanionAndLocalAttackSpeed == nil)
print("PASS: exact game import, Desecrated multi-line suffix, independent weapon rolls, fracture flags, legacy +2, repeated crafting/editor/round trip and intentional roll changes")

local raw = [[Rarity: Rare
Miracle Siege
Warmonger Bow
Quality: 20
Sockets: S S
Implicits: 1
80% increased Elemental Damage with Attacks
Adds 97 to 148 Fire Damage
Adds 12 to 219 Lightning Damage
18% increased Attack Speed
Gain 41 Life per Enemy Killed
+3.62% to Critical Hit Chance
Adds 64 to 101 Cold Damage]]
local bow = new("Item", raw)
local ire = candidate(bow, "Ire of Aldur")
assert(ire.aldurEstimate and not ire.aldurUnavailable, ire.aldurUnavailable)
local w = ire.weaponData[1]
assert((w.FireMin or 0) == 0 and (w.ColdMin or 0) == 0 and w.LightningMin == 25 and w.LightningMax == 614, "Two source tiers must become their equivalent target-tier averages")
assert(ire.explicitModLines[1].line == bow.explicitModLines[1].line, "Source text is the reversible input")
local none = candidate(ire, "None")
assert(none.weaponData[1].FireMin == 97 and none.weaponData[1].ColdMax == 101 and none.weaponData[1].LightningMin == 12)
local trip = new("Item", ire:BuildRaw()); near(trip.weaponData[1].LightningMax, w.LightningMax, "Estimated persistence")
local chaos = candidate(bow, "Betrayal of Aldur")
assert(chaos.aldurEstimate and not chaos.aldurUnavailable and not chaos.weaponData[1].FireMax and not chaos.weaponData[1].LightningMax and not chaos.weaponData[1].ColdMax)
local fractured = new("Item", raw:gsub("Adds 97 to 148 Fire Damage", "{fractured}Adds 97 to 148 Fire Damage"))
local protected = candidate(fractured, "Ire of Aldur")
assert(protected.weaponData[1].FireMin == 97 and not protected.weaponData[1].ColdMin)
local ambiguous = candidate(new("Item", raw:gsub("97 to 148", "999 to 999")), "Ire of Aldur")
assert(ambiguous.aldurUnavailable, "Missing/ambiguous equivalence must not produce a misleading numeric ranking")
print("PASS: equivalent-tier average transformations, two source elements, Chaos, fractured protection, original input retention, removal and persistence")

-- Verify every reference resolves to existing primary game-data modifier rows.
for _, family in ipairs(LoadModule("Data/AldurConversions")) do
	for _, id in ipairs(family) do
		assert(not id or data.itemMods.Item[id] or data.itemMods.Desecrated[id] or data.itemMods.Jewel[id], "Missing conversion data: " .. tostring(id))
	end
end
build.characterLevel = 96
build.skillsTab:PasteSocketGroup("Lightning Arrow 20/0 1")
build.skillsTab.socketGroupList[1].includeInFullDPS = true
build.itemsTab:AddItem(bow, true); build.itemsTab.slots["Weapon 1"]:SetSelItemId(bow.id); frame()
local names = { }; for name in pairs(aldur.Targets) do names[name] = true end
local result = report.Calculate(build, raw, "Weapon 1", names)
for _, row in ipairs(result.rows) do
	local c = candidate(bow, row.name); local values = oracle(c)
	assert(row.estimated and not row.unavailable, row.unavailable)
	for key, value in pairs(row.values) do near(value, values[key], "Independent complete calculation: " .. key) end
end
local unavailable = report.Calculate(build, ambiguous:BuildRaw(), "Weapon 1", { ["Ire of Aldur"] = true })
assert(unavailable.rows[1].unavailable and not next(unavailable.rows[1].values))
-- Hover must replace the actual socket and retain all others, including rune
-- count effects; compare the real UI output with a separate complete engine run.
bow = candidate(bow, "Perfect Storm Rune", 2)
bow = candidate(bow, "Perfect Iron Rune", 1)
build.itemsTab:SetDisplayItem(bow)
local before = oracle(bow)
local calculate = build.calcsTab:GetMiscCalculator()
for name in pairs(names) do
	local t = new("Tooltip"); build.itemsTab:AddRuneComparisonTooltip(t, 1, name)
	local c = candidate(bow, name); assert(c.runes[2] == "Perfect Storm Rune")
	local expected = new("Tooltip")
	local a = calculate({ repSlotName = "Weapon 1", repItem = bow }, true, { noEnvReuse = true })
	local b = calculate({ repSlotName = "Weapon 1", repItem = c }, true, { noEnvReuse = true })
	build:AddStatComparesToTooltip(expected, a, b, "\nReplacing socket #1 will give: ")
	assert(text(t):find("Estimate: average rolls", 1, true))
	assert(text(t):sub(-#text(expected)) == text(expected), "Real hover must match socket replacement")
	local values = oracle(c); near(b.FullDPS, values.FullDPS, "Hover independent Full DPS")
end
print("PASS: all four rune report values and real socket hovers match independent complete calculations; retained sockets and N/A handling")

-- Onslaught chance identifies a source but does not invent combat uptime.
local _, baseEnv = oracle(spirit)
assert(not baseEnv.player.modDB:GetCondition("Onslaught"))
build.configTab.input.buffOnslaught = true; build.configTab:BuildModList(); frame()
local buffed, buffEnv = oracle(spirit)
assert(buffEnv.player.modDB:GetCondition("Onslaught"))
assert(buffed.FullDPS > oracle(spirit).FullDPS * 0.99)
build.configTab.input.buffOnslaught = false; build.configTab:BuildModList(); frame()
local unbuffed = oracle(spirit)
assert(buffed.FullDPS > unbuffed.FullDPS, "Manual active Onslaught must affect speed and damage")
print("PASS: Onslaught source supported without automatic kill/boss uptime; existing manual buff enables its actual effect")
