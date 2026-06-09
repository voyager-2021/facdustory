local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local StatStore = DataStoreService:GetDataStore("PlayerStats")

local PlayerData = {}

PlayerData.Schema = {
	leaderstats = {
		test = { Type = "IntValue", BaseValue = 5, Name = "test" },
	},
	playerstats = {
		test2 = { Type = "IntValue", BaseValue = 50, Name = "test2" },
	},
}

local function safeGet(store, key)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if not ok then
		warn("[PlayerData] GetAsync failed:", key, result)
		return nil
	end

	return result
end

local function safeSet(store, key, value)
	local ok, result = pcall(function()
		store:SetAsync(key, value)
	end)

	if not ok then
		warn("[PlayerData] SetAsync failed:", key, result)
	end

	return ok
end

local function statKey(userId, fieldName)
	return tostring(userId) .. ":" .. fieldName
end

function PlayerData.LoadPlayer(player)
	for folderName, fields in pairs(PlayerData.Schema) do
		local old = player:FindFirstChild(folderName)
		if old then
			old:Destroy()
		end

		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = player

		for _, field in pairs(fields) do
			local value = Instance.new(field.Type)
			value.Name = field.Name
			value.Parent = folder

			local stored = safeGet(StatStore, statKey(player.UserId, field.Name))
			value.Value = (stored ~= nil) and stored or field.BaseValue
		end
	end
end

function PlayerData.SavePlayer(player)
	for folderName, fields in pairs(PlayerData.Schema) do
		local folder = player:FindFirstChild(folderName)
		if not folder then
			continue
		end

		for _, field in pairs(fields) do
			local value = folder:FindFirstChild(field.Name)
			if value and value:IsA("ValueBase") then
				safeSet(StatStore, statKey(player.UserId, field.Name), value.Value)
			end
		end
	end
end

function PlayerData.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.SavePlayer(player)
	end
end

function PlayerData.AutoSave(intervalSeconds)
	intervalSeconds = intervalSeconds or 120

	task.spawn(function()
		while task.wait(intervalSeconds) do
			PlayerData.SaveAll()
		end
	end)
end

return PlayerData