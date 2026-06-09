local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()
local DEBUG = true

local Logging = {}

local function getCaller()
	local source = debug.info(3, "s")
	local line = debug.info(3, "l")

	if source and line then
		return string.format("%s:%d", source, line)
	end

	return "unknown"
end

-- Production-only pretty serializer
local function serializePretty(value, indent, seen)
	indent = indent or 0
	seen = seen or {}

	local valueType = typeof(value)

	if valueType == "string" then
		return string.format("%q", value)
	end

	if valueType ~= "table" then
		return tostring(value)
	end

	if seen[value] then
		return "<recursive>"
	end

	seen[value] = true

	local padding = string.rep("  ", indent)
	local childPadding = string.rep("  ", indent + 1)

	local lines = {"{"}

	for k, v in pairs(value) do
		table.insert(
			lines,
			string.format(
				"%s[%s] = %s,",
				childPadding,
				serializePretty(k, 0, seen),
				serializePretty(v, indent + 1, seen)
			)
		)
	end

	table.insert(lines, padding .. "}")
	return table.concat(lines, "\n")
end

local function serialize(value)
	-- STUDIO: no formatting at all
	if isStudio then
		return value
	end

	-- PRODUCTION: structured output
	if typeof(value) ~= "table" then
		return tostring(value)
	end

	return serializePretty(value, 0, {})
end

local function formatArgs(...)
	local args = table.pack(...)
	local out = table.create(args.n)

	for i = 1, args.n do
		out[i] = serialize(args[i])
	end

	return table.unpack(out)
end

function Logging.Debug(...)
	if isStudio or DEBUG then
		print(string.format("[DEBUG] [%s]", getCaller()), ...)
	end
end

function Logging.Info(...)
	print(string.format("[INFO] [%s]", getCaller()), formatArgs(...))
end

function Logging.Warn(...)
	warn(string.format("[WARN] [%s]", getCaller()), formatArgs(...))
end

function Logging.Error(...)
	warn(string.format("[ERROR] [%s]", getCaller()), formatArgs(...))
end

return Logging
