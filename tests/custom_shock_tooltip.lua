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
