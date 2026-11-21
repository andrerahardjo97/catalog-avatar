local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage.Avatar.Look)
local Remotes = ReplicatedStorage.Remotes

local MAX_CACHE = 300
local MAX_BULK = 20

local looks = {}
local busy = {}
local cache = {}
local cacheSize = 0

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function cached(key: string, fetch: () -> HumanoidDescription): (boolean, any)
	local hit = cache[key]
	if hit then
		return true, Look.copy(hit)
	end
	local ok, description = pcall(fetch)
	if not ok then
		warn("AvatarService fetch", key, description)
		return false, "That look could not be loaded."
	end
	local look = Look.fromDescription(description)
	description:Destroy()
	if cacheSize >= MAX_CACHE then
		table.clear(cache)
		cacheSize = 0
	end
	cache[key] = look
	cacheSize += 1
	return true, Look.copy(look)
end

local function applyLook(player: Player, look: Look.Look): (boolean, any)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return false, "Your character is not ready."
	end
	local description = Look.toDescription(look)
	local okConform, conformed = pcall(function(): HumanoidDescription
		return AvatarEditorService:ConformToAvatarRulesAsync(description)
	end)
	if okConform and conformed then
		description:Destroy()
		description = conformed
	end
	local ok, err = pcall(function(): ()
		humanoid:ApplyDescriptionAsync(description)
	end)
	description:Destroy()
	if not ok then
		warn("AvatarService apply", player.Name, err)
		return false, "That look could not be worn."
	end
	local applied = Look.fromDescription(humanoid:GetAppliedDescription())
	applied.bundles = look.bundles
	if player.Parent then
		looks[player] = applied
	end
	return true, Look.copy(applied)
end

local handlers = {}

function handlers.current(player: Player, _payload: any): (boolean, any)
	local saved = looks[player]
	if saved then
		return true, Look.copy(saved)
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return false, "Your character is not ready."
	end
	return true, Look.fromDescription(humanoid:GetAppliedDescription())
end

function handlers.apply(player: Player, payload: any): (boolean, any)
	local look = Look.sanitize(payload)
	if not look then
		return false, "That look is not valid."
	end
	return applyLook(player, look)
end

function handlers.user(_player: Player, userId: any): (boolean, any)
	if not Look.isId(userId) then
		return false, "That user is not valid."
	end
	return cached("user" .. userId, function(): HumanoidDescription
		return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	end)
end

function handlers.name(player: Player, name: any): (boolean, any)
	if type(name) ~= "string" or #name < 3 or #name > 20 or not string.match(name, "^[%w_]+$") then
		return false, "Enter a valid username."
	end
	local ok, userId = pcall(function(): number
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not ok then
		return false, "No user is named " .. name .. "."
	end
	return handlers.user(player, userId)
end

function handlers.outfit(_player: Player, outfitId: any): (boolean, any)
	if not Look.isId(outfitId) then
		return false, "That outfit is not valid."
	end
	return cached("outfit" .. outfitId, function(): HumanoidDescription
		return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfitId)
	end)
end

function handlers.bundle(_player: Player, bundleId: any): (boolean, any)
	if not Look.isId(bundleId) then
		return false, "That bundle is not valid."
	end
	return cached("bundle" .. bundleId, function(): HumanoidDescription
		local details = AvatarEditorService:GetItemDetailsAsync(bundleId, Enum.AvatarItemType.Bundle)
		for _, item in details.BundledItems or {} do
			if item.Type == "UserOutfit" then
				return Players:GetHumanoidDescriptionFromOutfitIdAsync(item.Id)
			end
		end
		error("Bundle " .. bundleId .. " has no outfit")
	end)
end

Remotes.Avatar.OnServerInvoke = function(player: Player, kind: any, payload: any): (boolean, any)
	local handler = if type(kind) == "string" then handlers[kind] else nil
	if not handler then
		return false, "Unknown request."
	end
	if busy[player] then
		return false, "Please wait a moment."
	end
	busy[player] = true
	local ok, success, result = pcall(handler, player, payload)
	busy[player] = nil
	if not ok then
		warn("AvatarService", kind, success)
		return false, "Something went wrong."
	end
	return success, result
end

Remotes.Purchase.OnServerEvent:Connect(function(player, kind, payload)
	if kind == "asset" and Look.isId(payload) then
		MarketplaceService:PromptPurchase(player, payload)
	elseif kind == "bundle" and Look.isId(payload) then
		MarketplaceService:PromptBundlePurchase(player, payload)
	elseif kind == "bulk" and type(payload) == "table" then
		local items = {}
		for _, entry in payload do
			if #items >= MAX_BULK then
				break
			end
			if type(entry) == "table" and Look.isId(entry.id) then
				table.insert(items, {
					Type = if entry.bundle == true
						then Enum.MarketplaceProductType.AvatarBundle
						else Enum.MarketplaceProductType.AvatarAsset,
					Id = tostring(entry.id),
				})
			end
		end
		if #items > 0 then
			local ok, err = pcall(function(): ()
				MarketplaceService:PromptBulkPurchase(player, items, {})
			end)
			if not ok then
				warn("AvatarService bulk purchase", err)
			end
		end
	end
end)

local function onCharacter(player: Player, character: Model)
	local look = looks[player]
	if not look then
		return
	end
	while not player:HasAppearanceLoaded() or busy[player] do
		if player.Character ~= character or not player.Parent then
			return
		end
		task.wait(0.1)
	end
	if player.Character ~= character or not player.Parent then
		return
	end
	busy[player] = true
	applyLook(player, looks[player] or look)
	busy[player] = nil
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	looks[player] = nil
	busy[player] = nil
end)
