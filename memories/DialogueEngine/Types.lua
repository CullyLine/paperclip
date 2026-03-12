--[[
    Types.lua
    Type definitions for the Branching Dialogue Engine.
    All dialogue data structures are defined here for consistency.
]]

local Types = {}

export type DialogueAction = {
    type: "set" | "call",
    key: string,
    value: any?, -- only used for "set"
}

export type DialogueChoice = {
    text: string,
    targetNodeId: string,
    conditions: { [string]: any }?,
    hideWhenUnavailable: boolean?,
    actions: { DialogueAction }?,
}

export type DialogueNode = {
    speaker: string?, -- falls back to npcModel.Name when omitted
    text: string,
    portraitImageId: (string | number)?,
    npcModel: Model?, -- per-node override; usually auto-resolved from the model passed to Start()
    voiceSoundId: string?,
    choices: { DialogueChoice }?,
    isEndNode: boolean?,
    autoAdvanceDelay: number?,
    actions: { DialogueAction }?, -- fired when this node is entered
}

export type DialogueTree = {
    id: string,
    startNodeId: string,
    nodes: { [string]: DialogueNode },
}

export type ThemeConfig = {
    backgroundColor: Color3,
    backgroundTransparency: number,
    textColor: Color3,
    speakerColor: Color3,
    choiceColor: Color3,
    choiceHoverColor: Color3,
    choiceHighlightColor: Color3,
    choiceTextColor: Color3,
    choiceUnavailableColor: Color3,
    font: Enum.Font,
    speakerFont: Enum.Font,
    textSize: number,
    speakerTextSize: number,
    choiceTextSize: number,
    cornerRadius: UDim,
    portraitSize: UDim2,
    dialogueBoxSize: UDim2,
    dialogueBoxPosition: UDim2,
    typewriterSpeed: number,
    voiceVolume: number,
    padding: UDim,
    animationSpeed: number, -- multiplier for tween durations (default 1, 0 = instant/no animations)
    sfxVolume: number, -- volume for UI sound effects (0-1, default 1)
    openSoundId: string?, -- plays when dialogue opens
    closeSoundId: string?, -- plays when dialogue closes
    typewriterSoundId: string?, -- plays per character during typewriter
    typewriterSoundPitch: number?, -- random pitch variation range (default 0.1)
    choiceHoverSoundId: string?, -- plays when hovering a choice
    choiceSelectSoundId: string?, -- plays when selecting a choice
}

export type ConditionCallback = (key: string, value: any) -> boolean
export type VariableResolver = (variableName: string) -> any?

export type DialogueCallbacks = {
    conditions: { ConditionCallback }?,
    onNodeEnter: ((nodeId: string) -> ())?,
    onChoice: ((nodeId: string, choiceIndex: number) -> ())?,
    onEnd: (() -> ())?,
}

export type SavedState = {
    treeId: string,
    currentNodeId: string,
    visitedNodes: { [string]: boolean },
    timestamp: number,
}

return Types
