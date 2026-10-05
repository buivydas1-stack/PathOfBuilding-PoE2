-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_catalyst_report.lua
-- This fixture runner can also inspect the installation without accessing saves.
local open = io.open
io.open = function(path, mode)
	local normalized = path:gsub("\\", "/"):lower()
	assert(not (mode or "r"):find("[wa+]"), "Catalyst tests cannot write files")
	if normalized:match("settings%.xml$") or normalized:match("first%.run$") or normalized:find("/builds/", 1, true) then return nil end
	return open(path, mode)
end
arg = { }; dofile("HeadlessWrapper.lua")
newBuild()
local report = LoadModule("Modules/CatalystReport")
local shared = LoadModule("Modules/AugmentReport")
local calcs = LoadModule("Modules/Calcs")
local function near(actual, expected, name)
	assert(actual and math.abs(actual - expected) <= math.max(0.000001, math.abs(expected) * 0.000001), (name or "Mismatch") .. ": " .. tostring(actual) .. " / " .. tostring(expected))
end
local function row(result, name)
	for _, value in ipairs(result.rows) do if value.name == name then return value end end
	error("Missing " .. name)
end
local raw = [[Item Class: Amulets
Rarity: Rare
Blight Heart
Solar Amulet
--------
Requires: Level 64
--------
Item Level: 82
--------
{ Implicit Modifier }
+12(10-15) to Spirit
--------
{ Prefix Modifier "Mirage's" (Tier: 1) — Evasion }
47(45-50)% increased Evasion Rating
{ Prefix Modifier "Athlete's" (Tier: 1) — Life }
+127(120-149) to maximum Life
{ Desecrated Prefix Modifier "Countess'" (Tier: 1) }
+48(47-50) to Spirit
{ Suffix Modifier "of Archaeology" (Tier: 1) }
18(15-18)% increased Rarity of Items found
{ Suffix Modifier "of the Span" (Tier: 1) — Elemental, Fire, Cold, Lightning, Resistance }
+18(17-18)% to all Elemental Resistances
{ Suffix Modifier "of the Thunderhead" (Tier: 5) — Elemental, Lightning, Resistance }
+24(21-25)% to Lightning Resistance]]
local result, baseline = report.ItemResult(raw, 20)
assert(#result.rows == 13)
local esh, flesh, carapace = row(result, "Esh's Catalyst"), row(result, "Flesh Catalyst"), row(result, "Carapace Catalyst")
near(esh.score, 100 / 3, "Two resistance modifiers")
near(flesh.score, 25 / 127 * 100, "Life rounding")
near(carapace.score, 9 / 47 * 100, "Evasion rounding")
near(row(result, "Xoph's Catalyst").score, 3 / 18 * 100, "All resistance counted once")
near(row(result, "Tul's Catalyst").score, 3 / 18 * 100)
assert(#esh.changes == 2 and esh.changes[1].after == "+21% to all Elemental Resistances" and esh.changes[2].after == "+28% to Lightning Resistance")
assert(#flesh.changes == 1 and flesh.changes[1].after == "+152 to maximum Life")
assert(#carapace.changes == 1 and carapace.changes[1].after == "56% increased Evasion Rating")
for _, name in ipairs({ "Neural Catalyst", "Sibilant Catalyst", "Necrotic Catalyst" }) do near(row(result, name).score, 0) end
print("PASS: exact pasted amulet, 33.33 score, whole all-resistance modifier once, rounding and unaffected Spirit")

local existing = report.Prepare(baseline:BuildRaw(), 1, 20)
local existingRaw = existing:BuildRaw()
local replaced = report.ItemResult(existingRaw, 20)
near(row(replaced, "Esh's Catalyst").score, esh.score, "Existing quality removed from baseline")
assert(existing:BuildRaw() == existingRaw, "Recommendations must not mutate existing quality")
local forty = report.ItemResult(raw, 40)
near(row(forty, "Flesh Catalyst").score, 50 / 127 * 100, "Target quality")
local zero = report.ItemResult(raw, 0)
for _, value in ipairs(zero.rows) do assert(value.score == 0 and #value.changes == 0) end
local ring = report.ItemResult("Rarity: Rare\nRange Ring\nTopaz Ring\n--------\n+27% to Lightning Resistance (implicit)\n--------\nAdds 1 to 41 Lightning damage to Attacks", 20)
local range = row(ring, "Esh's Catalyst")
assert(#range.changes == 2)
near(range.score, 5 / 27 * 100 + 8 / 42 * 100, "Damage endpoints share one score")
local penalty = report.ItemResult("Rarity: Rare\nPenalty Ring\nGold Ring\n--------\n-18% to Lightning Resistance", 20)
near(row(penalty, "Esh's Catalyst").score, -3 / 18 * 100, "Negative resistance must lose score")
print("PASS: no/current quality baselines, editable quality, implicit changes, damage ranges and negative values")

local attributes = report.ItemResult("Rarity: Rare\nAttribute Amulet\nJade Amulet\n--------\n+12 to Dexterity (implicit)\n--------\n+31 to all Attributes\n+43 to Strength", 20)
local adaptive = row(attributes, "Adaptive Catalyst")
assert(#adaptive.changes == 3)
near(adaptive.score, 2 / 12 * 100 + 6 / 31 * 100 + 8 / 43 * 100, "Attribute modifiers and implicit")
-- Explicit tags exercise eligible effects independently of affix name guesses.
local tagged = report.ItemResult("Rarity: Rare\nTagged Amulet\nGold Amulet\n--------\n{tags:caster}40% increased Spell Damage\n{tags:mana}+81 to maximum Mana\n{tags:minion}15% increased Spirit\n{tags:life}10% reduced maximum Life", 20)
near(row(tagged, "Sibilant Catalyst").score, 20, "Caster modifier")
near(row(tagged, "Neural Catalyst").score, 16 / 81 * 100, "Mana modifier")
near(row(tagged, "Necrotic Catalyst").score, 20, "Tagged Spirit participates")
near(row(tagged, "Flesh Catalyst").score, -20, "Reduced Life is a penalty")
assert(row(tagged, "Necrotic Catalyst").changes[1].after == "18% increased Spirit")
print("PASS: attributes, caster, mana and catalyst-tagged Spirit participate; reduced Life loses score")

-- Item mode needs no build optimisation or allocated socket.
local jewelRaw = "Rarity: Rare\nCatalyst Jewel\nEmerald\n--------\n15% increased Lightning Damage\n7% increased Attack Speed"
local jewelResult = report.Calculate(build, jewelRaw, nil, 20)
assert(jewelResult.buildUnavailable and #jewelResult.rows == 13)
near(row(jewelResult, "Refined Esh's Catalyst").score, 20)
near(row(jewelResult, "Refined Skittering Catalyst").score, 1 / 7 * 100)
local tab = build.itemsTab
tab:CreateDisplayItemFromRaw(jewelRaw, true)
assert(tab.controls.displayItemCatalyst:IsShown() and tab.controls.catalystReport:IsShown() and not tab.controls.augmentReport:IsShown())
assert(tab.controls.displayItemCatalyst.list[8]:match("^Refined "), "Jewel selector must name refined catalysts")
tab.controls.displayItemCatalyst:SetSel(8)
assert(tab.displayItem.catalyst == 7 and tab.displayItem.catalystQuality == 20)
assert(tab.controls.displayItemCatalystQualitySlider.maxQuality == 20)
assert(tab.displayItem.explicitModLines[1].valueScalar == 1.2)
assert(not tab.controls.displayItemJewelQualitySlider:IsShown(), "Only one jewel quality editor should appear")
local restored = new("Item", tab.displayItem:BuildRaw())
assert(restored.catalyst == 7 and restored.catalystQuality == 20 and restored.explicitModLines[1].valueScalar == 1.2)
tab.controls.displayItemCatalystQualityEdit.changeFunc("10")
assert(tab.displayItem.catalystQuality == 10)
tab.controls.displayItemCatalyst:SetSel(1)
assert(tab.displayItem.catalystQuality == nil)
print("PASS: refined jewel names, inferred tags, selector, quality controls and item round trip")

local craftedRaw = "Rarity: Rare\nCrafted Eye\nEmerald\nCrafted: true\nPrefix: {range:0.5}JewelBowDamage\nPrefix: {range:0.5}JewelAttackDamage\nSuffix: {range:0.5}JewelAttackCriticalDamage\nSuffix: {range:0.55}CraftedJewelPrefixEffect\nCatalyst: Reaver\nCatalystQuality: 10"
local crafted = new("Item", craftedRaw); crafted:Craft()
local craftedResult, neutral = report.ItemResult(crafted:BuildRaw(), 20)
local direct = new("Item", craftedRaw)
direct.catalystQuality = 20; direct:Craft()
local changes, directScore = report.ModifierChanges(neutral, direct)
local reaver = row(craftedResult, "Refined Reaver Catalyst")
near(reaver.score, directScore, "Crafted jewel local effects and quality")
assert(#reaver.changes == #changes)
for index, change in ipairs(changes) do assert(reaver.changes[index].after == change.after, "Crafted quality must not double-scale") end
tab:SetDisplayItem(crafted)
tab.controls.displayItemCatalystQualityEdit.changeFunc("20")
local edited = { }
for _, line in ipairs(tab.displayItem.explicitModLines) do edited[line.line] = true end
for _, line in ipairs(direct.explicitModLines) do assert(edited[line.line], "Shared jewel quality editor must preserve original affix rolls") end
print("PASS: crafted jewel report and shared quality editor preserve affix rolls and additive local effects")

local qualityCopy = "Item Class: Jewels\nRarity: Rare\nLoath Eye\nEmerald\n--------\nQuality (Attack Modifiers): +10% (augmented)\n--------\nItem Level: 81\n--------\n13% increased Critical Damage Bonus for Attack Damage\n14% increased Attack Damage\n17% increased Damage with Bows\n22% increased Elemental Damage\n51% increased Effect of Prefixes"
local copiedResult, copiedBase = report.ItemResult(qualityCopy, 20)
local copiedReaver = row(copiedResult, "Refined Reaver Catalyst")
local expectedLines = { ["14% increased Critical Damage Bonus for Attack Damage"] = true,
	["15% increased Attack Damage"] = true, ["18% increased Damage with Bows"] = true }
assert(#copiedReaver.changes == 3)
for _, change in ipairs(copiedReaver.changes) do assert(expectedLines[change.after], "Copied quality/local effects were scaled twice: " .. change.after) end
tab:CreateDisplayItemFromRaw(qualityCopy, true)
tab.controls.displayItemCatalystQualityEdit.changeFunc("20")
local copyLines = { }
for _, line in ipairs(tab.displayItem.explicitModLines) do copyLines[line.line] = true end
for text in pairs(expectedLines) do assert(copyLines[text], "Normal-copy quality editor: " .. text) end
local qualityRing = report.ItemResult("Item Class: Rings\nRarity: Rare\nQuality Ring\nTopaz Ring\n--------\nQuality (Lightning Modifiers): +20% (augmented)\n--------\n+32% to Lightning Resistance (implicit)\n--------\n+152 to maximum Life", 20)
near(row(qualityRing, "Esh's Catalyst").score, 5 / 27 * 100, "Existing copied implicit quality")
print("PASS: normal game copies recover existing quality and jewel local effects without double scaling")

local unsupported = report.ItemResult("Rarity: Rare\nUnsupported Fixture\nGold Ring\n--------\n{tags:caster}10% increased Unmodelled Fixture Power", 20)
assert(row(unsupported, "Sibilant Catalyst").changes[1].unsupported, "Unsupported build effects must be identified")
local badCopy = "Item Class: Rings\nRarity: Rare\nUnknown Roll\nTopaz Ring\n--------\nQuality (Lightning Modifiers): +20% (augmented)\n--------\n+999% to Lightning Resistance"
local ok, error = pcall(report.ItemResult, badCopy, 20)
assert(not ok and tostring(error):find("advanced item copy", 1, true), "Unknown existing rolls must not be guessed")
tab:CreateDisplayItemFromRaw(badCopy, true)
local originalBadRaw = tab.displayItem:BuildRaw()
local oldPopup, message = main.OpenMessagePopup, nil
main.OpenMessagePopup = function(_, _, text) message = text end
tab.controls.displayItemCatalystQualityEdit.changeFunc("40")
main.OpenMessagePopup = oldPopup
assert(message and tab.displayItem:BuildRaw() == originalBadRaw, "Failed quality edits must preserve the item")
print("PASS: unsupported build effects and unknown existing rolls are explicit; failed edits preserve the item")

-- Independent complete calculations establish that item scores and EHP rankings
-- can disagree when the current build already caps every resistance.
build.configTab.input.customMods = "+200% to all Elemental Resistances"
build.configTab:BuildModList()
build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
local revision, flag = build.outputRevision, build.buildFlag
local calculated = report.Calculate(build, raw, "Amulet", 20)
assert(not calculated.buildUnavailable and calculated.baseline.TotalEHP)
local function oracle(item, slot)
	local override = { repSlotName = slot, repItem = item }
	local env = calcs.initEnv(build, "CALCULATOR", override); calcs.perform(env)
	return shared.Snapshot(env.player.output)
end
for _, value in ipairs(calculated.rows) do
	local expected = oracle(report.Prepare(baseline:BuildRaw(), value.id, 20), "Amulet")
	near(value.values.Life, expected.Life, value.name .. " complete Life")
	near(value.values.TotalEHP, expected.TotalEHP, value.name .. " complete EHP")
end
near(row(calculated, "Esh's Catalyst").values.TotalEHP, calculated.baseline.TotalEHP, "Capped resistance EHP")
assert(row(calculated, "Flesh Catalyst").values.TotalEHP > calculated.baseline.TotalEHP)
assert(build.outputRevision == revision and build.buildFlag == flag, "Report mutated the live build")
print("PASS: complete-calculation parity, Life wins EHP at capped resistances, unchanged build")

-- An allocated socket must apply the candidate jewel, not compare an unused one.
local socket
for _, node in pairs(build.spec.nodes) do
	if node.type == "Socket" and node.path and not node.ascendancyName and not node.charmSocket and not node.sinister then socket = node; break end
end
assert(socket, "Missing fixture jewel socket")
build.spec:AllocNode(socket)
tab:UpdateSockets()
local jewel = new("Item", jewelRaw)
tab:AddItem(jewel, true); tab.sockets[socket.id]:SetSelItemId(jewel.id)
build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
local slot = "Jewel " .. socket.id
local socketResult = report.Calculate(build, jewelRaw, slot, 20)
assert(not socketResult.buildUnavailable, socketResult.buildUnavailable)
near(row(socketResult, "Refined Skittering Catalyst").values.Speed, oracle(report.Prepare(jewelRaw, 11, 20), slot).Speed, "Allocated jewel speed")
print("PASS: active allocated jewel replacement matches a complete calculation")

tab:CreateDisplayItemFromRaw(raw, true)
local control = tab.controls.catalystReport
local metrics = { }
for _, stat in ipairs(control.controls.stat.list) do metrics[stat.stat] = true end
assert(metrics.Spirit and metrics.Str and metrics.Dex and metrics.Int and metrics.FullDPS and metrics.TotalEHP, "Build ranking must cover more than EHP")
control:Update()
control.result = calculated; control:Refresh()
assert(control.controls.itemScore.state and control.list[1].row.name == "Esh's Catalyst")
local cached, generation = control.result, control.generation
for index, stat in ipairs(control.controls.stat.list) do if stat.stat == "TotalEHP" then control.controls.stat:SetSel(index); break end end
control.controls.itemScore.state = false; control.controls.itemScore.changeFunc()
assert(control.result == cached and control.generation == generation and control.list[1].row.name == "Flesh Catalyst", "Mode changes must reuse cached results")
control.controls.itemScore.state = true; control.controls.itemScore.changeFunc()
assert(control.list[1].row.name == "Esh's Catalyst")
control.controls.search:SetText("life", true)
assert(#control.list == 1 and control.list[1].row.name == "Flesh Catalyst")
control.controls.search:SetText("", true)
control.controls.filter:SetSel(2); assert(#control.list == 5)
control.controls.filter:SetSel(1)
local tooltip = new("Tooltip")
control:AddValueTooltip(tooltip, 1, control.list[1])
assert(#tooltip.lines > 4)
control.controls.quality:SetText("40", true); control:Update()
assert(not control.result and control.generation > generation, "Quality changes invalidate results")
control.result = calculated
build.outputRevision = build.outputRevision + 1; control:Update()
assert(not control.result, "Build changes invalidate results")
tab:SetDisplayItem(nil); control:Update()
assert(not control.key and not control:IsShown(), "Closing the editor must clear the report without an error")
print("PASS: item/build sorting, cached mode switch, search, filters, tooltips and cache invalidation")

-- Exercise explicit scheduling and stale completion on the real Calculate
-- button; only the OS thread launcher is mocked here.
tab:CreateDisplayItemFromRaw(raw, true)
control.controls.quality:SetText("20", true)
local oldLaunch, oldAbort, oldPath = LaunchSubScript, AbortSubScript, GetScriptPath
local launched, aborted = 0, 0
GetScriptPath = function() return "." end
LaunchSubScript = function(script, _, _, root, xml, rawText, slotName, quality)
	assert(script:find('"catalyst"', 1, true) and xml:find("<PathOfBuilding2", 1, true))
	assert(rawText == control.itemRaw and slotName == "Amulet" and quality == 20)
	launched = launched + 1; return launched
end
AbortSubScript = function() aborted = aborted + 1 end
control:Update(); assert(launched == 0)
control.controls.calculate:Click(); assert(launched == 1 and control.worker == 1)
local stale = launch.subScripts[1].callback
for _ = 1, 10 do control:Update() end
assert(launched == 1)
control.controls.itemScore.state = false; control.controls.itemScore.changeFunc()
assert(control.worker == 1, "Mode changes must not cancel a calculation")
control.controls.quality:SetText("40", true); control:Update()
assert(aborted == 1 and not control.worker)
stale(require("dkjson").encode(calculated))
assert(not control.result, "Stale worker delivery must not restore obsolete results")
control.controls.quality:SetText("20", true); control:Update()
control:Calculate()
launch.subScripts[2].callback(require("dkjson").encode(calculated))
assert(control.result and not control.worker)
LaunchSubScript, AbortSubScript, GetScriptPath = oldLaunch, oldAbort, oldPath
print("PASS: explicit Calculate button, shared background worker dispatch, mode reuse, cancellation and stale delivery")

-- The real worker must transport the same item score and every build value.
local json = require("dkjson")
local snapshot = build:SaveDB("catalyst worker fixture")
local candidates = { ["Esh's Catalyst"] = true, ["Flesh Catalyst"] = true }
local expected = report.Calculate(build, raw, "Amulet", 20, candidates)
local worker = json.decode(assert(loadfile("Modules/AugmentReportWorker.lua"))(".", snapshot, raw, "Amulet", json.encode(candidates), nil, nil, "catalyst", 20))
for _, value in ipairs(expected.rows) do
	local actual = row(worker, value.name)
	near(actual.score, value.score, value.name .. " worker score")
	for stat, amount in pairs(value.values) do near(actual.values[stat], amount, value.name .. " worker " .. stat) end
end
print("PASS: real worker XML snapshot, item scores and complete build output transport parity")
