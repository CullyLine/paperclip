--!strict

local Utils = {}

function Utils.formatNumber(n: number): string
	if n >= 1_000_000_000_000 then
		return string.format("%.1fT", n / 1_000_000_000_000)
	elseif n >= 1_000_000_000 then
		return string.format("%.1fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	else
		return tostring(math.floor(n))
	end
end

function Utils.generateUID(): string
	return game:GetService("HttpService"):GenerateGUID(false)
end

function Utils.deepCopy<T>(original: T): T
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in original :: any do
		copy[key] = Utils.deepCopy(value)
	end
	return copy :: any
end

function Utils.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Utils.clamp(value: number, min: number, max: number): number
	return math.max(min, math.min(max, value))
end

function Utils.getUpgradeCost(baseCost: number, multiplier: number, currentLevel: number): number
	return math.floor(baseCost * (multiplier ^ currentLevel))
end

function Utils.calculatePetModifier(equippedPets: { { power: number } }): number
	local totalPower = 0
	for _, pet in equippedPets do
		totalPower += pet.power
	end
	return 1 + (totalPower / 100)
end

function Utils.calculateRebirthCost(rebirths: number, baseCost: number, multiplier: number): number
	return math.floor(baseCost * (multiplier ^ rebirths))
end

return Utils
