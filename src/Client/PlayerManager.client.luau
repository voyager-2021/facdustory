local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer

local PlayerGui = Player:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Models = ReplicatedStorage:WaitForChild("Models")

local StatsUpdatedEvent = Events:WaitForChild("StatsUpdated")
local TimeUpdatedEvent = Events:WaitForChild("TimeUpdated")

local CashLabel = MainGui:WaitForChild("Cash")
local ResearchPointLabel = MainGui:WaitForChild("ResearchPoint")

local Logging = require(ReplicatedStorage:WaitForChild("Logging"))

-- Time UI
local TimeLabel = MainGui:FindFirstChild("TimeLabel")
if not TimeLabel then
	TimeLabel = Instance.new("TextLabel")
	TimeLabel.Name = "TimeLabel"
	TimeLabel.Size = UDim2.fromOffset(200, 60)
	TimeLabel.Position = UDim2.new(0.5, -100, 0, 10)
	TimeLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TimeLabel.BackgroundTransparency = 0.5
	TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TimeLabel.TextSize = 48
	TimeLabel.Font = Enum.Font.FredokaOne
	TimeLabel.TextStrokeTransparency = 0.3
	TimeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	TimeLabel.BorderSizePixel = 0
	TimeLabel.Text = "6:00 AM"
	TimeLabel.Parent = MainGui
end

-- Temporary folder
local tempFolder = workspace:FindFirstChild("Temporary")
if not tempFolder then
	tempFolder = Instance.new("Folder")
	tempFolder.Name = "Temporary"
	tempFolder.Parent = workspace
	Logging.Warn("No Temporary folder found, creating one.")
end

-- Number formatting
local function formatNumber(num)
	local formatted = tostring(num)
	local length = #formatted

	if length <= 3 then
		return formatted
	end

	local result = ""
	for i = 1, length do
		if (length - i) % 3 == 0 and i > 1 then
			result ..= ","
		end
		result ..= formatted:sub(i, i)
	end

	return result
end

StatsUpdatedEvent.OnClientEvent:Connect(function(stats)
	CashLabel.Text = "$" .. formatNumber(stats.Cash)
	ResearchPointLabel.Text = "RP " .. formatNumber(stats.ResearchPoint)
end)

TimeUpdatedEvent.OnClientEvent:Connect(function(timeStr, currentTime)
	TimeLabel.Text = timeStr
	Logging.Debug("Current time:", currentTime)
end)

-- Grid system
local GRID_SIZE = 1
local BUILD_Y = 1

local function snap(n)
	return math.floor(n / GRID_SIZE + 0.5) * GRID_SIZE
end

local function snapVector(pos)
	return Vector3.new(
		snap(pos.X),
		pos.Y,
		snap(pos.Z)
	)
end

local camera = workspace.CurrentCamera

local function intersectBuildPlane(ray)
	local denom = ray.Direction.Y
	if math.abs(denom) < 1e-6 then
		return Vector3.new(0, BUILD_Y, 0)
	end

	local t = (BUILD_Y - ray.Origin.Y) / denom
	return ray.Origin + ray.Direction * t
end

local function getMouseWorldPosition(ghost)
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {ghost, Player.Character}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result then
		return result.Position
	end

	return intersectBuildPlane(ray)
end

-- Placement state
local IsPlacing = false

local function Placement(model)
	if IsPlacing then return end
	IsPlacing = true

	local ghost = model:Clone()
	ghost.Parent = tempFolder

	if not ghost.PrimaryPart then
		warn("Model has no PrimaryPart:", ghost.Name)
		IsPlacing = false
		ghost:Destroy()
		return
	end

	local ui = script:WaitForChild("Placement"):Clone()
	ui.Parent = ghost

	local checkMark = MainGui:WaitForChild("CheckMark")
	checkMark.Visible = UserInputService.TouchEnabled

	local heartbeat, placeConn, cancelConn, mobileConn

	local function cleanup()
		if heartbeat then
			heartbeat:Disconnect()
		end

		if placeConn then
			placeConn:Disconnect()
		end

		if cancelConn then
			cancelConn:Disconnect() 
		end

		if mobileConn then
			mobileConn:Disconnect()
		end

		if ui then
			ui:Destroy()
		end

		if ghost then
			ghost:Destroy()
		end

		checkMark.Visible = false
		IsPlacing = false
	end

	local function confirmPlacement()
		local worldPos = getMouseWorldPosition(ghost)
		local snapped = snapVector(worldPos)

		local targetPos = Vector3.new(snapped.X, BUILD_Y, snapped.Z)

		Events.ClientPlacement:FireServer({
			Template = model.Name,
			Position = targetPos
		})

		cleanup()
	end

	heartbeat = RunService.Heartbeat:Connect(function()
		local worldPos = getMouseWorldPosition(ghost)
		local snapped = snapVector(worldPos)

		local targetPos = Vector3.new(snapped.X, BUILD_Y, snapped.Z)

		-- PRIMARY PART BASED PLACEMENT
		local pivot = ghost:GetPivot()
		local primary = ghost.PrimaryPart

		-- compute offset from pivot -> primary
		local offset = pivot:ToObjectSpace(primary.CFrame)

		-- move so primary aligns to target position
		local newPrimaryCFrame = CFrame.new(targetPos)
		local newPivot = newPrimaryCFrame * offset:Inverse()

		ghost:PivotTo(newPivot)
	end)

	placeConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			confirmPlacement()
		end
	end)

	cancelConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cleanup()
		end
	end)

	mobileConn = checkMark.ImageButton.MouseButton1Click:Connect(confirmPlacement)
end

local SolarPanel1 = Models:WaitForChild("SolarPanel1")

MainGui.Build.ImageButton.MouseButton1Click:Connect(function()
	Placement(SolarPanel1)
end)
