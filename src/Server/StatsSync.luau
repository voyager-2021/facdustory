local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StatsSync = {}

local function createStatsUpdatedEvent()
	local folder = ReplicatedStorage:FindFirstChild("Events")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Events"
		folder.Parent = ReplicatedStorage
	end
	
	local event = folder:FindFirstChild("StatsUpdated")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "StatsUpdated"
		event.Parent = folder
	end
	
	return event
end

local StatsUpdatedEvent = createStatsUpdatedEvent()

function StatsSync.InitializeStatsListener(player)
	local leaderstats = player:WaitForChild("leaderstats")
	
	local cash = leaderstats:WaitForChild("Cash")
	local rp = leaderstats:WaitForChild("ResearchPoint")
	
	-- Send initial values
	StatsUpdatedEvent:FireClient(player, {
		Cash = cash.Value,
		ResearchPoint = rp.Value
	})
	
	-- Watch for changes
	cash.Changed:Connect(function()
		StatsUpdatedEvent:FireClient(player, {
			Cash = cash.Value,
			ResearchPoint = rp.Value
		})
	end)
	
	rip.Changed:Connect(function()
		StatsUpdatedEvent:FireClient(player, {
			Cash = cash.Value,
			ResearchPoint = rp.Value
		})
	end)
end

function StatsSync.AddCash(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = cash.Value + amount
		end
	end
end

function StatsSync.AddResearchPoint(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rp = leaderstats:FindFirstChild("ResearchPoint")
		if rp then
			rip.Value = rp.Value + amount
		end
	end
end

return StatsSync