-- The calculation runs in an isolated Lua thread. Drawing, sorting, filtering
-- and hovering use only completed numeric snapshots.
local report = LoadModule("Modules/AugmentReport")
local json = require("dkjson")
local ReportClass = newClass("AugmentReportControl", "ListControl", function(self, anchor, rect, itemsTab)
	self.ListControl(anchor, rect, 18, "VERTICAL", false)
	self.itemsTab = itemsTab
	self.colLabels = true
	self.colList = {
		{ width = 300, label = "Augment", sortable = true },
		{ width = 110, label = "Change", sortable = true },
		{ width = 100, label = "Change %", sortable = true },
		{ width = 120, label = "Result", sortable = true },
	}
	self.sortColumn = 2
	self.descending = true
	self.label = "One augment; all other sockets empty"
	self.controls.title = new("LabelControl", {"TOPLEFT", self, "TOPLEFT"}, {0, -76, 0, 16}, "^7Augment recommendations")
	self.controls.existing = new("CheckBoxControl", {"TOPLEFT", self, "TOPLEFT"}, {500, -78, 16}, "Consider existing augments", nil,
		"Unchecked: start with all sockets empty. Checked: replace the chosen socket and keep every other augment.", false)
	self.controls.socket = new("DropDownControl", {"TOPLEFT", self, "TOPLEFT"}, {525, -78, 113, 20}, {"Socket #1"})
	self.controls.socket.enabled = function() return self.controls.existing.state end
	local stats = report.GetStats()
	self.stat = stats[1]
	self.controls.stat = new("DropDownControl", {"TOPLEFT", self, "TOPLEFT"}, {0, -54, 240, 20}, stats, function(_, value)
		self.stat = value
		self.sortColumn, self.descending = 2, true
		self:Refresh()
	end)
	self.controls.filter = new("DropDownControl", {"TOPLEFT", self, "TOPLEFT"}, {246, -54, 145, 20}, {"All changes", "Gains only", "Losses only"}, function()
		self:Refresh()
	end)
	self.controls.search = new("EditControl", {"TOPLEFT", self, "TOPLEFT"}, {397, -54, 241, 20}, "", "Filter name / modifier", nil, nil, function() self:Refresh() end)
	self.controls.calculate = new("ButtonControl", {"TOPLEFT", self, "BOTTOMLEFT"}, {0, 4, 270, 20}, "Calculate augment recommendations", function() self:Calculate() end)
	self.controls.calculate.enabled = function() return self.itemRaw and not self.worker end
	self.shown = function()
		local item = self.itemsTab.displayItem
		return item and item.itemSocketCount > 0
	end
end)

function ReportClass:SetItem(item)
	-- BuildRaw is called on edits, never on every draw frame. Preserve the item ID
	-- separately: it chooses the comparison slot but is absent from clipboard text.
	self.itemRaw = item and item.itemSocketCount > 0 and item:BuildRaw() or nil
	local sockets = { }
	for i = 1, item and item.itemSocketCount or 0 do sockets[i] = "Socket #" .. i end
	self.controls.socket:SetList(sockets)
	self.controls.socket.selIndex = math.min(self.controls.socket.selIndex or 1, math.max(1, #sockets))
end

function ReportClass:Cancel()
	self.generation = (self.generation or 0) + 1
	if self.worker then
		-- Completion can race cancellation; stale callbacks are rejected below.
		pcall(AbortSubScript, self.worker)
		launch.subScripts[self.worker] = nil
		self.worker = nil
	end
end

function ReportClass:Update()
	local item = self.itemsTab.displayItem
	local slot = item and self.itemsTab:GetComparisonSlotNameForItem(item)
	local revision = self.itemsTab.build.outputRevision
	local existing, socketIndex = self.controls.existing.state, self.controls.socket.selIndex
	local key = self.itemRaw and slot and (revision .. "\n" .. slot .. "\n" .. tostring(existing) .. "\n" .. socketIndex .. "\n" .. self.itemRaw)
	if key ~= self.key then
		self:Cancel()
		self.key, self.result, self.failed = key, nil, nil
		self:Refresh()
	end
end

function ReportClass:Calculate()
	self:Update()
	if self.key and not self.worker then
		local slot = self.itemsTab:GetComparisonSlotNameForItem(self.itemsTab.displayItem)
		local existing, socketIndex = self.controls.existing.state, self.controls.socket.selIndex
		self.result, self.failed = nil, nil
		self:Refresh()
		local xml = self.itemsTab.build:SaveDB("augment comparison")
		if not xml then self:Fail("Could not read the current build."); return end
		local generation = self.generation
		local script = [[
			local root, xml, raw, slot, existing, socketIndex = ...
			local ok, result = pcall(function()
				return assert(loadfile(root .. "/Modules/AugmentReportWorker.lua"))(root, xml, raw, slot, nil, existing, socketIndex)
			end)
			if ok then return result else return nil, tostring(result) end
		]]
		local id = LaunchSubScript(script, "", "", GetScriptPath(), xml, self.itemRaw, slot, existing, socketIndex)
		if not id then self:Fail("Could not start the background calculation."); return end
		self.worker = id
		self.label = "Calculating in background..."
		launch:RegisterSubScript(id, function(encoded, err)
			if generation ~= self.generation then return end
			self.worker = nil
			if not encoded then self:Fail(err); return end
			local result, _, decodeError = json.decode(encoded)
			if decodeError or not result or not result.baseline or not result.rows then
				self:Fail("Invalid calculation result."); return
			end
			self.result = result
			self:Refresh()
		end, function(err)
			if generation == self.generation then self.worker = nil; self:Fail(err) end
		end)
	end
end

function ReportClass:Fail(err)
	self.failed = tostring(err or "Background calculation failed.")
	self.label = "Comparison unavailable (hover Calculate for reason)"
	self.controls.calculate.tooltipText = self.failed
end

function ReportClass:Refresh()
	self.tooltip:Clear()
	if not self.failed then self.controls.calculate.tooltipText = nil end
	self.list = { }
	self.selIndex, self.selValue = nil, nil
	if self.result then
		local search = (self.controls.search.buf or ""):lower()
		local filter = self.controls.filter.selIndex
		for _, row in ipairs(self.result.rows) do
			local delta, benefit, percent, value = report.Compare(self.result.baseline, row.values, self.stat)
			local text = (row.name .. " " .. table.concat(row.lines, " ")):lower()
			if (search == "" or text:find(search, 1, true)) and
				(filter == 1 or (filter == 2 and benefit and benefit > 0) or (filter == 3 and benefit and benefit < 0)) then
				table.insert(self.list, { row = row, delta = delta, benefit = benefit, percent = percent, value = value })
			end
		end
		self.label = self.result.slot .. (self.result.considerExisting and (" | Replace socket #" .. self.result.socketIndex) or " | One augment; other sockets empty") .. " | " .. #self.list .. " / " .. #self.result.rows
		if self.result.excluded > 0 then self.label = self.label .. " | " .. self.result.excluded .. " at limit" end
	else
		self.label = self.failed and "Comparison unavailable (hover Calculate for reason)" or self.worker and "Calculating in background..." or "Click Calculate to compare eligible augments"
	end
	self:Sort()
	self.controls.scrollBarV:SetContentDimension(#self.list * self.rowHeight, self:GetRowRegion().height)
end

function ReportClass:ReSort(column)
	if column == self.sortColumn then self.descending = not self.descending else self.descending = column > 1 end
	self.sortColumn = column
	self:Sort()
end

function ReportClass:Sort()
	local column, descending = self.sortColumn, self.descending
	local function key(entry)
		if column == 1 then return entry.row.name end
		if column == 4 then return entry.value end
		if column == 3 then return entry.percent and (self.stat.transform and -entry.percent or entry.percent) end
		return entry.benefit
	end
	table.sort(self.list, function(a, b)
		local av, bv = key(a), key(b)
		if av == bv then return a.row.name < b.row.name end
		if av == nil then return false elseif bv == nil then return true end
		return descending and av > bv or not descending and av < bv
	end)
end

local function number(value, signed)
	if value == nil then return "N/A" end
	return string.format(signed and "%+.2f" or "%.2f", value)
end

function ReportClass:GetRowValue(column, _, entry)
	local color = entry.benefit and (entry.benefit > 0 and main.colorPositive or entry.benefit < 0 and main.colorNegative) or "^7"
	return column == 1 and entry.row.name or color .. (column == 2 and number(entry.delta, true) or column == 3 and (number(entry.percent, true) .. (entry.percent and "%" or "")) or number(entry.value))
end

function ReportClass:AddValueTooltip(tooltip, _, entry)
	if tooltip:CheckForUpdate(entry) then
		tooltip:AddLine(16, "^7" .. entry.row.name)
		for _, line in ipairs(entry.row.lines) do tooltip:AddLine(14, "^7" .. line) end
		tooltip:AddSeparator(8)
		tooltip:AddLine(14, "^7Same edited item equipped in " .. self.result.slot .. ".")
		tooltip:AddLine(14, self.result.considerExisting and ("^7Replaces socket #" .. self.result.socketIndex .. "; keeps all other augments.") or "^7Adds one augment; all other sockets start empty.")
		tooltip:AddLine(14, "^7Uses current skills, gear and Configuration.")
		tooltip:AddLine(14, "^7" .. self.stat.label .. ": " .. number(self.result.baseline[self.stat.stat]) .. " -> " .. number(entry.value))
		for _, stat in ipairs(self.controls.stat.list) do
			local delta, benefit, percent = report.Compare(self.result.baseline, entry.row.values, stat)
			if delta and math.abs(delta) > 0.000001 then
				local color = benefit > 0 and main.colorPositive or main.colorNegative
				tooltip:AddLine(14, color .. number(delta, true) .. " " .. stat.label .. (percent and " (" .. number(percent, true) .. "%)" or ""))
			end
		end
	end
end
