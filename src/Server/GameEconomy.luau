-- GameEconomy Module
-- Easy methods to add/subtract Cash and ResearchPoints

local StatsSync = require(game:GetService("ServerScriptService"):WaitForChild("StatsSync"))

local GameEconomy = {}

function GameEconomy.AddCash(player, amount)
	StatsSync.AddCash(player, amount)
end

function GameEconomy.SubtractCash(player, amount)
	StatsSync.AddCash(player, -amount)
end

function GameEconomy.SetCash(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = amount
		end
	end
end

function GameEconomy.GetCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			return cash.Value
		end
	end
	return 0
end

function GameEconomy.AddResearchPoint(player, amount)
	StatsSync.AddResearchPoint(player, amount)
end

function GameEconomy.SubtractResearchPoint(player, amount)
	StatsSync.AddResearchPoint(player, -amount)
end

function GameEconomy.SetResearchPoint(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rp = leaderstats:FindFirstChild("ResearchPoint")
		if rp then
			rp.Value = amount
		end
	end
end

function GameEconomy.GetResearchPoint(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rp = leaderstats:FindFirstChild("ResearchPoint")
		if rp then
			return rp.Value
		end
	end
	return 0
end

-- Batch operations
function GameEconomy.Transaction(player, cashDelta, rpDelta)
	if cashDelta then
		StatsSync.AddCash(player, cashDelta)
	end

	if rpDelta then
		StatsSync.AddResearchPoint(player, rpDelta)
	end
end

return GameEconomy
