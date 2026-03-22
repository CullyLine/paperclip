--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

local PremiumService = {}

local premiumPlayers: { [number]: boolean } = {}

function PremiumService.isPremium(player: Player): boolean
	return premiumPlayers[player.UserId] == true
end

function PremiumService.init()
	Players.PlayerAdded:Connect(function(player)
		premiumPlayers[player.UserId] = player.MembershipType == Enum.MembershipType.Premium
	end)

	for _, player in Players:GetPlayers() do
		premiumPlayers[player.UserId] = player.MembershipType == Enum.MembershipType.Premium
	end

	Players.PlayerRemoving:Connect(function(player)
		premiumPlayers[player.UserId] = nil
	end)

	-- Handle mid-session premium purchases
	MarketplaceService.PromptPremiumPurchaseFinished:Connect(function(player)
		premiumPlayers[player.UserId] = player.MembershipType == Enum.MembershipType.Premium
		if PremiumService.isPremium(player) then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "premium_welcome",
				message = "Welcome to Premium! +50% coin earnings and daily premium gifts!",
			})
		end
	end)
end

return PremiumService
