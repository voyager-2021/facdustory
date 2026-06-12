local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")

local PlayerGui = Player:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Models = ReplicatedStorage:WaitForChild("Models")

local StatsUpdatedEvent = Events:WaitForChild("StatsUpdated")
local TimeUpdatedEvent = Events:WaitForChild("TimeUpdated")
local CashLabel = MainGui:WaitForChild("Cash")
local ResearchPointLabel = MainGui:WaitForChild("ResearchPoint")

-- Create TimeLabel if it doesn't exist
local TimeLabel = MainGui:FindFirstChild("TimeLabel")
if not TimeLabel then
	TimeLabel = Instance.new("TextLabel")
	TimeLabel.Name = "TimeLabel"
	TimeLabel.Size = UDim2.new(0, 200, 0, 60)
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

-- Stats listener
local function formatNumber(num)
	local formatted = tostring(num)
	local length = #formatted
	if length > 3 then
		local result = ""
		for i = 1, length do
			if (length - i) % 3 == 0 and i > 1 then
				result = result .. ","
			end
			result = result .. formatted:sub(i, i)
		end
		return result
	end
	return formatted
end

StatsUpdatedEvent.OnClientEvent:Connect(function(stats)
	CashLabel.Text = "$" .. formatNumber(stats.Cash)
	ResearchPointLabel.Text = "RP " .. formatNumber(stats.ResearchPoint)
end)

-- Time listener
TimeUpdatedEvent.OnClientEvent:Connect(function(timeStr, currentTime)
	TimeLabel.Text = timeStr
end)


local IsPlacing = false

local function Placement(model)
    if IsPlacing then return end
    IsPlacing = true

    local ghost = model:Clone()
    ghost.Parent = workspace:WaitForChild("Temporary")

    local ui = script:WaitForChild("Placement"):Clone()
    ui.Parent = ghost

    local checkMark = PlayerGui:WaitForChild("MainGui").CheckMark
    checkMark.Visible = true

    -- Update ghost position every frame
    local heartbeat = game:GetService("RunService").Heartbeat:Connect(function()
        local mousePos = mouse.Hit.Position
        ghost:PivotTo(CFrame.new(
            math.round(mousePos.X),
            2,
            math.round(mousePos.Z)
        ))
    end)

    local conn
    conn = checkMark.ImageButton.MouseButton1Click:Connect(function()
        conn:Disconnect()
        heartbeat:Disconnect()  -- stop moving the ghost

        local finalPos = mouse.Hit.Position  -- read fresh on confirm

        local payload = {
            Template = model.Name,
            Position = Vector3.new(
                math.round(finalPos.X),
                2,
                math.round(finalPos.Z)
            )
        }

        Events.ClientPlacement:FireServer(payload)

        ghost:Destroy()
        ui:Destroy()
        checkMark.Visible = false
        IsPlacing = false
    end)
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		task.spawn(function()
			while UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) do
				Player.Character:WaitForChild("Humanoid").WalkSpeed = 32
				task.wait()
			end
			Player.Character:WaitForChild("Humanoid").WalkSpeed = 16
		end)
	end
end)

MainGui:WaitForChild("Build"):WaitForChild("ImageButton").MouseButton1Click:Connect(function()
	
end)
