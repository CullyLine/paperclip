--!strict
-- Canonical module: ReplicatedStorage.DAC.Config.HatchCrackVisualSpec (client + server can require).
-- This file remains as a stable path for design-doc cross-references.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
return require(DAC:WaitForChild("Config"):WaitForChild("HatchCrackVisualSpec"))
