-- Path of Building
--
-- Class: Power Report
-- Power Report control.
--

local t_insert = table.insert
local t_remove = table.remove
local t_sort = table.sort

local PowerReportListClass = newClass("PowerReportListControl", "ListControl", function(self, anchor, rect, nodeSelectCallback, nodeIgnoreCallback, ignoredNodes)
	self.ListControl(anchor, rect, 16, "VERTICAL", false)

	local width = rect[3]
	self.powerColumn = { width = width * 0.16, label = "", sortable = true }
	self.colList = {
		{ width = width * 0.15, label = "Type", sortable = true },
		{ width = width * 0.45, label = "Node Name" },
		self.powerColumn,
		{ width = width * 0.05, label = "Points", sortable = true },
		{ width = width * 0.16, label = "Per Point", sortable = true },
	}
	self.colLabels = true
	self.nodeSelectCallback = nodeSelectCallback
	self.nodeIgnoreCallback = nodeIgnoreCallback
	self.ignoredNodes = ignoredNodes or { }
	self.showClusters = false
	self.allocated = false
	self.label = "Building Tree..."
	
	self.controls.filterSelect = new("DropDownControl", {"BOTTOMRIGHT", self, "TOPRIGHT"}, {0, -2, 200, 20},
		{ "Show Unallocated", "Show Unallocated & Clusters", "Show Allocated", "Show All" },
		function(index, value)
			self.showClusters = index == 2
			self.allocated = index == 3
			self.showAll = index == 4
			self:ReList()
			self:ReSort(3) -- Sort by power
		end)
end)

function PowerReportListClass:SetReport(stat, report, singleNotables)
	local enteringNotables = singleNotables and not self.singleNotables
	self.singleNotables = singleNotables
	self.colList[1].label = singleNotables and "Action" or "Type"
	if enteringNotables then self.controls.filterSelect:SetSel(4) end
	self.combinedReport = stat and stat.combinedReport or false
	self.percentReport = singleNotables and stat and (stat.stat == "FullDPS" or stat.stat == "TotalEHP" or stat.combinedReport)
	self.powerColumn.label = self.combinedReport and "Full DPS %" or self.percentReport and (stat.stat == "TotalEHP" and "EHP %" or "Full DPS %") or stat and stat.label or ""
	self.colList[5].label = self.combinedReport and "EHP %" or self.percentReport and "% / Point" or "Per Point"
	self.originalList = report or {}

	if stat and stat.stat then
		self.label = report and "Click to focus; right-click to ignore" or "Building Tree..."
	else
		self.label = "^7\""..self.powerColumn.label.."\" not supported.  Select a specific stat from the dropdown."
	end

	self:ReList()
	if self.sortColumn then
		self:ReSort(self.sortColumn)
	end
end

function PowerReportListClass:ReSort(colIndex)
	self.sortColumn = colIndex
	-- Reverse power sort for allocated because it uses negative numbers
	local compare = self.allocated and 
		function(a, b) return a < b end
		or function(a, b) return a > b end

	if colIndex == 1 then
		t_sort(self.list, function (a,b)
			if self.singleNotables and a.action ~= b.action then
				return (a.action or "Add") < (b.action or "Add")
			end
			if a.type == b.type then
				return compare(a.power, b.power)
			end
			return a.type < b.type
		end)
	elseif colIndex == 3 then
		t_sort(self.list, function (a,b)
			return compare(a.power, b.power)
		end)
	elseif colIndex == 4 then
		t_sort(self.list, function (a,b)
			if a.pathDist == "Anoint" or a.pathDist == "Cluster" then
				return false
			end
			if b.pathDist == "Anoint" or b.pathDist == "Cluster" then
				return true
			end
			if a.pathDist == b.pathDist then
				return compare(a.power, b.power)
			end
			return a.pathDist < b.pathDist
		end)
	elseif colIndex == 5 and self.combinedReport then
		t_sort(self.list, function(a, b)
			return compare(a.ehpPower or 0, b.ehpPower or 0)
		end)
	elseif colIndex == 5 then
		t_sort(self.list, function (a,b)
			if a.pathPower == b.pathPower and type(a.pathDist) == "number" and type(b.pathDist) == "number" then
				return a.pathDist < b.pathDist
			end
			return compare(a.pathPower, b.pathPower)
		end)
	end
end

function PowerReportListClass:ReList()
	self.list = { }
	self.selIndex, self.selValue = nil, nil
	if not self.originalList then
		return
	end

	for _, item in ipairs(self.originalList) do
		local insert = self.combinedReport and (item.power ~= 0 or (item.ehpPower or 0) ~= 0) or self.percentReport and item.power ~= 0 or item.power > 0
		if not self.showClusters and (item.isCluster or item.pathDist == "Cluster") then
			insert = false
		end
		if self.allocated then
			insert = item.allocated
		elseif not self.showAll and item.allocated then
			insert = false
		end

		if insert and not self.ignoredNodes[item.id] then
			t_insert(self.list, item)
		end
	end
	local region = self:GetRowRegion()
	self.controls.scrollBarV:SetContentDimension(#self.list * self.rowHeight, region.height)
end

function PowerReportListClass:RefreshIgnoredNodes()
	-- Node power is unchanged: reuse the complete report and preserve the chosen sort.
	self:ReList()
	if self.sortColumn then
		self:ReSort(self.sortColumn)
	end
end

function PowerReportListClass:OnKeyDown(key, doubleClick)
	if key ~= "RIGHTBUTTON" then
		return self.ListControl.OnKeyDown(self, key, doubleClick)
	end
	if not self:IsShown() or not self:IsEnabled() or not self:IsMouseOver() or self:GetMouseOverControl() then
		return
	end
	local x, y = self:GetPos()
	local cursorX, cursorY = GetCursorPos()
	local region = self:GetRowRegion()
	if cursorX >= x + region.x and cursorX < x + region.x + region.width and cursorY >= y + region.y and cursorY < y + region.y + region.height then
		local index = math.floor((cursorY - y - region.y + self.controls.scrollBarV.offset) / self.rowHeight) + 1
		local report = self.list[index]
		if report and report.id and self.nodeIgnoreCallback then
			self.nodeIgnoreCallback(report)
		end
	end
	return self
end

function PowerReportListClass:OnSelClick(index, report, doubleClick)
	if self.nodeSelectCallback then
		self.nodeSelectCallback(report)
	end
end

function PowerReportListClass:GetRowValue(column, index, report)
	return column == 1 and (self.singleNotables and report.action or report.type)
		or column == 2 and report.name
		or column == 3 and report.powerStr
		or column == 4 and (report.pathDist == 1000 and "Anoint" or report.pathDist)
		or column == 5 and (self.combinedReport and report.ehpPowerStr or report.pathPowerStr)
		or ""
end

function PowerReportListClass:AddValueTooltip(tooltip, _, node)
	if main.popups[1] then
		tooltip:Clear()
		return
	end
	if tooltip:CheckForUpdate(node) and node.sd then
		if self.percentReport or self.combinedReport then
			tooltip:AddLine(14, "Changes relative to the current build. N/A means the percentage is undefined. Single-node comparison; no travel points.")
			tooltip:AddLine(14, node.allocated and "Removal: effects of this notable alone are removed; dependent nodes are retained. Item-granted notables do not refund a skill point." or "Addition: effects of this notable alone are added.")
		elseif not self.singleNotables then
			tooltip:AddLine(14, node.allocated and "Total change from removing this node and its dependent nodes. Points counts the removed nodes; Per Point is the total divided by Points." or "Total change from adding this node and its travel path. Per Point is the total divided by Points. Anoint and Cluster entries compare the node alone.")
		end
		for _, line in ipairs(node.sd) do
			tooltip:AddLine(16, line)
		end
	end
end
