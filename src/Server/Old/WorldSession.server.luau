local DataStore = require(game:GetService("ServerScriptService"):WaitForChild("DataStore"))

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local Models = ReplicatedStorage:WaitForChild("Models")

local activeWorldCode
local activeAccessCode
local refreshRunning = false

local function captureTeleportData(player)
	if activeWorldCode and activeAccessCode then
		return
	end

	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if typeof(teleportData) ~= "table" then
		return
	end

	activeWorldCode = teleportData.WorldCode
	activeAccessCode = teleportData.AccessCode

	if typeof(activeWorldCode) ~= "string" or typeof(activeAccessCode) ~= "string" then
		return
	end

	game:SetAttribute("WorldCode", activeWorldCode)
	game:SetAttribute("OwnerUserId", teleportData.OwnerUserId or 0)
	game:SetAttribute("WorldName", teleportData.WorldName or "")

	DataStore.SetWorldRoute(activeWorldCode, activeAccessCode, 3600)

	if refreshRunning then
		return
	end

	refreshRunning = true
	task.spawn(function()
		while task.wait(300) do
			if #Players:GetPlayers() == 0 then
				break
			end

			if activeWorldCode and activeAccessCode then
				DataStore.SetWorldRoute(activeWorldCode, activeAccessCode, 3600)
			end
		end

		refreshRunning = false
	end)
end

local function canPlace(partCFrame, partSize, ignoreList)
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

Players.PlayerAdded:Connect(captureTeleportData)

for _, player in ipairs(Players:GetPlayers()) do
	captureTeleportData(player)
end

game:BindToClose(function()
	if activeWorldCode then
		DataStore.RemoveWorldRoute(activeWorldCode)
	end
end)

Events:WaitForChild("ClientPlacement").OnServerEvent:Connect(function(plr, Model, mousePos)
	local Clone:Model = Model:clone()
	Clone.Parent = workspace:WaitForChild("Models")
	Clone:MoveTo(mousePos)
end)