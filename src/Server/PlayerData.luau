local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Logging = require(game:GetService("ReplicatedStorage"):WaitForChild("Logging"))

local StatStore = DataStoreService:GetDataStore("PlayerStats")

local PlayerData = {}

PlayerData.Schema = {
	leaderstats = {
		Cash = { Type = "IntValue", BaseValue = 0, Name = "Cash" },
		ResearchPoint = { Type = "IntValue", BaseValue = 0, Name = "ResearchPoint" },
	},
	playerstats = {
		test2 = { Type = "IntValue", BaseValue = 50, Name = "test2" },
	},
}

local function safeGet(store, key)
	Logging.Debug("GetAsync:", { store, key })

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
	Logging.Debug("SetAsync:", { store, key, value })

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

			-- For Cash and ResearchPoint, always use BaseValue (0), ignore DataStore
			if field.Name == "Cash" or field.Name == "ResearchPoint" then
				value.Value = field.BaseValue
			else
				local stored = safeGet(StatStore, statKey(player.UserId, field.Name))
				value.Value = (stored ~= nil) and stored or field.BaseValue
			end
		end
	end
end

local saving = {}

function PlayerData.SavePlayer(player)
	if saving[player] then
		return
	end

	saving[player] = true

	Logging.Debug("Saving player:", player)

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

	saving[player] = nil
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
