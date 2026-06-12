-- TEMP: Reset player stats to 0 on load
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local StatStore = DataStoreService:GetDataStore("PlayerStats")

local function resetDataStore()
	for userId = 1, 1000 do
		local ok = pcall(function()
			StatStore:RemoveAsync(tostring(userId) .. ":Cash")
			StatStore:RemoveAsync(tostring(userId) .. ":ResearchPoint")
		end)
	end
end

resetDataStore()

Players.PlayerAdded:Connect(function(player)
	player:WaitForChild("leaderstats")
	local leaderstats = player:FindFirstChild("leaderstats")
	
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		local rp = leaderstats:FindFirstChild("ResearchPoint")
		
		if cash then cash.Value = 0 end
		if rp then rp.Value = 0 end
	end
end)
