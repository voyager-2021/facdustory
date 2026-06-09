local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementService = {}

local DEFAULT_TEMPLATE_FOLDER = ReplicatedStorage:WaitForChild("Models")

local function getTemplateFolder(templateFolder)
	return templateFolder or DEFAULT_TEMPLATE_FOLDER
end

local function deserializeCFrame(data)
	if typeof(data) == "CFrame" then
		return data
	end

	if typeof(data) ~= "table" then
		return nil
	end

	if #data == 12 then
		return CFrame.new(table.unpack(data))
	end

	return nil
end

local function serializeCFrame(cf)
	return { cf:GetComponents() }
end

function PlacementService.CanPlace(partCFrame, partSize, ignoreList)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}

	local overlapping = workspace:GetPartBoundsInBox(partCFrame, partSize, params)

	print("Hits:", #overlapping)

	for _, part in ipairs(overlapping) do
		if part.CanCollide then
			return false, part
		end
	end

	return true
end

function PlacementService.GetTemplate(templateName, templateFolder)
	if typeof(templateName) ~= "string" then
		return nil
	end

	local folder = getTemplateFolder(templateFolder)
	local template = folder:FindFirstChild(templateName)

	if template and template:IsA("Model") then
		return template
	end

	return nil
end

function PlacementService.BuildRecord(templateName, pivotCFrame)
	return {
		Template = templateName,
		Pivot = { pivotCFrame:GetComponents() }
	}
end

function PlacementService.SpawnPlacement(record, parentFolder, templateFolder)
	if typeof(record) ~= "table" then
		return nil, "Invalid placement record."
	end

	local templateName = record.Template
	if typeof(templateName) ~= "string" then
		return nil, "Missing template name."
	end

	local template = PlacementService.GetTemplate(templateName, templateFolder)
	if not template then
		return nil, "Template not found: " .. templateName
	end

	local clone = template:Clone()
	clone:SetAttribute("Template", templateName)
	clone.Parent = parentFolder

	local pivot = deserializeCFrame(record.Pivot or record.CFrame)
	if not pivot and typeof(record.Position) == "table" then
		local pos = record.Position
		if #pos == 3 then
			pivot = CFrame.new(pos[1], pos[2], pos[3])
		end
	end

	if pivot then
		clone:PivotTo(pivot)
	end

	return clone
end

function PlacementService.SerializeModel(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	return {
		Template = model:GetAttribute("Template") or model.Name,
		Pivot = serializeCFrame(model:GetPivot()),
	}
end

function PlacementService.RebuildWorld(records, parentFolder, templateFolder)
	if typeof(records) ~= "table" then
		return
	end

	for _, record in ipairs(records) do
		PlacementService.SpawnPlacement(record, parentFolder, templateFolder)
	end
end

return PlacementService
