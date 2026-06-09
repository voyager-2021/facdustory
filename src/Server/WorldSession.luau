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

	if state and typeof(state) == "table" then
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

local function snapshotState()
	return {
		Version = session.State.Version or 1,
		PlacedObjects = table.clone(session.State.PlacedObjects or {}),
	}
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
				local ok = WorldSession.Save(true)
				Logging.Debug("WORLD SAVED:", session.WorldName)
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
		Logging.Debug("WORLD NOT DIRTY:", session.WorldName)
		return true
	end

	local ok, err = WorldData.SaveWorldState(session.WorldName, snapshotState(), {
		Name = session.WorldName,
		OwnerUserId = session.OwnerUserId,
		WorldCode = session.WorldCode,
	})

	Logging.Debug("WORLD SAVED:", session.WorldName, err, ok)

	if ok then
		session.Dirty = false
	else
		Logging.Warn("WORLD SAVED FAILED:", err)
	end

	return ok, err
end

function WorldSession.PlaceObject(player, placementData)
	Logging.Debug("Place object:", player, placementData)
	Logging.Debug("PLACEMENT STATE SIZE:", #session.State.PlacedObjects)

	if not session.Started then
		Logging.Debug("World session not started, session:", session)

		return false, "World session not started."
	end

	if typeof(placementData) ~= "table" then
		Logging.Debug("Invalid placement data:", placementData)

		return false, "Invalid placement data."
	end

	local templateName = placementData.Template
	local position = placementData.Position

	if typeof(templateName) ~= "string" then
		Logging.Debug("Missing template name:", templateName)

		return false, "Missing template name."
	end

	if typeof(position) ~= "Vector3" then
		Logging.Debug("Missing or invalid position:", position)

		return false, "Missing or invalid position."
	end

	local template = PlacementService.GetTemplate(templateName, getTemplateFolder())

	if not template then
		Logging.Debug("Unknown template:", templateName)

		return false, "Unknown template: " .. templateName
	end

	local cf = CFrame.new(
		math.round(position.X),
		math.round(position.Y),
		math.round(position.Z)
	)

	local worldFolder = ensureWorldFolder()

	local ignoreList = { worldFolder, workspace.Baseplate }

	if player.Character then
		table.insert(ignoreList, player.Character)
	end

	local okPlace, hit = PlacementService.CanPlace(
		cf,
		template:GetExtentsSize(),
		ignoreList
	)

	if not okPlace then
		Logging.Debug("Blocked by:", hit)

		return false, "Blocked by " .. hit:GetFullName()
	end

	-- spawn
	local clone = template:Clone()
	clone:SetAttribute("Template", templateName)
	clone.Parent = worldFolder
	clone:PivotTo(cf)

	-- SAVE RECORD (THIS IS THE IMPORTANT PART)
	local record = PlacementService.BuildRecord(templateName, cf)

	Logging.Debug("PLACEMENT RECORD:", record)

	table.insert(session.State.PlacedObjects, record)
	markDirty()

	return true, clone, record
end

function WorldSession.Shutdown()
	Logging.Debug("Shutting down world session...")

	WorldSession.Save(true)

	Logging.Debug("Saved on shutdown:", session.WorldName)
	Logging.Debug(session)

	if not isStudio() and session.WorldCode then
		WorldRoutes.RemoveRoute(session.WorldCode)
	end

	session.Started = false

	return true
end

function WorldSession.StartStudioTest()
	Logging.Debug("Starting studio test world session...")

	if session.Started then
		Logging.Warn("World session already started.")
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

	local world = WorldData.GetWorld(session.WorldName)
	if not world then
		local ok, result = WorldData.SaveWorldState(session.WorldName, {
			Version = 1,
			PlacedObjects = {},
		}, {
			Name = session.WorldName,
			OwnerUserId = 0,
			CreatedAt = os.time(),
			WorldCode = nil,
		})

		if not ok then
			warn("[WorldSession] Failed to create studio world:", result)
		end
	end

	local ok = loadWorldState()
	Logging.Debug("LOAD WORLD STATE OK:", ok)

	if not ok then
		Logging.Debug("No datastore data found, using studio test seed.")
		session.State = {
			Version = 1,
			PlacedObjects = {},
		}
	end

	rebuildWorld()
	startAutosaveLoop()

	return true
end

return WorldSession
