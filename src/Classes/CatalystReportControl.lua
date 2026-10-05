local shared = LoadModule("Modules/AugmentReport")
local report = LoadModule("Modules/CatalystReport")
local ReportClass = newClass("CatalystReportControl", "AugmentReportControl", function(self, anchor, rect, itemsTab)
	self.AugmentReportControl(anchor, rect, itemsTab)
	self.controls.title.label = "^7Catalyst recommendations"
	self.controls.existing.shown, self.controls.socket.shown = false, false
	self.controls.itemScore = new("CheckBoxControl", {"TOPLEFT", self, "TOPLEFT"}, {500, -78, 16}, "Rank by item modifiers", function()
		self.sortColumn, self.descending = 2, true
		self:Refresh()
	end, "Checked: sum each modifier's percentage gain after rounding, counting each modifier once. Unchecked: rank by the selected build metric.", true)
	self.controls.qualityLabel = new("LabelControl", {"TOPLEFT", self, "TOPLEFT"}, {520, -78, 0, 20}, "^7Quality:")
	self.controls.quality = new("EditControl", {"TOPLEFT", self, "TOPLEFT"}, {585, -78, 50, 20}, "20", nil, "%D", 3, function()
		self:Update()
	end)
	self.controls.quality.tooltipText = "Target catalyst quality for every candidate. The comparison starts without catalyst quality."
	self.controls.calculate.label = "Calculate catalyst recommendations"
	-- Parent constructors capture their class proxy; bind these callbacks to the
	-- catalyst control so refresh/calculate dispatch to this report's methods.
	self.controls.stat.selFunc = function(_, value)
		self.stat = value
		self.sortColumn, self.descending = 2, true
		self:Refresh()
	end
	self.controls.filter.selFunc = function() self:Refresh() end
	self.controls.search.changeFunc = function() self:Refresh() end
	self.controls.calculate.onClick = function() self:Calculate() end
	self.controls.stat.enabled = function() return not self.controls.itemScore.state end
	self.controls.calculate.enabled = function() return self.itemRaw and not self.worker and self:GetQuality() ~= nil end
	self.shown = function() return self.itemsTab.displayItem and self.itemsTab.displayItem:CanUseCatalysts() end
	self:Refresh()
end)

function ReportClass:GetQuality()
	local value = tonumber(self.controls.quality.buf)
	return value and value >= 0 and value <= 100 and math.floor(value) or nil
end

function ReportClass:SetItem(item)
	self.itemRaw = item and item:CanUseCatalysts() and item:BuildRaw() or nil
end

function ReportClass:Update()
	local item = self.itemsTab.displayItem
	local raw = item and self.itemRaw
	local slot = raw and self.itemsTab:GetComparisonSlotNameForItem(item)
	local quality = self:GetQuality()
	local key = raw and quality and (self.itemsTab.build.outputRevision .. "\n" .. tostring(slot) .. "\n" .. quality .. "\n" .. raw)
	if key ~= self.key then
		self:Cancel()
		self.key, self.result, self.failed = key, nil, nil
		self:Refresh()
	end
end

function ReportClass:Calculate()
	self:Update()
	if not self.key or self.worker then return end
	self.result, self.failed = nil, nil
	self:Refresh()
	local xml = self.itemsTab.build:SaveDB("catalyst comparison")
	if not xml then self:Fail("Could not read the current build."); return end
	local script = [[
		local root, xml, raw, slot, quality = ...
		local ok, result = pcall(function()
			return assert(loadfile(root .. "/Modules/AugmentReportWorker.lua"))(root, xml, raw, slot, nil, nil, nil, "catalyst", quality)
		end)
		if ok then return result else return nil, tostring(result) end
	]]
	self:StartWorker(script, xml, self.itemRaw, self.itemsTab:GetComparisonSlotNameForItem(self.itemsTab.displayItem), self:GetQuality())
end

function ReportClass:Refresh()
	self.tooltip:Clear()
	if not self.failed then self.controls.calculate.tooltipText = nil end
	local itemMode = self.controls.itemScore.state
	self.colList[1].label = "Catalyst"
	self.colList[2].label = itemMode and "Item score" or "Change"
	self.colList[3].label = itemMode and "Modifiers" or "Change %"
	self.colList[4].label = itemMode and "Quality" or "Result"
	self.list, self.selIndex, self.selValue = { }, nil, nil
	if self.result then
		local search, filter = (self.controls.search.buf or ""):lower(), self.controls.filter.selIndex
		for _, row in ipairs(self.result.rows) do
			local delta, benefit, percent, value
			if itemMode then
				delta, benefit, percent, value = row.score, row.score, #row.changes, self.result.quality
			elseif row.values then
				delta, benefit, percent, value = shared.Compare(self.result.baseline, row.values, self.stat)
			end
			local text = (row.name .. " " .. table.concat(row.lines, " ")):lower()
			if (search == "" or text:find(search, 1, true)) and
				(filter == 1 or (filter == 2 and benefit and benefit > 0) or (filter == 3 and benefit and benefit < 0)) then
				table.insert(self.list, { row = row, delta = delta, benefit = benefit, percent = percent, value = value })
			end
		end
		self.label = "No catalyst baseline | " .. self.result.quality .. "% quality | " .. #self.list .. " / " .. #self.result.rows
		if not itemMode and self.result.buildUnavailable then self.label = "Build comparison unavailable (hover Calculate for reason)"; self.controls.calculate.tooltipText = self.result.buildUnavailable end
	else
		self.label = self.failed and "Comparison unavailable (hover Calculate for reason)" or self.worker and "Calculating in background..." or "Click Calculate to compare catalysts"
	end
	self:Sort()
	self.controls.scrollBarV:SetContentDimension(#self.list * self.rowHeight, self:GetRowRegion().height)
end

function ReportClass:Sort()
	if not self.controls.itemScore.state then self.AugmentReportControl.Sort(self); return end
	local column, descending = self.sortColumn, self.descending
	local function key(entry)
		return column == 1 and entry.row.name or column == 3 and #entry.row.changes or column == 4 and entry.value or entry.row.score
	end
	table.sort(self.list, function(a, b)
		local av, bv = key(a), key(b)
		if av == bv then return a.row.name < b.row.name end
		return descending and av > bv or not descending and av < bv
	end)
end

function ReportClass:GetRowValue(column, row, entry)
	if not self.controls.itemScore.state then return self.AugmentReportControl.GetRowValue(self, column, row, entry) end
	if column == 1 then return entry.row.name end
	if column == 3 then return tostring(#entry.row.changes) end
	if column == 4 then return entry.value .. "%" end
	local color = entry.row.score > 0 and main.colorPositive or entry.row.score < 0 and main.colorNegative or "^7"
	return color .. formatNumSep(string.format("%.2f", entry.row.score))
end

function ReportClass:AddValueTooltip(tooltip, _, entry)
	if not tooltip:CheckForUpdate(entry, main:IsComparisonRevealHeld(), self.stat, self.controls.itemScore.state) then return end
	tooltip:AddLine(16, "^7" .. entry.row.name .. " at " .. self.result.quality .. "% quality")
	tooltip:AddLine(14, "^7Starts with the same item without catalyst quality.")
	for _, change in ipairs(entry.row.changes) do
		tooltip:AddSeparator(4)
		tooltip:AddLine(14, "^7" .. change.before .. " -> " .. change.after)
		tooltip:AddLine(14, change.percent and ("^7Modifier gain: " .. formatNumSep(string.format("%+.2f%%", change.percent))) or "^7Percentage undefined from a zero value; excluded from score.")
		if change.unsupported then tooltip:AddLine(14, "^1PoB does not model this modifier's build effects.") end
	end
	if #entry.row.changes == 0 then tooltip:AddLine(14, "^7No modifier changes.") end
	tooltip:AddSeparator(8)
	tooltip:AddLine(14, "^7Item score: " .. formatNumSep(string.format("%.2f", entry.row.score)) .. " points.")
	tooltip:AddLine(14, "^7Sum of modifier percentage gains; each modifier counts once.")
	tooltip:AddLine(14, "^7A ranking score, not the item's overall percentage improvement.")
	if self.result.buildUnavailable then
		tooltip:AddLine(14, "^7" .. self.result.buildUnavailable)
	elseif entry.row.comparison then
		tooltip:AddSeparator(8)
		tooltip:AddLine(14, "^7Same edited item equipped in " .. self.result.slot .. ".")
		tooltip:AddLine(14, "^7Uses current skills, gear and Configuration.")
		local output = shared.ComparisonOutput(self.result.baselineComparison, entry.row.comparison)
		self.itemsTab.build:AddStatComparesToTooltip(tooltip, self.result.baselineComparison, output, "^7Build stat changes:")
	end
end
