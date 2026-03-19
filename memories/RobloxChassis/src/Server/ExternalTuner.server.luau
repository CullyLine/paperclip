--[[
	ExternalTuner — Example script showing how external code can
	modify the chassis's LiveValues in real-time.
	
	Drop this into ServerScriptService or any Script context.
	It finds the vehicle's LiveValues container and writes to it.
	The chassis picks up changes instantly — no restart needed.
	
	This demonstrates the external script interface requirement:
	any script can read/write ValueBase objects under LiveValues
	to tune the chassis on the fly.
]]

local function waitForVehicle(): Model
	local vehicle = workspace:WaitForChild("TestVehicle", 30)
	assert(vehicle, "TestVehicle not found in workspace")
	return vehicle
end

local function getOrCreateValue(container: Configuration, name: string, valueType: string, default: any): ValueBase
	local existing = container:FindFirstChild(name)
	if existing then return existing end

	local obj
	if valueType == "Number" then
		obj = Instance.new("NumberValue")
	elseif valueType == "Int" then
		obj = Instance.new("IntValue")
	elseif valueType == "String" then
		obj = Instance.new("StringValue")
	elseif valueType == "Bool" then
		obj = Instance.new("BoolValue")
	else
		obj = Instance.new("NumberValue")
	end

	obj.Name = name
	obj.Value = default
	obj.Parent = container
	return obj
end

-- Example: adjust suspension stiffness over time (sinusoidal test)
local function runSuspensionTest(liveValues: Configuration)
	print("[ExternalTuner] Starting suspension stiffness oscillation test")
	local baseStiffness = 85
	local amplitude = 30
	local stiffnessVal = getOrCreateValue(liveValues, "SpringStiffness", "Number", baseStiffness)

	-- Oscillate for 20 seconds then restore
	local startTime = tick()
	while tick() - startTime < 20 do
		local t = tick() - startTime
		stiffnessVal.Value = baseStiffness + math.sin(t * 0.5) * amplitude
		task.wait(0.1)
	end

	stiffnessVal.Value = baseStiffness
	print("[ExternalTuner] Suspension test complete, restored to default")
end

-- Example: switch between comfort and sport mode
local function setMode(liveValues: Configuration, mode: string)
	if mode == "comfort" then
		getOrCreateValue(liveValues, "SpringStiffness", "Number", 85).Value = 60
		getOrCreateValue(liveValues, "DampingCompression", "Number", 4.5).Value = 3.0
		getOrCreateValue(liveValues, "DampingRebound", "Number", 5.5).Value = 3.5
		getOrCreateValue(liveValues, "MaxSteerAngle", "Number", 35).Value = 40
		getOrCreateValue(liveValues, "AntiRollStiffness", "Number", 30).Value = 15
		print("[ExternalTuner] Switched to COMFORT mode")

	elseif mode == "sport" then
		getOrCreateValue(liveValues, "SpringStiffness", "Number", 85).Value = 120
		getOrCreateValue(liveValues, "DampingCompression", "Number", 4.5).Value = 6.0
		getOrCreateValue(liveValues, "DampingRebound", "Number", 5.5).Value = 7.0
		getOrCreateValue(liveValues, "MaxSteerAngle", "Number", 35).Value = 28
		getOrCreateValue(liveValues, "AntiRollStiffness", "Number", 30).Value = 50
		getOrCreateValue(liveValues, "MaxTorque", "Number", 450).Value = 550
		print("[ExternalTuner] Switched to SPORT mode")

	elseif mode == "drift" then
		getOrCreateValue(liveValues, "SpringStiffness", "Number", 85).Value = 90
		getOrCreateValue(liveValues, "DampingCompression", "Number", 4.5).Value = 4.0
		getOrCreateValue(liveValues, "DampingRebound", "Number", 5.5).Value = 5.0
		getOrCreateValue(liveValues, "TireFriction", "Number", 1.6).Value = 0.9
		getOrCreateValue(liveValues, "LateralGrip", "Number", 1.0).Value = 0.5
		getOrCreateValue(liveValues, "MaxTorque", "Number", 450).Value = 500
		getOrCreateValue(liveValues, "CounterSteerFactor", "Number", 0.3).Value = 0.6
		print("[ExternalTuner] Switched to DRIFT mode")
	end
end

-- API for external scripts to use
local ExternalTunerAPI = {}

function ExternalTunerAPI.setDriveMode(mode: string)
	local vehicle = workspace:FindFirstChild("TestVehicle")
	if not vehicle then return end
	local liveValues = vehicle:FindFirstChild("LiveValues")
	if not liveValues then return end
	setMode(liveValues, mode)
end

function ExternalTunerAPI.setValue(valueName: string, newValue: any)
	local vehicle = workspace:FindFirstChild("TestVehicle")
	if not vehicle then return end
	local liveValues = vehicle:FindFirstChild("LiveValues")
	if not liveValues then return end
	local valObj = liveValues:FindFirstChild(valueName)
	if valObj then
		valObj.Value = newValue
	end
end

function ExternalTunerAPI.getValue(valueName: string): any?
	local vehicle = workspace:FindFirstChild("TestVehicle")
	if not vehicle then return nil end
	local liveValues = vehicle:FindFirstChild("LiveValues")
	if not liveValues then return nil end
	local valObj = liveValues:FindFirstChild(valueName)
	if valObj then
		return valObj.Value
	end
	return nil
end

return ExternalTunerAPI
