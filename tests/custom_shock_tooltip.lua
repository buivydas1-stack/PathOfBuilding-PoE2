-- Presentation-only checks: use already calculated values in the normal tooltip.
if not build then arg = {}; dofile("HeadlessWrapper.lua") end
newBuild()
local actor = { mainSkill = { activeEffect = { statSet = { skillFlags = {hit=true} } } } }
local function compare(before, after)
	local tooltip = { lines = {}, AddLine = function(self, _, line) table.insert(self.lines, line) end }
	build:CompareStatList(tooltip, build.displayStats, actor, {ShockChance=before}, {ShockChance=after}, "Change")
	return table.concat(tooltip.lines, "\n")
end
assert(compare(22.34634,25.99770):find("+3.65%% Shock Chance"), "Gain must show percentage-point delta")
assert(compare(25.99770,22.34634):find("-3.65%% Shock Chance"), "Removal must show negative delta")
assert(compare(0,5):find("+5.00%% Shock Chance"), "Zero baseline must work")
assert(compare(100,100) == "", "Unchanged capped chance must not show a change")
print("PASS: Shock chance tooltip gains, removals, zero baseline and unchanged cap")

local tooltip = { lines = {}, AddLine = function(self, size, line) table.insert(self.lines, {size=size,text=line}) end }
local count = build:CompareStatList(tooltip, build.displayStats, actor,
	{FullDPS=100, ShockChance=20, ElectrocuteBuildupAvg=10, TotalEHP=1000, Str=10},
	{FullDPS=120, ShockChance=25, ElectrocuteBuildupAvg=12.5, TotalEHP=900, Str=15}, "Node and path", 2)
assert(count == 5, "Headings must not change the returned stat count")
local headings, lines = {}, {}
for _, line in ipairs(tooltip.lines) do
	if line.size == 12 then table.insert(headings,line.text) end
	table.insert(lines,line.text)
end
assert(table.concat(headings,"|") == "^8Damage|^8Ailments|^8Survivability|^8Utility", "Only changed categories, in consistent order")
local text = table.concat(lines,"\n")
assert(text:find("+2.50%% Electrocute Buildup %(%+25.0%%%)"), "Buildup shows absolute and relative gain")
assert(text:find("per point",1,true), "Path comparison retains per-point values")
assert(text:find(colorCodes.NEGATIVE.."-100 Effective Hit Pool",1,true), "Loss colour and value retained")
assert(not compare(20,25):find("^8Ailments",1,true), "Single-category comparison has no heading")
local before = #tooltip.lines
build:CompareStatList(tooltip, build.displayStats, actor, {ShockChance=20}, {ShockChance=25}, "Node alone")
assert(tooltip.lines[before+1].text == "Node alone", "Node and path sections remain separate")
print("PASS: compact category headings, Electrocute buildup, losses and separate path comparisons")
