local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")

local PlayerGui = Player:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Models = ReplicatedStorage:WaitForChild("Models")

local mouse = Player:GetMouse()

repeat task.wait() until Player.Character

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