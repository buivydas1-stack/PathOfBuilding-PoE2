-- Run with tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_ring_comparison_order.lua.
arg = {}; dofile("HeadlessWrapper.lua")
newBuild()
local tab = build.itemsTab
local function ring(name, life)
	return new("Item", "Rarity: Rare\n" .. name .. "\nIron Ring\n--------\n+" .. life .. " to maximum Life")
end
local first, second = ring("First Ring", 200), ring("Second Ring", 10)
tab:AddItem(first, true); tab.slots["Ring 1"]:SetSelItemId(first.id)
tab:AddItem(second, true); tab.slots["Ring 2"]:SetSelItemId(second.id)
build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
main.showItemComparison = true; main.slotOnlyTooltips = false
local candidate = ring("Candidate Ring", 50)
local original = build.AddStatComparesToTooltip
local headers, outputs
build.AddStatComparesToTooltip = function(self, tooltip, before, after, header)
	headers[#headers + 1] = header
	outputs[#outputs + 1] = after
	return original(self, tooltip, before, after, header)
end
local function check(item, expected)
	headers, outputs = {}, {}
	tab:AddItemTooltip(new("Tooltip"), item)
	assert(#headers == #expected, "Unexpected comparison count: " .. #headers)
	for i, slot in ipairs(expected) do
		assert(headers[i]:find(slot, 1, true), "Unexpected comparison header: " .. headers[i])
	end
end
check(candidate, {"Ring 1", "Ring 2"})
assert(outputs[1].Life < outputs[2].Life, "Fixture must favour Ring 2 so benefit sorting cannot pass")
tab.slots["Ring 2"]:SetSelItemId(0)
check(candidate, {"Ring 1", "Ring 2"})
tab.slots["Ring 2"]:SetSelItemId(second.id)
check(first, {"Ring 1", "Ring 2"})
-- Limited uniques return before the benefit sorter; they also need stable slot order.
first.rarity = "UNIQUE"; second.rarity = "UNIQUE"
first.name = "Limited Ring"; second.name = "Limited Ring"
candidate.rarity = "UNIQUE"; candidate.name = "Limited Ring"; candidate.limit = 2
check(candidate, {"Ring 1", "Ring 2"})
main.slotOnlyTooltips = true
headers, outputs = {}, {}
tab:AddItemTooltip(new("Tooltip"), candidate, "Ring 2")
assert(#headers == 1 and headers[1]:find("Ring 2", 1, true), "Affected-slot-only setting must retain Ring 2")
build.AddStatComparesToTooltip = original
print("PASS: ring slot order with unequal gains, empty slot, removal, limited uniques and affected-slot-only comparisons")
