local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(game:GetService("ServerScriptService"):WaitForChild("Logging"))
local PlayerData = require(game:GetService("ServerScriptService"):WaitForChild("PlayerData"))
local WorldSession = require(game:GetService("ServerScriptService"):WaitForChild("WorldSession"))

local Events = ReplicatedStorage:WaitForChild("Events")
local ClientPlacement = Events:WaitForChild("ClientPlacement")

local function onPlayerAdded(player)
	PlayerData.LoadPlayer(player)
end

local shuttingDown = false

local function onPlayerRemoving(player)
	if shuttingDown then
		return
	end

	PlayerData.SavePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

local function startWorldSession()
	if RunService:IsStudio() then
		local ok, err = WorldSession.StartStudioTest()
		if not ok then
			warn("[Main] Studio session failed:", err)
		end
		return
	end

	-- wait for at least one player reliably
	local player = Players.PlayerAdded:Wait()

	local ok, err = WorldSession.StartFromPlayer(player)
	if not ok then
		warn("[Main] Live session failed:", err)
	end
end

startWorldSession()

PlayerData.AutoSave(120)

ClientPlacement.OnServerEvent:Connect(function(player, placementData)
	print(placementData)
	
	local ok, result, record = WorldSession.PlaceObject(player, placementData)

	Logging.Debug({ok, result, record})
	Logging.Debug(placementData)

	if not ok then
		warn("[Main] Placement rejected:", result)
	end
end)

game:BindToClose(function()
	shuttingDown = true

	PlayerData.SaveAll()
	WorldSession.Shutdown()
end)
