--!strict
--[[
	Procedural bone animation engine for pets.
	Drives Bone.Transform CFrames via RunService.Heartbeat using sinusoidal oscillators.
	Supports per-pet custom animation sets with a generic fallback.

	API:
	  PetAnimator.start(model, animName, fullAnimation?)
	  PetAnimator.setAnim(model, animName)
	  PetAnimator.stop(model)

	fullAnimation=false applies only a simple float-bob (for remote pets with animations disabled).
]]

local RunService = game:GetService("RunService")

local PetAnimator = {}

local PET_ANIM_LOD_DISTANCE = 100

local TWO_PI = 2 * math.pi

local BREATHE_SPEED = 1.2
local BREATHE_AMOUNT = 0.03

local function osc(t: number, cycles: number, amplitude: number, phase: number?): number
	return amplitude * math.sin(t * cycles * TWO_PI + (phase or 0))
end

type BoneCache = { [string]: Bone }

type AnimState = {
	model: Model,
	animName: string,
	fullAnimation: boolean,
	bones: BoneCache,
	boneList: { Bone },
	skeleton: SkeletonInfo,
	baseScale: number,
	startTime: number,
	connection: RBXScriptConnection?,
}

type SkeletonInfo = {
	root: string?,
	spine: { string },
	limbs: { { string } },
	tips: { string },
	all: { string },
	count: number,
}

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

local function genericIdle(state: AnimState, t: number)
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
			applyBoneTransform(b, 0, 0, 0, 0, 0, osc(t, 1, 0.02))
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 2 * (i / #skel.spine)
			applyBoneTransform(b, osc(t, 1, amp, 0.3 * i), 0, osc(t, 1, amp * 0.5, 0.5 * i), 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = limbIdx * 1.2
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 3 * (j / #chain)
				applyBoneTransform(b, osc(t, 1, amp, phase), 0, 0, 0, 0, 0)
			end
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

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b,
				0, osc(t, 2, 3), 0,
				osc(t, 2, 0.005), 0, osc(t, 1, 0.015)
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 3 * (i / #skel.spine)
			applyBoneTransform(b, osc(t, 2, amp, 0.4 * i), 0, osc(t, 1, amp * 0.3), 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = if limbIdx % 2 == 0 then 0 else math.pi
		for j, name in chain do
			local b = bones[name]
			if b then
				local amp = 15 * (j / #chain)
				applyBoneTransform(b, osc(t, 2, amp, phase), 0, 0, 0, 0, 0)
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

	local hopCycle = (t * 3.5 * TWO_PI) % TWO_PI
	local airPhase = math.sin(hopCycle)
	local airborne = airPhase > 0
	local squash = math.max(0, -airPhase)
	local stretch = math.max(0, airPhase)

	if skel.root then
		local b = bones[skel.root]
		if b then
			local squashY = -0.02 * squash
			local stretchY = 0.015 * stretch
			local tiltX = -4 * stretch + 6 * squash
			applyBoneTransform(b, tiltX, osc(t, 1.75, 2), 0, 0, squashY + stretchY, 0)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = i / #skel.spine
			local wave = osc(t, 3.5, 2.5 * pct, 0.3 * i)
			applyBoneTransform(b, wave, 0, osc(t, 1.75, 1.5 * pct, 0.5 * i), 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local phase = if limbIdx % 2 == 0 then 0 else math.pi * 0.25
		for j, name in chain do
			local b = bones[name]
			if b then
				local pct = j / #chain
				if airborne then
					applyBoneTransform(b, 12 * pct + osc(t, 3.5, 5 * pct, phase), 0, 0, 0, 0, 0)
				else
					applyBoneTransform(b, -8 * pct * squash, 0, 0, 0, 0, 0)
				end
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

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b, 8, 0, 0, 0, -0.03, osc(t, 0.4, 0.008))
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local pct = i / #skel.spine
			applyBoneTransform(b, osc(t, 0.4, 1.5 * pct, 0.2 * i), 0, 0, 0, 0, 0)
		end
	end

	for limbIdx, chain in skel.limbs do
		local isFront = limbIdx <= 2
		for j, name in chain do
			local b = bones[name]
			if b then
				if isFront then
					applyBoneTransform(b, -5 * (j / #chain), 0, 0, 0, 0, 0)
				else
					applyBoneTransform(b, 20 * (j / #chain), 0, 0, 0, 0, 0)
				end
			end
		end
	end

	for _, name in skel.tips do
		local b = bones[name]
		if b then
			applyBoneTransform(b, osc(t, 0.6, 3, 0), 0, osc(t, 0.4, 2, 0.5), 0, 0, 0)
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

	if skel.root then
		local b = bones[skel.root]
		if b then
			applyBoneTransform(b,
				osc(t, 0.5, 3), 0, 0,
				0, 0, 0.03 + osc(t, 1, 0.015)
			)
		end
	end

	for i, name in skel.spine do
		local b = bones[name]
		if b and i > 1 then
			local amp = 4 * (i / #skel.spine)
			applyBoneTransform(b,
				osc(t, 0.5, amp, 0.6 * i),
				osc(t, 0.33, amp * 0.3, 0.4 * i),
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
				applyBoneTransform(b,
					osc(t, 0.5, amp, phase + j * 0.3),
					0,
					osc(t, 0.33, amp * 0.5, phase),
					0, 0, 0
				)
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

function PetAnimator.start(model: Model, animName: string, fullAnimation: boolean?)
	if activeAnims[model] then
		PetAnimator.stop(model)
	end

	local full = if fullAnimation == nil then true else fullAnimation
	local bones, boneList = discoverBones(model)
	local skeleton = analyzeSkeletonFromBones(bones, boneList)
	local petName = resolvePetName(model)

	local baseScale = model:GetScale()

	local state: AnimState = {
		model = model,
		animName = animName,
		fullAnimation = full,
		bones = bones,
		boneList = boneList,
		skeleton = skeleton,
		baseScale = baseScale,
		startTime = os.clock(),
		connection = nil,
	}

	local animFn = resolveAnimFn(petName, animName)

	state.connection = RunService.Heartbeat:Connect(function(_dt)
		if not model.Parent then
			PetAnimator.stop(model)
			return
		end

		if not full then
			return
		end

		local t = os.clock() - state.startTime
		animFn(state, t)

		-- Squishy toy breathing: subtle scale pulse
		local breathe = 1 + math.sin(t * BREATHE_SPEED * TWO_PI) * BREATHE_AMOUNT
		model:ScaleTo(baseScale * breathe)
	end)

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

	local petName = resolvePetName(model)
	local animFn = resolveAnimFn(petName, animName)

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
		animFn(state, t)
	end)
end

function PetAnimator.setFullAnimation(model: Model, full: boolean)
	local state = activeAnims[model]
	if not state then
		return
	end
	state.fullAnimation = full
	if not full then
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

	for _, bone in state.boneList do
		resetBone(bone)
	end

	model:ScaleTo(state.baseScale)
	activeAnims[model] = nil
end

function PetAnimator.isActive(model: Model): boolean
	return activeAnims[model] ~= nil
end

function PetAnimator.getAnimName(model: Model): string?
	local state = activeAnims[model]
	return if state then state.animName else nil
end

PetAnimator.LOD_DISTANCE = PET_ANIM_LOD_DISTANCE

return PetAnimator
