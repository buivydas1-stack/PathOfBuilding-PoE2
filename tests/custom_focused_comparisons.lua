arg = {}
dofile("HeadlessWrapper.lua")
newBuild()

local held = false
IsKeyDown = function(key) return key == main.comparisonRevealKey and held end
local actor = { mainSkill = { activeEffect = { statSet = { skillFlags = { hit = true } } } } }
local before = { FullDPS = 100, TotalEHP = 1000, ShockChance = 20, Str = 10 }
local after = { FullDPS = 120, TotalEHP = 900, ShockChance = 25, Str = 15 }
local function compare(viewMode, from, to)
	build.viewMode = viewMode
	local tooltip = { lines = {}, AddLine = function(self, _, line) table.insert(self.lines, line) end }
	local count = build:CompareStatList(tooltip, build.displayStats, actor, from or before, to or after, "Change")
	return count, table.concat(tooltip.lines, "\n")
end

local count, compact = compare("TREE")
assert(count == 4, "Hidden changes must still count")
assert(compact:find("Full DPS", 1, true) < compact:find("Effective Hit Pool", 1, true), "Priority stats must be first")
assert(not compact:find("Shock Chance", 1, true) and not compact:find("Strength", 1, true), "Other stats must be hidden")
assert(compact:find("Hold ALT to show other stat changes", 1, true), "Compact view must explain how to reveal changes")

held = true
local _, expanded = compare("TREE")
assert(expanded:find("Full DPS", 1, true) < expanded:find("Shock Chance", 1, true), "Full DPS must lead the expanded list")
assert(expanded:find("Effective Hit Pool", 1, true) < expanded:find("Shock Chance", 1, true), "EHP must lead the expanded list")
assert(expanded:find("Strength", 1, true), "Held key must reveal other stat changes")
held = false
assert(select(2, compare("ITEMS")) == compact, "Releasing the key must restore the compact Items view")

main.comparisonRevealKey = "F3"
assert(select(2, compare("ITEMS")):find("Hold F3", 1, true), "Hint must follow the selected key")
held = true
assert(select(2, compare("ITEMS")):find("Shock Chance", 1, true), "Selected key must reveal other changes")
held = false
main.comparisonRevealKey = "ALT"

local otherCount, otherOnly = compare("TREE", { ShockChance = 20 }, { ShockChance = 25 })
assert(otherCount == 1 and otherOnly:find("Hold ALT", 1, true), "Other-only changes need a reveal hint")
assert(not otherOnly:find("Shock Chance", 1, true), "Other-only changes remain hidden by default")
assert(select(2, compare("CALCS")):find("Shock Chance", 1, true), "Other views retain full comparisons")
print("PASS: focused Tree/Items comparisons, priority ordering, held-key reveal, and other views")
