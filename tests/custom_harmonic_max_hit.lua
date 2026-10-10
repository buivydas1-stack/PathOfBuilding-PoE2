local open = io.open
io.open = function(path, mode)
	local p = path:gsub("\\", "/"):lower()
	if p:match("settings%.xml$") or p:match("first%.run$") or p:find("/builds/", 1, true) then return nil end
	assert(not (mode or "r"):find("[wa+]"), "No user-data writes")
	return open(path, mode)
end
arg = {}; dofile("HeadlessWrapper.lua")
newBuild()
local calcs = build.calcsTab.calcs
local types = { "Physical", "Lightning", "Cold", "Fire", "Chaos" }
local function sample(values)
	local output = {}
	for i, name in ipairs(types) do output[name.."MaximumHitTaken"] = values[i] end
	return calcs.harmonicMaximumHitTaken(output)
end
local function near(a, b)
	assert(a == b or math.abs(a-b) <= math.abs(b)*1e-10, tostring(a).." / "..tostring(b))
end
near(sample({1000,10000,10000,10000,10000}), 25000/7)
near(sample({100,100,100,100,100}), 100)
near(sample({0,100,100,100,100}), 0)
near(sample({100,math.huge,math.huge,math.huge,math.huge}), 500)
near(sample({math.huge,math.huge,math.huge,math.huge,math.huge}), math.huge)
near(sample({1e-300,1e-300,1e-300,1e-300,1e-300}), 1e-300)
assert(sample({2000,10000,10000,10000,10000}) > sample({1000,10000,10000,10000,10000}))
assert(sample({0/0,100,100,100,100}) == 0)
build.skillsTab:PasteSocketGroup("Spark 20/0 1")
build.buildFlag = true; runCallback("OnFrame")
local calculator = build.calcsTab:GetMiscCalculator()
local before = calculator({}, true, {noEnvReuse=true})
near(before.HarmonicMaximumHitTaken, 5 / (1/before.PhysicalMaximumHitTaken + 1/before.FireMaximumHitTaken + 1/before.ColdMaximumHitTaken + 1/before.LightningMaximumHitTaken + 1/before.ChaosMaximumHitTaken))
assert(before.SecondMinimalMaximumHitTaken == nil)
local original = calcs.harmonicMaximumHitTaken
calcs.harmonicMaximumHitTaken = function() return 123 end
local after = calculator({}, true, {noEnvReuse=true})
calcs.harmonicMaximumHitTaken = original
assert(after.HarmonicMaximumHitTaken == 123)
assert(after.TotalEHP == before.TotalEHP, "Aggregate must not change EHP")
for _, name in ipairs(types) do assert(after[name.."MaximumHitTaken"] == before[name.."MaximumHitTaken"]) end
local shared = LoadModule("Modules/AugmentReport")
assert(shared.Snapshot({HarmonicMaximumHitTaken=math.huge}).HarmonicMaximumHitTaken == nil)
assert(build.calcsTab:CalculatePowerStat({stat="HarmonicMaximumHitTaken"},{HarmonicMaximumHitTaken=120},{HarmonicMaximumHitTaken=100}) == 20)
newBuild()
build.skillsTab:PasteSocketGroup("Skeletal Sniper 20/0 1")
build.buildFlag=true; runCallback("OnFrame")
local minionOutput=build.calcsTab:GetMiscCalculator()({},true,{noEnvReuse=true})
assert(minionOutput.Minion)
near(minionOutput.Minion.HarmonicMaximumHitTaken, calcs.harmonicMaximumHitTaken(minionOutput.Minion))
near(data.powerStatList.GetFromOutput(minionOutput,{stat="MinionHarmonicMaximumHitTaken"}),minionOutput.Minion.HarmonicMaximumHitTaken)
local order = LoadModule("Modules/PowerStatOrder")
main.powerStatOrder = { "TotalEHP", "SecondMinimalMaximumHitTaken", "FullDPS", "MinionSecondMinimalMaximumHitTaken" }
local list = LoadModule("Modules/AugmentReport").GetStats()
assert(list[2].stat == "HarmonicMaximumHitTaken")
assert(main.powerStatOrder[4] == "MinionHarmonicMaximumHitTaken")
for _, stat in ipairs(list) do assert(not stat.stat:find("SecondMinimal",1,true)) end
local function text(tooltip)
	local lines = {}; for _, line in ipairs(tooltip.lines) do lines[#lines+1] = line.text end
	return table.concat(lines, "\n")
end
main.IsComparisonRevealHeld = function() return false end
build.viewMode = "ITEMS"
local base = {TotalEHP=1000,HarmonicMaximumHitTaken=100, FireResist=75,FireResistOverCap=20,ColdResist=50,ColdResistOverCap=0,LightningResist=75,LightningResistOverCap=10,ChaosResist=20,ChaosResistOverCap=0}
local changed = copyTable(base)
changed.TotalEHP=1100; changed.HarmonicMaximumHitTaken=120
changed.FireResistOverCap=25; changed.ColdResist=40; changed.LightningResistOverCap=5; changed.ChaosResist=30
local tooltip = new("Tooltip")
build:AddStatComparesToTooltip(tooltip,base,changed,"Changes",nil,{"FullDPS","TotalEHP","HarmonicMaximumHitTaken"})
local rendered = text(tooltip)
for _, expected in ipairs({"+100 Effective Hit Pool", "+20 Balanced Maximum Hit", "+5% Fire Res. Over Max", "-10% Cold Resistance", "-5% Lightning Res. Over Max", "+10% Chaos Resistance"}) do
	assert(rendered:find(expected,1,true), expected.." missing: "..rendered)
end
assert(not rendered:find("show other stat changes",1,true), "No hidden changes in this fixture")
local control = build.itemsTab.controls.catalystReport
main.popups = {}
control.stat={stat="HarmonicMaximumHitTaken",label="Balanced Maximum Hit"}
control.result={quality=20,baselineComparison=base}
local entry={row={name="Flesh Catalyst",changes={{before="+100 to maximum Life",after="+120 to maximum Life"}}, comparison=LoadModule("Modules/AugmentReport").ComparisonChanges(base,changed)}}
local compact = new("Tooltip")
control:AddValueTooltip(compact,1,entry)
rendered=text(compact)
assert(rendered:find("Balanced Maximum Hit",1,true) and rendered:find("Effective Hit Pool",1,true))
for _, removed in ipairs({"Uses current", "Sum of modifier", "Double-click", "ranking score", "Starts with", "Modifier gain", "Percentage change is"}) do assert(not rendered:find(removed,1,true)) end
print("PASS: harmonic mean extremes, real engine EHP invariance, legacy order migration, compact hover and default resistance gains/losses")
