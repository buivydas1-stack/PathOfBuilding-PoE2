local shared = LoadModule("Modules/AugmentReport")
local report = LoadModule("Modules/CatalystReport")
local ReportClass = newClass("CatalystReportControl", "AugmentReportControl", function(self, anchor, rect, itemsTab)
	self.AugmentReportControl(anchor, rect, itemsTab)
	self.colList = {
		{ label = "Catalyst", sortable = true },
		{ label = "Sum of modifier gains (%)", sortable = true, textHeight = 17 },
		{ sortable = true, textHeight = 17 },
		{ sortable = true, textHeight = 17 },
	}
	self.controls.title.label = function() return (self.unavailableReason and "^8" or "^7") .. "Catalyst recommendations" end
	self.enabled = function() return not self.unavailableReason end
	self.controls.existing.shown = false
	self.controls.socket.x, self.controls.socket.y, self.controls.socket.width = 0, -28, 240
	self.controls.socket:SetList({ })
	self.controls.socket.shown = function()
		local item = self.itemsTab.displayItem
		return item and (item.type == "Jewel" or item.type == "Ring")
	end
	self.controls.socket.enabled = function() return not self.unavailableReason and #self.controls.socket.list > 0 end
	self.controls.socket.selFunc = function(_, selected)
		if self.itemsTab.displayItem and self.itemsTab.displayItem.type == "Ring" then self.ringSlot = selected.slotName end
		self:Update()
	end
	self.controls.socket.tooltipText = "Slot to use for build comparisons, including occupied jewel sockets. Replaces only the selected slot and keeps the other items equipped."
	self.controls.status = new("LabelControl", {"TOPLEFT", self, "BOTTOMLEFT"}, {0, 4, 0, 16}, function() return (self.unavailableReason and "^8" or "^7") .. (self.statusLabel or "") end)
	self.controls.status.shown = self.controls.socket.shown
	self.controls.qualityLabel = new("LabelControl", {"TOPLEFT", self, "TOPLEFT"}, {520, -78, 0, 20}, function() return (self.unavailableReason and "^8" or "^7") .. "Quality:" end)
	self.controls.quality = new("EditControl", {"TOPLEFT", self, "TOPLEFT"}, {585, -78, 72, 20}, "20", nil, "%D", 3, function()
		self:Update()
	end)
	self.controls.quality.tooltipText = "Target catalyst quality for every candidate. The comparison starts without catalyst quality."
	self.controls.calculate.label = "Calculate catalyst recommendations"
	-- Parent constructors capture their class proxy; bind these callbacks to the
	-- catalyst control so refresh/calculate dispatch to this report's methods.
	self.controls.stat.selFunc = function(_, value)
		self.stat = value
		self:Refresh()
	end
	self.controls.filter.selFunc = function() self:Refresh() end
	self.controls.search.changeFunc = function() self:Refresh() end
	self.controls.calculate.onClick = function() self:Calculate() end
	for _, name in ipairs({ "stat", "filter", "search", "quality" }) do
		self.controls[name].enabled = function() return not self.unavailableReason end
	end
	for _, name in ipairs({ "buttonUp", "buttonDown" }) do
		self.controls.quality.controls[name].enabled = function() return not self.unavailableReason end
	end
	self.controls.stat.tooltipText = "Build stat to display alongside modifier gains. Click a column header to sort; click again to reverse. Compares the same item without catalyst quality against each catalyst at the target quality."
	self.controls.filter.tooltipText = "Gains and losses refer to the selected build stat, independently of the sorting column."
	self.controls.calculate.enabled = function() return not self.unavailableReason and self.itemRaw and not self.worker and self:GetQuality() ~= nil end
	self.shown = function() return self.itemsTab.displayItem and self.itemsTab.displayItem:CanUseCatalysts() end
	self:Refresh()
end)

function ReportClass:GetQuality()
	local value = tonumber(self.controls.quality.buf)
	return value and value >= 0 and value <= 100 and math.floor(value) or nil
end

function ReportClass:ApplyEntry(entry)
	self:Update()
	local item = self.itemsTab.displayItem
	if not item or self.unavailableReason or not self.result or self.worker or self.itemRaw ~= item:BuildRaw() then return end
	local current = false
	for _, value in ipairs(self.list) do if value == entry then current = true; break end end
	if not current or not entry.row.id then return end
	self.itemsTab:SetDisplayItemCatalystQuality(self.result.quality, entry.row.id, true)
end

function ReportClass:OnSelClick(_, entry, doubleClick)
	if doubleClick then self:ApplyEntry(entry) end
end

function ReportClass:OpenApplyMenu(entry)
	self.tooltip:Clear()
	local x, y = GetCursorPos()
	local popup
	local controls = { }
	controls.apply = new("ButtonControl", {"CENTER",nil,"CENTER"}, {0, 0, 172, 24}, "Apply to item", function()
		main:ClosePopup()
		self:ApplyEntry(entry)
	end)
	popup = main:OpenPopup(180, 32, "", controls, "apply")
	popup.x, popup.y = math.min(x, main.screenW-180), math.min(y, main.screenH-32)
	function popup:Draw(viewPort)
		local menuX, menuY = self:GetPos()
		SetDrawColor(0.5, 0.5, 0.5); DrawImage(nil, menuX, menuY, 180, 32)
		SetDrawColor(0, 0, 0); DrawImage(nil, menuX+1, menuY+1, 178, 30)
		self:DrawControls(viewPort)
	end
	local process = popup.ProcessInput
	function popup:ProcessInput(events, viewPort)
		for _, event in pairs(events) do
			if event.type == "KeyDown" and event.key:match("BUTTON") and not self:IsMouseInBounds() then main:ClosePopup(); return end
		end
		return process(self, events, viewPort)
	end
	return popup
end

function ReportClass:OnKeyDown(key, doubleClick)
	if key ~= "RIGHTBUTTON" then return self.ListControl.OnKeyDown(self, key, doubleClick) end
	if not self:IsShown() or not self:IsEnabled() or self:GetMouseOverControl() then return end
	local index = self:GetHoverIndex()
	local entry = index and self.list[index]
	if entry and self:SelectIndex(index) then self:OpenApplyMenu(entry); return self end
end

function ReportClass:SetItem(item)
	self.itemRaw = item and item:CanUseCatalysts() and item:BuildRaw() or nil
	self.unavailableReason = report.UnavailableReason(item)
	self:UpdateComparisonSlots(item)
	self:Update()
end

function ReportClass:UpdateComparisonSlots(item)
	local options, selected = { }, self.controls.socket.list[self.controls.socket.selIndex or 0]
	local preferred = self.slotItem == item and selected and selected.slotName or item and self.itemsTab:GetComparisonSlotNameForItem(item)
	if item and item.type == "Ring" and self.slotItem ~= item then
		local equipped = self.itemsTab:GetEquippedSlotForItem(item)
		preferred = equipped and equipped.slotName or self.ringSlot or "Ring 1"
	end
	if item and (item.type == "Jewel" or item.type == "Ring") then
		for _, slot in ipairs(self.itemsTab.orderedSlots) do
			local eligible = item.type == "Ring" and slot.slotName:match("^Ring %d$") or
				item.type == "Jewel" and (slot.parentSlot or slot.nodeId and self.itemsTab.build.spec.allocNodes[slot.nodeId])
			if eligible and not slot.inactive and slot:IsShown() and
				self.itemsTab:IsItemValidForSlot(item, slot.slotName) then
				local label = slot.nodeId and ("Jewel " .. slot.label) or slot.slotName
				table.insert(options, { label = "Compare: " .. label, slotName = slot.slotName })
			end
		end
	end
	self.controls.socket:SetList(options)
	self.controls.socket.selIndex = 1
	for index, option in ipairs(options) do
		if option.slotName == preferred then self.controls.socket:SetSel(index, true); break end
	end
	self.slotItem, self.slotRevision = item, self.itemsTab.build.outputRevision
end

function ReportClass:GetComparisonSlot()
	local item = self.itemsTab.displayItem
	if not item then return end
	if item.type == "Jewel" or item.type == "Ring" then
		local selected = self.controls.socket.list[self.controls.socket.selIndex or 0]
		return selected and selected.slotName
	end
	return self.itemsTab:GetComparisonSlotNameForItem(item)
end

function ReportClass:Update()
	local item = self.itemsTab.displayItem
	if self.slotRevision ~= self.itemsTab.build.outputRevision then self:UpdateComparisonSlots(item) end
	local raw = item and not self.unavailableReason and self.itemRaw
	local slot = raw and self:GetComparisonSlot()
	local quality = self:GetQuality()
	local key = raw and quality and (self.itemsTab.build.outputRevision .. "\n" .. tostring(slot) .. "\n" .. quality .. "\n" .. raw)
	if key ~= self.key or self.unavailableReason ~= self.previousUnavailableReason then
		self:Cancel()
		self.previousUnavailableReason = self.unavailableReason
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
	self:StartWorker(script, xml, self.itemRaw, self:GetComparisonSlot(), self:GetQuality())
	self:Refresh()
end

function ReportClass:Fail(err)
	self.AugmentReportControl.Fail(self, err)
	self:Refresh()
end

function ReportClass:Refresh()
	self.tooltip:Clear()
	if not self.failed then self.controls.calculate.tooltipText = self.unavailableReason end
	local metric = self.stat.stat == "TotalEHP" and "EHP" or self.stat.stat == "FullDPS" and "Full DPS"
	self.colList[3].label = metric and (metric .. " gain") or "Stat change"
	self.colList[4].label = metric and (metric .. " increase (%)") or "Stat change (%)"
	self.colList[1].label, self.colList[2].label = "Catalyst", "Sum of modifier gains (%)"
	if self.unavailableReason then
		for _, column in ipairs(self.colList) do column.label = "^8" .. column.label end
	end
	for column = 2, 4 do
		self.colList[column].width = math.max(column == 2 and 180 or 100, DrawStringWidth(12, "VAR", self.colList[column].label) + 20)
	end
	self.colList[1].width = function()
		return self:GetRowRegion().width - self.colList[2].width - self.colList[3].width - self.colList[4].width
	end
	self.list, self.selIndex, self.selValue = { }, nil, nil
	if self.unavailableReason then
		self.label = "Catalyst comparison disabled (hover Calculate for reason)"
	elseif self.result then
		local search, filter = (self.controls.search.buf or ""):lower(), self.controls.filter.selIndex
		for _, row in ipairs(self.result.rows) do
			local delta, benefit, percent, value
			if row.values then
				delta, benefit, percent, value = shared.Compare(self.result.baseline, row.values, self.stat)
			end
			local text = (row.name .. " " .. table.concat(row.lines, " ")):lower()
			if (search == "" or text:find(search, 1, true)) and
				(filter == 1 or (filter == 2 and benefit and benefit > 0) or (filter == 3 and benefit and benefit < 0)) then
				table.insert(self.list, { row = row, delta = delta, benefit = benefit, percent = percent, value = value })
			end
		end
		self.label = "No catalyst baseline | " .. self.result.quality .. "% quality | " .. #self.list .. " / " .. #self.result.rows
		if self.result.buildUnavailable then
			self.label = self.label .. " | Build gains unavailable"
			self.controls.calculate.tooltipText = self.result.buildUnavailable
		end
	else
		self.label = self.failed and "Comparison unavailable (hover Calculate for reason)" or self.worker and "Calculating in background..." or "Click Calculate to compare catalysts"
	end
	local selector = self.controls.socket:IsShown()
	self.statusLabel = self.label
	self.label = not selector and ((self.unavailableReason and "^8" or "^7") .. self.label) or nil
	self.controls.calculate.y = selector and 24 or 4
	self:Sort()
	self.controls.scrollBarV:SetContentDimension(#self.list * self.rowHeight, self:GetRowRegion().height)
end

function ReportClass:Sort()
	local column, descending = self.sortColumn, self.descending
	local function key(entry)
		if column == 1 then return entry.row.name end
		if column == 2 then return entry.row.score end
		if column == 3 then return entry.benefit end
		return entry.percent and (self.stat.transform and -entry.percent or entry.percent)
	end
	table.sort(self.list, function(a, b)
		local av, bv = key(a), key(b)
		if av == bv then return a.row.name < b.row.name end
		if av == nil then return false elseif bv == nil then return true end
		return descending and av > bv or not descending and av < bv
	end)
end

function ReportClass:GetRowValue(column, _, entry)
	if column == 1 then return entry.row.name end
	local value = column == 2 and entry.row.score or column == 3 and entry.delta or entry.percent
	if value == nil then return "N/A" end
	local benefit = column == 2 and entry.row.score or entry.benefit
	local color = benefit and (benefit > 0 and main.colorPositive or benefit < 0 and main.colorNegative) or "^7"
	return color .. formatNumSep(string.format("%+.2f", value)) .. (column ~= 3 and "%" or "")
end

function ReportClass:Draw(viewPort, noTooltip)
	self.ListControl.Draw(self, viewPort, noTooltip)
	local x, y = self:GetPos()
	local column = self.colList[self.sortColumn]
	if not self.unavailableReason and column and column._width then
		SetDrawColor(1, 1, 1)
		main:DrawArrow(x + column._offset + column._width - 7, y + 10, 6, 6, self.descending and "DOWN" or "UP")
	end
end

function ReportClass:AddValueTooltip(tooltip, _, entry)
	if main.popups[1] then tooltip:Clear(); return end
	if not tooltip:CheckForUpdate(entry, main:IsComparisonRevealHeld(), self.stat) then return end
	tooltip:AddLine(16, "^7" .. entry.row.name .. " at " .. self.result.quality .. "% quality")
	tooltip:AddLine(14, "^7Double-click to apply to item; right-click for the menu.")
	tooltip:AddLine(14, "^7Starts with the same item without catalyst quality.")
	for _, change in ipairs(entry.row.changes) do
		tooltip:AddSeparator(4)
		tooltip:AddLine(14, "^7" .. change.before .. " -> " .. change.after)
		tooltip:AddLine(14, change.percent and ("^7Modifier gain: " .. formatNumSep(string.format("%+.2f%%", change.percent))) or "^7Percentage undefined from a zero value; excluded from score.")
		if change.unsupported then tooltip:AddLine(14, "^1PoB does not model this modifier's build effects.") end
	end
	if #entry.row.changes == 0 then tooltip:AddLine(14, "^7No modifier changes.") end
	tooltip:AddSeparator(8)
	tooltip:AddLine(14, "^7Sum of modifier gains: " .. formatNumSep(string.format("%+.2f%%", entry.row.score)))
	tooltip:AddLine(14, "^7Changed modifiers: " .. #entry.row.changes)
	tooltip:AddLine(14, "^7Sum of modifier percentage gains; each modifier counts once.")
	tooltip:AddLine(14, "^7A ranking score, not the item's overall percentage improvement.")
	if self.result.buildUnavailable then
		tooltip:AddLine(14, "^7" .. self.result.buildUnavailable)
	elseif entry.row.comparison then
		tooltip:AddSeparator(8)
		tooltip:AddLine(14, "^7Same edited item equipped in " .. self.result.slot .. ".")
		tooltip:AddLine(14, "^7Uses current skills, gear and Configuration.")
		if entry.value then
			tooltip:AddLine(14, "^7" .. self.stat.label .. ": " .. formatNumSep(string.format("%.2f", self.result.baseline[self.stat.stat])) .. " -> " .. formatNumSep(string.format("%.2f", entry.value)))
			tooltip:AddLine(14, "^7Percentage change is relative to this build stat with the same item at no catalyst quality.")
		end
		local output = shared.ComparisonOutput(self.result.baselineComparison, entry.row.comparison)
		self.itemsTab.build:AddStatComparesToTooltip(tooltip, self.result.baselineComparison, output, "^7Build stat changes:")
	end
end
