local PlacementService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModelsFolder = ReplicatedStorage:WaitForChild("Models")

function PlacementService.CanPlace(partCFrame, partSize, ignoreList)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}

	local overlapping = workspace:GetPartBoundsInBox(partCFrame, partSize, params)

	for _, p in ipairs(overlapping) do
		if p.CanCollide then
			return false, p
		end
	end

	return true
end

function PlacementService.SpawnPlacement(data, parentFolder)
	local template = ModelsFolder:FindFirstChild(data.Template)
	if not template then
		return nil, "Missing template: " .. tostring(data.Template)
	end

	local clone = template:Clone()
	clone.Parent = parentFolder

	if data.CFrame then
		clone:PivotTo(CFrame.new(table.unpack(data.CFrame)))
	elseif data.Position then
		clone:MoveTo(Vector3.new(table.unpack(data.Position)))
	end

	return clone
end

function PlacementService.SerializeModel(model)
	return {
		Template = model.Name,
		CFrame = { model:GetPivot():GetComponents() },
	}
end

return PlacementService
