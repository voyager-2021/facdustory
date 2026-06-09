local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")

local PlayerGui = Player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Models = ReplicatedStorage:WaitForChild("Models")

local mouse = Player:GetMouse()

repeat task.wait() until Player.Character

local IsPlacing = false

local function Placement(Model)
	if IsPlacing then return end
	
	IsPlacing = true
	
	local mousePos = Vector3.new(math.round(mouse.Hit.Position.X), 2, math.round(mouse.Hit.Position.Z))
	local Clone:Model = Model:Clone()
	Clone.Parent = workspace:WaitForChild("Temporary")
	Clone:move(mousePos)
	
	local Clone2 = script:WaitForChild("Placement"):Clone()
	Clone2.Parent = Clone
	
	local CheckMark:Frame = PlayerGui:WaitForChild("MainGui").CheckMark
	CheckMark.Visible = true
	
	CheckMark:WaitForChild("ImageButton").MouseButton1Click:Connect(function()
		local PlacementData = {
			Template = Model.name,
			Pivot = CFrame.new(mousePos)
		}
		
		Events:WaitForChild("ClientPlacement"):FireServer(PlacementData)
		Clone:Destroy()
		Clone2:Destroy()
		CheckMark.Visible = false
		
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

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E then
		Placement(Models:WaitForChild("Test"))
	end
end)