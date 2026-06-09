--[[
	DataStore.lua

	Handles:
	  • Player stats
	  • World metadata keyed by worldName
	  • World code index keyed by worldCode -> worldName
	  • Player-owned world index
	  • Live world routing via MemoryStore keyed by worldCode

	World metadata is permanent.
	Live routing is temporary and refreshed by the world server.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local StatStore = DataStoreService:GetDataStore("PlayerStats")
local WorldMetaStore = DataStoreService:GetDataStore("WorldMetadata")
local WorldCodeStore = DataStoreService:GetDataStore("WorldCodeIndex")
local OwnerStore = DataStoreService:GetDataStore("PlayerWorlds")
local WorldRouteStore = MemoryStoreService:GetHashMap("WorldRoutes")

local StatSchema = {
	leaderstats = {
		Money = { Type = "IntValue", BaseValue = 1000, Name = "Money" },
	},
	playerstats = {
		test2 = { Type = "IntValue", BaseValue = 50, Name = "test2" },
	},
}

local DataStore = {}

DataStore.Schema = StatSchema


local function safeGet(store, key)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok then
		warn("[DataStore] GetAsync failed:", key, result)
		return nil
	end
	return result
end


local function safeSet(store, key, value)
	local ok, result = pcall(function()
		store:SetAsync(key, value)
	end)
	if not ok then
		warn("[DataStore] SetAsync failed:", key, result)
	end
	return ok
end


local function safeRemove(store, key)
	local ok, result = pcall(function()
		store:RemoveAsync(key)
	end)
	if not ok then
		warn("[DataStore] RemoveAsync failed:", key, result)
	end
	return ok
end


local function statKey(userId, fieldName)
	return tostring(userId) .. ":" .. fieldName
end


local function ownerKey(userId)
	return tostring(userId)
end


local function worldNameKey(worldName)
	return worldName
end


local function worldCodeKey(worldCode)
	return worldCode
end


function DataStore.LoadPlayer(player)
	for folderName, fields in pairs(StatSchema) do
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


function DataStore.SavePlayer(player)
	for folderName, fields in pairs(StatSchema) do
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


function DataStore.AutoSave(intervalSeconds)
	intervalSeconds = intervalSeconds or 120

	task.spawn(function()
		while task.wait(intervalSeconds) do
			for _, player in ipairs(Players:GetPlayers()) do
				DataStore.SavePlayer(player)
			end
		end
	end)
end


function DataStore.WorldNameExists(worldName)
	return safeGet(WorldMetaStore, worldNameKey(worldName)) ~= nil
end


function DataStore.WorldCodeExists(worldCode)
	return safeGet(WorldCodeStore, worldCodeKey(worldCode)) ~= nil
end


function DataStore.GetWorld(worldName)
	return safeGet(WorldMetaStore, worldNameKey(worldName))
end


function DataStore.GetWorldNameFromCode(worldCode)
	return safeGet(WorldCodeStore, worldCodeKey(worldCode))
end


function DataStore.GetWorldByCode(worldCode)
	local worldName = DataStore.GetWorldNameFromCode(worldCode)
	if not worldName then
		return nil
	end

	return DataStore.GetWorld(worldName)
end


function DataStore.CreateWorld(userId, worldName, worldMeta)
	if DataStore.WorldNameExists(worldName) then
		return false, "World name already exists."
	end

	worldMeta = worldMeta or {}
	worldMeta.WorldName = worldName
	worldMeta.Name = worldMeta.Name or worldName
	worldMeta.OwnerUserId = userId
	worldMeta.CreatedAt = worldMeta.CreatedAt or os.time()
	worldMeta.WorldCode = worldMeta.WorldCode or nil
	worldMeta.WorldData = worldMeta.WorldData or {
		Version = 1,
		PlacedObjects = {},
	}

	local ok = safeSet(WorldMetaStore, worldNameKey(worldName), worldMeta)
	if not ok then
		return false, "Failed to save world metadata."
	end

	local ownerOk = pcall(function()
		OwnerStore:UpdateAsync(ownerKey(userId), function(current)
			current = current or {}
			if not table.find(current, worldName) then
				table.insert(current, worldName)
			end
			return current
		end)
	end)

	if not ownerOk then
		safeRemove(WorldMetaStore, worldNameKey(worldName))
		return false, "Failed to update owner index."
	end

	return true, worldMeta
end

function DataStore.UpdateWorld(worldName, patch)
	local ok, result = pcall(function()
		return WorldMetaStore:UpdateAsync(worldNameKey(worldName), function(current)
			if not current then
				return nil
			end

			if typeof(patch) == "function" then
				local updated = patch(table.clone(current))
				return updated or current
			end

			for k, v in pairs(patch) do
				current[k] = v
			end

			return current
		end)
	end)

	if not ok then
		warn("[DataStore] UpdateWorld failed:", worldName, result)
		return false, result
	end

	return true, result
end


function DataStore.GetWorldState(worldName)
	local world = DataStore.GetWorld(worldName)
	if not world then
		return nil
	end

	return world.WorldData or {
		Version = 1,
		PlacedObjects = {},
	}
end


function DataStore.SaveWorldState(worldName, worldState)
	return DataStore.UpdateWorld(worldName, function(world)
		world.WorldData = worldState
		return world
	end)
end


function DataStore.SetWorldCodeIndex(worldCode, worldName)
	return safeSet(WorldCodeStore, worldCodeKey(worldCode), worldName)
end


function DataStore.RemoveWorldCodeIndex(worldCode)
	return safeRemove(WorldCodeStore, worldCodeKey(worldCode))
end


function DataStore.GetWorlds(userId)
	local names = safeGet(OwnerStore, ownerKey(userId)) or {}
	local result = {}

	for _, worldName in ipairs(names) do
		local meta = safeGet(WorldMetaStore, worldNameKey(worldName))
		if meta then
			local item = table.clone(meta)
			item.WorldName = worldName
			item.IsOnline = item.WorldCode and safeGet(WorldRouteStore, item.WorldCode) ~= nil or false
			item.HasCode = item.WorldCode ~= nil
			table.insert(result, item)
		end
	end

	table.sort(result, function(a, b)
		return (a.CreatedAt or 0) > (b.CreatedAt or 0)
	end)

	return result
end


function DataStore.SetWorldRoute(worldCode, accessCode, ttlSeconds)
	ttlSeconds = ttlSeconds or 259200

	local ok = pcall(function()
		WorldRouteStore:SetAsync(worldCodeKey(worldCode), accessCode, ttlSeconds)
	end)

	if not ok then
		warn("[DataStore] Failed to set world route:", worldCode)
	end

	return ok
end


function DataStore.GetWorldRoute(worldCode)
	local ok, result = pcall(function()
		return WorldRouteStore:GetAsync(worldCodeKey(worldCode))
	end)

	if not ok then
		warn("[DataStore] Failed to read world route:", worldCode)
		return nil
	end

	return result
end


function DataStore.RemoveWorldRoute(worldCode)
	local ok = pcall(function()
		WorldRouteStore:RemoveAsync(worldCodeKey(worldCode))
	end)

	if not ok then
		warn("[DataStore] Failed to remove world route:", worldCode)
	end

	return ok
end


function DataStore.DeleteWorld(userId, worldName)
	local names = safeGet(OwnerStore, ownerKey(userId)) or {}
	local found = false
	local filtered = {}

	for _, name in ipairs(names) do
		if name == worldName then
			found = true
		else
			table.insert(filtered, name)
		end
	end

	if not found then
		return false, "World not owned by player."
	end

	local meta = DataStore.GetWorld(worldName)
	if not meta then
		return false, "World metadata missing."
	end

	local ok = safeSet(OwnerStore, ownerKey(userId), filtered)
	if not ok then
		return false, "Failed to update owner index."
	end

	if meta.WorldCode then
		safeRemove(WorldCodeStore, worldCodeKey(meta.WorldCode))
		safeRemove(WorldRouteStore, worldCodeKey(meta.WorldCode))
	end

	safeRemove(WorldMetaStore, worldNameKey(worldName))

	return true
end

return DataStore
