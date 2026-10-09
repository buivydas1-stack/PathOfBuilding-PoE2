-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_augment_mana_regen.lua
arg = {}; dofile("HeadlessWrapper.lua")
newBuild()
local calcs = LoadModule("Modules/Calcs")
local report = LoadModule("Modules/AugmentReport")
local json = require("dkjson")
local function near(a, b, label)
	assert(a and b and math.abs(a-b) < 0.000001, (label or "Mismatch") .. ": " .. tostring(a) .. " / " .. tostring(b))
end
local function equip(raw, slot)
	local item = new("Item", raw)
	build.itemsTab:AddItem(item, true); build.itemsTab.slots[slot]:SetSelItemId(item.id)
	return item
end
local helmet = equip("Rarity: Rare\nRegeneration Helmet\nRusted Greathelm\n--------\nSockets: S S\n--------\n+100 to maximum Life", "Helmet")
equip("Rarity: UNIQUE\nLavianga's Spirits\nGargantuan Mana Flask\n--------\nThis Flask cannot be Used but applies its Effect constantly\n70% reduced Amount Recovered", "Flask 2")
local function frame(mods)
	build.configTab.input.customMods = mods or ""
	build.configTab:BuildModList(); build.buildFlag = true
	runCallback("OnFrame"); runCallback("OnFrame")
end
local kurgal = new("Item", helmet:BuildRaw())
kurgal.runes[1] = "Kurgal's Gaze"
kurgal:UpdateRunes(); kurgal:BuildAndParseRaw(); kurgal:BuildModList()
assert(kurgal.runes[1] == "Kurgal's Gaze" and not kurgal.runeModLines[1].extra, "Kurgal must parse through the normal rune editor")
local reloaded = new("Item", kurgal:BuildRaw())
assert(reloaded.runes[1] == "Kurgal's Gaze" and not reloaded.runeModLines[1].extra, "Kurgal import/round trip must preserve support")
local function complete(item)
	local env = calcs.initEnv(build, "CALCULATOR", {repSlotName="Helmet", repItem=item})
	calcs.perform(env)
	return env.player.output, env.player.modDB
end
local function check(mods, expectedLifeInc)
	frame(mods)
	local before, db = complete(helmet)
	local after = complete(kurgal)
	near(db:Sum("INC", nil, "LifeRegen"), expectedLifeInc, "Fixture life increase")
	local base = db:Sum("BASE", nil, "ManaRegen") + before.Mana * db:Sum("BASE", nil, "ManaRegenPercent") / 100
	local expected = round(base * (1 + (before.ManaRegenInc + expectedLifeInc) / 100) * db:More(nil, "ManaRegen", "ManaRecoveryRate"), 1)
	near(after.ManaRegen, expected, "Independent Kurgal formula")
	near(after.ManaRegenInc, before.ManaRegenInc + expectedLifeInc, "Shared increased/reduced modifiers")
	near(after.LifeRegen, before.LifeRegen, "Life regeneration remains intact")
	near(after.ManaFlaskRecoveryPerSecond, before.ManaFlaskRecoveryPerSecond, "Flask recovery is independent")
	near(complete(kurgal).ManaRegen, after.ManaRegen, "Repeated calculations must not accumulate shared modifiers")
	return before, after
end
check("40% increased Mana Regeneration Rate\n60% increased Life Regeneration Rate", 60)
check("40% increased Mana Regeneration Rate\n20% reduced Life Regeneration Rate", -20)
check("10% increased Life and Mana Regeneration Rate", 10)
check("Regenerate 17.8 Life per second\nRegenerate 2% of Life per second\n50% more Life Regeneration Rate\n20% increased Life Recovery Rate", 0)
build.configTab.input.conditionMoving = false
check("30% increased Life Regeneration Rate while moving", 0)
build.configTab.input.conditionMoving = true
check("30% increased Life Regeneration Rate while moving", 30)
build.configTab.input.conditionMoving = false
local _, chained = check("60% increased Life Regeneration Rate\n40% increased Mana Regeneration Rate\nRegenerate 2 Rage per second\nIncreases and Reductions to Mana Regeneration Rate also apply to Rage Regeneration Rate\nIncreases and Reductions to Mana Regeneration Rate also apply to Energy Shield Recharge Rate", 60)
near(chained.RageRegenInc, 100, "Furious Wellspring includes newly shared modifiers once")
local chainEnv = calcs.initEnv(build, "CALCULATOR", {repSlotName="Helmet", repItem=kurgal}); calcs.perform(chainEnv)
near(chainEnv.player.modDB:Sum("INC", nil, "EnergyShieldRecharge"), 100, "Waveshaper includes newly shared modifiers once")
print("PASS: Kurgal import/editor/round trip, independent formula, increases/reductions, combined stats, flat/more/recovery exclusions, conditions and downstream conversions")

frame("60% increased Life Regeneration Rate\n40% increased Mana Regeneration Rate")
build.viewMode = "ITEMS"; build.itemsTab:SetDisplayItem(helmet)
local control = build.itemsTab.controls.augmentReport
control:Update()
local names = {["Kurgal's Gaze"]=true, ["Perfect Inspiration Rune"]=true, ["Perfect Vision Rune"]=true}
local result = json.decode(json.encode(report.Calculate(build, helmet:BuildRaw(), "Helmet", names, true, 1)))
control.result = result; control:Refresh()
local oldReveal, reveal = main.IsComparisonRevealHeld, false
main.IsComparisonRevealHeld = function() return reveal end
local function text(tooltip)
	local lines = {}; for _, line in ipairs(tooltip.lines) do lines[#lines+1] = line.text end
	return table.concat(lines, "\n")
end
local generation = control.generation
local tooltip = new("Tooltip")
for _, entry in ipairs(control.list) do
	for _, show in ipairs({false, true, false}) do
		reveal = show; control:AddValueTooltip(tooltip, 1, entry)
		local rendered = text(tooltip)
		assert((rendered:find("Total mana regeneration:",1,true) ~= nil) == show, "Alt must update the cached tooltip")
		if show then
			local after = report.ComparisonOutput(result.baselineComparison, entry.row.comparison)
			local base = result.baselineComparison.ManaRegen
			local percent = (after.ManaRegen-base)/base*100
			assert(rendered:find(string.format("(%+.2f%%)", percent),1,true), "Tooltip must use total regeneration as its denominator")
			assert(rendered:find(string.format("%.2f -> %.2f mana/s",base,after.ManaRegen),1,true), "Tooltip must show total rates")
			if entry.row.name == "Perfect Vision Rune" then
				near(after.ManaRegen,base,"Flask rune regeneration gain")
				assert(entry.row.values.ManaRegenRecovery > result.baseline.ManaRegenRecovery)
				assert(rendered:find("Total mana regeneration change: +0.00 mana/s (+0.00%)",1,true), "Flask-only gains must explicitly show zero regeneration gain")
			elseif entry.row.name == "Kurgal's Gaze" then
				near(after.ManaRegen,complete(kurgal).ManaRegen,"Kurgal report vs full calculation")
			end
		end
	end
end
assert(control.result == result and not control.worker and control.generation == generation, "Alt must only use cached results")
-- Existing-socket replacement uses its own baseline, including losses.
local replaced = report.Calculate(build,kurgal:BuildRaw(),"Helmet",{["Perfect Vision Rune"]=true},true,1)
control.result = replaced;control:Refresh();reveal=true
control:AddValueTooltip(tooltip,1,control.list[1])
assert(text(tooltip):find("Total mana regeneration change: -",1,true),"Replacement loss must use the socket's current baseline")
-- Zero baseline has no defined relative percentage; do not invent one.
control.result={slot="Helmet",considerExisting=true,socketIndex=1,excluded=0,baseline={Life=100},baselineComparison={ManaRegen=0},rows={{name="Zero baseline",lines={},values={Life=100},comparison={ManaRegen=10}}}}
control:Refresh();control:AddValueTooltip(tooltip,1,control.list[1])
assert(text(tooltip):find("+10.00 mana/s (N/A)",1,true))
main.IsComparisonRevealHeld=oldReveal
-- The isolated worker bootstrap replaces global UI callbacks in this test state,
-- so run it after the UI assertions (the app runs it in its own Lua thread).
local worker = json.decode(assert(loadfile("Modules/AugmentReportWorker.lua"))(".", build:SaveDB("mana regeneration worker fixture"), helmet:BuildRaw(), "Helmet", json.encode(names), true, 1))
near(worker.baselineComparison.ManaRegen,result.baselineComparison.ManaRegen,"Worker baseline")
for i,row in ipairs(worker.rows) do
	assert(row.name == result.rows[i].name)
	near(report.ComparisonOutput(worker.baselineComparison,row.comparison).ManaRegen,report.ComparisonOutput(result.baselineComparison,result.rows[i].comparison).ManaRegen,"Worker result")
end
print("PASS: total-rate percentages, zero/flask-only gain, replacement losses, zero baseline, cached Alt transitions and real XML/JSON worker parity")
