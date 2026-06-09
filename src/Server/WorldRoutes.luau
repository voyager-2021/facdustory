local MemoryStoreService = game:GetService("MemoryStoreService")

local WorldRouteStore = MemoryStoreService:GetHashMap("WorldRoutes")

local WorldRoutes = {}

function WorldRoutes.SetRoute(worldCode, accessCode, ttlSeconds)
	ttlSeconds = ttlSeconds or 3600

	local ok = pcall(function()
		WorldRouteStore:SetAsync(tostring(worldCode), tostring(accessCode), ttlSeconds)
	end)

	if not ok then
		warn("[WorldRoutes] Failed to set world route:", worldCode)
	end

	return ok
end

function WorldRoutes.GetRoute(worldCode)
	local ok, result = pcall(function()
		return WorldRouteStore:GetAsync(tostring(worldCode))
	end)

	if not ok then
		warn("[WorldRoutes] Failed to read world route:", worldCode)
		return nil
	end

	return result
end

function WorldRoutes.RemoveRoute(worldCode)
	local ok = pcall(function()
		WorldRouteStore:RemoveAsync(tostring(worldCode))
	end)

	if not ok then
		warn("[WorldRoutes] Failed to remove world route:", worldCode)
	end

	return ok
end

return WorldRoutes
