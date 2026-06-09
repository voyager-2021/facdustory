local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

local Logging = {}

function Logging.Debug(...)
	if isStudio then
		print("[DEBUG]", ...)
	end
end

function Logging.Info(...)
 	print("[INFO]", ...)
end

function Logging.Warn(...)
	warn("[WARN]", ...)
end

function Logging.Error(...)
	print("[ERROR]", ...)
end

return Logging
