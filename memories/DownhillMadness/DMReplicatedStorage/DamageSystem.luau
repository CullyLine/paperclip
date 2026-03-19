--[[
	DamageSystem — Shared damage calculations for vehicle destruction.

	Pure computation module (no Roblox service references beyond types).
	Used by both the owning client (collision detection + local effects)
	and the server (validation + broadcast).

	Damage flow:
	  1. Client detects collision on CollisionShell (Touched or velocity delta)
	  2. Client calculates impact damage via this module
	  3. Client applies damage locally (visual feedback, panel detach)
	  4. Client sends damage event to server for validation + replication
	  5. Server validates, applies, broadcasts to other clients
]]

local DamageSystem = {}

export type PanelState = {
	name: string,
	health: number,
	maxHealth: number,
	destroyed: boolean,
	originalColor: { number },
}

export type DamageResult = {
	panelName: string,
	damage: number,
	newHealth: number,
	destroyed: boolean,
}

export type VehicleDamageState = {
	panels: { [string]: PanelState },
	totalMaxHealth: number,
	destroyedCount: number,
	isWrecked: boolean,
}

----------------------------------------------------------------
-- Build initial damage state from a vehicle's BodyPanels model
----------------------------------------------------------------

function DamageSystem.buildState(bodyPanelsModel: Model): VehicleDamageState
	local state: VehicleDamageState = {
		panels = {},
		totalMaxHealth = 0,
		destroyedCount = 0,
		isWrecked = false,
	}

	for _, part in bodyPanelsModel:GetChildren() do
		if not part:IsA("BasePart") then continue end
		local maxHp = part:GetAttribute("MaxHealth") or part:GetAttribute("Health") or 100
		local hp = part:GetAttribute("Health") or maxHp

		state.panels[part.Name] = {
			name = part.Name,
			health = hp,
			maxHealth = maxHp,
			destroyed = hp <= 0,
			originalColor = { part.Color.R, part.Color.G, part.Color.B },
		}
		state.totalMaxHealth += maxHp
		if hp <= 0 then
			state.destroyedCount += 1
		end
	end

	return state
end

----------------------------------------------------------------
-- Calculate impact damage from a collision velocity
----------------------------------------------------------------

function DamageSystem.calculateImpactDamage(
	impactSpeed: number,
	cfg: any
): number
	if impactSpeed < cfg.damageSpeedThreshold then
		return 0
	end

	local excess = impactSpeed - cfg.damageSpeedThreshold
	return excess * cfg.damageMultiplier
end

----------------------------------------------------------------
-- Find the nearest panel(s) to a world-space collision point.
-- Returns up to `maxPanels` panel names sorted by distance.
----------------------------------------------------------------

function DamageSystem.findNearestPanels(
	collisionPoint: Vector3,
	bodyPanelsModel: Model,
	maxPanels: number?
): { string }
	local limit = maxPanels or 2
	local panels: { { name: string, dist: number } } = {}

	for _, part in bodyPanelsModel:GetChildren() do
		if not part:IsA("BasePart") then continue end
		local dist = (part.Position - collisionPoint).Magnitude
		table.insert(panels, { name = part.Name, dist = dist })
	end

	table.sort(panels, function(a, b)
		return a.dist < b.dist
	end)

	local result: { string } = {}
	for i = 1, math.min(limit, #panels) do
		table.insert(result, panels[i].name)
	end
	return result
end

----------------------------------------------------------------
-- Apply damage to a panel in the state. Returns the result.
----------------------------------------------------------------

function DamageSystem.applyDamage(
	state: VehicleDamageState,
	panelName: string,
	damage: number
): DamageResult?
	local panel = state.panels[panelName]
	if not panel or panel.destroyed then
		return nil
	end

	panel.health = math.max(panel.health - damage, 0)
	local justDestroyed = false

	if panel.health <= 0 and not panel.destroyed then
		panel.destroyed = true
		panel.health = 0
		justDestroyed = true
		state.destroyedCount += 1
	end

	state.isWrecked = DamageSystem.isWrecked(state)

	return {
		panelName = panelName,
		damage = damage,
		newHealth = panel.health,
		destroyed = justDestroyed,
	}
end

----------------------------------------------------------------
-- Calculate the damage tint color based on remaining health ratio
----------------------------------------------------------------

function DamageSystem.getDamageTint(
	healthRatio: number,
	originalColor: { number },
	darkColor: { number }
): Color3
	local t = 1 - math.clamp(healthRatio, 0, 1)
	-- Quadratic curve: damage tint accelerates as health drops
	t = t * t

	local r = originalColor[1] * (1 - t) + darkColor[1] * t
	local g = originalColor[2] * (1 - t) + darkColor[2] * t
	local b = originalColor[3] * (1 - t) + darkColor[3] * t

	return Color3.new(r, g, b)
end

----------------------------------------------------------------
-- Check if the vehicle is in "wrecked" state (total health below threshold)
----------------------------------------------------------------

function DamageSystem.isWrecked(state: VehicleDamageState): boolean
	if state.totalMaxHealth <= 0 then return false end

	local totalCurrent = 0
	for _, panel in state.panels do
		totalCurrent += panel.health
	end

	return totalCurrent / state.totalMaxHealth < 0.20
end

----------------------------------------------------------------
-- Calculate handling penalties for lost panels + wrecked state
----------------------------------------------------------------

export type DamagePenalties = {
	speedMultiplier: number,
	extraDrag: number,
}

function DamageSystem.calculatePenalties(
	state: VehicleDamageState,
	cfg: any
): DamagePenalties
	local speedMul = 1.0
	local extraDrag = 0.0

	speedMul -= state.destroyedCount * cfg.panelLossSpeedPerPanel
	extraDrag += state.destroyedCount * cfg.panelLossDragPerPanel

	if state.isWrecked then
		speedMul -= cfg.wreckedSpeedPenalty
		extraDrag += cfg.wreckedDragPenalty
	end

	speedMul = math.max(speedMul, 0.3)

	return {
		speedMultiplier = speedMul,
		extraDrag = extraDrag,
	}
end

----------------------------------------------------------------
-- Validate a damage report from the client (server-side)
-- Returns true if the report is plausible
----------------------------------------------------------------

function DamageSystem.validateDamageReport(
	panelName: string,
	damage: number,
	impactSpeed: number,
	cfg: any
): boolean
	if damage <= 0 then return false end
	if impactSpeed < cfg.damageSpeedThreshold * 0.8 then return false end

	local expectedMax = impactSpeed * cfg.damageMultiplier * 1.5
	if damage > expectedMax then return false end

	return true
end

return DamageSystem
