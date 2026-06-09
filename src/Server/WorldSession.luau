local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(game:GetService("ServerScriptService"):WaitForChild("Logging"))

local WorldData = require(game:GetService("ServerScriptService"):WaitForChild("WorldData"))
local WorldRoutes = require(game:GetService("ServerScriptService"):WaitForChild("WorldRoutes"))
local PlacementService = require(game:GetService("ServerScriptService"):WaitForChild("PlacementService"))

local WorldSession = {}

local session = {
	Started = false,

	WorldName = nil,
	WorldCode = nil,
	AccessCode = nil,
	OwnerUserId = 0,

	State = {
		Version = 1,
		PlacedObjects = {},
	},

	Dirty = false,
	Refreshing = false,
	Autosaving = false,

	RouteTTL = 3600,
	RouteRefreshInterval = 300,
	AutosaveInterval = 120,
}

local function ensureWorldFolder()
	local folder = workspace:FindFirstChild("Models")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Models"
		folder.Parent = workspace
	end
	return folder
end

local function getTemplateFolder()
	return ReplicatedStorage:WaitForChild("Models")
end

local function markDirty()
	session.Dirty = true
end

local function isStudio()
	return RunService:IsStudio()
end

local function loadWorldState()
	Logging.Debug("Loading world state:", session.WorldName)

	if not session.WorldName then
		return false, "No world name."
	end

	local state = WorldData.GetWorldState(session.WorldName)

	Logging.Debug(state)

	if state then
		session.State = state
	else
		session.State = {
			Version = 1,
			PlacedObjects = {},
		}
	end

	if typeof(session.State.PlacedObjects) ~= "table" then
		session.State.PlacedObjects = {}
	end

	Logging.Debug(session)

	return true
end

local function rebuildWorld()
	local folder = ensureWorldFolder()
	folder:ClearAllChildren()

	PlacementService.RebuildWorld(session.State.PlacedObjects, folder, getTemplateFolder())
end

local function refreshRouteOnce()
	if session.WorldCode and session.AccessCode then
		WorldRoutes.SetRoute(session.WorldCode, session.AccessCode, session.RouteTTL)
	end
end

local function startRouteRefreshLoop()
	if session.Refreshing then
		return
	end

	session.Refreshing = true
	task.spawn(function()
		while session.Started do
			task.wait(session.RouteRefreshInterval)

			if not session.Started then
				break
			end

			refreshRouteOnce()
		end

		session.Refreshing = false
	end)
end

local function startAutosaveLoop()
	if session.Autosaving then
		return
	end

	session.Autosaving = true
	task.spawn(function()
		while session.Started do
			task.wait(session.AutosaveInterval)

			if not session.Started then
				break
			end

			if session.Dirty then
				local ok = session.Save(true)
				if ok then
					session.Dirty = false
				end
			end
		end

		session.Autosaving = false
	end)
end

function WorldSession.IsStarted()
	return session.Started
end

function WorldSession.GetState()
	return session.State
end

function WorldSession.GetInfo()
	return {
		WorldName = session.WorldName,
		WorldCode = session.WorldCode,
		AccessCode = session.AccessCode,
		OwnerUserId = session.OwnerUserId,
		Started = session.Started,
	}
end

function WorldSession.StartFromPlayer(player)
	if session.Started then
		return true
	end

	local worldName = game:GetAttribute("WorldName")
	local worldCode = game:GetAttribute("WorldCode")
	local accessCode = game:GetAttribute("AccessCode")
	local ownerUserId = tonumber(game:GetAttribute("OwnerUserId")) or 0

	local okJoin, joinData = pcall(function()
		return player:GetJoinData()
	end)

	if okJoin and joinData and typeof(joinData.TeleportData) == "table" then
		local tp = joinData.TeleportData
		if typeof(tp.WorldName) == "string" and tp.WorldName ~= "" then
			worldName = tp.WorldName
		end
		if typeof(tp.WorldCode) == "string" and tp.WorldCode ~= "" then
			worldCode = tp.WorldCode
		end
		if typeof(tp.AccessCode) == "string" and tp.AccessCode ~= "" then
			accessCode = tp.AccessCode
		end
		if typeof(tp.OwnerUserId) == "number" then
			ownerUserId = tp.OwnerUserId
		end
	end

	if (not worldName or worldName == "") and worldCode then
		local world = WorldData.GetWorldByCode(worldCode)
		if world then
			worldName = world.WorldName or world.Name
			if not ownerUserId or ownerUserId == 0 then
				ownerUserId = world.OwnerUserId or 0
			end
		end
	end

	if not worldName or worldName == "" then
		return false, "No world was provided to the session."
	end

	session.WorldName = worldName
	session.WorldCode = worldCode
	session.AccessCode = accessCode
	session.OwnerUserId = ownerUserId
	session.Started = true

	game:SetAttribute("WorldName", session.WorldName)
	game:SetAttribute("WorldCode", session.WorldCode or "")
	game:SetAttribute("OwnerUserId", session.OwnerUserId)

	loadWorldState()
	rebuildWorld()
	refreshRouteOnce()
	startRouteRefreshLoop()
	startAutosaveLoop()

	return true
end

function WorldSession.Save(force)
	if not session.WorldName then
		return false, "No active world."
	end

	if not force and not session.Dirty then
		return true
	end

	local ok, result = WorldData.SaveWorldState(session.WorldName, session.State)
	if ok then
		session.Dirty = false
	end

	return ok, result
end

function WorldSession.PlaceObject(player, placementData)
	Logging.Debug("Place object:", player, placementData)

	if not session.Started then
		return false, "World session is not started."
	end

	if typeof(placementData) ~= "table" then
		return false, "Invalid placement data."
	end

	local templateName = placementData.Template
	if typeof(templateName) ~= "string" then
		return false, "Missing template name."
	end

	local template = PlacementService.GetTemplate(templateName, getTemplateFolder())
	if not template then
		return false, "Unknown template: " .. templateName
	end

	local pivot = placementData.Pivot
		or placementData.CFrame
		or placementData.Position

	if typeof(pivot) ~= "CFrame" and typeof(pivot) ~= "table" then
		return false, "Missing placement transform."
	end

	local cf
	if typeof(pivot) == "CFrame" then
		cf = pivot
	elseif typeof(pivot) == "table" then
		if #pivot == 12 then
			cf = CFrame.new(table.unpack(pivot))
		elseif #pivot == 3 then
			cf = CFrame.new(pivot[1], pivot[2], pivot[3])
		end
	end

	if not cf then
		return false, "Invalid placement transform."
	end

	local worldFolder = ensureWorldFolder()
	local ignoreList = { worldFolder }

	if player and player.Character then
		table.insert(ignoreList, player.Character)
	end

	local okPlace, hit = PlacementService.CanPlace(cf, template:GetExtentsSize(), ignoreList)
	if not okPlace then
		if hit ~= workspace.Baseplate then
			return false, "Blocked by " .. hit:GetFullName()
		end
	end

	local clone = template:Clone()
	clone:SetAttribute("Template", templateName)
	clone.Parent = worldFolder
	clone:PivotTo(cf)


	local record = PlacementService.BuildRecord(templateName, cf, placementData.Extra)
	table.insert(session.State.PlacedObjects, record)
	markDirty()

	return true, clone, record
end

function WorldSession.Shutdown()
	Logging.Debug("Shutting down world session...")

	WorldSession.Save(true)

	if not isStudio() and session.WorldCode then
		WorldRoutes.RemoveRoute(session.WorldCode)
	end

	session.Started = false
	return true
end

function WorldSession.StartStudioTest()
	Logging.Debug("Starting studio test world session...")

	if session.Started then
		return true
	end

	session.WorldName = "StudioTestWorld"
	session.WorldCode = nil
	session.AccessCode = nil
	session.OwnerUserId = 0
	session.Started = true

	game:SetAttribute("WorldName", session.WorldName)
	game:SetAttribute("WorldCode", "")
	game:SetAttribute("OwnerUserId", 0)
	game:SetAttribute("StudioMode", true)

	session.State = {
		Version = 1,
		PlacedObjects = {},
	}

	rebuildWorld()
	startAutosaveLoop()

	return true
end

return WorldSession
