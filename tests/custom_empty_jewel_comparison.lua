arg = {}; dofile("HeadlessWrapper.lua")
newBuild()
local tab = build.itemsTab
local sockets = {}
for _, node in pairs(build.spec.nodes) do
	if node.type == "Socket" and node.path and not node.ascendancyName and not node.charmSocket and not node.sinister then
		sockets[#sockets + 1] = node
	end
end
table.sort(sockets, function(a, b) return a.id < b.id end)
assert(#sockets >= 3)
for i = 1, 3 do build.spec:AllocNode(sockets[i]) end
tab:UpdateSockets()
local empty = new("Item", "Rarity: Rare\nEmpty Eye\nEmerald")
local life = new("Item", "Rarity: Rare\nLife Eye\nEmerald\n--------\n+20 to maximum Life")
tab:AddItem(life, true)
tab.sockets[sockets[2].id]:SetSelItemId(life.id)
build.buildFlag = true; runCallback("OnFrame"); runCallback("OnFrame")
main.showItemComparison = true; main.slotOnlyTooltips = false
build.viewMode = "ITEMS"
local function capture(item, slot)
	local tooltip = new("Tooltip")
	local lines = {}
	local original = tooltip.AddLine
	tooltip.AddLine = function(self, size, text, ...)
		lines[#lines + 1] = text
		return original(self, size, text, ...)
	end
	tab:AddItemTooltip(tooltip, item, slot)
	return table.concat(lines, "\n")
end
local text = capture(empty)
for i = 1, 3 do
	assert(text:find("Equipping this item in " .. tab.sockets[sockets[i].id].label, 1, true), "Missing socket comparison")
end
local _, count = text:gsub("No stat changes", "")
assert(count == #tab.activeSocketList - 1, "Every empty zero-change socket needs a result")
assert(text:find("replacing ", 1, true), "Occupied replacement must remain visible")
main.slotOnlyTooltips = true
local slot = tab.sockets[sockets[1].id]
text = capture(empty, slot.slotName)
assert(text:find(slot.label, 1, true) and text:find("No stat changes", 1, true))
text = capture(life, slot.slotName)
assert(text:find("Life", 1, true) and not text:find("No stat changes", 1, true), "Real gains must not be labelled unchanged")
-- Detailed-only changes still count even while Alt details are collapsed.
assert(text:find("Hold", 1, true), "Fixture must exercise collapsed stat details")
build.spec:DeallocNode(sockets[1])
tab:UpdateSockets()
main.slotOnlyTooltips = false
text = capture(empty)
local _, headers = text:gsub("Equipping this item in Socket #", "")
assert(headers == #tab.activeSocketList, "Only allocated sockets may appear")
print("PASS: empty jewel sockets, zero changes, real gains, occupied replacement, affected slot and unallocated exclusion")
