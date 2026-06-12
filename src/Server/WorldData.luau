local DataStoreService = game:GetService("DataStoreService")

local Logging = require(game:GetService("ReplicatedStorage"):WaitForChild("Logging"))

local WorldMetaStore = DataStoreService:GetDataStore("WorldMetadata")
local WorldCodeStore = DataStoreService:GetDataStore("WorldCodeIndex")
local OwnerStore = DataStoreService:GetDataStore("PlayerWorlds")

local WorldData = {}

local DEFAULT_WORLD_STATE = {
	Version = 1,
	PlacedObjects = {},
}

local function deepCopy(value, seen)
	if typeof(value) ~= "table" then
		return value
	end

	if seen and seen[value] then
		return seen[value]
	end

	seen = seen or {}
	local copy = {}
	seen[value] = copy

	for k, v in pairs(value) do
		copy[deepCopy(k, seen)] = deepCopy(v, seen)
	end

	return copy
end

local function safeGet(store, key)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if not ok then
		warn("[WorldData] GetAsync failed:", key, result)
		return nil
	end

	return result
end

local function safeSet(store, key, value)
	local ok, result = pcall(function()
		store:SetAsync(key, value)
	end)

	if not ok then
		warn("[WorldData] SetAsync failed:", key, result)
	end

	return ok
end

local function safeRemove(store, key)
	local ok, result = pcall(function()
		store:RemoveAsync(key)
	end)

	if not ok then
		warn("[WorldData] RemoveAsync failed:", key, result)
	end

	return ok
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

local function normalizeWorldMeta(userId, worldName, worldMeta)
	worldMeta = worldMeta or {}

	worldMeta.WorldName = worldName
	worldMeta.Name = worldMeta.Name or worldName
	worldMeta.OwnerUserId = userId
	worldMeta.CreatedAt = worldMeta.CreatedAt or os.time()
	worldMeta.WorldCode = worldMeta.WorldCode or nil
	worldMeta.WorldData = worldMeta.WorldData or deepCopy(DEFAULT_WORLD_STATE)

	Logging.Debug(worldMeta)

	return worldMeta
end

function WorldData.WorldNameExists(worldName)
	return safeGet(WorldMetaStore, worldNameKey(worldName)) ~= nil
end

function WorldData.WorldCodeExists(worldCode)
	return safeGet(WorldCodeStore, worldCodeKey(worldCode)) ~= nil
end

function WorldData.GetWorld(worldName)
	return safeGet(WorldMetaStore, worldNameKey(worldName))
end

function WorldData.GetWorldNameFromCode(worldCode)
	return safeGet(WorldCodeStore, worldCodeKey(worldCode))
end

function WorldData.GetWorldByCode(worldCode)
	local worldName = WorldData.GetWorldNameFromCode(worldCode)
	if not worldName then
		return nil
	end

	return WorldData.GetWorld(worldName)
end

function WorldData.CreateWorld(userId, worldName, worldMeta)
	if WorldData.WorldNameExists(worldName) then
		return false, "World name already exists."
	end

	worldMeta = normalizeWorldMeta(userId, worldName, worldMeta)

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

function WorldData.UpdateWorld(worldName, patch)
	local ok, result = pcall(function()
		return WorldMetaStore:UpdateAsync(worldNameKey(worldName), function(current)
			if not current then
				return nil
			end

			if typeof(patch) == "function" then
				local updated = patch(deepCopy(current))
				return updated or current
			end

			for k, v in pairs(patch) do
				current[k] = v
			end

			Logging.Debug(current)

			return current
		end)
	end)

	if not ok then
		warn("[WorldData] UpdateWorld failed:", worldName, result)
		return false, result
	end

	return true, result
end

function WorldData.GetWorldState(worldName)
	local world = WorldData.GetWorld(worldName)
	if not world then
		return nil
	end

	return deepCopy(world.WorldData or DEFAULT_WORLD_STATE)
end

function WorldData.SaveWorldState(worldName, worldState, worldMeta)
	worldState = deepCopy(worldState or DEFAULT_WORLD_STATE)
	worldMeta = worldMeta or {}

	local ok, result = pcall(function()
		return WorldMetaStore:UpdateAsync(worldNameKey(worldName), function(current)
			if not current then
				current = {
					WorldName = worldName,
					Name = worldMeta.Name or worldName,
					OwnerUserId = worldMeta.OwnerUserId or 0,
					CreatedAt = worldMeta.CreatedAt or os.time(),
					WorldCode = worldMeta.WorldCode or nil,
				}
			end

			current.WorldName = worldName
			current.Name = current.Name or worldName
			current.OwnerUserId = worldMeta.OwnerUserId or current.OwnerUserId or 0
			current.CreatedAt = current.CreatedAt or os.time()
			current.WorldCode = worldMeta.WorldCode or current.WorldCode or nil
			current.WorldData = worldState

			return current
		end)
	end)

	if not ok then
		warn("[WorldData] SaveWorldState failed:", worldName, result)
		return false, result
	end

	return true, result
end

function WorldData.SetWorldCodeIndex(worldCode, worldName)
	return safeSet(WorldCodeStore, worldCodeKey(worldCode), worldName)
end

function WorldData.RemoveWorldCodeIndex(worldCode)
	return safeRemove(WorldCodeStore, worldCodeKey(worldCode))
end

function WorldData.GetOwnedWorldNames(userId)
	return safeGet(OwnerStore, ownerKey(userId)) or {}
end

function WorldData.GetWorlds(userId, routeResolver)
	local names = WorldData.GetOwnedWorldNames(userId)
	local result = {}

	for _, worldName in ipairs(names) do
		local meta = WorldData.GetWorld(worldName)
		if meta then
			local item = deepCopy(meta)
			item.WorldName = worldName
			item.HasCode = item.WorldCode ~= nil

			if routeResolver and item.WorldCode then
				item.IsOnline = routeResolver(item.WorldCode) ~= nil
			else
				item.IsOnline = false
			end

			table.insert(result, item)
		end
	end

	table.sort(result, function(a, b)
		return (a.CreatedAt or 0) > (b.CreatedAt or 0)
	end)

	return result
end

function WorldData.DeleteWorld(userId, worldName)
	local names = WorldData.GetOwnedWorldNames(userId)
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

	local meta = WorldData.GetWorld(worldName)
	if not meta then
		return false, "World metadata missing."
	end

	local ok = safeSet(OwnerStore, ownerKey(userId), filtered)
	if not ok then
		return false, "Failed to update owner index."
	end

	if meta.WorldCode then
		safeRemove(WorldCodeStore, worldCodeKey(meta.WorldCode))
	end

	safeRemove(WorldMetaStore, worldNameKey(worldName))

	return true, meta
end

return WorldData
