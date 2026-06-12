local DataStoreService = game:GetService("DataStoreService")
local StatStore = DataStoreService:GetDataStore("PlayerStats")

-- Clear all cached data
task.spawn(function()
	for i = 1, 500 do
		pcall(function()
			StatStore:RemoveAsync(i .. ":Cash")
			StatStore:RemoveAsync(i .. ":ResearchPoint")
		end)
	end
end)
