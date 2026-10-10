-- Stat selectors share one saved order without changing their selected metric,
-- calculation results or menu-specific entries. LoadModule is not cached, so
-- keep the weak control registry on main rather than in a module-local table.
local order = { }
local defaultIds = { "FullDPS", "ManaCost", "ManaPerSecondCost", "TotalEHP", "FullDPSAndEHP" }

function order.Id(entry)
	return type(entry) == "table" and (entry.stat or (entry.combinedOffDef and "OffenceDefence")) or nil
end

function order.Apply(list)
	local byId, sorted, slots = { }, { }, { }
	for index, entry in ipairs(list) do
		local id = order.Id(entry)
		if id then byId[id] = entry; table.insert(slots, index) end
	end
	for _, id in ipairs(main.powerStatOrder or { }) do
		if byId[id] then table.insert(sorted, byId[id]); byId[id] = nil end
	end
	for _, id in ipairs(defaultIds) do
		if byId[id] then table.insert(sorted, byId[id]); byId[id] = nil end
	end
	for _, entry in ipairs(list) do
		local id = order.Id(entry)
		if id and byId[id] then table.insert(sorted, entry); byId[id] = nil end
	end
	for index, slot in ipairs(slots) do list[slot] = sorted[index] end
	return list
end

function order.Sync()
	for control, extraLists in pairs(main.powerStatControls or { }) do
		local selected = control.list[control.selIndex]
		for _, list in ipairs(extraLists) do order.Apply(list) end
		order.Apply(control.list)
		for index, entry in ipairs(control.list) do
			if entry == selected then control.selIndex = index; break end
		end
		control:UpdateSearch()
	end
end

function order.Reorder(control, target)
	local visible = control.list
	local moved = order.Id(visible[target])
	if not moved then return end
	local master, seen = { }, { }
	local function add(id)
		if id and id ~= moved and not seen[id] then table.insert(master, id); seen[id] = true end
	end
	for _, id in ipairs(main.powerStatOrder or { }) do add(id) end
	-- Complete the master order, including metrics hidden in the current menu.
	for _, id in ipairs(defaultIds) do add(id) end
	for _, entry in ipairs(data.powerStatList) do add(order.Id(entry)) end
	for other, extraLists in pairs(main.powerStatControls or { }) do
		for _, list in ipairs(extraLists) do
			for _, entry in ipairs(list) do add(order.Id(entry)) end
		end
		for _, entry in ipairs(other.list) do add(order.Id(entry)) end
	end
	local nextId, previousId = order.Id(visible[target + 1]), order.Id(visible[target - 1])
	local insertAt = #master + 1
	for index, id in ipairs(master) do
		if nextId and id == nextId then insertAt = index; break end
		if not nextId and id == previousId then insertAt = index + 1; break end
	end
	table.insert(master, insertAt, moved)
	main.powerStatOrder = master
	order.Sync()
	main:SaveSettings()
end

function order.Bind(control, extraLists)
	main.powerStatControls = main.powerStatControls or setmetatable({ }, { __mode = "k" })
	main.powerStatControls[control] = extraLists or { }
	control.reorderAllowed = function(source, target)
		return order.Id(control.list[source]) ~= nil and order.Id(control.list[target]) ~= nil
	end
	control.reorderFunc = function(_, target) order.Reorder(control, target) end
	local selected = control.list[control.selIndex]
	order.Apply(control.list)
	for index, entry in ipairs(control.list) do
		if entry == selected then control.selIndex = index; break end
	end
	control:UpdateSearch()
end

return order
