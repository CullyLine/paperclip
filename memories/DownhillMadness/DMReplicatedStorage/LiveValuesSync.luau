--[[
	⚠️ DEPRECATED — This module is NOT currently used by Downhill Madness.
	The active chassis (DownhillConfig.luau) uses a simple flat table
	with no live-tuning bridge. Kept as reference for the original
	Polaris-based approach.

	LiveValuesSync — Bridges ValueBase instances on the vehicle model
	to the runtime ChassisConfig table. Changes to any LiveValue are
	reflected in the config instantly via .Changed connections.
	
	LiveValues container structure (under vehicle model):
	  LiveValues (Configuration)
	    ├── SpringStiffness (NumberValue)
	    ├── DampingCompression (NumberValue)
	    ├── DampingRebound (NumberValue)
	    ├── MaxSteerAngle (NumberValue)
	    ├── MaxTorque (NumberValue)
	    ├── ActiveGearCount (IntValue)
	    ├── SuspensionRestLength (NumberValue)
	    ├── TireFriction (NumberValue)
	    ├── AntiRollStiffness (NumberValue)
	    ├── MaxSpeed (NumberValue)
	    └── ... (any config key)
]]

local LiveValuesSync = {}
LiveValuesSync.__index = LiveValuesSync

type LiveValuesInstance = {
	container: Configuration,
	connections: { RBXScriptConnection },
	config: any,
}

local VALUE_KEY_MAP = {
	SpringStiffness       = "springStiffness",
	DampingCompression    = "dampingCompression",
	DampingRebound        = "dampingRebound",
	AntiRollStiffness     = "antiRollStiffness",
	SuspensionRestLength  = "suspensionRestLength",
	SuspensionMaxTravel   = "suspensionMaxTravel",
	MaxSteerAngle         = "maxSteerAngle",
	SteerSpeed            = "steerSpeed",
	SteerReturnSpeed      = "steerReturnSpeed",
	CounterSteerFactor    = "counterSteerFactor",
	MaxTorque             = "maxTorque",
	BrakeTorque           = "brakeTorque",
	ReverseTorque         = "reverseTorque",
	IdleRPM               = "idleRPM",
	RedlineRPM            = "redlineRPM",
	ShiftUpRPM            = "shiftUpRPM",
	ShiftDownRPM          = "shiftDownRPM",
	ActiveGearCount       = "activeGearCount",
	TransmissionEfficiency = "transmissionEfficiency",
	TireFriction          = "tireFrictionCoefficient",
	LateralGrip           = "lateralGripMultiplier",
	LongitudinalGrip      = "longitudinalGripMultiplier",
	WheelRadius           = "wheelRadius",
	DownforceCoefficient  = "downforceCoefficient",
	DragCoefficient       = "dragCoefficient",
	MaxSpeed              = "maxSpeedStudsPerSec",
	ReverseGearRatio      = "reverseGearRatio",
	FinalDriveRatio       = "finalDriveRatio",
	BrakeBiasFront        = "brakeBiasFront",
	HandbrakeForce        = "handbrakeForce",
	EngineBraking         = "engineBrakingCoefficient",
	AbsSlipThreshold      = "absSlipThreshold",
	AbsCycleRate          = "absCycleRate",
	TcsSlipThreshold      = "tcsSlipThreshold",
	TcsMinTorqueFraction  = "tcsMinTorqueFraction",
	TcsFadeRate           = "tcsFadeRate",
	AngularDamping        = "angularDampingCoefficient",
	MaxSuspForceMultiplier = "maxSuspensionForceMultiplier",
	MaxLateralForceClamp  = "maxLateralForceClamp",
	HydraulicMaxLift      = "hydraulicMaxLift",
	HydraulicPumpSpeed    = "hydraulicPumpSpeed",
	HydraulicLowerSpeed   = "hydraulicLowerSpeed",
	HydraulicBounceFrequency = "hydraulicBounceFrequency",
	HydraulicBounceAmplitude = "hydraulicBounceAmplitude",
}

-- Nested diff values: LiveValue name → { parent config key, child key }
local DIFF_VALUE_MAP = {
	RearDiffPreload    = { "rearDiff",   "preload"   },
	RearDiffPowerRamp  = { "rearDiff",   "powerRamp" },
	RearDiffCoastRamp  = { "rearDiff",   "coastRamp" },
	FrontDiffPreload   = { "frontDiff",  "preload"   },
	FrontDiffPowerRamp = { "frontDiff",  "powerRamp" },
	FrontDiffCoastRamp = { "frontDiff",  "coastRamp" },
	CenterDiffPreload  = { "centerDiff", "preload"   },
	CenterDiffPowerRamp = { "centerDiff", "powerRamp" },
	CenterDiffCoastRamp = { "centerDiff", "coastRamp" },
}

local DIFF_TYPE_MAP = {
	RearDiffType   = "rearDiff",
	FrontDiffType  = "frontDiff",
	CenterDiffType = "centerDiff",
}

function LiveValuesSync.createContainer(parent: Instance, config: any): Configuration
	local container = Instance.new("Configuration")
	container.Name = "LiveValues"

	for displayName, configKey in VALUE_KEY_MAP do
		local val = config[configKey]
		if val == nil then continue end

		local valueObj
		if typeof(val) == "number" then
			if math.floor(val) == val and val < 1000 and val > -1000 and configKey:find("Count") then
				valueObj = Instance.new("IntValue")
			else
				valueObj = Instance.new("NumberValue")
			end
			valueObj.Value = val
		elseif typeof(val) == "boolean" then
			valueObj = Instance.new("BoolValue")
			valueObj.Value = val
		end

		if valueObj then
			valueObj.Name = displayName
			valueObj.Parent = container
		end
	end

	-- Differential numeric values
	for displayName, mapping in DIFF_VALUE_MAP do
		local parentKey = mapping[1]
		local childKey = mapping[2]
		local diffTable = config[parentKey]
		if diffTable and diffTable[childKey] ~= nil then
			local valueObj = Instance.new("NumberValue")
			valueObj.Value = diffTable[childKey]
			valueObj.Name = displayName
			valueObj.Parent = container
		end
	end

	-- Differential type values (string)
	for displayName, parentKey in DIFF_TYPE_MAP do
		local diffTable = config[parentKey]
		if diffTable and diffTable.diffType then
			local valueObj = Instance.new("StringValue")
			valueObj.Value = diffTable.diffType
			valueObj.Name = displayName
			valueObj.Parent = container
		end
	end

	container.Parent = parent
	return container
end

function LiveValuesSync.bind(container: Configuration, config: any): LiveValuesInstance
	local inst: LiveValuesInstance = {
		container = container,
		connections = {},
		config = config,
	}

	local function bindChild(child: Instance)
		if not child:IsA("ValueBase") then return end

		-- Flat config key
		local configKey = VALUE_KEY_MAP[child.Name]
		if configKey and config[configKey] ~= nil then
			config[configKey] = child.Value
			local conn = child.Changed:Connect(function(newValue)
				config[configKey] = newValue
				if configKey == "activeGearCount" then
					config.activeGearCount = math.clamp(
						newValue, 1, #config.gearRatios
					)
				end
			end)
			table.insert(inst.connections, conn)
			return
		end

		-- Nested differential numeric values
		local diffMapping = DIFF_VALUE_MAP[child.Name]
		if diffMapping then
			local parentKey, childKey = diffMapping[1], diffMapping[2]
			if config[parentKey] then
				config[parentKey][childKey] = child.Value
				local conn = child.Changed:Connect(function(newValue)
					config[parentKey][childKey] = newValue
				end)
				table.insert(inst.connections, conn)
			end
			return
		end

		-- Differential type (string → diffType field)
		local diffTypeParent = DIFF_TYPE_MAP[child.Name]
		if diffTypeParent and config[diffTypeParent] then
			config[diffTypeParent].diffType = child.Value
			local conn = child.Changed:Connect(function(newValue)
				config[diffTypeParent].diffType = newValue
			end)
			table.insert(inst.connections, conn)
		end
	end

	for _, child in container:GetChildren() do
		bindChild(child)
	end

	-- Watch for dynamically added LiveValues
	local addedConn = container.ChildAdded:Connect(function(child)
		bindChild(child)
	end)
	table.insert(inst.connections, addedConn)

	setmetatable(inst, LiveValuesSync)
	return inst
end

function LiveValuesSync:destroy()
	for _, conn in self.connections do
		conn:Disconnect()
	end
	table.clear(self.connections)
end

return LiveValuesSync
