--!strict
--[[
	Procedural bone animation engine for pets.
	Drives Bone.Transform CFrames via RunService.Heartbeat using sinusoidal oscillators.
	Supports per-pet custom animation sets with a generic fallback.

	API:
	  PetAnimator.start(model, animName, fullAnimation?, rarity?)
	  PetAnimator.setAnim(model, animName)
	  PetAnimator.playEmote(model, emoteId, duration?)
	  PetAnimator.isEmotePlaying(model) - true while an emote overlay is active
	  PetAnimator.stop(model)
	  PetAnimator.setBpm(bpm), PetAnimator.getBpm() - shared musical grid for walk / hop / float (default 118).

	fullAnimation=false applies only a simple float-bob (for remote pets with animations disabled).
	rarity boosts idle motion; optional Attribute PetPersonalitySeed de-syncs pets.
	Emotes: "landing", "coin", "stretch", "shake" (curious: glances at nearby player heads + ActivePets), "playbow" (additive overlay).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PetAnimator = {}

local PET_ANIM_LOD_DISTANCE = 100

local TWO_PI = 2 * math.pi

-- One shared tempo (Spider-Man meme energy): ~118 BPM reads "on beat" with lots of tracks; tweak anytime.
local DEFAULT_BPM = 118
local currentBpm = DEFAULT_BPM

local function beatsPerSecond(): number
	return currentBpm / 60
end

local function osc(t: number, cycles: number, amplitude: number, phase: number?): number
	return amplitude * math.sin(t * cycles * TWO_PI + (phase or 0))
end

-- 0..1 easing for softer transitions (hop land, limb blends)
local function smoothstep01(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

type BoneCache = { [string]: Bone }

type AnimState = {
	model: Model,
	animName: string,
	fullAnimation: boolean,
	bones: BoneCache,
	boneList: { Bone },
	skeleton: SkeletonInfo,
	startTime: number,
	connection: RBXScriptConnection?,
	-- Feel-good layer: rarity amplitude + stable per-pet variation
	juiceMul: number,
	personalitySeed: number,
	emoteId: string?,
	emoteStart: number?,
	emoteDuration: number?,
	-- Curious emote ("shake"): world point to glance at (other pets / player heads), picked once per emote
	emoteLookTarget: Vector3?,
}

type SkeletonInfo = {
	root: string?,
	spine: { string },
	limbs: { { string } },
	tips: { string },
	all: { string },
	count: number,
}

-- Wall-clock phase so every pet shares the same downbeat; personalitySeed adds tiny de-sync.
-- beatMult: 1 = quarter notes at current BPM, 2 = double-time, 0.5 = half-time.
local function beatPhase(state: AnimState, beatMult: number?): number
	local m = if beatMult == nil then 1 else beatMult
	return os.clock() * beatsPerSecond() * m * TWO_PI + state.personalitySeed * 0.003
end

local activeAnims: { [Model]: AnimState } = {}

local function discoverBones(model: Model): (BoneCache, { Bone })
	local cache: BoneCache = {}
	local list: { Bone } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("Bone") then
			cache[desc.Name] = desc
			table.insert(list, desc)
		end
	end
	return cache, list
end

local function analyzeSkeletonFromBones(bones: BoneCache, boneList: { Bone }): SkeletonInfo
	local rootBone: Bone? = nil
	for _, b in boneList do
		if not b.Parent or not b.Parent:IsA("Bone") then
			rootBone = b
			break
		end
	end

	if not rootBone then
		local allNames = {}
		for _, b in boneList do
			table.insert(allNames, b.Name)
		end
		return {
			root = nil,
			spine = {},
			limbs = {},
			tips = {},
			all = allNames,
			count = #boneList,
		}
	end

	local childrenMap: { [string]: { Bone } } = {}
	for _, b in boneList do
		if b.Parent and b.Parent:IsA("Bone") then
			local pName = b.Parent.Name
			if not childrenMap[pName] then
				childrenMap[pName] = {}
			end
			table.insert(childrenMap[pName], b)
		end
	end

	local spine: { string } = {}
	local current: Bone? = rootBone
	while current do
		table.insert(spine, current.Name)
		local kids = childrenMap[current.Name]
		if kids and #kids == 1 then
			current = kids[1]
		else
			break
		end
	end

	local limbs: { { string } } = {}
	local tips: { string } = {}
	local lastSpine = spine[#spine]
	if lastSpine then
		local branchKids = childrenMap[lastSpine]
		if branchKids then
			for _, kid in branchKids do
				local chain: { string } = {}
				local cur: Bone? = kid
				while cur do
					table.insert(chain, cur.Name)
					local cKids = childrenMap[cur.Name]
					if cKids and #cKids == 1 then
						cur = cKids[1]
					else
						if cKids then
							for _, subKid in cKids do
								table.insert(tips, subKid.Name)
							end
						end
						cur = nil
					end
				end
				if #chain > 0 then
					table.insert(limbs, chain)
					table.insert(tips, chain[#chain])
				end
			end
		end
	end

	local allNames = {}
	for _, b in boneList do
		table.insert(allNames, b.Name)
	end

	return {
		root = rootBone.Name,
		spine = spine,
		limbs = limbs,
		tips = tips,
		all = allNames,
		count = #boneList,
	}
end

local function applyBoneTransform(bone: Bone, rx: number, ry: number, rz: number, lx: number, ly: number, lz: number)
	bone.Transform = CFrame.new(lx, ly, lz)
		* CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

local function resetBone(bone: Bone)
	bone.Transform = CFrame.identity
end

local function rarityToJuice(rarity: string?): number
	if not rarity then
		return 1
	end
	local r = string.lower(rarity)
	if r == "legendary" or r == "mythic" or r == "secret" then
		return 1.18
	end
	if r == "epic" then
		return 1.12
	end
	if r == "rare" then
		return 1.07
	end
	if r == "uncommon" then
		return 1.04
	end
	return 1
end

local EMOTE_DURATION: { [string]: number } = {
	landing = 0.38,
	coin = 0.55,
	-- Idle random emotes: long, readable beats (seconds).
	stretch = 6.75,
	shake = 3.85,
	playbow = 2.45,
}

local CURIOUS_LOOK_RANGE = 42
local CURIOUS_BLEND_LOOK = 0.78

local function hashString(s: string): number
	local h = 0
	for i = 1, #s do
		h = (h * 131 + string.byte(s, i)) % 100000
	end
	return h
end

local function pickCuriousLookTarget(model: Model, seed: number): Vector3?
	local pp = model.PrimaryPart
	if not pp then
		return nil
	end
	local origin = model:GetPivot().Position
	local playersList: { Vector3 } = {}
	local petsList: { Vector3 } = {}

	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		if ch then
			local head = ch:FindFirstChild("Head") :: BasePart?
			if head then
				local d = (head.Position - origin).Magnitude
				if d < CURIOUS_LOOK_RANGE and d > 1.5 then
					table.insert(playersList, head.Position)
				end
			end
		end
	end

	local function considerPetModel(other: Model)
		if other == model then
			return
		end
		local op = other.PrimaryPart
		if not op then
			return
		end
		local d = (op.Position - origin).Magnitude
		if d >= CURIOUS_LOOK_RANGE or d <= 1.5 then
			return
		end
		local _, sz = other:GetBoundingBox()
		local aim = op.Position + Vector3.new(0, math.clamp(sz.Y * 0.35, 0.2, 2.5), 0)
		table.insert(petsList, aim)
	end

	local activeFolder = workspace:FindFirstChild("ActivePets")
	if activeFolder then
		for _, child in activeFolder:GetChildren() do
			if child:IsA("Model") then
				considerPetModel(child)
			end
		end
	end

	local np, nPet = #playersList, #petsList
	if np == 0 and nPet == 0 then
		return nil
	end
	local roll = (hashString(model.Name) + seed * 3) % 100
	if roll < 48 and np > 0 then
		local i = (hashString(model.Name) + seed) % np + 1
		return playersList[i]
	elseif nPet > 0 then
		local i = (hashString(model.Name) + seed * 7) % nPet + 1
		return petsList[i]
	elseif np > 0 then
		local i = (hashString(model.Name) + seed * 11) % np + 1
		return playersList[i]
	end
	return nil
end

local function lookYawPitchTowardWorld(model: Model, target: Vector3): (number, number)
	local cf = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local eyeLift = math.clamp(size.Y * 0.22, 0.25, 1.2)
	local eye = cf.Position + cf.UpVector * eyeLift
	local dir = target - eye
	if dir.Magnitude < 0.08 then
		return 0, 0
	end
	dir = dir.Unit
	local localDir = cf:VectorToObjectSpace(dir)
	local yaw = math.deg(math.atan2(localDir.X, -localDir.Z))
	local pitch = math.deg(math.asin(math.clamp(localDir.Y, -1, 1)))
	return yaw, pitch
end

local function applyEmoteOverlay(state: AnimState)
	local id = state.emoteId
	local emoteStart = state.emoteStart
	if not id or emoteStart == nil then
		return
	end
	local dur = state.emoteDuration or EMOTE_DURATION[id] or 0.45
	local et = os.clock() - emoteStart
	if et >= dur then
		state.emoteId = nil
		state.emoteStart = nil
		state.emoteDuration = nil
		state.emoteLookTarget = nil
		return
	end

	local bones = state.bones
	local skel = state.skeleton
	local u = et / dur
	local w = math.sin(u * math.pi)
	local easeOut = 1 - (1 - u) * (1 - u)

	if id == "landing" then
		local s = math.sin(u * math.pi)
		if skel.root then
			local b = bones[skel.root]
			if b then
				b.Transform = b.Transform * CFrame.new(0, -0.04 * s, 0) * CFrame.Angles(math.rad(14 * s), 0, 0)
			end
		end
	elseif id == "coin" then
		local bounce = math.sin(u * math.pi * 3) * easeOut * easeOut
		local wiggle = math.sin(u * math.pi * 5) * (1 - u) * 6
		if skel.root then
			local b = bones[skel.root]
			if b then
				b.Transform = b.Transform
					* CFrame.Angles(math.rad(-10 * bounce), math.rad(12 * bounce + wiggle * 0.3), math.rad(4 * bounce))
			end
		end
		for _, name in skel.tips do
			local b = bones[name]
			if b then
				b.Transform = b.Transform * CFrame.Angles(math.rad(18 * bounce), math.rad(10 * bounce), math.rad(12 * bounce))
			end
		end
	elseif id == "stretch" then
		-- sin(pi*u): 0 at start & end so the pose eases back smoothly (no head snap).
		local env = math.sin(u * math.pi)
		local s = env * env
		local arch = math.sin(u * math.pi * 2) * 0.35 * env
		if skel.root then
			local b = bones[skel.root]
			if b then
				b.Transform = b.Transform
					* CFrame.Angles(math.rad(-18 * s), math.rad(5 * arch + 3 * s), 0)
					* CFrame.new(0, 0.06 * s, -0.06 * s)
			end
		end
		local spineN = #skel.spine
		for i, name in skel.spine do
			local b = bones[name]
			if b and spineN > 0 and i > 1 then
				local pct = i / spineN
				b.Transform = b.Transform * CFrame.Angles(math.rad(26 * s * pct), math.rad(8 * arch * pct), 0)
			end
		end
		for limbIdx, chain in skel.limbs do
			local side = if limbIdx % 2 == 1 then 1 else -1
			for j, name in chain do
				local b = bones[name]
				if b then
					local reach = (j / #chain) * s
					b.Transform = b.Transform * CFrame.Angles(math.rad(12 * reach), math.rad(-6 * side * reach), math.rad(4 * side * reach))
				end
			end
		end
		for _, name in skel.tips do
			local b = bones[name]
			if b then
				b.Transform = b.Transform * CFrame.Angles(math.rad(-32 * s), math.rad(10 * arch), math.rad(22 * s))
			end
		end
	elseif id == "shake" then
		-- "Curious" (id kept as shake): glance at nearby player heads / other pets; wobble fills the rest.
		local seed = state.personalitySeed
		local env = math.sin(u * math.pi)
		local t = u * math.pi * 4.5
		local yawP =
			(math.sin(t + seed * 0.07) * 0.55 + math.sin(t * 1.35 + seed * 0.11) * 0.35 + math.sin(t * 2.1 + seed * 0.03) * 0.1)
				* 32
		local pitchP =
			(math.sin(t * 0.82 + seed * 0.13) * 0.5 + math.sin(t * 1.65 + seed * 0.05) * 0.35 + math.sin(t * 2.4 + seed * 0.09) * 0.15)
				* 14
		local rollP = math.sin(t * 0.55 + seed * 0.19) * 7

		if state.emoteLookTarget == nil then
			state.emoteLookTarget = pickCuriousLookTarget(state.model, seed)
		end
		local target = state.emoteLookTarget
		local lookYaw, lookPitch = 0, 0
		if target then
			lookYaw, lookPitch = lookYawPitchTowardWorld(state.model, target)
			lookYaw = math.clamp(lookYaw, -48, 48)
			lookPitch = math.clamp(lookPitch, -28, 28)
		end
		local bLook = CURIOUS_BLEND_LOOK
		if not target then
			bLook = 0
		end
		local yaw = (lookYaw * bLook + yawP * (1 - bLook)) * env
		local pitch = (lookPitch * bLook + pitchP * (1 - bLook)) * env
		local roll = rollP * env

		if skel.root then
			local b = bones[skel.root]
			if b then
				b.Transform = b.Transform
					* CFrame.Angles(math.rad(pitch * 0.2), math.rad(yaw * 0.18), math.rad(roll * 0.15))
			end
		end
		local spineN = #skel.spine
		for i, name in skel.spine do
			local b = bones[name]
			if b and spineN > 0 and i > 1 then
				local pct = i / spineN
				b.Transform = b.Transform
					* CFrame.Angles(math.rad(pitch * 0.35 * pct), math.rad(yaw * 0.4 * pct), math.rad(roll * 0.2 * pct))
			end
		end
		for _, name in skel.tips do
			local b = bones[name]
			if b then
				b.Transform = b.Transform * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
			end
		end
	elseif id == "playbow" then
		local s = w
		local dip = smoothstep01(u)
		if skel.root then
			local b = bones[skel.root]
			if b then
				b.Transform = b.Transform * CFrame.Angles(math.rad(38 * s), math.rad(10 * dip * s), 0) * CFrame.new(0, -0.09 * s, 0.12 * s)
			end
		end
		for i, name in skel.spine do
			local b = bones[name]
			if b and i > 1 then
				local pct = i / #skel.spine
				b.Transform = b.Transform * CFrame.Angles(math.rad(20 * s * pct), 0, 0)
			end
		end
		for limbIdx, chain in skel.limbs do
			for j, name in chain do
				local b = bones[name]
				if b then
					local reach = (j / #chain) * s
					b.Transform = b.Transform * CFrame.Angles(math.rad(14 * reach), 0, 0)
				end
			end
		end
		for _, name in skel.tips do
			local b = bones[name]
			if b then
				b.Transform = b.Transform * CFrame.Angles(math.rad(-32 * s), 0, math.rad(6 * dip * s))
			end
		end
	end
end

local function genericIdle(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones
	local J = state.juiceMul
	local seed = state.personalitySeed * 0.017
	local ph = seed

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	-- Breathing + slow sway; layered "perk" bursts (fast + medium) so idle feels alive often
	local breathe = osc(t, 0.52, 0.85 * J, ph)
	local sway = osc(t, 0.31, 1.2 * J, ph + 1.1)
	-- ^2 on positive lobe = frequent visible bumps; two rates so it doesn't feel one-note
	local perkA = (math.max(0, math.sin(t * 4.8 + seed)) ^ 2) * 2.2 * J
	local perkB = (math.max(0, math.sin(t * 2.4 + seed * 1.7)) ^ 2) * 1.4 * J
	local perk = perkA + perkB
	local q = beatPhase(state, 1)
	local beatNod = 0.09 * J * math.sin(q)

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(
				b,
				1.6 * breathe + perk + beatNod, sway * 0.28, osc(t, 0.38, 1.0 * J, ph),
				0, 0, osc(t, 1, 0.018 * J) + perk * 0.0012 + 0.0006 * math.sin(q)
			)
		end
	end

	local spineN = #skel.spine
	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = if spineN > 0 then i / spineN else 0
			local amp = (1.4 + 0.9 * pct) * J
			local headTilt = if i == spineN then osc(t, 0.35, 2.2 * J, ph) else 0
			applyBoneTransform(
				b,
				osc(t, 1, amp, 0.3 * i + ph) + headTilt * 0.2 + perk * 0.14 * pct,
				osc(t, 0.78, amp * 0.32, 0.5 * i + ph),
				osc(t, 1, amp * 0.38, 0.5 * i) + headTilt * 0.28 + perk * 0.1 * pct,
				0, 0, 0
			)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 1.2 + ph
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = (2 * (j / #chain)) * J
				applyBoneTransform(b, osc(t, 1, amp, phase) + perk * 0.1, osc(t, 1.25, amp * 0.42, phase), perk * 0.06 * (j / #chain), 0, 0, 0)
			end
		end
	end

	for _, name in skel.tips do
		local b = bones[name]
		if b then
			applyBoneTransform(
				b,
				osc(t, 1.1, (1.1 + perk * 0.35) * J, ph),
				osc(t, 1.4, (0.9 + perk * 0.25) * J, ph + 1),
				osc(t, 1.0, (0.85 + perk * 0.3) * J, ph),
				0,
				0,
				0
			)
		end
	end
end

local function genericWalk(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	-- Global BPM grid: quarter-note sway + eighth-note stride (meme-friendly "fits any song").
	local q = beatPhase(state, 1)
	local s = math.sin(q)
	local c = math.cos(q)
	local bodyWave = 0.72 * s + 0.28 * math.sin(q * 2 + 0.4)
	local stepPulse = math.max(0, s) ^ 1.35

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b,
				4.5 * bodyWave + 1.2 * math.sin(q * 2),
				2.2 * math.sin(q + 0.2),
				5.5 * s,
				0.01 * c,
				0.014 * stepPulse + 0.004 * math.sin(q * 2),
				0.012 * math.sin(q * 0.5 + math.pi * 0.25)
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = i / #skel.spine
			local lag = 0.55 * i
			local flex = 2.8 * pct
			applyBoneTransform(
				b,
				flex * math.sin(q + lag),
				1.8 * pct * math.sin(q * 0.5 + lag + 0.4),
				2.2 * pct * math.sin(q + lag + 0.2),
				0,
				0,
				0
			)
		end
	end

	local limbCount = #skel.limbs
	for limbIdx, chain in skel.limbs do
		local phase = (limbIdx - 1) * math.pi * 0.5
		local isFront = limbIdx <= math.max(1, math.ceil(limbCount / 2))
		for j, name in chain do
			local b = bones[name]
			if b then
				local along = j / #chain
				local taper = along ^ 0.85
				local baseAmp = if isFront then 11 else 14
				local swing = baseAmp * taper
				local reach = 3.5 * taper * c
				local rx = swing * math.sin(q + phase) + 0.35 * math.sin(q * 2 + phase)
				local rz = 4 * taper * math.sin(q + phase + 0.6)
				applyBoneTransform(b, rx, reach, rz, 0, 0, 0)
			end
		end
	end
end

local function genericHop(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	-- One hop per quarter note at global BPM (bounce locks to the same grid as walk).
	local q = beatPhase(state, 1)
	local airRaw = math.sin(q)
	local air01 = smoothstep01((airRaw + 1) * 0.5)
	local ground01 = 1 - air01
	local squash = math.max(0, -airRaw)
	local stretch = math.max(0, airRaw)
	local squashE = squash ^ 1.25
	local stretchE = stretch ^ 0.85

	if skel.root then
		local b = bones[skel.root]
		if b then
			local squashY = -0.028 * squashE
			local stretchY = 0.022 * stretchE
			local tiltX = -7 * stretchE * air01 + 9 * squashE * ground01
			applyBoneTransform(
				b,
				tiltX,
				2.2 * math.sin(q * 0.5 + 0.2),
				3.5 * airRaw,
				0,
				squashY + stretchY + 0.006 * math.sin(q * 2),
				0.014 * math.sin(q * 0.5 + math.pi * 0.2)
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = i / #skel.spine
			local lag = 0.35 * i
			local wave = 3 * pct * math.sin(q + lag) * (0.55 + 0.45 * air01)
			applyBoneTransform(b, wave, 1.2 * pct * math.sin(q * 0.5 + lag), 2 * pct * math.sin(q + 0.5 * i), 0, 0, 0)
		end
	end

	local limbCount = #skel.limbs
	for limbIdx, chain in skel.limbs do
		local phase = (limbIdx - 1) * 0.6
		local isFront = limbIdx <= math.max(1, math.ceil(limbCount / 2))
		for j, name in chain do
			local b = bones[name]
			if b then
				local pct = j / #chain
				local tuck = pct ^ 0.9
				local airAngle = (if isFront then 16 else 22) * tuck + 6 * math.sin(q + phase) * tuck
				local groundAngle = -(if isFront then 10 else 14) * tuck * squashE
				local rx = airAngle * air01 + groundAngle * ground01
				applyBoneTransform(b, rx + 3 * math.sin(q + phase + j) * tuck, 0, 5 * air01 * tuck * math.sin(q + phase), 0, 0, 0)
			end
		end
	end
end

local function genericSit(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	-- Quadruped sit pose + whisper of the same global beat (so "jam" still reads while sitting).
	local J = state.juiceMul
	local breathe = osc(t, 0.32, 1.1)
	local q = beatPhase(state, 1)
	local sitJamPitch = 0.11 * math.sin(q)
	local sitJamRoll = 0.07 * J * math.sin(q * 0.5 + 0.2)

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(
				b,
				-14 + 0.8 * breathe + sitJamPitch,
				0,
				sitJamRoll,
				0,
				-0.07 + osc(t, 0.32, 0.012),
				osc(t, 0.28, 0.006) + 0.0005 * math.sin(q)
			)
		end
	end

	local spineN = #skel.spine
	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = if spineN > 1 then (i - 1) / (spineN - 1) else 0
			local arch = 22 * (1 - pct) * (1 - pct)
			local lift = 8 * pct * pct
			applyBoneTransform(
				b,
				arch - lift + 0.4 * breathe + 0.15 * pct * math.sin(q + 0.1 * i),
				0,
				osc(t, 0.45, 2.5 * pct, 0.15 * i) + 0.2 * pct * math.sin(q * 0.5),
				0,
				0,
				0
			)
		end
	end

	local limbCount = #skel.limbs
	local half = math.max(1, math.ceil(limbCount / 2))
	for limbIdx, chain in skel.limbs do
		local isFront = limbIdx <= half
		for j, name in chain do
			local b = bones[name]
			if b then
				local along = j / #chain
				local taper = along ^ 0.9
				if isFront then
					local brace = -12 * taper
					applyBoneTransform(b, brace + 2 * breathe * taper, 0, 4 * taper, 0, 0, 0)
				else
					local fold = (42 + 8 * along) * taper
					applyBoneTransform(
						b,
						fold + 1.5 * breathe * taper + 0.25 * taper * math.sin(q + limbIdx),
						osc(t, 0.4, 3 * taper, limbIdx),
						6 * taper,
						0,
						0,
						0
					)
				end
			end
		end
	end

	for _, name in skel.tips do
		local b = bones[name]
		if b then
			applyBoneTransform(
				b,
				osc(t, 0.55, 2.2, 0) + 0.35 * math.sin(q),
				0,
				osc(t, 0.38, 1.6, 0.5) + 0.25 * math.sin(q * 0.5),
				0,
				0,
				0
			)
		end
	end
end

local function genericGriddy(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	-- Double-time vs walk so the dance feels busy, still on the same global BPM grid.
	local qg = beatPhase(state, 2)
	local bounce = math.abs(math.sin(qg))
	local down = -bounce

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b,
				4 * down, 3 * math.sin(qg * 0.5 + 0.1), 0,
				0, -0.025 * bounce, 0
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = i / #skel.spine
			applyBoneTransform(b,
				-3 * pct * down,
				2 * pct * math.sin(qg * 0.5 + 0.3 * i),
				0, 0, 0, 0
			)
		end
	end

	for limbIdx, chain in skel.limbs do
		local isLeft = limbIdx % 2 == 0
		local legPhase = if isLeft then 0 else math.pi
		for j, name in chain do
			local b = bones[name]
			if b then
				local pct = j / #chain
				local kneePump = math.sin(qg + legPhase)

				if limbIdx <= math.ceil(#skel.limbs / 2) then
					applyBoneTransform(b,
						8 * pct * math.sin(qg + legPhase),
						0,
						5 * pct * math.sin(qg * 0.5 + limbIdx),
						0, 0, 0
					)
				else
					local bend = 25 * pct * math.max(0, kneePump)
					local extend = -8 * pct * math.max(0, -kneePump)
					applyBoneTransform(b, bend + extend, 0, 0, 0, 0, 0)
				end
			end
		end
	end

	for _, name in skel.tips do
		local b = bones[name]
		if b then
			applyBoneTransform(b, 6 * math.sin(qg), 0, 4 * math.sin(qg * 0.5 + 1), 0, 0, 0)
		end
	end
end

local function genericFloat(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	-- Half-time sway + faster shimmer, same downbeat as walk/hop.
	local q = beatPhase(state, 1)

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b,
				3 * math.sin(q * 0.5) + 1.2 * math.sin(q * 2),
				0,
				0,
				0, 0, 0.03 + 0.015 * math.abs(math.sin(q))
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 4 * (i / #skel.spine)
			applyBoneTransform(b,
				amp * math.sin(q * 0.5 + 0.6 * i),
				amp * 0.3 * math.sin(q * 0.5 + 0.4 * i),
				0, 0, 0, 0
			)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 0.8
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 5 * (j / #chain)
				local frx = amp * math.sin(q + phase + j * 0.3)
				local frz = amp * 0.5 * math.sin(q * 0.5 + phase)
				applyBoneTransform(b, frx, 0, frz, 0, 0, 0)
			end
		end
	end
end

local function jellyIdle(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b, 0, 0, 0, 0, 0, osc(t, 2, 0.01))
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 6 * (i / #skel.spine)
			applyBoneTransform(b, osc(t, 0.5, amp, 0.8 * i), osc(t, 0.5, amp * 0.4, i), 0, 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 1.5
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 10 * (j / #chain)
				applyBoneTransform(b, osc(t, 0.5, amp, phase + j * 0.6), 0, osc(t, 0.5, amp * 0.5, phase), 0, 0, 0)
			end
		end
	end
end

local function jellyWalk(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b, 0, 0, 0, 0, 0, osc(t, 3, 0.02))
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 8 * (i / #skel.spine)
			applyBoneTransform(b, osc(t, 3, amp, 0.5 * i), 0, osc(t, 1.5, amp * 0.3, i), 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 1.2
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 14 * (j / #chain)
				applyBoneTransform(b, osc(t, 1, amp, phase + j * 0.8), osc(t, 0.5, amp * 0.3, phase), 0, 0, 0, 0)
			end
		end
	end
end

local function jellyFloat(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b, osc(t, 0.33, 2), 0, 0, 0, 0, 0.03 + osc(t, 0.5, 0.01))
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 5 * (i / #skel.spine)
			applyBoneTransform(b, osc(t, 0.33, amp, 1.0 * i), osc(t, 0.25, amp * 0.4, 0.7 * i), 0, 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 2.0
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 8 * (j / #chain)
				applyBoneTransform(b, osc(t, 0.33, amp, phase + j * 1.0), 0, osc(t, 0.25, amp * 0.5, phase + 0.5), 0, 0, 0)
			end
		end
	end
end

local function whaleIdle(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b, 0, osc(t, 0.5, 2), 0, 0, 0, osc(t, 1, 0.01))
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 5 * (i / #skel.spine)
			applyBoneTransform(b, 0, osc(t, 0.5, amp, 0.6 * i), 0, 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 0.8
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 4 * (j / #chain)
				applyBoneTransform(b, osc(t, 0.5, amp * 0.5, phase), osc(t, 0.5, amp, phase + j * 0.3), 0, 0, 0, 0)
			end
		end
	end
end

local function whaleFloat(state: AnimState, t: number)
	local skel = state.skeleton
	local bones = state.bones

	for _, name in skel.all do
		local b = bones[name]
		if b then
			resetBone(b)
		end
	end

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b,
				osc(t, 0.33, 3), osc(t, 0.25, 2), 0,
				0, 0, 0.03 + osc(t, 0.5, 0.015)
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 6 * (i / #skel.spine)
			applyBoneTransform(b, 0, osc(t, 0.33, amp, 0.7 * i), osc(t, 0.25, amp * 0.3, i), 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 1.0
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 6 * (j / #chain)
				applyBoneTransform(b, osc(t, 0.33, amp * 0.5, phase), osc(t, 0.33, amp, phase + j * 0.4), 0, 0, 0, 0)
			end
		end
	end
end

type AnimFn = (state: AnimState, t: number) -> ()

local ANIM_REGISTRY: { [string]: { [string]: AnimFn } } = {
	_generic = {
		idle = genericIdle,
		walk = genericWalk,
		hop = genericHop,
		float = genericFloat,
		sit = genericSit,
		griddy = genericGriddy,
	},
	jellyfish = {
		idle = jellyIdle,
		walk = jellyWalk,
		float = jellyFloat,
	},
	whale = {
		idle = whaleIdle,
		walk = genericWalk,
		float = whaleFloat,
	},
}

local function resolveAnimFn(petName: string, animName: string): AnimFn
	local petSet = ANIM_REGISTRY[petName]
	if petSet and petSet[animName] then
		return petSet[animName]
	end
	local generic = ANIM_REGISTRY._generic
	if generic[animName] then
		return generic[animName]
	end
	return genericIdle
end

local function resolvePetName(model: Model): string
	local name = string.lower(model.Name)
	if ANIM_REGISTRY[name] then
		return name
	end
	if string.find(name, "jelly") then
		return "jellyfish"
	end
	if string.find(name, "whale") then
		return "whale"
	end
	return "_generic"
end

local function readPersonalitySeed(model: Model): number
	local a = model:GetAttribute("PetPersonalitySeed")
	if type(a) == "number" then
		return a
	end
	return 0
end

local function beginHeartbeat(state: AnimState)
	local model = state.model
	if state.connection then
		state.connection:Disconnect()
	end
	state.connection = RunService.Heartbeat:Connect(function(_dt)
		if not model.Parent then
			PetAnimator.stop(model)
			return
		end

		if not state.fullAnimation then
			return
		end

		local t = os.clock() - state.startTime
		local petName = resolvePetName(model)
		local animFn = resolveAnimFn(petName, state.animName)
		animFn(state, t)
		applyEmoteOverlay(state)
	end)
end

function PetAnimator.start(model: Model, animName: string, fullAnimation: boolean?, rarity: string?)
	if activeAnims[model] then
		PetAnimator.stop(model)
	end

	local full = if fullAnimation == nil then true else fullAnimation
	local bones, boneList = discoverBones(model)
	local skeleton = analyzeSkeletonFromBones(bones, boneList)

	local state: AnimState = {
		model = model,
		animName = animName,
		fullAnimation = full,
		bones = bones,
		boneList = boneList,
		skeleton = skeleton,
		startTime = os.clock(),
		connection = nil,
		juiceMul = rarityToJuice(rarity),
		personalitySeed = readPersonalitySeed(model),
		emoteId = nil,
		emoteStart = nil,
		emoteDuration = nil,
		emoteLookTarget = nil,
	}

	beginHeartbeat(state)

	activeAnims[model] = state
end

function PetAnimator.setAnim(model: Model, animName: string)
	local state = activeAnims[model]
	if not state then
		return
	end

	if state.animName == animName then
		return
	end

	state.animName = animName
	state.startTime = os.clock()

	beginHeartbeat(state)
end

function PetAnimator.playEmote(model: Model, emoteId: string, duration: number?)
	local state = activeAnims[model]
	if not state then
		return
	end
	state.emoteId = emoteId
	state.emoteStart = os.clock()
	state.emoteDuration = duration or EMOTE_DURATION[emoteId]
	state.emoteLookTarget = nil
end

function PetAnimator.setFullAnimation(model: Model, enabled: boolean)
	local state = activeAnims[model]
	if not state then
		return
	end
	state.fullAnimation = enabled
	if not enabled then
		for _, bone in state.boneList do
			resetBone(bone)
		end
	end
end

function PetAnimator.stop(model: Model)
	local state = activeAnims[model]
	if not state then
		return
	end

	if state.connection then
		state.connection:Disconnect()
		state.connection = nil
	end

	state.emoteId = nil
	state.emoteStart = nil
	state.emoteDuration = nil
	state.emoteLookTarget = nil

	for _, bone in state.boneList do
		resetBone(bone)
	end

	activeAnims[model] = nil
end

function PetAnimator.isActive(model: Model)
	return activeAnims[model] ~= nil
end

function PetAnimator.getAnimName(model: Model)
	local state = activeAnims[model]
	if state then
		return state.animName
	end
	return nil
end

function PetAnimator.isEmotePlaying(model: Model): boolean
	local state = activeAnims[model]
	if not state or state.emoteId == nil or state.emoteStart == nil then
		return false
	end
	local dur = state.emoteDuration or EMOTE_DURATION[state.emoteId] or 0.45
	return os.clock() - state.emoteStart < dur
end

PetAnimator.LOD_DISTANCE = PET_ANIM_LOD_DISTANCE

function PetAnimator.setBpm(bpm: number)
	currentBpm = math.clamp(bpm, 48, 220)
end

function PetAnimator.getBpm()
	return currentBpm
end

return PetAnimator
