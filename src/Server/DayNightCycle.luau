local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayNightCycle = {}

-- Create/get TimeUpdated event
local function createTimeUpdatedEvent()
	local folder = ReplicatedStorage:FindFirstChild("Events")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Events"
		folder.Parent = ReplicatedStorage
	end
	
	local event = folder:FindFirstChild("TimeUpdated")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "TimeUpdated"
		event.Parent = folder
	end
	
	return event
end

local TimeUpdatedEvent = createTimeUpdatedEvent()

-- Config
local CYCLE_DURATION = 180 -- 3 minute cycle for testing, change to 1200 (20 min) for IRL speed
local START_TIME = 6 -- Start at 6 AM

local currentTime = START_TIME
local isRunning = false

-- Colors for different times
local TIME_COLORS = {
	[0] = {amb = Color3.fromRGB(40, 40, 60)},      -- Midnight
	[6] = {amb = Color3.fromRGB(200, 150, 100)},   -- Dawn
	[12] = {amb = Color3.fromRGB(255, 255, 255)},  -- Noon
	[18] = {amb = Color3.fromRGB(255, 100, 50)},   -- Dusk
	[24] = {amb = Color3.fromRGB(40, 40, 60)},     -- Midnight
}

local function interpolateColor(c1, c2, alpha)
	return Color3.new(
		c1.R + (c2.R - c1.R) * alpha,
		c1.G + (c2.G - c1.G) * alpha,
		c1.B + (c2.B - c1.B) * alpha
	)
end

local function getSunRotation(hour)
	-- Sun moves from left (-80°) at 6 AM through top (0°) at 12 PM to right (80°) at 6 PM
	-- Below horizon at night
	if hour >= 6 and hour <= 18 then
		local sunProgress = (hour - 6) / 12  -- 0 to 1 from 6 AM to 6 PM
		local angle = -80 + (sunProgress * 160)  -- -80 to +80 degrees
		return math.rad(angle)
	else
		return math.rad(-100)  -- Below horizon at night
	end
end

local function getColorForTime(hour)
	local nextHour = (hour + 1) % 24
	local alpha = 0  -- Will be calculated from minutes
	
	local color1 = TIME_COLORS[math.floor(hour) % 24].amb
	local color2 = TIME_COLORS[nextHour].amb
	
	return interpolateColor(color1, color2, alpha), string.format("%02d:00", math.floor(hour))
end

local function updateLighting()
	local ambColor, timeStr = getColorForTime(currentTime)
	Lighting.Ambient = ambColor
	Lighting.OutdoorAmbient = ambColor
	
	-- Update sun rotation
	local sunAngle = getSunRotation(currentTime)
	Lighting:SetMinutesAfterMidnight(currentTime * 60)  -- Update internal time
	
	-- Broadcast to all clients with proper formatting
	local displayHour = math.floor(currentTime)
	local displayMin = math.floor((currentTime - displayHour) * 60)
	local displayStr = string.format("%02d:%02d", displayHour, displayMin)
	
	TimeUpdatedEvent:FireAllClients(displayStr, currentTime)
end

function DayNightCycle.Start()
	if isRunning then return end
	isRunning = true
	
	task.spawn(function()
		while isRunning do
			task.wait(CYCLE_DURATION / 24)  -- Advance time every tick
			currentTime = currentTime + 1
			if currentTime >= 24 then
				currentTime = 0
			end
			updateLighting()
		end
	end)
end

function DayNightCycle.Stop()
	isRunning = false
end

function DayNightCycle.SetTime(hour)
	currentTime = hour % 24
	updateLighting()
end

function DayNightCycle.GetTime()
	return currentTime
end

function DayNightCycle.SetCycleDuration(seconds)
	CYCLE_DURATION = seconds
end

-- Initialize lighting
updateLighting()

return DayNightCycle