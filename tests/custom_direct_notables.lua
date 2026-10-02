arg = { }
dofile("HeadlessWrapper.lua")
local function frame()
	build.buildFlag = true
	runCallback("OnFrame")
	runCallback("OnFrame")
end
local function count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end
newBuild()
build.skillsTab:PasteSocketGroup("Spark 20/0 1")
frame()
local spec = build.spec
local node = spec.tree.notableMap["Pure Power"] or spec.tree.notableMap["pure power"]
if node then node = spec.nodes[node.id] end
if not node then
	for _, candidate in pairs(spec.nodes) do
		if spec:CanDirectAllocateNotable(candidate) and candidate.pathDist > 4 and candidate.modKey ~= "" then node = candidate; break end
	end
end
assert(node and spec:CanDirectAllocateNotable(node))
local before, points = count(spec.allocNodes), spec:CountAllocNodes()
local calc, base = build.calcsTab:GetMiscCalculator()
local expected = calc({ addNodes = { [node] = true } }, true, { noEnvReuse = true })
assert(spec:ToggleDirectNotable(node))
assert(count(spec.allocNodes) == before + 1 and node.alloc)
assert(spec:CountAllocNodes() == points, "Direct allocation spent a point")
assert(#node.depends == 1 and node.depends[1] == node)
for _, neighbor in ipairs(node.linked) do
	if not neighbor.alloc then assert(neighbor.pathRoot ~= node, "Direct notable became a path root") end
end
frame()
local actual = build.calcsTab.mainOutput
for _, stat in ipairs({ "Life", "Mana", "TotalDPS" }) do
	if expected[stat] and actual[stat] then
		assert(math.abs(expected[stat] - actual[stat]) < 0.00001, "Wrong isolated calculation: "..stat)
	end
end
assert(#spec:GetUnsupportedDirectNotables(build.calcsTab.mainEnv) == 1)
local warningFound = false
for _, line in ipairs(build.controls.warnings.lines) do
	if line == "No equipped item grants "..node.dn then warningFound = true end
end
assert(warningFound, "Missing bottom-left warning")
print("PASS: isolated allocation, point count, calculation, path isolation and warning")

local state = spec:CreateUndoState()
local saved = { elem = "Spec" }
spec:Save(saved)
assert(saved.attrib.directNotables:find(tostring(node.id), 1, true))
assert(spec:ToggleDirectNotable(node) and not node.alloc)
spec:RestoreUndoState(state)
node = spec.nodes[node.id]
assert(node.alloc and spec.directNotables[node.id] and spec:CountAllocNodes() == points)
spec:ResetNodes()
spec:Load(saved, "disposable direct-notable fixture")
assert(node.alloc and spec.directNotables[node.id] and node.isFreeAllocate)
frame()
assert(#spec:GetUnsupportedDirectNotables(build.calcsTab.mainEnv) == 1)
print("PASS: save/load and undo restoration retain direct allocation and warning")

local amulet = new("Item", "Rarity: Rare\nDirect Notable Test\nGold Amulet\nAllocates "..node.dn)
assert(amulet.base and not amulet.modList[1].extra)
build.itemsTab:AddItem(amulet, true)
build.itemsTab.slots.Amulet:SetSelItemId(amulet.id)
frame()
assert(#spec:GetUnsupportedDirectNotables(build.calcsTab.mainEnv) == 0, "Equipped grant did not clear warning")
local withDirect = build.calcsTab.mainOutput.TotalDPS
spec:ToggleDirectNotable(node)
frame()
assert(build.calcsTab.mainOutput.TotalDPS == withDirect, "Item and direct allocation applied twice")
spec:ToggleDirectNotable(node)
build.itemsTab.slots.Amulet:SetSelItemId(0)
frame()
assert(#spec:GetUnsupportedDirectNotables(build.calcsTab.mainEnv) == 1, "Unequipping grant did not restore warning")
local input = build.configTab.configSets[build.configTab.activeConfigSetId].input
input.customMods = "Allocates "..node.dn
build.configTab:BuildModList()
frame()
assert(#spec:GetUnsupportedDirectNotables(build.calcsTab.mainEnv) == 1, "Custom modifier incorrectly counted as equipment")
spec:DeallocNode(node)
frame()
assert(not node.alloc and not spec.directNotables[node.id])
assert(#spec:GetUnsupportedDirectNotables(build.calcsTab.mainEnv) == 0)
assert(not spec:ToggleDirectNotable(spec.nodes[spec.curClass.startNodeId]))
print("PASS: equipped grants, no double count, item removal, custom-mod warning and normal-click removal")

-- Exercise the actual tree input handler without controlling the desktop.
input.customMods = nil
build.configTab:BuildModList()
frame()
local viewer = build.treeTab.viewer
local keys = { ALT = true, SHIFT = true }
local oldKey, oldCursor = IsKeyDown, GetCursorPos
IsKeyDown = function(key) return keys[key] or false end
local viewport = { x = 350, y = 50, width = 1000, height = 800 }
viewer.zoom, viewer.zoomX, viewer.zoomY = 1, -node.x * 800 / spec.tree.size, -node.y * 800 / spec.tree.size
GetCursorPos = function() return viewport.x + viewport.width / 2, viewport.y + viewport.height / 2 end
local function click()
	viewer:Draw(build, viewport, { { type = "KeyDown", key = "LEFTBUTTON" }, { type = "KeyUp", key = "LEFTBUTTON" } })
end
click()
assert(node.alloc and spec.directNotables[node.id], "Alt+click did not allocate")
click()
assert(not node.alloc and not spec.directNotables[node.id], "Alt+click did not unallocate")
IsKeyDown, GetCursorPos = oldKey, oldCursor
local tooltip = new("Tooltip")
viewer:AddNodeTooltip(tooltip, node, build, 0)
local function tooltipText(t)
	local text = { }
	for _, line in ipairs(t.lines) do
		for _, value in pairs(line) do
			if type(value) == "string" then table.insert(text, value) end
		end
	end
	return table.concat(text, "\n")
end
assert(tooltipText(tooltip):find("Alt+left-click", 1, true), "Missing notable shortcut tooltip")
local attribute
for _, candidate in pairs(spec.nodes) do if candidate.isAttribute then attribute = candidate; break end end
assert(attribute)
tooltip:Clear()
viewer:AddNodeTooltip(tooltip, attribute, build, 0)
local text = tooltipText(tooltip)
assert(text:find("Right-click to cycle", 1, true) and text:find("1/I (Int), 2/S (Str), or 3/D (Dex)", 1, true), "Missing attribute hints")
print("PASS: actual Alt+click handler and notable/attribute tooltip text")
