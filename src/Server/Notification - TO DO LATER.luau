local TweenService = game:GetService("TweenService")
local Label = script:WaitForChild("NotificationLabel")

local notification = {}

function notification.send(plr, msg, color)
	local Clone = Label:Clone()
	Clone.Parent = plr.PlayerGui:WaitForChild("MainGui")
	Clone.Text = msg
	Clone.TextColor = color

	task.wait(3)

	TweenService:Create(Clone, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
		Position = Label.Position + UDim2.new(0, 0, 0, -0.3),
	}):Play()

	task.wait(0.5)

	Clone:Destroy()
end

return notification
